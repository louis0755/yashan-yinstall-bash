#!/usr/bin/env bash

run_db_install() {
	local host=$1
	run_os_prepare "${host}"
	run_step C-001 "${host}" "check package and target state" db_precheck "${host}"
	run_step C-002 "${host}" "upload package" db_upload_package "${host}"
	run_step C-003 "${host}" "extract package" db_extract_package "${host}"
	run_step C-004 "${host}" "generate standalone configuration" db_generate_config "${host}"
	run_step C-005 "${host}" "configure managed service ports" db_configure_ports "${host}"
	run_step C-006 "${host}" "install YashanDB software" db_install_software "${host}"
	run_step C-007 "${host}" "deploy standalone database" db_deploy "${host}"
	run_step C-008 "${host}" "verify standalone database" db_verify "${host}"
}

remote_package_path() {
	if [[ ${LOCAL} == true ]]; then
		printf '%s' "${PACKAGE}"
	else
		printf '%s/%s' "${REMOTE_PACKAGE_DIR}" "$(basename -- "${PACKAGE}")"
	fi
}

db_precheck() {
	local host=$1 stage_q ports_q
	stage_q=$(quote "${STAGE_DIR}")
	ports_q="$(quote "${YASOM_PORT}") $(quote "${YASAGENT_PORT}") $(quote "${DB_PORT}") $(quote "${REPLICAT_PORT}")"
	[[ -z ${MYSQL_PORT} ]] || ports_q+=" $(quote "${MYSQL_PORT}")"
	remote_check C-001 "${host}" "
set -e
if [ -e ${stage_q}/${CLUSTER}.toml ] && [ ${FORCE} != true ]; then
  echo 'existing managed configuration found; use clean or --force after review' >&2
  exit 1
fi
for port in ${ports_q}; do
  if ss -ltn 2>/dev/null | awk '{print \$4}' | grep -Eq "[:.]\${port}$"; then
    echo \"managed port \${port} is already listening\" >&2
    exit 1
  fi
done
"
}

db_upload_package() {
	local host=$1 remote_path package_dir_q user_q group_q
	remote_path=$(remote_package_path)
	package_dir_q=$(quote "${REMOTE_PACKAGE_DIR}")
	user_q=$(quote "${OS_USER}")
	group_q=$(quote "${OS_GROUP}")
	remote_exec C-002 "${host}" true "install -d -o ${user_q} -g ${group_q} ${package_dir_q}"
	remote_copy C-002 "${host}" "${PACKAGE}" "${remote_path}"
}

db_extract_package() {
	local host=$1 remote_path stage_q remote_q user_group_q
	remote_path=$(remote_package_path)
	stage_q=$(quote "${STAGE_DIR}")
	remote_q=$(quote "${remote_path}")
	user_group_q=$(quote "${OS_USER}:${OS_GROUP}")
	remote_exec C-003 "${host}" true "
set -e
if [ -d ${stage_q} ] && [ -n \"\$(find ${stage_q} -mindepth 1 -maxdepth 1 -print -quit)\" ]; then
  if [ ${FORCE} = true ]; then
    find ${stage_q} -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  else
    echo 'stage directory is not empty; use --force only after review' >&2
    exit 1
  fi
fi
install -d -o $(quote "${OS_USER}") -g $(quote "${OS_GROUP}") ${stage_q}
case ${remote_q} in
  *.tar.gz|*.tgz) tar -zxf ${remote_q} -C ${stage_q} ;;
  *.tar) tar -xf ${remote_q} -C ${stage_q} ;;
  *) echo 'unsupported package extension' >&2; exit 1 ;;
esac
test -x ${stage_q}/bin/yasboot
find ${stage_q} -maxdepth 2 -type f -name 'database-*.tar.gz' -print -quit | grep -q .
chown -R ${user_group_q} ${stage_q}
"
}

validate_extra_args() {
	local value=$1 label=$2
	# The '$(' text is intentionally a literal pattern to reject command substitution.
	# shellcheck disable=SC2016
	[[ ${value} != *$'\n'* && ${value} != *';'* && ${value} != *'`'* && ${value} != *'$('* ]] || die "${label} contains shell control characters"
}

db_generate_config() {
	local host=$1 stage_q yasboot_q cluster_q user_q password_q install_q data_q log_q auth_args mode_args force_arg
	validate_extra_args "${YASBOOT_GEN_EXTRA_ARGS}" "--yasboot-gen-extra-args"
	stage_q=$(quote "${STAGE_DIR}")
	yasboot_q=$(quote "${STAGE_DIR}/bin/yasboot")
	cluster_q=$(quote "${CLUSTER}")
	user_q=$(quote "${OS_USER}")
	password_q=$(quote "${DB_ADMIN_PASSWORD}")
	install_q=$(quote "${INSTALL_PATH}")
	data_q=$(quote "${DATA_PATH}")
	log_q=$(quote "${LOG_PATH}")
	if [[ ${LOCAL} == true ]]; then
		auth_args="-N"
	else
		auth_args="-p ${password_q}"
	fi
	mode_args=""
	[[ ${DB_MODE} == yashan ]] || mode_args="-m mysql"
	force_arg=""
	[[ ${FORCE} == false ]] || force_arg="--force"
	remote_exec C-004 "${host}" true "
set -e
host_ip=\$(hostname -I | awk '{print \$1}')
test -n \"\${host_ip}\"
cd ${stage_q}
runuser -u ${user_q} -- ${yasboot_q} package se gen --cluster ${cluster_q} -u ${user_q} ${auth_args} --ip \"\${host_ip}\" --port ${SSH_PORT} --install-path ${install_q} --data-path ${data_q} --log-path ${log_q} --begin-port ${BEGIN_PORT} ${mode_args} ${force_arg} --node 1 ${YASBOOT_GEN_EXTRA_ARGS}
test -f ${stage_q}/${CLUSTER}.toml
"
}

db_configure_ports() {
	local host=$1 stage_q hosts_q cluster_config_q user_q memory_value
	stage_q=$(quote "${STAGE_DIR}")
	hosts_q=$(quote "${STAGE_DIR}/hosts.toml")
	cluster_config_q=$(quote "${STAGE_DIR}/${CLUSTER}.toml")
	user_q=$(quote "${OS_USER}")
	memory_value=""
	if [[ -n ${MEMORY_SIZE} ]]; then
		memory_value=${MEMORY_SIZE%[MmGg]}
		case ${MEMORY_SIZE} in *[Gg]) memory_value=$((memory_value * 1024))M ;; *) memory_value=${memory_value}M ;; esac
	fi
	remote_exec C-005 "${host}" true "
set -e
host_ip=\$(hostname -I | awk '{print \$1}')
test -n \"\${host_ip}\"
test -f ${hosts_q}
test -f ${cluster_config_q}
runuser -u ${user_q} -- bash -s -- ${hosts_q} ${cluster_config_q} \"\${host_ip}\" ${YASOM_PORT} ${YASAGENT_PORT} $(quote "${memory_value}") $(quote "${MYSQL_PORT}") $(quote "${USE_NATIVE_TYPE}") <<'PORTS'
set -euo pipefail
hosts_file=\$1
cluster_file=\$2
host_ip=\$3
yasom_port=\$4
yasagent_port=\$5
memory_value=\$6
mysql_port=\$7
use_native_type=\$8

set_listen_addr() {
  local section=\$1 address=\$2 temp_file
  temp_file=\"\${hosts_file}.tmp.\$\$\"
  awk -v section=\"\${section}\" -v address=\"\${address}\" '
    /^[[:space:]]*\\[/ {
      current = \$0
      sub(/^[[:space:]]*/, \"\", current)
      sub(/[[:space:]]*$/, \"\", current)
      in_section = (current == section)
    }
    in_section && /^[[:space:]]*LISTEN_ADDR[[:space:]]*=/ {
      match(\$0, /^[[:space:]]*/)
      indent = substr(\$0, RSTART, RLENGTH)
      print indent \"LISTEN_ADDR = \\\"\" address \"\\\"\"
      found = 1
      next
    }
    { print }
    END { if (!found) exit 1 }
  ' \"\${hosts_file}\" >\"\${temp_file}\" || {
    rm -f -- \"\${temp_file}\"
    echo \"missing LISTEN_ADDR in \${section}\" >&2
    exit 1
  }
  mv -- \"\${temp_file}\" \"\${hosts_file}\"
}

set_listen_addr '[om.config]' \"\${host_ip}:\${yasom_port}\"
set_listen_addr '[host.yasagent.config]' \"\${host_ip}:\${yasagent_port}\"

set_memory_limit() {
  local config_file=\$1 section=\$2 temp_file
  temp_file=\"\${config_file}.memory.\$\$\"
  awk -v section=\"\${section}\" -v value=\"\${memory_value}\" '
    function add_value() {
      if (in_section && !written) print section_indent \"  memory_limit = \\\"\" value \"\\\"\"
    }
    /^[[:space:]]*\[/ {
      add_value()
      current = \$0
      sub(/^[[:space:]]*/, \"\", current)
      sub(/[[:space:]]*$/, \"\", current)
      in_section = (current == section)
      written = 0
      if (in_section) {
        match(\$0, /^[[:space:]]*/)
        section_indent = substr(\$0, RSTART, RLENGTH)
        found_section = 1
      }
    }
    in_section && /^[[:space:]]*memory_limit[[:space:]]*=/ {
      match(\$0, /^[[:space:]]*/)
      print substr(\$0, RSTART, RLENGTH) \"memory_limit = \\\"\" value \"\\\"\"
      written = 1
      next
    }
    { print }
    END {
      add_value()
      if (!found_section) exit 1
    }
  ' \"\${config_file}\" >\"\${temp_file}\" || {
    rm -f -- \"\${temp_file}\"
    echo \"missing section \${section} in \${config_file}\" >&2
    exit 1
  }
  mv -- \"\${temp_file}\" \"\${config_file}\"
}

set_columnar_buffer_size() {
  local config_file=\$1 temp_file
  temp_file=\"\${config_file}.columnar.\$\$\"
  awk '
    function add_value() {
      if (in_section && !written) print section_indent \"  COLUMNAR_BUFFER_SIZE = \\\"256M\\\"\"
    }
    /^[[:space:]]*\[/ {
      add_value()
      current = \$0
      sub(/^[[:space:]]*/, \"\", current)
      sub(/[[:space:]]*\$/, \"\", current)
      in_section = (current == \"[group.node.config]\")
      written = 0
      if (in_section) {
        match(\$0, /^[[:space:]]*/)
        section_indent = substr(\$0, RSTART, RLENGTH)
        found_section = 1
      }
    }
    in_section && /^[[:space:]]*COLUMNAR_BUFFER_SIZE[[:space:]]*=/ {
      match(\$0, /^[[:space:]]*/)
      print substr(\$0, RSTART, RLENGTH) \"COLUMNAR_BUFFER_SIZE = \\\"256M\\\"\"
      written = 1
      next
    }
    { print }
    END {
      add_value()
      if (!found_section) exit 1
    }
  ' \"\${config_file}\" >\"\${temp_file}\" || {
    rm -f -- \"\${temp_file}\"
    echo \"missing [group.node.config] in \${config_file}\" >&2
    exit 1
  }
  mv -- \"\${temp_file}\" \"\${config_file}\"
}

set_mysql_addr() {
  local config_file=\$1 address=\$2 temp_file
  temp_file=\"\${config_file}.mysql.\$\$\"
  awk -v address=\"\${address}\" '
    /^[[:space:]]*\[/ {
      current = \$0
      sub(/^[[:space:]]*/, \"\", current)
      sub(/[[:space:]]*\$/, \"\", current)
      in_section = (current == \"[[group.node]]\")
    }
    in_section && /^[[:space:]]*mysql_addr[[:space:]]*=/ {
      match(\$0, /^[[:space:]]*/)
      print substr(\$0, RSTART, RLENGTH) \"mysql_addr = \\\"\" address \"\\\"\"
      found = 1
      next
    }
    { print }
    END { if (!found) exit 1 }
  ' \"\${config_file}\" >\"\${temp_file}\" || {
    rm -f -- \"\${temp_file}\"
    echo \"missing mysql_addr in [[group.node]] in \${config_file}\" >&2
    exit 1
  }
  mv -- \"\${temp_file}\" \"\${config_file}\"
}

set_node_bool() {
  local config_file=\$1 key=\$2 temp_file
  temp_file="\${config_file}.\${key}.\$\$"
  awk -v key="\${key}" '
    function add_value() {
      if (in_section && !written) print section_indent \"  \" key \" = true\"
    }
    /^[[:space:]]*\[/ {
      add_value()
      current = \$0
      sub(/^[[:space:]]*/, \"\", current)
      sub(/[[:space:]]*$/, \"\", current)
      in_section = (current == \"[group.node.config]\")
      written = 0
      if (in_section) {
        match(\$0, /^[[:space:]]*/)
        section_indent = substr(\$0, RSTART, RLENGTH)
        found_section = 1
      }
    }
    in_section && \$0 ~ \"^[[:space:]]*\" key \"[[:space:]]*=\" {
      match(\$0, /^[[:space:]]*/)
      print substr(\$0, RSTART, RLENGTH) key \" = true\"
      written = 1
      next
    }
    { print }
    END {
      add_value()
      if (!found_section) exit 1
    }
  ' \"\${config_file}\" >\"\${temp_file}\" || {
    rm -f -- \"\${temp_file}\"
    echo \"missing [group.node.config] in \${config_file}\" >&2
    exit 1
  }
  mv -- \"\${temp_file}\" \"\${config_file}\"
}

if [[ -n \${memory_value} ]]; then
  set_memory_limit \"\${hosts_file}\" '[[host]]'
  set_memory_limit \"\${cluster_file}\" '[[group.node]]'
fi
set_columnar_buffer_size "\${cluster_file}"
if [[ -n \${mysql_port} ]]; then
  set_mysql_addr "\${cluster_file}" "\${host_ip}:\${mysql_port}"
fi
if [[ \${use_native_type} == true ]]; then
  set_node_bool "\${cluster_file}" USE_NATIVE_TYPE
fi
PORTS
"
}

db_install_software() {
	local host=$1 stage_q yasboot_q hosts_q user_q
	stage_q=$(quote "${STAGE_DIR}")
	yasboot_q=$(quote "${STAGE_DIR}/bin/yasboot")
	hosts_q=$(quote "${STAGE_DIR}/hosts.toml")
	user_q=$(quote "${OS_USER}")
	remote_exec C-006 "${host}" true "
set -e
cd ${stage_q}
runuser -u ${user_q} -- ${yasboot_q} package install -t ${hosts_q}
"
}

db_deploy() {
	local host=$1 stage_q yasboot_q config_q user_q password_q auth_args
	validate_extra_args "${YASBOOT_DEPLOY_EXTRA_ARGS}" "--yasboot-deploy-extra-args"
	stage_q=$(quote "${STAGE_DIR}")
	yasboot_q=$(quote "${STAGE_DIR}/bin/yasboot")
	config_q=$(quote "${STAGE_DIR}/${CLUSTER}.toml")
	user_q=$(quote "${OS_USER}")
	password_q=$(quote "${DB_ADMIN_PASSWORD}")
	auth_args="-p ${password_q}"
	remote_exec C-007 "${host}" true "
set -e
cd ${stage_q}
runuser -u ${user_q} -- ${yasboot_q} cluster deploy -t ${config_q} ${auth_args} ${YASBOOT_DEPLOY_EXTRA_ARGS}
"
}

db_verify() {
	local host=$1 yasboot_q cluster_q user_q
	yasboot_q=$(quote "${STAGE_DIR}/bin/yasboot")
	cluster_q=$(quote "${CLUSTER}")
	user_q=$(quote "${OS_USER}")
	remote_check C-008 "${host}" "
set -e
${yasboot_q} cluster status -c ${cluster_q} -d
pgrep -x yasdb >/dev/null
"
}
