#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/whisperflow-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/whisperflow-swift-cache"
BUILD_ARGS=(-c release)
if [[ "${1:-}" == "--universal" ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
elif [[ $# -ne 0 ]]; then
  echo "Usage: bash scripts/build.sh [--universal]" >&2
  exit 2
fi
swift build "${BUILD_ARGS[@]}"
BIN_DIR=$(swift build "${BUILD_ARGS[@]}" --show-bin-path)
DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' scripts/Info.plist)
APP="${APP_OUTPUT_DIR:-$PWD/dist}/$DISPLAY_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/WhisperFlow" "$APP/Contents/MacOS/WhisperFlow"
cp scripts/Info.plist "$APP/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns "$PWD/.build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
IDENTIFIER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' scripts/Info.plist)
codesign --force --sign - --identifier "$IDENTIFIER" "$APP"
codesign --verify --strict "$APP"
echo "Built: $APP"
