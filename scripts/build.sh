#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/whisperflow-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/whisperflow-swift-cache"
swift build -c release
DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' scripts/Info.plist)
APP="$PWD/dist/$DISPLAY_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/WhisperFlow "$APP/Contents/MacOS/WhisperFlow"
cp scripts/Info.plist "$APP/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns "$PWD/.build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier ca.donwong.whisperflow "$APP"
codesign --verify --strict "$APP"
echo "Built: $APP"
