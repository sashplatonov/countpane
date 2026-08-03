#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-1.0.0}"
ARCHITECTURE="${2:-universal}"
case "$ARCHITECTURE" in
    universal) ARTIFACT_SUFFIX="" ;;
    arm64|x86_64) ARTIFACT_SUFFIX="-$ARCHITECTURE" ;;
    *) echo "Usage: $0 [version] [universal|arm64|x86_64]" >&2; exit 64 ;;
esac
APP_NAME="Countpane${ARTIFACT_SUFFIX}.app"
DMG_NAME="Countpane-${VERSION}${ARTIFACT_SUFFIX}.dmg"
STAGING_DIR="$ROOT_DIR/dist/dmg"
DMG_PATH="$ROOT_DIR/dist/$DMG_NAME"

"$ROOT_DIR/Scripts/build-app.sh" "$VERSION" "$ARCHITECTURE"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$ROOT_DIR/dist/$APP_NAME" "$STAGING_DIR/Countpane.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "Countpane" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Built $DMG_PATH"
