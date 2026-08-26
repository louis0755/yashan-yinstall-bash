#!/usr/bin/env bash

ssh_args() {
	SSH_ARGS=(-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -p "${SSH_PORT}")
	if [[ -n ${SSH_KEY_PATH} ]]; then
		SSH_ARGS+=(-i "${SSH_KEY_PATH}")
	fi
}

run_local_script() {
	local privileged=$1 script=$2
	if [[ -n ${GENERATE_SCRIPT} ]]; then
		printf '\n# generated local step\n%s\n' "${script}" >>"${GENERATE_SCRIPT}"
		return 0
	fi
	if [[ ${privileged} == true ]]; then
		"${SUDO_BIN}" -n bash -se <<<"${script}"
	else
		bash -se <<<"${script}"
	fi
}

remote_exec() {
	local step=$1 host=$2 privileged=$3 script=$4
	if [[ ${LOCAL} == true ]]; then
		log DEBUG "${step}" local "local mutation scheduled"
	else
		ssh_args
		log DEBUG "${step}" "${host}" "remote mutation scheduled"
	fi
	if [[ ${PRECHECK} == true || ${DRY_RUN} == true ]]; then
		log INFO "${step}" "${host}" "remote mutation skipped by precheck/dry-run"
		return 0
	fi
	if [[ ${LOCAL} == true ]]; then
		if [[ -n ${GENERATE_SCRIPT} ]]; then
			printf '\n# generated %s\n%s\n' "${step}" "${script}" >>"${GENERATE_SCRIPT}"
			return 0
		fi
		run_local_script "${privileged}" "${script}"
		return
	fi
	if [[ ${privileged} == true ]]; then
		ssh "${SSH_ARGS[@]}" "${SSH_USER}@${host}" '/usr/bin/sudo -n bash -se' <<<"${script}"
	else
		ssh "${SSH_ARGS[@]}" "${SSH_USER}@${host}" 'bash -se' <<<"${script}"
	fi
}

remote_check() {
	local step=$1 host=$2 script=$3
	if [[ ${LOCAL} == true ]]; then
		if [[ -n ${GENERATE_SCRIPT} ]]; then
			printf '\n# generated %s check\n%s\n' "${step}" "${script}" >>"${GENERATE_SCRIPT}"
			return 0
		fi
		log DEBUG "${step}" local "local read-only check"
		bash -se <<<"${script}"
		return
	fi
	ssh_args
	log DEBUG "${step}" "${host}" "remote read-only check"
	ssh "${SSH_ARGS[@]}" "${SSH_USER}@${host}" 'bash -se' <<<"${script}"
}

remote_copy() {
	local step=$1 host=$2 source=$3 target=$4
	if [[ ${LOCAL} == true ]]; then
		log INFO "${step}" local "package upload skipped for local package"
		return
	fi
	ssh_args
	if [[ ${PRECHECK} == true || ${DRY_RUN} == true ]]; then
		log INFO "${step}" "${host}" "package upload skipped by precheck/dry-run"
		return 0
	fi
	local -a scp_args=(-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -P "${SSH_PORT}")
	if [[ -n ${SSH_KEY_PATH} ]]; then scp_args+=(-i "${SSH_KEY_PATH}"); fi
	scp "${scp_args[@]}" -- "${source}" "${SSH_USER}@${host}:${target}"
}
