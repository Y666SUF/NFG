#!/usr/bin/env bash
# Fast device install — avoids devicectl hanging without --timeout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${ROOT}/.derivedData/Build/Products/Release-iphoneos/NFGCrash.app"
DEVICE_ID="${1:-780913DE-A5CD-5D65-9A69-F9CC38DD7D59}"
TIMEOUT_SEC="${INSTALL_TIMEOUT:-120}"

if [[ ! -d "$APP" ]]; then
  echo "Missing build. Run first:"
  echo "  cd \"$ROOT\" && ./scripts/build-iphone.sh"
  exit 1
fi

echo "Installing to device $DEVICE_ID (timeout ${TIMEOUT_SEC}s)…"
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  --timeout "$TIMEOUT_SEC" \
  --quiet \
  "$APP"
echo "Done. Open NFG Crash on your iPhone."
