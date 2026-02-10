#!/usr/bin/env bash
set -euo pipefail

# sync-submodules.sh
# Purpose: Safely update submodules to commits pinned by the root repo.
# Behavior: Refuses to proceed if any submodule is dirty unless STASH_DIRTY=1.

STASH_DIRTY="${STASH_DIRTY:-0}"

echo "[sync-submodules] start: $(date)"

echo "[sync-submodules] pulling root"
git pull

echo "[sync-submodules] syncing submodule URLs"
git submodule sync --recursive

echo "[sync-submodules] checking dirty submodules"
DIRTY=0
while IFS= read -r line; do
  # lines look like: "Entering '<path>'"
  if [[ "$line" =~ Entering\ \'(.*)\' ]]; then
    SUB_PATH="${BASH_REMATCH[1]}"
    STATUS="$(git -C "$SUB_PATH" status --porcelain || true)"
    if [[ -n "$STATUS" ]]; then
      echo "[sync-submodules] DIRTY: $SUB_PATH"
      if [[ "$STASH_DIRTY" == "1" ]]; then
        git -C "$SUB_PATH" stash push -u -m "wip: allow submodule update"
      else
        DIRTY=1
      fi
    fi
  fi
done < <(git submodule foreach --recursive 'true')

if [[ "$DIRTY" == "1" ]]; then
  echo "[sync-submodules] abort: dirty submodules detected"
  echo "[sync-submodules] re-run with STASH_DIRTY=1 to auto-stash"
  exit 2
fi

echo "[sync-submodules] updating submodules (pinned commits)"
git submodule update --init --recursive

echo "[sync-submodules] done: $(date)"
