#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/swift-module-cache"

swift build --disable-sandbox -c release
BINARY_DIR="$(swift build --disable-sandbox -c release --show-bin-path)"
APP="$ROOT/dist/听写.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY_DIR/LocalTranscriber" "$APP/Contents/MacOS/LocalTranscriber"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
for LANGUAGE in en zh-Hans; do
    mkdir -p "$APP/Contents/Resources/$LANGUAGE.lproj"
    cp "$ROOT/Resources/$LANGUAGE.lproj/InfoPlist.strings" "$APP/Contents/Resources/$LANGUAGE.lproj/InfoPlist.strings"
done

swift "$ROOT/scripts/make-icon.swift" "$ROOT/.build/AppIcon.iconset"
iconutil -c icns "$ROOT/.build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --options runtime \
    --entitlements "$ROOT/Resources/LocalTranscriber.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/LocalTranscriber-macOS.zip"
printf '\n已构建：%s\n' "$APP"
du -sh "$APP"
bash "$ROOT/scripts/build-dmg.sh"
