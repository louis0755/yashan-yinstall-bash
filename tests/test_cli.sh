#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "${TMP_DIR}"' EXIT
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p -- "${FAKE_BIN}"

printf '%s\n' '#!/usr/bin/env bash' 'cat >/dev/null' 'exit 0' >"${FAKE_BIN}/ssh"
# The fake scp must preserve TEST_MARKER for its child process.
# shellcheck disable=SC2016
printf '%s\n' '#!/usr/bin/env bash' 'echo scp >>"${TEST_MARKER}"' 'exit 0' >"${FAKE_BIN}/scp"
chmod +x "${FAKE_BIN}/ssh" "${FAKE_BIN}/scp"

ln -s -- "${ROOT_DIR}/yinstall.sh" "${TMP_DIR}/yinstall-link"
"${TMP_DIR}/yinstall-link" --version | grep -F "yinstall $(<"${ROOT_DIR}/VERSION")" >/dev/null

assert_success() {
	"$@" >"${TMP_DIR}/stdout" 2>"${TMP_DIR}/stderr" || {
		cat "${TMP_DIR}/stderr" >&2
		return 1
	}
}

assert_failure() {
	if "$@" >"${TMP_DIR}/stdout" 2>"${TMP_DIR}/stderr"; then
		echo "expected command to fail: $*" >&2
		return 1
	fi
}

assert_success bash "${ROOT_DIR}/yinstall.sh" --help
grep -F "yinstall $(<"${ROOT_DIR}/VERSION")" "${TMP_DIR}/stdout" >/dev/null
assert_success bash "${ROOT_DIR}/yinstall.sh" --version
grep -F "yinstall $(<"${ROOT_DIR}/VERSION")" "${TMP_DIR}/stdout" >/dev/null
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --package /missing.tar.gz
assert_failure bash "${ROOT_DIR}/yinstall.sh" os prepare -t 'bad host'
assert_failure bash "${ROOT_DIR}/yinstall.sh" clean standby --primary 10.0.0.11 -t 10.0.0.12
assert_failure bash "${ROOT_DIR}/yinstall.sh" standby add --primary 10.0.0.11 --standbys 10.0.0.12
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install -t 10.0.0.11 --package /missing.tar.gz --db-port 2
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install -t 10.0.0.11 --package /missing.tar.gz --db-port 1703 --yasom-port 1700 --yasagent-port 1702 --replicat-port 1704
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --local --package /missing.tar.gz --db-admin-password test --memory-size 1T
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --local --package /missing.tar.gz --db-admin-password test --mode mysql
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --local --package /missing.tar.gz --db-admin-password test --mysql-port 3307
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --local --package /missing.tar.gz --db-admin-password test --recommend-memory
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --local --package /missing.tar.gz --db-admin-password test --memory-limit 50
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --local --package /missing.tar.gz --db-admin-password test --character-set LATIN1

touch "${TMP_DIR}/YashanDB.tar.gz"
export TEST_MARKER="${TMP_DIR}/marker"
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --local \
	--package "${TMP_DIR}/YashanDB.tar.gz" --db-port 1703 --dry-run --log-dir "${TMP_DIR}/missing-password-logs"
assert_success env PATH="${FAKE_BIN}:${PATH}" bash "${ROOT_DIR}/yinstall.sh" db install -t 10.0.0.11 \
	--package "${TMP_DIR}/YashanDB.tar.gz" --db-admin-password test --db-port 1703 --dry-run --log-dir "${TMP_DIR}/logs"
[[ ! -e ${TEST_MARKER} ]] || {
	echo 'dry-run invoked scp' >&2
	exit 1
}

LOCAL_FAKE_BIN="${TMP_DIR}/local-bin"
mkdir -p -- "${LOCAL_FAKE_BIN}"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"${LOCAL_FAKE_BIN}/ssh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"${LOCAL_FAKE_BIN}/scp"
chmod +x "${LOCAL_FAKE_BIN}/ssh" "${LOCAL_FAKE_BIN}/scp"
assert_success env PATH="${LOCAL_FAKE_BIN}:${PATH}" bash "${ROOT_DIR}/yinstall.sh" db install --local \
	--package "${TMP_DIR}/YashanDB.tar.gz" --db-admin-password test --db-port 1703 --include-steps C-004 --dry-run --log-dir "${TMP_DIR}/local-logs"

assert_failure bash "${ROOT_DIR}/yinstall.sh" db install -t 10.0.0.11 --standbys 10.0.0.12 \
	--package "${TMP_DIR}/YashanDB.tar.gz" --db-admin-password test --db-port 1703
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --local --standbys 10.0.0.12 \
	--host-ip 10.0.0.11 --package "${TMP_DIR}/YashanDB.tar.gz" --db-admin-password test --db-port 1703

# Safe-path guard: a bare managed root must be rejected, a cluster-scoped path accepted.
SAFE_TMP="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}" "${SAFE_TMP}"' EXIT
mkdir -p -- "${SAFE_TMP}/data/yashan/ys1703"
mkdir -p -- "${SAFE_TMP}/data/yashan/ys1703/install/bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${SAFE_TMP}/data/yashan/ys1703/install/bin/yasboot"
chmod +x "${SAFE_TMP}/data/yashan/ys1703/install/bin/yasboot"
touch "${SAFE_TMP}/data/yashan/ys1703/install/hosts.toml"
# A bare /data/yashan install path must be refused.
assert_failure bash "${ROOT_DIR}/yinstall.sh" db install --local \
	--package "${TMP_DIR}/YashanDB.tar.gz" --db-admin-password test --db-port 1703 \
	--install-path /data/yashan --data-path /data/yashan --log-path /data/yashan \
	--stage-dir /data/yashan --dry-run --log-dir "${TMP_DIR}/safe-logs"
# A cluster-scoped path must be accepted (dry-run only).
assert_success bash "${ROOT_DIR}/yinstall.sh" db install --local \
	--package "${TMP_DIR}/YashanDB.tar.gz" --db-admin-password test --cluster ys1703 --db-port 1703 \
	--install-path "${SAFE_TMP}/data/yashan/ys1703/yasdb-home" \
	--data-path "${SAFE_TMP}/data/yashan/ys1703/yasdb-data" \
	--log-path "${SAFE_TMP}/data/yashan/ys1703/yasdb-log" \
	--stage-dir "${SAFE_TMP}/data/yashan/ys1703/install" \
	--include-steps C-004 --dry-run --log-dir "${TMP_DIR}/safe-logs"

# Password must be accepted from the environment and never echoed into the log.
assert_success env YINSTALL_SYS_PASSWORD='secr3t-Pass' bash "${ROOT_DIR}/yinstall.sh" db install --local \
	--package "${TMP_DIR}/YashanDB.tar.gz" --db-port 1703 --include-steps C-004 \
	--install-path "${SAFE_TMP}/data/yashan/ys1703/yasdb-home" \
	--data-path "${SAFE_TMP}/data/yashan/ys1703/yasdb-data" \
	--log-path "${SAFE_TMP}/data/yashan/ys1703/yasdb-log" \
	--stage-dir "${SAFE_TMP}/data/yashan/ys1703/install" \
	--dry-run --log-dir "${TMP_DIR}/env-pwd-logs"
if grep -rF -- 'secr3t-Pass' "${TMP_DIR}/env-pwd-logs" >/dev/null 2>&1; then
	echo 'password was echoed into the log' >&2
	exit 1
fi

echo "test_cli.sh: passed"
