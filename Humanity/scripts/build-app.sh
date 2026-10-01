#!/bin/sh
# Builds Humanity.app from the Swift package. Works with just the Command Line Tools.
#
# SIGN_ID: codesigning identity. The default "-" (ad-hoc) changes on every build,
# so macOS forgets permission grants (camera, Accessibility) after rebuilding.
# A self-signed "oculOS Dev" certificate keeps them: see the repo README.
set -eu

APP_NAME="Humanity"
CONFIG="${1:-release}"
SIGN_ID="${SIGN_ID:--}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/$APP_NAME.app"

cd "$ROOT"
# UNIVERSAL=1 builds arm64 + x86_64; that needs full Xcode (as on GitHub runners).
ARCH_FLAGS=""
[ "${UNIVERSAL:-0}" = 1 ] && ARCH_FLAGS="--arch arm64 --arch x86_64"
swift build -c "$CONFIG" --product "$APP_NAME" $ARCH_FLAGS
BIN="$(swift build -c "$CONFIG" $ARCH_FLAGS --show-bin-path)/$APP_NAME"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ]; then
    swift scripts/make-icon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign "$SIGN_ID" "$APP"
echo "Built $APP"
