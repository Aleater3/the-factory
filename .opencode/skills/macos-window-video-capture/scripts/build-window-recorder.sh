#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
SOURCE_FILE="${SCRIPT_DIR}/macos-window-recorder.swift"
BIN_DIR="${SKILL_DIR}/bin"
BIN_FILE="${BIN_DIR}/macos-window-recorder"

mkdir -p "${BIN_DIR}"

xcrun swiftc -O "${SOURCE_FILE}" -o "${BIN_FILE}"

echo "Built ${BIN_FILE}"
