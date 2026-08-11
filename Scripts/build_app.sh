#!/bin/bash
# Builds Paste.IT as a universal binary (Apple Silicon + Intel) and
# packages it into a runnable, self-contained .app bundle with icon.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Paste.IT"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
ICONSET="$ROOT_DIR/Assets/AppIcon.iconset"

echo "Building release binary for arm64..."
swift build -c release --arch arm64 --package-path "$ROOT_DIR"

echo "Building release binary for x86_64..."
swift build -c release --arch x86_64 --package-path "$ROOT_DIR"

ARM_BIN="$ROOT_DIR/.build/arm64-apple-macosx/release/PasteIT"
X86_BIN="$ROOT_DIR/.build/x86_64-apple-macosx/release/PasteIT"
RESOURCE_BUNDLE="$(find "$ROOT_DIR/.build/arm64-apple-macosx/release" -maxdepth 1 -name '*.bundle' | head -n 1)"

echo "Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "Merging into a universal (arm64 + x86_64) binary..."
lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP_DIR/Contents/MacOS/PasteIT"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

if [ -n "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi

if command -v iconutil >/dev/null 2>&1 && [ -d "$ICONSET" ]; then
    echo "Building AppIcon.icns..."
    iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "Skipping icon (iconutil not found or Assets/AppIcon.iconset missing)."
fi

echo "Code signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "$ROOT_DIR/PasteIT.entitlements" \
    "$APP_DIR"

echo ""
file "$APP_DIR/Contents/MacOS/PasteIT"
echo ""
echo "Done: $APP_DIR"
echo "Move it to /Applications, open it once, then grant Accessibility"
echo "permission when macOS prompts you (System Settings > Privacy &"
echo "Security > Accessibility)."
