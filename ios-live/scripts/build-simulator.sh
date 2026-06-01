#!/usr/bin/env bash
# Build NFG Live for the iOS Simulator (quick compile check).
# Usage: ./scripts/build-simulator.sh ["iPhone 17 Pro"]
set -euo pipefail

cd "$(dirname "$0")/.."

SIM_NAME="${1:-iPhone 17 Pro}"

echo "==> Building NFGLive (Debug) for Simulator: $SIM_NAME"
xcodebuild \
  -scheme NFGLive \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath .build \
  build
