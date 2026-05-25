#!/usr/bin/env bash
# Release simulator build (no signing).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIM_NAME="${1:-iPhone 17 Pro Max}"
echo "Building for simulator: $SIM_NAME"
xcodebuild -scheme NFGCrash \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -configuration Release \
  -derivedDataPath "$ROOT/.derivedData" \
  build | tail -20
echo "BUILD finished."
