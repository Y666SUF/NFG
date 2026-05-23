#!/usr/bin/env bash
# Show (and copy) the pending cross-device Agent prompt for THIS machine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PENDING="$ROOT/docs/cross-device/pending-on-mac.md"
if [[ ! -f "$PENDING" ]]; then
  echo "No pending file at docs/cross-device/pending-on-mac.md"
  exit 0
fi

if ! grep -qiE 'cross_device_status:\s*pending' "$PENDING"; then
  echo "No pending Mac task (cross_device_status is not pending)."
  echo "File: docs/cross-device/pending-on-mac.md"
  exit 0
fi

TITLE="$(grep -iE '^title:' "$PENDING" | head -1 | sed 's/^title:[[:space:]]*//' | tr -d "\"'" || true)"
PROMPT="Run the pending cross-device task in @docs/cross-device/pending-on-mac.md"

echo ""
echo "PENDING MAC TASK${TITLE:+: $TITLE}"
echo "=============================================="
echo ""
echo "1. Open Cursor Agent on this Mac"
echo "2. Send this (copied to clipboard if pbcopy available):"
echo ""
echo "$PROMPT"
echo ""

if command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$PROMPT" | pbcopy
  echo "Copied to clipboard."
fi
