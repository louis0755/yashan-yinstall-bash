#!/usr/bin/env bash
# Aggregate syntax check and CLI tests for the yinstall installer.
# Usage: tests/run_all.sh [--shellcheck]
set -Eeuo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

echo "== syntax check =="
bash -n "${ROOT_DIR}/yinstall.sh" "${ROOT_DIR}"/lib/*.sh "${ROOT_DIR}"/steps/*.sh "${ROOT_DIR}"/tests/test_*.sh

if [[ ${1:-} == --shellcheck ]]; then
	echo "== shellcheck =="
	if command -v shellcheck >/dev/null 2>&1; then
		shellcheck "${ROOT_DIR}/yinstall.sh" "${ROOT_DIR}"/lib/*.sh "${ROOT_DIR}"/steps/*.sh
	else
		echo "shellcheck not found; skipping" >&2
	fi
fi

echo "== test_cli.sh =="
bash "${ROOT_DIR}/tests/test_cli.sh"
echo "== test_ports.sh =="
bash "${ROOT_DIR}/tests/test_ports.sh"

echo "run_all.sh: passed"
