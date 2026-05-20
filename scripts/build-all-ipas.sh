#!/usr/bin/env bash
# Build NFG Crash + NFG Hangman IPAs into releases/ipa/ (for GitHub + sideload).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/releases/ipa"
NODE_BIN="${NODE_BIN:-}"
if [[ -z "$NODE_BIN" ]]; then
  if command -v npm >/dev/null 2>&1; then
    NODE_BIN="$(dirname "$(command -v npm)")"
  elif [[ -x /tmp/node-v22.15.1-darwin-arm64/bin/npm ]]; then
    NODE_BIN="/tmp/node-v22.15.1-darwin-arm64/bin"
  fi
fi
export PATH="${NODE_BIN:+$NODE_BIN:}$PATH"

mkdir -p "$OUT_DIR"

echo "=== NFG Crash (Swift) ==="
CRASH_ARCHIVE="$ROOT/ios/archive/NFGCrash.xcarchive"
rm -rf "$CRASH_ARCHIVE" "$ROOT/ios/export/NFGCrash.ipa"
xcodebuild -project "$ROOT/ios/NFGCrash.xcodeproj" \
  -scheme NFGCrash \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -archivePath "$CRASH_ARCHIVE" \
  archive
xcodebuild -exportArchive \
  -archivePath "$CRASH_ARCHIVE" \
  -exportPath "$ROOT/ios/export" \
  -exportOptionsPlist "$ROOT/ios/export/ExportOptions.plist"
cp "$ROOT/ios/export/NFGCrash.ipa" "$OUT_DIR/NFG-Crash.ipa"
echo "Wrote $OUT_DIR/NFG-Crash.ipa"

echo "=== NFG Hangman (Capacitor) ==="
HM_APP="$ROOT/hangman v2/iOS/app"
cd "$HM_APP"
npm install
npm run build
npx cap sync ios
HM_ARCHIVE="$HM_APP/ios/archive/App.xcarchive"
rm -rf "$HM_ARCHIVE" "$HM_APP/ios/export/App.ipa"
xcodebuild -project "$HM_APP/ios/App/App.xcodeproj" \
  -scheme App \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -archivePath "$HM_ARCHIVE" \
  archive
mkdir -p "$HM_APP/ios/export"
xcodebuild -exportArchive \
  -archivePath "$HM_ARCHIVE" \
  -exportPath "$HM_APP/ios/export" \
  -exportOptionsPlist "$HM_APP/ios/export/ExportOptions.plist"
cp "$HM_APP/ios/export/App.ipa" "$OUT_DIR/NFG-Hangman.ipa"
echo "Wrote $OUT_DIR/NFG-Hangman.ipa"

ls -lh "$OUT_DIR"/*.ipa
echo "Done. Copy to PC Downloads or commit releases/ipa/ for GitHub."
