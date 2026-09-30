#!/usr/bin/env bash
# Build a DMG from a .app bundle. The app is packaged as-is: pass a notarized
# app for distribution, or an ad-hoc signed one for internal builds.
# Usage: make_dmg.sh <path-to-app> <output-dmg>
set -euo pipefail

APP_PATH="${1:?missing app path}"
OUT_DMG="${2:?missing output dmg path}"
APP_NAME="$(basename "$APP_PATH" .app)"
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

mkdir -p "$(dirname "$OUT_DMG")"
rm -f "$OUT_DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$OUT_DMG"

echo "Built $OUT_DMG"
