#!/bin/bash
# Submits the already-signed build/Paste.IT.app to Apple for notarization,
# waits for the result, and staples the ticket so Gatekeeper accepts it
# offline. Run ./Scripts/build_app.sh with DEVELOPER_ID_APPLICATION set
# first — notarization requires a Developer ID (not ad-hoc) signature.
#
# One-time setup (see README.md > "Distributing outside your own Mac"):
#   xcrun notarytool store-credentials "PasteIT-Notary" \
#     --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
#
# Then:
#   ./Scripts/notarize.sh
# Or with a different stored profile name:
#   NOTARY_PROFILE="SomeOtherProfile" ./Scripts/notarize.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Paste.IT"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/build/$APP_NAME.zip"
NOTARY_PROFILE="${NOTARY_PROFILE:-PasteIT-Notary}"

if [ ! -d "$APP_DIR" ]; then
    echo "error: $APP_DIR not found. Run ./Scripts/build_app.sh first." >&2
    exit 1
fi

echo "Verifying the app is signed with a Developer ID (not ad-hoc)..."
if ! codesign --display --verbose=2 "$APP_DIR" 2>&1 | grep -q "Authority=Developer ID Application"; then
    echo "error: $APP_DIR is not signed with a Developer ID Application certificate." >&2
    echo "Rebuild with: DEVELOPER_ID_APPLICATION=\"Developer ID Application: ...\" ./Scripts/build_app.sh" >&2
    exit 1
fi

echo "Zipping for submission..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Submitting to Apple notary service (profile: $NOTARY_PROFILE)..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling the notarization ticket..."
xcrun stapler staple "$APP_DIR"

echo ""
echo "Verifying Gatekeeper acceptance..."
spctl -a -vvv "$APP_DIR"

echo ""
echo "Done: $APP_DIR is notarized and stapled — safe to distribute."
