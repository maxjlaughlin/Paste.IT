#!/bin/bash
# Builds Paste.IT as a universal binary (Apple Silicon + Intel) and
# packages it into a runnable, self-contained .app bundle with icon.
#
# By default this ad-hoc signs the app, which is fine for running it on
# your own Mac. To produce a build you can hand to someone else's Mac
# without Gatekeeper blocking it, set DEVELOPER_ID_APPLICATION to your
# "Developer ID Application" signing identity before running this script,
# then run notarize.sh afterwards. See README.md > "Distributing outside
# your own Mac" for how to obtain that identity.
#
#   DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
#     ./Scripts/build_app.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Paste.IT"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
ICONSET="$ROOT_DIR/Assets/AppIcon.iconset"
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:--}"

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

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "Code signing ad-hoc (local testing only — set DEVELOPER_ID_APPLICATION to distribute this build)..."
    codesign --force --deep --sign - \
        --entitlements "$ROOT_DIR/PasteIT.entitlements" \
        "$APP_DIR"
else
    echo "Code signing with \"$SIGN_IDENTITY\" (hardened runtime, ready for notarization)..."
    codesign --force --deep --options runtime --timestamp \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$ROOT_DIR/PasteIT.entitlements" \
        "$APP_DIR"
fi

echo ""
file "$APP_DIR/Contents/MacOS/PasteIT"
codesign --display --verbose=2 "$APP_DIR" 2>&1 | grep -E "Authority|TeamIdentifier"
echo ""
echo "Done: $APP_DIR"
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "This is an ad-hoc build — it'll run on this Mac but Gatekeeper will"
    echo "block it on any other Mac. See README.md for notarizing a real build."
else
    echo "Signed and hardened. Next: ./Scripts/notarize.sh to notarize it."
fi
echo "On first launch, grant Accessibility permission when macOS prompts"
echo "(System Settings > Privacy & Security > Accessibility)."
