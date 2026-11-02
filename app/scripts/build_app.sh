#!/usr/bin/env bash
# Builds Stashbar.app (universal: Apple silicon + Intel), ad-hoc signs it and packs a drag-to-Applications .dmg.
# Usage: VERSION=1.0.3 BUILD=3 app/scripts/build_app.sh
set -euo pipefail

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-1}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

OUT="$HERE/build"
APP="$OUT/Stashbar.app"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/StashBar" "$APP/Contents/MacOS/StashBar"
cp -R Sources/StashBar/Resources/. "$APP/Contents/Resources/"
iconutil -c icns Support/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Support/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature (no Apple Developer ID). Required for Apple silicon; users approve the
# first launch once in System Settings → Privacy & Security → "Open Anyway".
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --verbose=2 "$APP"
lipo -info "$APP/Contents/MacOS/StashBar"

# DMG with an Applications shortcut for drag-and-drop install.
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Stashbar" -srcfolder "$STAGE" -ov -format UDZO -fs HFS+ "$OUT/Stashbar.dmg"
rm -rf "$STAGE"
shasum -a 256 "$OUT/Stashbar.dmg"
echo "Built $OUT/Stashbar.dmg ($VERSION, build $BUILD)"
