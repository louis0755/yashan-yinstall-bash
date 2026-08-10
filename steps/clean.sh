#!/usr/bin/env bash

run_clean_standby() {
	local host=$1
	run_step X-001 "${host}" "list managed cleanup paths" clean_precheck "${host}"
	run_step X-002 "${PRIMARY}" "remove standby relationship" clean_remove_relationship "${host}"
	run_step X-003 "${host}" "remove managed standby artifacts" clean_host "${host}"
}

run_clean_all() {
	local host
	IFS=',' read -r -a cleanup_standbys <<<"${STANDBYS}"
	for host in "${cleanup_standbys[@]}"; do run_clean_standby "${host}"; done
	run_step X-004 "${PRIMARY}" "remove managed primary artifacts" clean_host "${PRIMARY}"
}

clean_precheck() {
	local host=$1 install_q data_q log_q stage_q
	install_q=$(quote "${INSTALL_PATH}")
	data_q=$(quote "${DATA_PATH}")
	log_q=$(quote "${LOG_PATH}")
	stage_q=$(quote "${STAGE_DIR}")
	remote_check X-001 "${host}" "printf '%s\\n' ${install_q} ${data_q} ${log_q} ${stage_q} /etc/systemd/system/yashandb-${CLUSTER}.service"
}

clean_remove_relationship() {
	local standby=$1 rendered
	rendered=$(render_standby_command "${STANDBY_REMOVE_CMD}" "${standby}")
	remote_exec X-002 "${PRIMARY}" true "set -e; ${rendered}"
}

clean_host() {
	local host=$1 install_q data_q log_q stage_q service_q
	safe_managed_path "${INSTALL_PATH}" || die "refusing to clean unsafe path"
	safe_managed_path "${LOG_PATH}" || die "refusing to clean unsafe path"
	safe_managed_path "${STAGE_DIR}" || die "refusing to clean unsafe path"
	[[ ${PURGE_DATA} != true ]] || safe_managed_path "${DATA_PATH}" || die "refusing to purge unsafe path"
	install_q=$(quote "${INSTALL_PATH}")
	data_q=$(quote "${DATA_PATH}")
	log_q=$(quote "${LOG_PATH}")
	stage_q=$(quote "${STAGE_DIR}")
	service_q=$(quote "yashandb-${CLUSTER}")
	remote_exec X-003 "${host}" true "
set -e
systemctl stop ${service_q} 2>/dev/null || true
systemctl disable ${service_q} 2>/dev/null || true
rm -f -- /etc/systemd/system/yashandb-${CLUSTER}.service
systemctl daemon-reload
rm -rf -- ${install_q} ${log_q} ${stage_q}
$(if [[ ${PURGE_DATA} == true ]]; then printf 'rm -rf -- %s' "${data_q}"; else printf ':'; fi)
"
}
