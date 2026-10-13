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
grep -F -- 'set_host_yasagent_addrs' "${SCRIPT_LOG}" >/dev/null
grep -F -- 'host-addrs.awk' "${SCRIPT_LOG}" >/dev/null
if grep -F -- '--recommend-param' "${SCRIPT_LOG}" >/dev/null; then
	echo 'recommend param was enabled without a memory size' >&2
	exit 1
fi
if grep -F -- '-m mysql' "${SCRIPT_LOG}" >/dev/null; then
	echo 'default generation unexpectedly enabled MySQL mode' >&2
	exit 1
fi

: >"${SCRIPT_LOG}"
env PATH="${FAKE_BIN}:${PATH}" TEST_SCRIPT_LOG="${SCRIPT_LOG}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1703 \
	--db-port 1703 --memory-size 10G --install-path /data/yashan/ys1703/yasdb-home \
	--data-path /data/yashan/ys1703/yasdb-data --log-path /data/yashan/ys1703/yasdb-log \
	--stage-dir /data/yashan/ys1703/install --include-steps C-004 --log-dir "${TMP_DIR}/memory-logs"
# --memory-size must reach the database parameters through yasboot recommendations.
grep -F -- '--recommend-param --memory-limit ${memory_percent}' "${SCRIPT_LOG}" >/dev/null
grep -F -- 'memory_percent=$(( (10240 * 100 + total_mb - 1) / total_mb ))' "${SCRIPT_LOG}" >/dev/null

: >"${SCRIPT_LOG}"
env PATH="${FAKE_BIN}:${PATH}" TEST_SCRIPT_LOG="${SCRIPT_LOG}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --standbys 10.0.0.12 --host-ip 10.0.0.11 \
	--package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1703 \
	--db-port 1711 --install-path /data/yashan/ys1711/yasdb-home \
	--data-path /data/yashan/ys1711/yasdb-data --log-path /data/yashan/ys1711/yasdb-log \
	--stage-dir /data/yashan/ys1711/install --include-steps B-000,C-004 --log-dir "${TMP_DIR}/ha-logs"
grep -F -- '--ip 10.0.0.11,10.0.0.12' "${SCRIPT_LOG}" >/dev/null
grep -F -- '--node 2 --standby-node 1' "${SCRIPT_LOG}" >/dev/null
grep -F -- 'BatchMode=yes' "${SCRIPT_LOG}" >/dev/null

: >"${SCRIPT_LOG}"
env PATH="${FAKE_BIN}:${PATH}" TEST_SCRIPT_LOG="${SCRIPT_LOG}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1703 \
	--db-port 1703 --install-path /data/yashan/ys1703/yasdb-home \
	--data-path /data/yashan/ys1703/yasdb-data --log-path /data/yashan/ys1703/yasdb-log \
	--stage-dir /data/yashan/ys1703/install --mode mysql --mysql-port 3307 \
	--include-steps C-001,C-004 --log-dir "${TMP_DIR}/mysql-logs"
grep -F -- '-m mysql' "${SCRIPT_LOG}" >/dev/null
grep -F -- "'3307'" "${SCRIPT_LOG}" >/dev/null

# YINSTALL-014: yasboot drops the build suffix when it names the software directory,
# so --db-version must rewrite the hosts.toml path before "package install" (and the
# rewrite must not run when no version is requested).
: >"${SCRIPT_LOG}"
env PATH="${FAKE_BIN}:${PATH}" TEST_SCRIPT_LOG="${SCRIPT_LOG}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1919 \
	--db-port 1919 --db-version 27.1.1.2-356-gd953d3665a9 \
	--install-path /data/yashan/ys1919/yasdb-home \
	--data-path /data/yashan/ys1919/yasdb-data --log-path /data/yashan/ys1919/yasdb-log \
	--stage-dir /data/yashan/ys1919/install --include-steps C-006 --log-dir "${TMP_DIR}/db-version-logs"
grep -F -- "-v path='/data/yashan/ys1919/yasdb-home/27.1.1.2-356-gd953d3665a9'" "${SCRIPT_LOG}" >/dev/null
grep -F -- '.install-path' "${SCRIPT_LOG}" >/dev/null
awk '/install-path/ { rewrite = NR } /package install -t/ { install = NR } END { exit !(rewrite && install && rewrite < install) }' "${SCRIPT_LOG}" || {
	echo 'C-006 did not rewrite the software path before package install' >&2
	exit 1
}

: >"${SCRIPT_LOG}"
env PATH="${FAKE_BIN}:${PATH}" TEST_SCRIPT_LOG="${SCRIPT_LOG}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1919 \
	--db-port 1919 --install-path /data/yashan/ys1919/yasdb-home \
	--data-path /data/yashan/ys1919/yasdb-data --log-path /data/yashan/ys1919/yasdb-log \
	--stage-dir /data/yashan/ys1919/install --include-steps C-006 --log-dir "${TMP_DIR}/no-db-version-logs"
if grep -F -- '.install-path' "${SCRIPT_LOG}" >/dev/null; then
	echo 'C-006 rewrote the software path without --db-version' >&2
	exit 1
fi

# --legacy (22.2-era packages): the flat tree is verified with bin/yasdb, the config
# comes from "package config gen -t SE" with the database port as --begin-port, and the
# software is installed from the package archive with -i.
: >"${SCRIPT_LOG}"
env PATH="${FAKE_BIN}:${PATH}" TEST_SCRIPT_LOG="${SCRIPT_LOG}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1915 \
	--db-port 1915 --legacy \
	--install-path /data/yashan/ys1915/yasdb-home \
	--data-path /data/yashan/ys1915/yasdb-data --log-path /data/yashan/ys1915/yasdb-log \
	--stage-dir /data/yashan/ys1915/install \
	--include-steps C-003,C-004,C-005,C-006 --log-dir "${TMP_DIR}/legacy-logs"
grep -F -- 'bin/yasdb' "${SCRIPT_LOG}" >/dev/null
grep -F -- 'package config gen --cluster' "${SCRIPT_LOG}" >/dev/null
grep -F -- '-t SE' "${SCRIPT_LOG}" >/dev/null
grep -F -- '--begin-port 1915' "${SCRIPT_LOG}" >/dev/null
# The remote flow must hand yasboot the uploaded package path, not the caller's.
grep -F -- "package install -i '/data/yashan/soft/yashandb.tar.gz'" "${SCRIPT_LOG}" >/dev/null
# The C-005 helper comment mentions "package se gen"; only the real 23.x invocation
# ("package se gen --cluster ...") must be absent here.
if grep -F -- 'package se gen --cluster' "${SCRIPT_LOG}" >/dev/null; then
	echo 'legacy install used the 23.x package se gen' >&2
	exit 1
fi

# The rewrite helper itself: every path entry is replaced and everything else is kept.
HOST_PATH_TOML="${TMP_DIR}/host-path.toml"
printf '%s\n' \
	'uuid = "x"' \
	'[[host]]' \
	'  path = "/data/yashan/ys1919/yasdb-home/27.1.1.2"' \
	'  log_path = "/data/yashan/ys1919/yasdb-log"' \
	'[[host]]' \
	'    path = "/data/yashan/ys1919/yasdb-home/27.1.1.2"' >"${HOST_PATH_TOML}"
awk -v path=/data/yashan/ys1919/yasdb-home/27.1.1.2-356-gd953d3665a9 \
	-f "${ROOT_DIR}/steps/host-path.awk" "${HOST_PATH_TOML}" >"${TMP_DIR}/host-path.out"
test "$(grep -cF 'path = "/data/yashan/ys1919/yasdb-home/27.1.1.2-356-gd953d3665a9"' "${TMP_DIR}/host-path.out")" = 2
grep -Fx '  path = "/data/yashan/ys1919/yasdb-home/27.1.1.2-356-gd953d3665a9"' "${TMP_DIR}/host-path.out" >/dev/null
grep -Fx '    path = "/data/yashan/ys1919/yasdb-home/27.1.1.2-356-gd953d3665a9"' "${TMP_DIR}/host-path.out" >/dev/null
grep -Fx '  log_path = "/data/yashan/ys1919/yasdb-log"' "${TMP_DIR}/host-path.out" >/dev/null
if grep -F '27.1.1.2"' "${TMP_DIR}/host-path.out" >/dev/null; then
	echo 'the rewrite helper left an unqualified software path behind' >&2
	exit 1
fi

EXEC_STAGE="${TMP_DIR}/stage"
mkdir -p -- "${EXEC_STAGE}"
printf '%s\n' \
	'[om]' \
	'  [om.config]' \
	'    LISTEN_ADDR = "127.0.0.1:1686"' \
	'[[host]]' \
	'  hostid = "host0001"' \
	'  ip = "127.0.0.1"' \
	'  [host.yasagent]' \
	'    [host.yasagent.config]' \
	'      LISTEN_ADDR = "127.0.0.1:1687"' \
	'[[host]]' \
	'  hostid = "host0002"' \
	'  ip = "127.0.0.2"' \
	'  [host.yasagent]' \
	'    [host.yasagent.config]' \
	'      LISTEN_ADDR = "127.0.0.1:1687"' >"${EXEC_STAGE}/hosts.toml"
printf '%s\n' \
	'[[group]]' \
	'  [group.config]' \
	'    CHARACTER_SET = "utf8"' \
	'  [[group.node]]' \
	'    mysql_addr = "127.0.0.1:1688"' \
	'    [group.node.config]' \
	'      RUN_LOG_LEVEL = "INFO"' \
	'    [group.node.mysql_config]' >"${EXEC_STAGE}/ys1703.toml"
printf '%s\n' '#!/usr/bin/env bash' 'bash -se' >"${FAKE_BIN}/ssh"
chmod +x "${FAKE_BIN}/ssh"

env PATH="${FAKE_BIN}:${PATH}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1703 \
	--db-port 1703 --install-path "${TMP_DIR}/yasdb-home" --data-path "${TMP_DIR}/yasdb-data" \
	--log-path "${TMP_DIR}/yasdb-log" --stage-dir "${EXEC_STAGE}" --memory-size 1G \
	--mode mysql --mysql-port 3307 --use-native-type --character-set GBK --include-steps C-005 --log-dir "${TMP_DIR}/execute-logs"

grep -E 'LISTEN_ADDR = ".*:1701"' "${EXEC_STAGE}/hosts.toml" >/dev/null
grep -E 'LISTEN_ADDR = ".*:1702"' "${EXEC_STAGE}/hosts.toml" >/dev/null
test "$(grep -cF 'LISTEN_ADDR = "127.0.0.1:1702"' "${EXEC_STAGE}/hosts.toml")" = 1
test "$(grep -cF 'LISTEN_ADDR = "127.0.0.2:1702"' "${EXEC_STAGE}/hosts.toml")" = 1
grep -F '    LISTEN_ADDR = ' "${EXEC_STAGE}/hosts.toml" >/dev/null
grep -F '      LISTEN_ADDR = ' "${EXEC_STAGE}/hosts.toml" >/dev/null
# The written value is the smallest 1%-of-host-memory value that covers the
# request, so that yasom recomputes the same percentage at deploy time.
TOTAL_MB=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)
EXPECT_PERCENT=$(( (1024 * 100 + TOTAL_MB - 1) / TOTAL_MB ))
(( EXPECT_PERCENT < 1 )) && EXPECT_PERCENT=1
(( EXPECT_PERCENT > 100 )) && EXPECT_PERCENT=100
EXPECT_LIMIT=$(( (EXPECT_PERCENT * TOTAL_MB + 99) / 100 ))M
grep -F "  memory_limit = \"${EXPECT_LIMIT}\"" "${EXEC_STAGE}/hosts.toml" >/dev/null
grep -F "    memory_limit = \"${EXPECT_LIMIT}\"" "${EXEC_STAGE}/ys1703.toml" >/dev/null
grep -F '      COLUMNAR_BUFFER_SIZE = "256M"' "${EXEC_STAGE}/ys1703.toml" >/dev/null
grep -E 'mysql_addr = ".*:3307"' "${EXEC_STAGE}/ys1703.toml" >/dev/null
grep -F 'USE_NATIVE_TYPE = true' "${EXEC_STAGE}/ys1703.toml" >/dev/null
grep -F 'CHARACTER_SET = "GBK"' "${EXEC_STAGE}/ys1703.toml" >/dev/null

# --legacy must keep the port rewriting but never add COLUMNAR_BUFFER_SIZE, which does
# not exist in 22.2-era releases.
printf '%s\n' \
	'[om]' \
	'  [om.config]' \
	'    LISTEN_ADDR = "127.0.0.1:1686"' \
	'[[host]]' \
	'  hostid = "host0001"' \
	'  ip = "127.0.0.1"' \
	'  [host.yasagent]' \
	'    [host.yasagent.config]' \
	'      LISTEN_ADDR = "127.0.0.1:1687"' >"${EXEC_STAGE}/hosts.toml"
printf '%s\n' \
	'[[group]]' \
	'  [group.config]' \
	'    CHARACTER_SET = "utf8"' \
	'  [[group.node]]' \
	'    [group.node.config]' \
	'      RUN_LOG_LEVEL = "INFO"' >"${EXEC_STAGE}/ys1915.toml"
env PATH="${FAKE_BIN}:${PATH}" bash "${ROOT_DIR}/yinstall.sh" db install \
	--target 10.0.0.11 --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test --cluster ys1915 \
	--db-port 1915 --legacy --install-path "${TMP_DIR}/yasdb-home" --data-path "${TMP_DIR}/yasdb-data" \
	--log-path "${TMP_DIR}/yasdb-log" --stage-dir "${EXEC_STAGE}" --include-steps C-005 --log-dir "${TMP_DIR}/legacy-execute-logs"
grep -E 'LISTEN_ADDR = ".*:1913"' "${EXEC_STAGE}/hosts.toml" >/dev/null
grep -E 'LISTEN_ADDR = ".*:1914"' "${EXEC_STAGE}/hosts.toml" >/dev/null
if grep -F 'COLUMNAR_BUFFER_SIZE' "${EXEC_STAGE}/ys1915.toml" >/dev/null; then
	echo 'legacy C-005 wrote COLUMNAR_BUFFER_SIZE' >&2
	exit 1
fi

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

# YINSTALL-013: the C-001 port check must anchor the port pattern and keep it quoted.
# A five-digit listener (:19205 from a neighbouring cluster) must not make managed
# port 1920 look busy, while a real listener on the managed port must still fail.
printf '%s\n' '#!/usr/bin/env bash' 'cat "${TEST_SS_OUTPUT}"' >"${FAKE_BIN}/ss"
chmod +x "${FAKE_BIN}/ss"
PORT_CHECK_ARGS=(
	db install --local --package "${TMP_DIR}/yashandb.tar.gz" --db-admin-password test
	--cluster ys1919 --db-port 1919
	--install-path "${TMP_DIR}/port-check/yasdb-home" --data-path "${TMP_DIR}/port-check/yasdb-data"
	--log-path "${TMP_DIR}/port-check/yasdb-log" --stage-dir "${TMP_DIR}/port-check/install"
	--include-steps C-001 --log-dir "${TMP_DIR}/port-check-logs"
)
printf '%s\n' 'LISTEN 0 512 192.168.23.5:19205 0.0.0.0:*' 'LISTEN 0 512 192.168.23.5:19206 0.0.0.0:*' >"${TMP_DIR}/ss-prefix-only"
env PATH="${FAKE_BIN}:${PATH}" TEST_SS_OUTPUT="${TMP_DIR}/ss-prefix-only" \
	bash "${ROOT_DIR}/yinstall.sh" "${PORT_CHECK_ARGS[@]}" >"${TMP_DIR}/port-check-stdout" 2>"${TMP_DIR}/port-check-stderr" || {
	cat "${TMP_DIR}/port-check-stderr" >&2
	echo 'C-001 treated a five-digit listener as a managed port conflict' >&2
	exit 1
}
printf '%s\n' 'LISTEN 0 512 192.168.23.5:1920 0.0.0.0:*' >"${TMP_DIR}/ss-exact-port"
if env PATH="${FAKE_BIN}:${PATH}" TEST_SS_OUTPUT="${TMP_DIR}/ss-exact-port" \
	bash "${ROOT_DIR}/yinstall.sh" "${PORT_CHECK_ARGS[@]}" >"${TMP_DIR}/port-check-stdout" 2>"${TMP_DIR}/port-check-stderr"; then
	echo 'C-001 did not report an exact managed port conflict' >&2
	exit 1
fi
grep -F 'managed port 1920 is already listening' "${TMP_DIR}/port-check-stderr" >/dev/null

echo "test_ports.sh: passed"
