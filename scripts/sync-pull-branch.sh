#!/usr/bin/env bash
# Pull latest for the current branch (default: emergent/ui-polish-2026).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BRANCH="${1:-$(git branch --show-current)}"
if [[ -z "$BRANCH" ]]; then
  BRANCH="emergent/ui-polish-2026"
fi

git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

echo ""
echo "Updated $(pwd) on branch $BRANCH"
echo "Open ios/NFGCrash.xcodeproj and press ⌘R to run on your iPhone."
