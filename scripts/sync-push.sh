#!/usr/bin/env bash
# Push local NFG changes to GitHub (run on Mac after Cursor edits).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 ]]; then
  echo "Usage: ./scripts/sync-push.sh \"commit message\""
  exit 1
fi
MSG="$*"

git fetch origin
BEHIND="$(git rev-list HEAD..origin/main --count 2>/dev/null || echo 0)"
if [[ "${BEHIND}" -gt 0 ]]; then
  echo "You are ${BEHIND} commit(s) behind origin/main."
  echo "Run ./scripts/sync-pull.sh first, then push again."
  exit 1
fi

if [[ -z "$(git status --porcelain)" ]]; then
  echo "Nothing to commit. Working tree clean."
  exit 0
fi

echo "Changes to push:"
git status -sb
echo ""

git add -A
git commit -m "$MSG"
git push origin main

echo ""
echo "Pushed to https://github.com/Y666SUF/NFG (main)"
echo "On PC:  cd C:\\Users\\Yusef\\test && .\\scripts\\sync-pull.ps1"
