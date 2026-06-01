#!/usr/bin/env bash
# Build NFG Live (Release) for a connected iPhone.
# Usage: ./scripts/build-iphone.sh [DEVICE_ID]
# If DEVICE_ID is omitted, builds for "generic/platform=iOS" (no install).
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_ID="${1:-}"
SCHEME="NFGLive"
CONFIG="Release"
DERIVED=".derivedDataDevice"

if [[ -n "$DEVICE_ID" ]]; then
  DEST="id=$DEVICE_ID"
else
  DEST="generic/platform=iOS"
fi

echo "==> Building $SCHEME ($CONFIG) for $DEST"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  build

echo "==> Built: $DERIVED/Build/Products/$CONFIG-iphoneos/$SCHEME.app"
