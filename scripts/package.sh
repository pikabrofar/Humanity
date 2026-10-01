#!/bin/sh
# Builds an Humanity app and wraps it in a drag-to-Applications DMG.
# Usage: scripts/package.sh <AppName> [version]
#   UNIVERSAL=1  build arm64 + x86_64 (needs full Xcode, as on GitHub runners)
#   SIGN_ID=...  codesigning identity (default: ad-hoc)
set -eu
APP_NAME="$1"
VERSION="${2:-dev}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/$APP_NAME"
OUT="$ROOT/dist"

VERSION="$VERSION" "$APP_DIR/scripts/build-app.sh" release

mkdir -p "$OUT"
STAGE="$(mktemp -d)"
cp -R "$APP_DIR/build/$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$OUT/$APP_NAME-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
rm -rf "$STAGE"
(cd "$OUT" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Packaged $DMG"
