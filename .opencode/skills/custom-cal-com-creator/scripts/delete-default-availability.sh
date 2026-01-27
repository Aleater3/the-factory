#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

: "${CAL_API_KEY:?CAL_API_KEY is required}"
: "${DEFAULT_AVAILABILITY_ID:?DEFAULT_AVAILABILITY_ID is required}"

curl -sS -X DELETE "https://api.cal.com/v1/availabilities/${DEFAULT_AVAILABILITY_ID}?apiKey=${CAL_API_KEY}"
