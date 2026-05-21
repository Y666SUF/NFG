#!/usr/bin/env bash
# Google Mobile Ads SPM binary targets sometimes fail to download in CI/CLI.
# Run after resolvePackageDependencies; safe to re-run.
set -euo pipefail

if [[ -z "${DERIVED_DATA:-}" ]]; then
  echo "Set DERIVED_DATA to your Xcode DerivedData path for NFGCrash."
  exit 1
fi

ART_ROOT="$DERIVED_DATA/SourcePackages/artifacts"
GMA_ZIP="https://dl.google.com/googleadmobadssdk/c8c5523373ed76aa/googlemobileadsios-spm-12.14.0.zip"
UMP_ZIP="https://dl.google.com/googleadmobadssdk/90fe6bf3b0f4ce0d/googleusermessagingplatformios-spm-3.1.0.zip"

TMP="${TMPDIR:-/tmp}/nfg-spm-$$"
mkdir -p "$TMP"

echo "==> Download Google Mobile Ads xcframework"
curl -fsSL "$GMA_ZIP" -o "$TMP/gma.zip"
unzip -oq "$TMP/gma.zip" -d "$TMP/gma"
mkdir -p "$ART_ROOT/swift-package-manager-google-mobile-ads/GoogleMobileAds"
rm -rf "$ART_ROOT/swift-package-manager-google-mobile-ads/GoogleMobileAds/GoogleMobileAds.xcframework"
cp -R "$TMP/gma/GoogleMobileAds.xcframework" "$ART_ROOT/swift-package-manager-google-mobile-ads/GoogleMobileAds/"

echo "==> Download User Messaging Platform xcframework"
curl -fsSL "$UMP_ZIP" -o "$TMP/ump.zip"
unzip -oq "$TMP/ump.zip" -d "$TMP/ump"
mkdir -p "$ART_ROOT/swift-package-manager-google-user-messaging-platform/UserMessagingPlatform"
rm -rf "$ART_ROOT/swift-package-manager-google-user-messaging-platform/UserMessagingPlatform/UserMessagingPlatform.xcframework"
cp -R "$TMP/ump/UserMessagingPlatform.xcframework" "$ART_ROOT/swift-package-manager-google-user-messaging-platform/UserMessagingPlatform/"

rm -rf "$TMP"
test -d "$ART_ROOT/swift-package-manager-google-mobile-ads/GoogleMobileAds/GoogleMobileAds.xcframework"
test -d "$ART_ROOT/swift-package-manager-google-user-messaging-platform/UserMessagingPlatform/UserMessagingPlatform.xcframework"
echo "==> AdMob SPM artifacts ready under $ART_ROOT"
