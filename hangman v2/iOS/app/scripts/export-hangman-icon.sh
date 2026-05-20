#!/usr/bin/env bash
# Export 1024x1024 PNG for Xcode App Icon from the SVG master.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/public/nfg-hangman-app-icon.svg"
OUT="$ROOT/public/NFG-Hangman-AppIcon-1024.png"

if ! command -v qlmanage >/dev/null 2>&1; then
  echo "qlmanage not found. Open $SVG in Preview → Export → PNG (1024 px)."
  exit 1
fi

TMP="$(mktemp -d)"
qlmanage -t -s 1024 -o "$TMP" "$SVG" >/dev/null 2>&1 || true
PNG="$(find "$TMP" -name '*.png' | head -1)"
if [[ -z "$PNG" ]]; then
  echo "Could not rasterize SVG. Open $SVG in Preview → Export → PNG (1024 px)."
  rm -rf "$TMP"
  exit 1
fi
cp "$PNG" "$OUT"
rm -rf "$TMP"
echo "Wrote $OUT"
echo "In Xcode (after cap add ios): set App Icon to this PNG."
