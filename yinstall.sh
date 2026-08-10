#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
VERSION=$(<"${ROOT_DIR}/VERSION")
# shellcheck source=lib/yins-common.sh
source "${ROOT_DIR}/lib/yins-common.sh"
# shellcheck source=lib/ssh.sh
source "${ROOT_DIR}/lib/ssh.sh"
# shellcheck source=steps/os.sh
source "${ROOT_DIR}/steps/os.sh"
# shellcheck source=steps/db.sh
source "${ROOT_DIR}/steps/db.sh"
# shellcheck source=steps/standby.sh
source "${ROOT_DIR}/steps/standby.sh"
# shellcheck source=steps/clean.sh
source "${ROOT_DIR}/steps/clean.sh"

usage() {
	printf 'yinstall %s\n\n' "${VERSION}"
	cat <<'EOF'
Usage:
  yinstall.sh os prepare (--local | -t HOST) [options]
  yinstall.sh db install (--local | -t HOST) --package FILE --db-admin-password PASSWORD [options]
  yinstall.sh standby add --primary HOST --standbys HOST[,HOST...] --package FILE \
    --db-admin-password PASSWORD --standby-join-cmd COMMAND [options]
  yinstall.sh clean standby --primary HOST -t HOST --confirm [--purge-data] [options]
  yinstall.sh clean all --primary HOST --standbys HOST[,HOST...] --confirm [--purge-data] [options]

Global options: --local (run on this host), -t/--target, -u/--ssh-user,
  -i/--ssh-key-path, -p/--ssh-port,
  --precheck, --dry-run, --include-steps, --exclude-steps, --force, --log-dir,
  --generate-script FILE (local os/db steps; write commands for manual execution).

Database options: --package, --db-admin-password, --cluster, --os-user,
  --os-group, --install-path, --data-path, --log-path, --stage-dir,
  --db-port, --yasom-port, --yasagent-port, --replicat-port, --begin-port,
  --memory-limit, --yasboot-gen-extra-args,
  --recommend-memory (let yasboot calculate memory from --memory-limit),
  --memory-size (write an exact integer M by default, or G),
  --yasboot-deploy-extra-args.

Standby options: --standby-join-cmd and --standby-remove-cmd are required
because their exact yasboot/YashanDB commands vary by product release. They may
contain {primary}, {standby}, and {cluster} placeholders.

Cleanup keeps data by default. Removing data requires --confirm and --purge-data.
EOF
}

main() {
	if (($# == 1)) && [[ $1 == --version || $1 == version ]]; then
		printf 'yinstall %s\n' "${VERSION}"
		return 0
	fi
	init_defaults
	parse_args "$@"
	init_logging
	validate_request
	init_generated_script

	case "${COMMAND}:${SUBCOMMAND}" in
	os:prepare) run_os_prepare "${TARGET}" ;;
	db:install) run_db_install "${TARGET}" ;;
	standby:add) run_standby_add ;;
	clean:standby) run_clean_standby "${TARGET}" ;;
	clean:all) run_clean_all ;;
	*)
		usage
		die "unsupported command: ${COMMAND} ${SUBCOMMAND}"
		;;
	esac
}

main "$@"
