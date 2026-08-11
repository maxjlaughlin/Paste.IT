#!/bin/bash
# Builds Paste.IT and packages it into a runnable .app bundle.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Paste.IT"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"

echo "Building release binary..."
swift build -c release --package-path "$ROOT_DIR"

echo "Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/PasteIT" "$APP_DIR/Contents/MacOS/PasteIT"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "Code signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "$ROOT_DIR/PasteIT.entitlements" \
    "$APP_DIR"

echo ""
echo "Done: $APP_DIR"
echo "Move it to /Applications, open it once, then grant Accessibility"
echo "permission when macOS prompts you (System Settings > Privacy &"
echo "Security > Accessibility)."
