#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "${TMP_DIR}"' EXIT
FAKE_BIN="${TMP_DIR}/bin"
SCRIPT_LOG="${TMP_DIR}/remote-scripts"
mkdir -p -- "${FAKE_BIN}"
touch "${TMP_DIR}/yashandb.tar.gz"

printf '%s\n' '#!/usr/bin/env bash' 'cat >>"${TEST_SCRIPT_LOG}"' 'printf "\n---\n" >>"${TEST_SCRIPT_LOG}"' 'exit 0' >"${FAKE_BIN}/ssh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${FAKE_BIN}/scp"
printf '%s\n' '#!/usr/bin/env bash' 'while (($#)); do' '  if [[ $1 == -- ]]; then shift; exec "$@"; fi' '  shift' 'done' 'exit 1' >"${FAKE_BIN}/runuser"
chmod +x "${FAKE_BIN}/ssh" "${FAKE_BIN}/scp"
chmod +x "${FAKE_BIN}/runuser"

env PATH="${FAKE_BIN}:${PATH}" TEST_SCRIPT_LOG="${SCRIPT_LOG}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1703 \
	--db-port 1703 --install-path /data/yashan/ys1703/yasdb-home \
	--data-path /data/yashan/ys1703/yasdb-data --log-path /data/yashan/ys1703/yasdb-log \
	--stage-dir /data/yashan/ys1703/install --include-steps C-004,C-005 --log-dir "${TMP_DIR}/logs"

grep -F -- '--begin-port 1703' "${SCRIPT_LOG}" >/dev/null
grep -F -- '1701 1702' "${SCRIPT_LOG}" >/dev/null
grep -F -- "set_listen_addr '[om.config]'" "${SCRIPT_LOG}" >/dev/null
grep -F -- "set_listen_addr '[host.yasagent.config]'" "${SCRIPT_LOG}" >/dev/null
if grep -F -- '--recommend-param' "${SCRIPT_LOG}" >/dev/null; then
	echo 'default generation unexpectedly enabled recommended memory' >&2
	exit 1
fi

: >"${SCRIPT_LOG}"
env PATH="${FAKE_BIN}:${PATH}" TEST_SCRIPT_LOG="${SCRIPT_LOG}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1703 \
	--db-port 1703 --install-path /data/yashan/ys1703/yasdb-home \
	--data-path /data/yashan/ys1703/yasdb-data --log-path /data/yashan/ys1703/yasdb-log \
	--stage-dir /data/yashan/ys1703/install --recommend-memory --memory-limit 25 \
	--include-steps C-004 --log-dir "${TMP_DIR}/recommend-logs"
grep -F -- '--recommend-param --memory-limit 25' "${SCRIPT_LOG}" >/dev/null

EXEC_STAGE="${TMP_DIR}/stage"
mkdir -p -- "${EXEC_STAGE}"
printf '%s\n' \
	'[om]' \
	'  [om.config]' \
	'    LISTEN_ADDR = "127.0.0.1:1686"' \
	'[[host]]' \
	'  memory_limit = "5152M"' \
	'  [host.yasagent]' \
	'    [host.yasagent.config]' \
	'      LISTEN_ADDR = "127.0.0.1:1687"' >"${EXEC_STAGE}/hosts.toml"
printf '%s\n' \
	'[[group]]' \
	'  [[group.node]]' \
	'    memory_limit = "5152M"' \
	'    [group.node.config]' \
	'      RUN_LOG_LEVEL = "INFO"' >"${EXEC_STAGE}/ys1703.toml"
printf '%s\n' '#!/usr/bin/env bash' 'bash -se' >"${FAKE_BIN}/ssh"
chmod +x "${FAKE_BIN}/ssh"

env PATH="${FAKE_BIN}:${PATH}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1703 \
	--db-port 1703 --install-path "${TMP_DIR}/yasdb-home" --data-path "${TMP_DIR}/yasdb-data" \
	--log-path "${TMP_DIR}/yasdb-log" --stage-dir "${EXEC_STAGE}" --memory-size 1G --include-steps C-005 --log-dir "${TMP_DIR}/execute-logs"

grep -E 'LISTEN_ADDR = ".*:1701"' "${EXEC_STAGE}/hosts.toml" >/dev/null
grep -E 'LISTEN_ADDR = ".*:1702"' "${EXEC_STAGE}/hosts.toml" >/dev/null
grep -F '    LISTEN_ADDR = ' "${EXEC_STAGE}/hosts.toml" >/dev/null
grep -F '      LISTEN_ADDR = ' "${EXEC_STAGE}/hosts.toml" >/dev/null
grep -F '  memory_limit = "1024M"' "${EXEC_STAGE}/hosts.toml" >/dev/null
grep -F '    memory_limit = "1024M"' "${EXEC_STAGE}/ys1703.toml" >/dev/null
grep -F '      COLUMNAR_BUFFER_SIZE = "256M"' "${EXEC_STAGE}/ys1703.toml" >/dev/null

LOCAL_SCRIPT_LOG="${TMP_DIR}/local-scripts"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"${FAKE_BIN}/ssh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"${FAKE_BIN}/scp"
printf '%s\n' '#!/usr/bin/env bash' 'cat >>"${TEST_LOCAL_SCRIPT_LOG}"' 'printf "\n---\n" >>"${TEST_LOCAL_SCRIPT_LOG}"' 'exit 0' >"${FAKE_BIN}/sudo"
chmod +x "${FAKE_BIN}/ssh" "${FAKE_BIN}/scp" "${FAKE_BIN}/sudo"

env PATH="${FAKE_BIN}:${PATH}" YINSTALL_SUDO_BIN="${FAKE_BIN}/sudo" TEST_LOCAL_SCRIPT_LOG="${LOCAL_SCRIPT_LOG}" bash "${ROOT_DIR}/yinstall.sh" db install --local \
	--package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1703 --db-port 1703 \
	--install-path /data/yashan/ys1703/yasdb-home \
	--data-path /data/yashan/ys1703/yasdb-data --log-path /data/yashan/ys1703/yasdb-log \
	--stage-dir /data/yashan/ys1703/install --include-steps C-004,C-007 --log-dir "${TMP_DIR}/local-logs"

grep -F -- 'package se gen' "${LOCAL_SCRIPT_LOG}" >/dev/null
grep -F -- ' -N --ip ' "${LOCAL_SCRIPT_LOG}" >/dev/null
grep -F -- 'cluster deploy' "${LOCAL_SCRIPT_LOG}" >/dev/null
if ! grep -Eq -- 'cluster deploy.*[[:space:]]-p[[:space:]]' "${LOCAL_SCRIPT_LOG}"; then
	echo 'local mode did not pass a database password to yasboot cluster deploy' >&2
	exit 1
fi
if grep -Eq -- 'package se gen.*[[:space:]]-p[[:space:]]' "${LOCAL_SCRIPT_LOG}"; then
	echo 'local mode passed a database password to yasboot package se gen' >&2
	exit 1
fi

echo "test_ports.sh: passed"
