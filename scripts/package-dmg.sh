#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.0}"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$BUILD_DIR/BatteryWatt.app"
STAGING_DIR="$BUILD_DIR/dmg-root"
DMG_PATH="$DIST_DIR/BatteryWatt-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/BatteryWatt-$VERSION.zip"

"$ROOT_DIR/scripts/build.sh" "$VERSION" >/dev/null
rm -rf "$STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
mkdir -p "$DIST_DIR" "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/BatteryWatt.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "BatteryWatt $VERSION" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
(cd "$DIST_DIR" && shasum -a 256 "BatteryWatt-$VERSION.dmg" "BatteryWatt-$VERSION.zip" > SHA256SUMS.txt)

echo "$DMG_PATH"
