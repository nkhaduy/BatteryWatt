#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_PATH="$BUILD_DIR/BatteryWatt.app"
VERSION="${1:-1.0.0}"
MIN_MACOS="${MACOS_MIN_VERSION:-13.0}"
SWIFTC="$(xcrun --find swiftc)"
SWIFT_BUILD="$(xcrun --find swift)"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$APP_PATH" "$BUILD_DIR/AppIcon.iconset" "$BUILD_DIR/render-icon"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

build_architecture() {
    local architecture="$1"
    local scratch_path="$BUILD_DIR/swiftpm-$architecture"
    local target="$architecture-apple-macosx$MIN_MACOS"
    local binary_directory

    binary_directory="$("$SWIFT_BUILD" build --configuration release --scratch-path "$scratch_path" --triple "$target" --product BatteryWatt --show-bin-path)"
    "$SWIFT_BUILD" build --configuration release --scratch-path "$scratch_path" --triple "$target" --product BatteryWatt >/dev/null
    printf '%s\n' "$binary_directory/BatteryWatt"
}

ARM64_BINARY="$(build_architecture arm64)"
X86_64_BINARY="$(build_architecture x86_64)"

if [[ ! -f "$ARM64_BINARY" || ! -f "$X86_64_BINARY" ]]; then
    echo "Release binaries were not produced for both architectures." >&2
    exit 1
fi

lipo -create "$ARM64_BINARY" "$X86_64_BINARY" -output "$APP_PATH/Contents/MacOS/BatteryWatt"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${BUILD_NUMBER:-1}" "$APP_PATH/Contents/Info.plist"

"$SWIFTC" \
    -sdk "$SDKROOT" \
    -target "arm64-apple-macosx$MIN_MACOS" \
    -framework CoreGraphics \
    -framework ImageIO \
    -framework UniformTypeIdentifiers \
    "$ROOT_DIR/scripts/render-icon.swift" \
    -o "$BUILD_DIR/render-icon"
"$BUILD_DIR/render-icon" "$BUILD_DIR/AppIcon.iconset"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$APP_PATH/Contents/Resources/AppIcon.icns"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_PATH" >/dev/null
else
    codesign --force --deep --sign - "$APP_PATH" >/dev/null
fi

codesign --verify --deep --strict "$APP_PATH"

echo "$APP_PATH"
