#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-1.0.0}"
DMG_NAME="Countpane-${VERSION}.dmg"
STAGING_DIR="$ROOT_DIR/dist/dmg"
DMG_PATH="$ROOT_DIR/dist/$DMG_NAME"

"$ROOT_DIR/Scripts/build-app.sh" "$VERSION"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$ROOT_DIR/dist/Countpane.app" "$STAGING_DIR/Countpane.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "Countpane" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Built $DMG_PATH"
