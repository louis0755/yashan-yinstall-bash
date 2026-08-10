#!/usr/bin/env bash

run_os_prepare() {
	local host=$1
	run_step B-001 "${host}" "check connectivity" os_connectivity "${host}"
	run_step B-002 "${host}" "validate Linux prerequisites" os_precheck "${host}"
	run_step B-003 "${host}" "apply OS baseline" os_apply "${host}"
	run_step B-004 "${host}" "verify OS baseline" os_verify "${host}"
}

os_connectivity() {
	remote_check B-001 "$1" 'command -v bash >/dev/null; id; test -r /etc/os-release'
}

os_precheck() {
	local host=$1
	# The remote script must expand its own OS-release variables, not controller variables.
	# shellcheck disable=SC2016
	remote_check B-002 "${host}" '
set -e
. /etc/os-release
case "${ID}" in rhel|rocky|almalinux|ol|centos|kylin|uos|ubuntu|debian) ;; *) echo "unsupported distribution: ${ID}" >&2; exit 1 ;; esac
command -v systemctl >/dev/null
command -v awk >/dev/null
command -v tar >/dev/null
'
}

os_apply() {
	local host=$1 user_q group_q install_q data_q log_q stage_q package_q yasom_q yasagent_q db_q replicat_q
	user_q=$(quote "${OS_USER}")
	group_q=$(quote "${OS_GROUP}")
	install_q=$(quote "${INSTALL_PATH}")
	data_q=$(quote "${DATA_PATH}")
	log_q=$(quote "${LOG_PATH}")
	stage_q=$(quote "${STAGE_DIR}")
	package_q=$(quote "${REMOTE_PACKAGE_DIR}")
	yasom_q=$(quote "${YASOM_PORT}")
	yasagent_q=$(quote "${YASAGENT_PORT}")
	db_q=$(quote "${DB_PORT}")
	replicat_q=$(quote "${REPLICAT_PORT}")
	remote_exec B-003 "${host}" true "
set -e
getent group ${group_q} >/dev/null || groupadd ${group_q}
id -u ${user_q} >/dev/null 2>&1 || useradd -m -g ${group_q} ${user_q}
install -d -o ${user_q} -g ${group_q} -m 0750 ${install_q} ${data_q} ${log_q} ${stage_q} ${package_q}
cat >/etc/sysctl.d/99-yashandb.conf <<'SYSCTL'
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
SYSCTL
sysctl --system >/dev/null
cat >/etc/security/limits.d/99-yashandb.conf <<'LIMITS'
${OS_USER} soft nofile 65536
${OS_USER} hard nofile 65536
${OS_USER} soft nproc 16384
${OS_USER} hard nproc 16384
LIMITS
if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
  for port in ${yasom_q} ${yasagent_q} ${db_q} ${replicat_q}; do
    firewall-cmd --permanent --add-port="\${port}"/tcp
  done
  firewall-cmd --reload
fi
"
}

os_verify() {
	local host=$1 user_q install_q data_q
	user_q=$(quote "${OS_USER}")
	install_q=$(quote "${INSTALL_PATH}")
	data_q=$(quote "${DATA_PATH}")
	remote_check B-004 "${host}" "
set -e
id ${user_q} >/dev/null
test -d ${install_q}
test -d ${data_q}
test -f /etc/sysctl.d/99-yashandb.conf
test -f /etc/security/limits.d/99-yashandb.conf
"
}
