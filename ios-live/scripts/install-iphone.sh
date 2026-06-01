#!/usr/bin/env bash
# Install the most recent NFG Live device build onto a connected iPhone.
# Usage: ./scripts/install-iphone.sh DEVICE_ID
# Find DEVICE_ID with: xcrun xctrace list devices
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_ID="${1:-}"
if [[ -z "$DEVICE_ID" ]]; then
  echo "Usage: $0 DEVICE_ID"
  echo "List devices: xcrun xctrace list devices"
  exit 1
fi

APP=".derivedDataDevice/Build/Products/Release-iphoneos/NFGLive.app"
if [[ ! -d "$APP" ]]; then
  echo "No device build found at $APP"
  echo "Run: ./scripts/build-iphone.sh $DEVICE_ID   (build first)"
  exit 1
fi

echo "==> Installing $APP onto $DEVICE_ID"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
echo "==> Done. Launch 'NFG Live' on the iPhone."
