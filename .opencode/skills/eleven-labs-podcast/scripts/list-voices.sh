#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SKILL_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  printf "Missing %s. Copy .env.example to .env and set ELEVEN_LABS_API.\n" "$ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

API_KEY="${ELEVEN_LABS_API:-${ELEVENLABS_API_KEY:-}}"
: "${API_KEY:?ELEVEN_LABS_API is required in .opencode/skills/eleven-labs-podcast/.env}"

API_BASE="${ELEVEN_LABS_API_BASE:-https://api.elevenlabs.io}"
VOICES_JSON="$(curl -sS \
  -H "Accept: application/json" \
  -H "xi-api-key: $API_KEY" \
  "$API_BASE/v1/voices")"

if command -v jq >/dev/null 2>&1; then
  printf "%s\n" "$VOICES_JSON" | jq '.voices[] | {name, voice_id, labels}'
else
  printf "%s\n" "$VOICES_JSON"
fi
