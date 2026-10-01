#!/bin/sh
# Builds OculOS.app from the Swift package. Works with just the Command Line Tools.
#
# SIGN_ID: codesigning identity. The default "-" (ad-hoc) changes on every build,
# so macOS forgets permission grants (camera, Accessibility) after rebuilding.
# A self-signed "Humanity Self-Signed" certificate keeps them: see the repo README.
# PIN_DR=0: plain ad-hoc signature (releases without a certificate; see below).
# VERSION: CFBundleShortVersionString to stamp into the bundle.
set -eu

APP_NAME="OculOS"
CONFIG="${1:-release}"
SIGN_ID="${SIGN_ID:--}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/$APP_NAME.app"

cd "$ROOT"
# UNIVERSAL=1 builds arm64 + x86_64; that needs full Xcode (as on GitHub runners).
ARCH_FLAGS=""
[ "${UNIVERSAL:-0}" = 1 ] && ARCH_FLAGS="--arch arm64 --arch x86_64"
# SCRATCH: build directory. Releases build outside the home folder so no local
# path ends up in the binary.
[ -n "${SCRATCH:-}" ] && ARCH_FLAGS="$ARCH_FLAGS --scratch-path $SCRATCH"
# OFFICIAL=1: a release build that asks for a Gumroad license key (see LicenseKit).
[ "${OFFICIAL:-0}" = 1 ] && ARCH_FLAGS="$ARCH_FLAGS -Xswiftc -DHUMANITY_OFFICIAL"
swift build -c "$CONFIG" --product "$APP_NAME" $ARCH_FLAGS
BIN="$(swift build -c "$CONFIG" $ARCH_FLAGS --show-bin-path)/$APP_NAME"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -n "${VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
fi

if [ ! -f build/AppIcon.icns ]; then
    swift scripts/make-icon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Licenses ship with every copy; the About window shows them as credits.
cp ../LICENSE ../THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cat ../LICENSE ../THIRD_PARTY_NOTICES.md | textutil -stdin -format txt -convert rtf -output "$APP/Contents/Resources/Credits.rtf"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)"
# Hardened runtime: no injected libraries or debugger attach into a process that
# holds camera, microphone and Accessibility grants.
# Only the devices this app uses (hardened runtime blocks the rest).
ENT="$(mktemp)"
printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict>%s</dict></plist>\n' \
    "<key>com.apple.security.device.camera</key><true/>" > "$ENT"
SIGN="codesign --force --options runtime --entitlements $ENT"
if [ "$SIGN_ID" = "-" ] && [ "${PIN_DR:-1}" = 1 ]; then
    # An ad-hoc signature is identified by its hash, which changes every build, so
    # macOS silently stops honoring Accessibility / Screen Recording grants after a
    # rebuild. Pinning the designated requirement to the bundle id keeps the grant
    # attached to this app. Local dev builds only: any app claiming this bundle id
    # would match, so releases use a certificate or plain ad-hoc (PIN_DR=0).
    $SIGN --sign - --requirements "=designated => identifier \"$BUNDLE_ID\"" "$APP"
else
    # Notarization needs a secure timestamp on real-certificate signatures.
    $SIGN --timestamp --sign "$SIGN_ID" "$APP"
fi
echo "Built $APP"
