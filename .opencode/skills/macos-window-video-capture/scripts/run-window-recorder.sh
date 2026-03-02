#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
BIN_FILE="${SKILL_DIR}/bin/macos-window-recorder"

if [[ -f "${SKILL_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SKILL_DIR}/.env"
  set +a
fi

if [[ ! -x "${BIN_FILE}" ]]; then
  bash "${SCRIPT_DIR}/build-window-recorder.sh"
fi

exec "${BIN_FILE}" "$@"
