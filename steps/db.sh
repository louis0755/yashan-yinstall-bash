#!/usr/bin/env bash

run_db_install() {
	local host=$1
	run_os_prepare "${host}"
	resolve_memory_limit "${host}"
	run_step C-001 "${host}" "check package and target state" db_precheck "${host}"
	run_step C-002 "${host}" "upload package" db_upload_package "${host}"
	run_step C-003 "${host}" "extract package" db_extract_package "${host}"
	run_step C-004 "${host}" "generate standalone configuration" db_generate_config "${host}"
	run_step C-005 "${host}" "configure managed service ports" db_configure_ports "${host}"
	run_step C-006 "${host}" "install YashanDB software" db_install_software "${host}"
	run_step C-007 "${host}" "deploy standalone database" db_deploy "${host}"
	run_step C-008 "${host}" "verify standalone database" db_verify "${host}"
}

resolve_memory_limit() {
	local host=$1 size_mb total_mb calculated
	[[ -n ${MEMORY_SIZE} ]] || return 0
	size_mb=${MEMORY_SIZE%[MmGg]}
	case "${MEMORY_SIZE}" in *[Gg]) size_mb=$((size_mb * 1024)) ;; esac
	if [[ ${LOCAL} == true ]]; then
		total_mb=$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
	else
		ssh_args
		total_mb=$(ssh "${SSH_ARGS[@]}" "${SSH_USER}@${host}" "awk '/^MemTotal:/ { print int(\$2 / 1024) }' /proc/meminfo")
	fi
	[[ ${total_mb} =~ ^[1-9][0-9]*$ ]] || die "failed to read target memory"
	((size_mb <= total_mb)) || die "memory size ${MEMORY_SIZE} exceeds target memory ${total_mb}M"
	calculated=$(((size_mb * 100 + total_mb - 1) / total_mb))
	((calculated < 1)) && calculated=1
	MEMORY_LIMIT=${calculated}
	log INFO MEMORY "${host}" "memory size ${MEMORY_SIZE} resolved to ${MEMORY_LIMIT}% of ${total_mb}M"
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
	local host=$1 stage_q yasboot_q cluster_q user_q password_q install_q data_q log_q auth_args
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
	remote_exec C-004 "${host}" true "
set -e
host_ip=\$(hostname -I | awk '{print \$1}')
test -n \"\${host_ip}\"
cd ${stage_q}
runuser -u ${user_q} -- ${yasboot_q} package se gen --cluster ${cluster_q} --recommend-param -u ${user_q} ${auth_args} --ip \"\${host_ip}\" --port ${SSH_PORT} --install-path ${install_q} --data-path ${data_q} --log-path ${log_q} --begin-port ${BEGIN_PORT} --memory-limit ${MEMORY_LIMIT} --node 1 ${YASBOOT_GEN_EXTRA_ARGS}
test -f ${stage_q}/${CLUSTER}.toml
"
}

db_configure_ports() {
	local host=$1 stage_q hosts_q user_q
	stage_q=$(quote "${STAGE_DIR}")
	hosts_q=$(quote "${STAGE_DIR}/hosts.toml")
	user_q=$(quote "${OS_USER}")
	remote_exec C-005 "${host}" true "
set -e
host_ip=\$(hostname -I | awk '{print \$1}')
test -n \"\${host_ip}\"
test -f ${hosts_q}
runuser -u ${user_q} -- bash -s -- ${hosts_q} \"\${host_ip}\" ${YASOM_PORT} ${YASAGENT_PORT} <<'PORTS'
set -euo pipefail
hosts_file=\$1
host_ip=\$2
yasom_port=\$3
yasagent_port=\$4

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
