#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SKILL_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy .env.example to .env and set RENDER_API_KEY." >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

: "${RENDER_API_KEY:?RENDER_API_KEY is required in .opencode/skills/render/.env}"

METHOD="${1:-GET}"
PATH_OR_URL="${2:-/services}"
BODY="${3:-}"
BASE_URL="${RENDER_API_BASE:-https://api.render.com/v1}"

if [[ "$PATH_OR_URL" == http://* || "$PATH_OR_URL" == https://* ]]; then
  URL="$PATH_OR_URL"
else
  URL="$BASE_URL$PATH_OR_URL"
fi

if [[ -n "$BODY" ]]; then
  curl -sS -X "$METHOD" \
    -H "Authorization: Bearer $RENDER_API_KEY" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --data "$BODY" \
    "$URL"
  exit 0
fi

curl -sS -X "$METHOD" \
  -H "Authorization: Bearer $RENDER_API_KEY" \
  -H "Accept: application/json" \
  "$URL"
