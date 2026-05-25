#!/usr/bin/env bash
# Push current branch to GitHub (NFG Crash work on emergent/ui-polish-2026, etc.).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 ]]; then
  echo "Usage: ./scripts/sync-push-branch.sh \"commit message\""
  exit 1
fi
MSG="$*"
BRANCH="$(git branch --show-current)"

git fetch origin

if [[ -z "$(git status --porcelain -- ':!ios/.derivedData' ':!**/*.xcuserstate' ':!**/xcuserdata/**')" ]]; then
  echo "Nothing to commit (ignoring build artifacts)."
  git status -sb
  exit 0
fi

echo "Branch: $BRANCH"
echo "Changes:"
git status -sb -- ':!ios/.derivedData' ':!**/*.xcuserstate' ':!**/xcuserdata/**'
echo ""

git add -A -- ':!ios/.derivedData' ':!**/*.xcuserstate' ':!**/xcuserdata/**'
if git diff --cached --quiet; then
  echo "No staged changes after excluding build artifacts."
  exit 0
fi

git commit -m "$MSG"
git push -u origin "$BRANCH"

echo ""
echo "Pushed to https://github.com/Y666SUF/NFG ($BRANCH)"
echo "On another Mac:  cd ~/Documents/nfg-crash && git pull origin $BRANCH"
