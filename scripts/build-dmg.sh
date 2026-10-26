#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/听写.app"
if [[ ! -d "$APP" ]]; then
    printf 'App bundle missing. Run bash scripts/build-app.sh first.\n' >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/LocalTranscriber")"
case "$ARCHS" in
    arm64) ARCH=arm64 ;;
    x86_64) ARCH=x86_64 ;;
    *arm64*x86_64*|*x86_64*arm64*) ARCH=universal ;;
    *) printf 'Unsupported architecture: %s\n' "$ARCHS" >&2; exit 1 ;;
esac

mkdir -p "$ROOT/.build" "$ROOT/dist"
STAGING="$(mktemp -d "$ROOT/.build/dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/听写.app"
ln -s /Applications "$STAGING/Applications"
codesign --verify --deep --strict "$STAGING/听写.app"

DMG="$ROOT/dist/LocalTranscriber-v$VERSION-macOS-$ARCH.dmg"
hdiutil create -ov -volname "听写 $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO "$DMG"
hdiutil verify "$DMG"
# A stable filename keeps an existing GitHub /releases/latest/download link useful.
cp "$DMG" "$ROOT/dist/LocalTranscriber-macOS-$ARCH.dmg"
printf '\nDMG: %s\n' "$DMG"
