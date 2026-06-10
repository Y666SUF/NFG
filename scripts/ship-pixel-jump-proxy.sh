#!/usr/bin/env bash
# Push Pixel Jump proxy changes to nfg-crash (Windows server auto-pulls if configured).
set -euo pipefail
cd "$(dirname "$0")/.."

MSG="${1:-Add Pixel Jump API proxy (/api/pixel-jump + WS /api/ws/mp) on port 8001.}"

echo "→ Shipping nfg-crash Pixel Jump proxy to origin"
git add server/pixel-jump-proxy.js server/pixel-jump-process.js server/index.js server/hangman-proxy.js
git diff --cached --quiet && echo "Nothing to commit." && exit 0
git commit -m "$MSG"
git push -u origin HEAD
echo ""
echo "On Windows server: pull nfg-crash and restart the NFG Crash node process."
echo "Ensure Pixel Jump API is on http://127.0.0.1:8001 (docker compose in NFG-JUMP-MULTIPLAYER)."
echo "Verify:"
echo "  curl -s https://y666suf.com/api/pixel-jump/"
echo "  curl -s -X POST https://y666suf.com/api/pixel-jump/mp/rooms -H 'Content-Type: application/json' -d '{\"hostName\":\"Test\",\"character\":\"char-cat-0\"}'"
