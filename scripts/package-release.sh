#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_OUTPUT_DIR="$PWD/dist/public-release" bash scripts/build.sh --universal
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist)
APP="$PWD/dist/public-release/Blabberflow.app"
DEST="${RELEASE_OUTPUT_DIR:-$PWD/dist/releases}"
mkdir -p "$DEST"
DEST=$(cd "$DEST" && pwd)
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/blabberflow-package.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT

ditto "$APP" "$STAGING/Blabberflow.app"
ln -s /Applications "$STAGING/Applications"
cp LICENSE "$STAGING/LICENSE.txt"
cat > "$STAGING/Read Me.txt" <<'EOF'
Blabberflow — experimental Mac release

1. Drag Blabberflow to Applications, then eject this disk image.
2. Open the installed app from Applications.
3. Allow Microphone, Speech Recognition, and Accessibility.
4. Click a text field, hold Control + Shift, speak, and release.

Requires macOS 13 or later. Supports Apple Silicon and Intel.
This release is NOT Developer ID signed or notarized by Apple.
macOS may block its first launch. Read the guide before deciding to open it:
https://github.com/donwon/blabberflow/blob/main/docs/INSTALL.md

No paid transcription API key is required. Enable on-device-only in Settings
to require local recognition. Otherwise Apple may process speech online.
EOF

BASE="Blabberflow-$VERSION-universal"
hdiutil create -volname Blabberflow -srcfolder "$STAGING" -ov -format UDZO "$DEST/$BASE.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DEST/$BASE.zip"
(cd "$DEST" && shasum -a 256 "$BASE.dmg" "$BASE.zip" > SHA256SUMS.txt)
echo "Release files: $DEST"
