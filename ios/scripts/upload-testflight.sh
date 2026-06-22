#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$ROOT/archive/NFGCrash.xcarchive"
EXPORT_DIR="$ROOT/export"
PLIST="$ROOT/export/ExportOptions-AppStore.plist"

echo "==> Archive (Release) → $ARCHIVE"
rm -rf "$ARCHIVE"

xcodebuild -project "$ROOT/NFGCrash.xcodeproj" \
  -scheme NFGCrash \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  archive

echo "==> Upload to App Store Connect / TestFlight"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$PLIST"

echo "==> Done. Check App Store Connect for processing status."
