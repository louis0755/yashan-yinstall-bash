#!/usr/bin/env bash

run_standby_add() {
	local host failed=0
	run_step E-001 "${PRIMARY}" "validate primary health" standby_check_primary
	IFS=',' read -r -a standby_hosts <<<"${STANDBYS}"
	for host in "${standby_hosts[@]}"; do
		log INFO E-000 "${host}" "starting standby workflow"
		if ! standby_add_one "${host}"; then
			log ERROR E-999 "${host}" "standby workflow failed; continuing with remaining hosts"
			failed=1
		fi
	done
	((failed == 0)) || return 1
}

standby_add_one() {
	local host=$1
	run_os_prepare "${host}" || return
	run_step E-010 "${host}" "check standby target" db_precheck "${host}" || return
	run_step E-011 "${host}" "upload package" db_upload_package "${host}" || return
	run_step E-012 "${host}" "extract package" db_extract_package "${host}" || return
	run_step E-013 "${host}" "generate standby configuration" db_generate_config "${host}" || return
	run_step E-014 "${host}" "install standby software" db_install_software "${host}" || return
	run_step E-015 "${host}" "check primary connectivity" standby_check_connectivity "${host}" || return
	run_step E-016 "${host}" "join primary replication" standby_join "${host}" || return
	run_step E-017 "${host}" "verify replication" standby_verify "${host}" || return
}

standby_check_primary() {
	local yasboot_q cluster_q user_q
	yasboot_q=$(quote "${STAGE_DIR}/bin/yasboot")
	cluster_q=$(quote "${CLUSTER}")
	user_q=$(quote "${OS_USER}")
	remote_check E-001 "${PRIMARY}" "
set -e
${yasboot_q} cluster status -c ${cluster_q} -d
pgrep -x yasdb >/dev/null
"
}

standby_check_connectivity() {
	local host=$1
	remote_check E-015 "${host}" "timeout 5 bash -c '>/dev/tcp/${PRIMARY}/${BEGIN_PORT}'"
}

render_standby_command() {
	local command=$1 standby=$2
	command=${command//\{primary\}/${PRIMARY}}
	command=${command//\{standby\}/${standby}}
	command=${command//\{cluster\}/${CLUSTER}}
	# The '$(' text is intentionally a literal pattern to reject command substitution.
	# shellcheck disable=SC2016
	[[ ${command} != *$'\n'* && ${command} != *'`'* && ${command} != *'$('* ]] || die "standby command contains unsafe shell control characters"
	printf '%s' "${command}"
}

standby_join() {
	local host=$1 rendered
	rendered=$(render_standby_command "${STANDBY_JOIN_CMD}" "${host}")
	remote_exec E-016 "${host}" true "set -e; ${rendered}"
}

standby_verify() {
	local host=$1 yasboot_q cluster_q user_q
	yasboot_q=$(quote "${STAGE_DIR}/bin/yasboot")
	cluster_q=$(quote "${CLUSTER}")
	user_q=$(quote "${OS_USER}")
	remote_check E-017 "${host}" "
set -e
${yasboot_q} cluster status -c ${cluster_q} -d | grep -qi standby
pgrep -x yasdb >/dev/null
"
}
