#!/bin/sh
# Builds a Sentidos app and wraps it in a drag-to-Applications DMG.
# Usage: scripts/package.sh <AppName> [version]
#   UNIVERSAL=1  build arm64 + x86_64 (needs full Xcode, as on GitHub runners)
#   SIGN_ID=...  codesigning identity (default: ad-hoc)
#   NOTARY_PROFILE=...  notarytool keychain profile: notarize and staple the DMG
#                       (needs a Developer ID SIGN_ID)
set -eu
APP_NAME="$1"
VERSION="${2:-}"  # empty: keep Info.plist version
case "$VERSION" in
    ""|[0-9]*.[0-9]*.[0-9]*) ;;
    *) echo "version must look like 1.2.3, got '$VERSION'" >&2; exit 1 ;;
esac
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/$APP_NAME"
OUT="$ROOT/dist"

# Packages are for sharing: never pin the signature to the bundle id (any app
# claiming the id would inherit permission grants). Only local dev builds pin.
PIN_DR="${PIN_DR:-0}" VERSION="$VERSION" "$APP_DIR/scripts/build-app.sh" release

mkdir -p "$OUT"
STAGE="$(mktemp -d)"
cp -R "$APP_DIR/build/$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$OUT/$APP_NAME-${VERSION:-dev}.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
rm -rf "$STAGE"
if [ "${SIGN_ID:--}" != "-" ]; then
    codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
    if [ -n "${NOTARY_PROFILE:-}" ]; then
        xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$DMG"
    fi
fi
# Checksum last: signing and stapling both change the file.
(cd "$OUT" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Packaged $DMG"
