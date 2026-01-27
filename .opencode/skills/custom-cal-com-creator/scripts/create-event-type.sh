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
: "${SCHEDULE_ID:?SCHEDULE_ID is required}"

EVENT_TITLE=${EVENT_TITLE:-"Tom x OpenWork"}
EVENT_SLUG=${EVENT_SLUG:-"tom-x-openwork"}
EVENT_LENGTH=${EVENT_LENGTH:-30}
LOCATION_TYPE=${LOCATION_TYPE:-"integrations:daily"}

payload=$(cat <<EOF
{"title":"${EVENT_TITLE}","slug":"${EVENT_SLUG}","length":${EVENT_LENGTH},"scheduleId":${SCHEDULE_ID},"metadata":{},"locations":[{"type":"${LOCATION_TYPE}"}]}
EOF
)

curl -sS -X POST "https://api.cal.com/v1/event-types?apiKey=${CAL_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$payload"
