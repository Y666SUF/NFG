#!/usr/bin/env bash
# Release build for a connected iPhone (signing required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVICE_ID="${1:-}"
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null | awk '/connected/ { print $3; exit }')"
fi
if [[ -z "$DEVICE_ID" ]]; then
  echo "No connected iPhone. Plug in device and trust this Mac."
  exit 1
fi

echo "Building NFGCrash for device ${DEVICE_ID}..."
xcodebuild -scheme NFGCrash \
  -destination "id=$DEVICE_ID" \
  -configuration Release \
  -derivedDataPath "$ROOT/.derivedData" \
  build | tail -20

echo "Build output: $ROOT/.derivedData/Build/Products/Release-iphoneos/NFGCrash.app"
