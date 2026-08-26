#!/usr/bin/env bash
# shellcheck disable=SC2034 # Globals are consumed by separately sourced step modules.

init_defaults() {
	COMMAND=""
	SUBCOMMAND=""
	TARGET=""
	LOCAL=false
	PRIMARY=""
	STANDBYS=""
	SSH_USER="yashan"
	SSH_KEY_PATH=""
	SSH_PORT=22
	PRECHECK=false
	DRY_RUN=false
	FORCE=false
	CONFIRM=false
	PURGE_DATA=false
	INCLUDE_STEPS=""
	EXCLUDE_STEPS=""
	LOG_DIR="./logs"
	GENERATE_SCRIPT=""
	SUDO_BIN="${YINSTALL_SUDO_BIN:-/usr/bin/sudo}"
	PACKAGE=""
	DB_ADMIN_PASSWORD=""
	CLUSTER="yashandb"
	OS_USER="yashan"
	OS_GROUP="yashan"
	INSTALL_PATH="/data/yashan/yasdb_home"
	DATA_PATH="/data/yashan/yasdb_data"
	LOG_PATH="/data/yashan/yasdb_log"
	STAGE_DIR="/home/yashan/install"
	REMOTE_PACKAGE_DIR="/data/yashan/soft"
	BEGIN_PORT=1688
	BEGIN_PORT_SET=false
	DB_PORT=""
	YASOM_PORT=""
	YASAGENT_PORT=""
	REPLICAT_PORT=""
	DB_MODE="yashan"
	MYSQL_PORT=""
	USE_NATIVE_TYPE=false
	CHARACTER_SET=""
	MEMORY_SIZE=""
	STANDBY_JOIN_CMD=""
	STANDBY_REMOVE_CMD=""
	YASBOOT_GEN_EXTRA_ARGS=""
	YASBOOT_DEPLOY_EXTRA_ARGS=""
}

parse_args() {
	if (($# == 1)) && [[ $1 == -h || $1 == --help ]]; then
		usage
		exit 0
	fi
	(($# >= 2)) || {
		usage
		exit 2
	}
	COMMAND=$1
	SUBCOMMAND=$2
	shift 2
	while (($#)); do
		case "$1" in
		-t | --target)
			TARGET=${2:?missing value for $1}
			shift 2
			;;
		--local)
			LOCAL=true
			shift
			;;
		--primary)
			PRIMARY=${2:?missing value for $1}
			shift 2
			;;
		--standbys)
			STANDBYS=${2:?missing value for $1}
			shift 2
			;;
		-u | --ssh-user)
			SSH_USER=${2:?missing value for $1}
			shift 2
			;;
		-i | --ssh-key-path)
			SSH_KEY_PATH=${2:?missing value for $1}
			shift 2
			;;
		-p | --ssh-port)
			SSH_PORT=${2:?missing value for $1}
			shift 2
			;;
		--package)
			PACKAGE=${2:?missing value for $1}
			shift 2
			;;
		--db-admin-password)
			DB_ADMIN_PASSWORD=${2:?missing value for $1}
			shift 2
			;;
		--cluster)
			CLUSTER=${2:?missing value for $1}
			shift 2
			;;
		--os-user)
			OS_USER=${2:?missing value for $1}
			shift 2
			;;
		--os-group)
			OS_GROUP=${2:?missing value for $1}
			shift 2
			;;
		--install-path)
			INSTALL_PATH=${2:?missing value for $1}
			shift 2
			;;
		--data-path)
			DATA_PATH=${2:?missing value for $1}
			shift 2
			;;
		--log-path)
			LOG_PATH=${2:?missing value for $1}
			shift 2
			;;
		--stage-dir)
			STAGE_DIR=${2:?missing value for $1}
			shift 2
			;;
		--begin-port)
			BEGIN_PORT=${2:?missing value for $1}
			BEGIN_PORT_SET=true
			shift 2
			;;
		--db-port)
			DB_PORT=${2:?missing value for $1}
			shift 2
			;;
		--yasom-port)
			YASOM_PORT=${2:?missing value for $1}
			shift 2
			;;
		--yasagent-port)
			YASAGENT_PORT=${2:?missing value for $1}
			shift 2
			;;
		--replicat-port)
			REPLICAT_PORT=${2:?missing value for $1}
			shift 2
			;;
		--memory-size)
			MEMORY_SIZE=${2:?missing value for $1}
			shift 2
			;;
		--mode)
			DB_MODE=${2:?missing value for $1}
			shift 2
			;;
		--mysql-port)
			MYSQL_PORT=${2:?missing value for $1}
			shift 2
			;;
		--use-native-type)
			USE_NATIVE_TYPE=true
			shift
			;;
		--character-set)
			CHARACTER_SET=${2:?missing value for $1}
			shift 2
			;;
		--standby-join-cmd)
			STANDBY_JOIN_CMD=${2:?missing value for $1}
			shift 2
			;;
		--standby-remove-cmd)
			STANDBY_REMOVE_CMD=${2:?missing value for $1}
			shift 2
			;;
		--yasboot-gen-extra-args)
			YASBOOT_GEN_EXTRA_ARGS=${2:?missing value for $1}
			shift 2
			;;
		--yasboot-deploy-extra-args)
			YASBOOT_DEPLOY_EXTRA_ARGS=${2:?missing value for $1}
			shift 2
			;;
		--include-steps)
			INCLUDE_STEPS=${2:?missing value for $1}
			shift 2
			;;
		--exclude-steps)
			EXCLUDE_STEPS=${2:?missing value for $1}
			shift 2
			;;
		--log-dir)
			LOG_DIR=${2:?missing value for $1}
			shift 2
			;;
		--generate-script)
			GENERATE_SCRIPT=${2:?missing value for $1}
			shift 2
			;;
		--precheck)
			PRECHECK=true
			shift
			;;
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--force)
			FORCE=true
			shift
			;;
		--confirm)
			CONFIRM=true
			shift
			;;
		--purge-data)
			PURGE_DATA=true
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*) die "unknown option: $1" ;;
		esac
	done
}

init_logging() {
	mkdir -p -- "${LOG_DIR}"
	LOG_FILE="${LOG_DIR}/yinstall-$(date +%Y%m%d-%H%M%S).log"
}

init_generated_script() {
	[[ -n ${GENERATE_SCRIPT} ]] || return 0
	mkdir -p -- "$(dirname -- "${GENERATE_SCRIPT}")"
	printf '%s\n\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail' >"${GENERATE_SCRIPT}"
	chmod 700 -- "${GENERATE_SCRIPT}"
}

log() {
	local level=$1 step=$2 host=$3
	shift 3
	local line
	line="$(date '+%Y-%m-%dT%H:%M:%S%z') ${level} [${step}] [${host}] $*"
	printf '%s\n' "${line}" | tee -a "${LOG_FILE}" >&2
}

die() {
	if [[ -n ${LOG_FILE:-} ]]; then
		log ERROR CLI local "$*"
	else
		printf 'yinstall: %s\n' "$*" >&2
	fi
	exit 1
}
quote() { printf "'%s'" "${1//\'/\'\\\'}"; }
is_identifier() { [[ $1 =~ ^[A-Za-z][A-Za-z0-9_-]{0,63}$ ]]; }
is_port() { [[ $1 =~ ^[1-9][0-9]*$ ]] && (($1 >= 1 && $1 <= 65535)); }
is_percent() { [[ $1 =~ ^[0-9]+$ ]] && (($1 >= 1 && $1 <= 100)); }
is_host() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,253}$ ]]; }
is_absolute_path() { [[ $1 == /* && $1 != / && $1 != *".."* ]]; }

contains_step() { [[ ",$1," == *",$2,"* ]]; }
should_run_step() {
	[[ -n ${INCLUDE_STEPS} ]] && ! contains_step "${INCLUDE_STEPS}" "$1" && return 1
	[[ -n ${EXCLUDE_STEPS} ]] && contains_step "${EXCLUDE_STEPS}" "$1" && return 1
	return 0
}
run_step() {
	local id=$1 host=$2 phase=$3
	shift 3
	should_run_step "${id}" || {
		log INFO "${id}" "${host}" "skipped by step selection"
		return 0
	}
	log INFO "${id}" "${host}" "${phase}"
	"$@"
}

validate_host_list() {
	local hosts=$1 host
	IFS=',' read -r -a host_list <<<"${hosts}"
	((${#host_list[@]})) || die "at least one standby is required"
	for host in "${host_list[@]}"; do is_host "${host}" || die "invalid host: ${host}"; done
}

resolve_database_ports() {
	local individual_ports_set=false
	[[ -n ${YASOM_PORT}${YASAGENT_PORT}${REPLICAT_PORT} ]] && individual_ports_set=true

	if [[ -n ${DB_PORT} ]]; then
		[[ ${BEGIN_PORT_SET} == false ]] || die "--db-port cannot be combined with --begin-port"
		is_port "${DB_PORT}" || die "invalid database port: ${DB_PORT}"
		if [[ ${individual_ports_set} == true ]]; then
			[[ -n ${YASOM_PORT} && -n ${YASAGENT_PORT} && -n ${REPLICAT_PORT} ]] || die "--yasom-port, --yasagent-port, and --replicat-port must be supplied together with --db-port"
			is_port "${YASOM_PORT}" || die "invalid Yasom port: ${YASOM_PORT}"
			is_port "${YASAGENT_PORT}" || die "invalid Yasagent port: ${YASAGENT_PORT}"
			is_port "${REPLICAT_PORT}" || die "invalid Replicat port: ${REPLICAT_PORT}"
			((YASOM_PORT == DB_PORT - 2 && YASAGENT_PORT == DB_PORT - 1 && REPLICAT_PORT == DB_PORT + 1)) || die "explicit ports must be db-port-2, db-port-1, db-port, and db-port+1"
		else
			((DB_PORT >= 3 && DB_PORT <= 65534)) || die "--db-port must allow two lower and one higher port"
			YASOM_PORT=$((DB_PORT - 2))
			YASAGENT_PORT=$((DB_PORT - 1))
			REPLICAT_PORT=$((DB_PORT + 1))
		fi
	elif [[ ${individual_ports_set} == true ]]; then
		[[ -n ${DB_PORT} ]] || die "--db-port is required with individual port options"
	else
		DB_PORT=${BEGIN_PORT}
		((DB_PORT >= 3 && DB_PORT <= 65534)) || die "--begin-port must allow two lower and one higher port"
		YASOM_PORT=$((DB_PORT - 2))
		YASAGENT_PORT=$((DB_PORT - 1))
		REPLICAT_PORT=$((DB_PORT + 1))
	fi

	is_port "${YASOM_PORT}" || die "invalid Yasom port: ${YASOM_PORT}"
	is_port "${YASAGENT_PORT}" || die "invalid Yasagent port: ${YASAGENT_PORT}"
	is_port "${DB_PORT}" || die "invalid database port: ${DB_PORT}"
	is_port "${REPLICAT_PORT}" || die "invalid Replicat port: ${REPLICAT_PORT}"
	if [[ -n ${BEGIN_PORT} ]]; then
		BEGIN_PORT=${DB_PORT}
	fi
}

validate_request() {
	is_port "${SSH_PORT}" || die "invalid SSH port: ${SSH_PORT}"
	resolve_database_ports
	[[ -z ${MEMORY_SIZE} || ${MEMORY_SIZE} =~ ^[1-9][0-9]*([MmGg])?$ ]] || die "memory size must be an integer with optional M or G suffix"
	[[ ${DB_MODE} == yashan || ${DB_MODE} == mysql ]] || die "--mode must be yashan or mysql"
	if [[ -n ${CHARACTER_SET} ]]; then
		CHARACTER_SET=${CHARACTER_SET^^}
		case ${CHARACTER_SET} in
		ASCII | ISO88591 | GBK | UTF8 | GB18030) ;;
		*) die "--character-set must be ASCII, ISO88591, GBK, UTF8, or GB18030" ;;
		esac
	fi
	if [[ ${DB_MODE} == mysql ]]; then
		is_port "${MYSQL_PORT}" || die "--mysql-port is required with --mode mysql"
	else
		[[ -z ${MYSQL_PORT} ]] || die "--mysql-port requires --mode mysql"
	fi
	is_identifier "${CLUSTER}" || die "invalid cluster name"
	is_identifier "${OS_USER}" || die "invalid OS user"
	is_identifier "${OS_GROUP}" || die "invalid OS group"
	local path
	for path in "${INSTALL_PATH}" "${DATA_PATH}" "${LOG_PATH}" "${STAGE_DIR}"; do
		is_absolute_path "${path}" || die "unsafe path: ${path}"
	done
	if [[ -n ${GENERATE_SCRIPT} ]]; then
		[[ ${LOCAL} == true ]] || die "--generate-script requires --local"
		[[ ${COMMAND}:${SUBCOMMAND} == os:prepare || ${COMMAND}:${SUBCOMMAND} == db:install ]] || die "--generate-script is supported only by os prepare and db install"
		[[ ${PRECHECK} == false && ${DRY_RUN} == false ]] || die "--generate-script cannot be combined with --precheck or --dry-run"
		is_absolute_path "${GENERATE_SCRIPT}" || die "unsafe generated script path: ${GENERATE_SCRIPT}"
	fi
	if [[ ${LOCAL} == true && ${COMMAND}:${SUBCOMMAND} != os:prepare && ${COMMAND}:${SUBCOMMAND} != db:install ]]; then
		die "--local is supported only by os prepare and db install"
	fi
	case "${COMMAND}:${SUBCOMMAND}" in
	os:prepare | db:install)
		if [[ ${LOCAL} == true ]]; then
			[[ -z ${TARGET} ]] || die "--local cannot be combined with --target"
			TARGET="local"
		else
			is_host "${TARGET}" || die "a valid --target is required"
		fi
		;;
	standby:add)
		is_host "${PRIMARY}" || die "a valid --primary is required"
		[[ -n ${STANDBYS} ]] || die "--standbys is required"
		[[ -n ${STANDBY_JOIN_CMD} ]] || die "--standby-join-cmd is required"
		validate_host_list "${STANDBYS}"
		;;
	clean:standby)
		is_host "${PRIMARY}" || die "a valid --primary is required"
		is_host "${TARGET}" || die "a valid --target is required"
		[[ -n ${STANDBY_REMOVE_CMD} ]] || die "--standby-remove-cmd is required"
		;;
	clean:all)
		is_host "${PRIMARY}" || die "a valid --primary is required"
		validate_host_list "${STANDBYS}"
		[[ -n ${STANDBY_REMOVE_CMD} ]] || die "--standby-remove-cmd is required"
		;;
	esac
	if [[ ${COMMAND}:${SUBCOMMAND} == db:install || ${COMMAND}:${SUBCOMMAND} == standby:add ]]; then
		[[ -f ${PACKAGE} ]] || die "--package must name a readable local file"
		[[ -n ${DB_ADMIN_PASSWORD} ]] || die "--db-admin-password is required"
	fi
	if [[ ${COMMAND} == clean && ${PRECHECK} != true && ${DRY_RUN} != true && ${CONFIRM} != true ]]; then
		die "cleanup requires --confirm"
	fi
	if [[ ${PURGE_DATA} == true && ${PRECHECK} != true && ${DRY_RUN} != true && ${CONFIRM} != true ]]; then
		die "--purge-data requires --confirm"
	fi
}

safe_managed_path() {
	case "$1" in /data/yashan/* | /home/yashan/* | /etc/systemd/system/yashandb-*) return 0 ;; *) return 1 ;; esac
}
