#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_PATH="$BUILD_DIR/BatteryWatt.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/BatteryWatt"
ICON_SOURCE="$ROOT_DIR/Resources/BatteryWattIcon.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

/usr/bin/xcrun swiftc \
  -O \
  -whole-module-optimization \
  -target arm64-apple-macosx15.0 \
  -framework AppKit \
  -framework IOKit \
  -framework ServiceManagement \
  "$ROOT_DIR"/Sources/*.swift \
  -o "$EXECUTABLE_PATH"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
/bin/mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512; do
  /usr/bin/sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  /usr/bin/sips -z "$double_size" "$double_size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$APP_PATH/Contents/Resources/AppIcon.icns"
/usr/bin/codesign --force --deep --sign - "$APP_PATH"

echo "$APP_PATH"
