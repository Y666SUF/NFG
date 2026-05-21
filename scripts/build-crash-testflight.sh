#!/usr/bin/env bash
# Archive NFG Crash (Release) and export an App Store .ipa for TestFlight / Transporter.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
PROJECT="$IOS/NFGCrash.xcodeproj"
SCHEME="NFGCrash"
ARCHIVE="$IOS/archive/NFGCrash-AppStore.xcarchive"
EXPORT_DIR="$IOS/export/appstore"
OUT_IPA="$EXPORT_DIR/NFG-Crash-AppStore.ipa"

echo "==> Archive Release (App Store)"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  archive

mkdir -p "$EXPORT_DIR"
echo "==> Export for App Store Connect"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$IOS/export/ExportOptions-appstore.plist"

if [[ -f "$EXPORT_DIR/NFGCrash.ipa" ]]; then
  cp "$EXPORT_DIR/NFGCrash.ipa" "$OUT_IPA"
fi

echo ""
echo "Done."
echo "  IPA: $OUT_IPA"
ls -lh "$OUT_IPA" 2>/dev/null || ls -lh "$EXPORT_DIR"/*.ipa 2>/dev/null || true
echo ""
echo "Upload with Apple Transporter or Xcode → Distribute App → App Store Connect."
echo "See ios/TESTFLIGHT-SETUP.md for App Store Connect steps."
