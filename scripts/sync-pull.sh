#!/usr/bin/env bash
# Pull latest NFG code from GitHub (run on Mac before working, or after PC pushed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STASHED=0
if [[ -n "$(git status --porcelain)" ]]; then
  STAMP="$(date '+%Y-%m-%d %H:%M')"
  echo "Stashing local changes ($STAMP)..."
  git stash push -u -m "sync-pull auto-stash $STAMP"
  STASHED=1
fi

git fetch origin
git pull --rebase origin main

if [[ "$STASHED" -eq 1 ]]; then
  echo "Re-applying your stashed changes..."
  git stash pop
fi

echo ""
echo "Synced with origin/main:"
git log -1 --oneline

bash "$(dirname "$0")/run-pending-task.sh"
