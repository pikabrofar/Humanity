#!/bin/sh
# Builds VisionGaze.app from the Swift package. Works with just the Command Line Tools.
set -eu

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/VisionGaze.app"

cd "$ROOT"
swift build -c "$CONFIG" --product VisionGaze
BIN="$(swift build -c "$CONFIG" --show-bin-path)/VisionGaze"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VisionGaze"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ]; then
    swift scripts/make-icon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: required for the camera permission prompt to attach to the app.
codesign --force --sign - "$APP"
echo "Built $APP"
