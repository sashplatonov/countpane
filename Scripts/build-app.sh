#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-0.0.0}" 
BUILD_TIMESTAMP="${BUILD_TIMESTAMP:-$(date +"%Y%m%d-%H%M")}" 
BUILD_NUMBER="${BUILD_NUMBER:-${BUILD_TIMESTAMP//-/}}"
CONFIGURATION="${CONFIGURATION:-release}"
APP_DIR="$ROOT_DIR/dist/Countpane.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
UNIVERSAL_BUILD_ROOT="$ROOT_DIR/.build-universal"
ENTITLEMENTS="$ROOT_DIR/Packaging/Countpane.entitlements"
ARCHITECTURES=(arm64 x86_64)

find_product() {
    local build_root="$1"
    local product
    # SwiftPM may use either its legacy lower-case configuration directory or
    # Xcode's Products/Release layout when building for a target triple.
    product="$(find "$build_root" -type f -name Countpane -perm -111 ! -path '*.dSYM/*' | head -n 1 || true)"
    if [[ -z "$product" ]]; then
        echo "Unable to locate Countpane executable under $build_root" >&2
        exit 1
    fi
    printf '%s\n' "$product"
}

rm -rf "$UNIVERSAL_BUILD_ROOT"
mkdir -p "$UNIVERSAL_BUILD_ROOT"

PRODUCTS=()
for ARCH in "${ARCHITECTURES[@]}"; do
    SCRATCH_PATH="$UNIVERSAL_BUILD_ROOT/$ARCH"
    echo "Building Countpane for $ARCH..."
    swift build \
        -c "$CONFIGURATION" \
        --triple "${ARCH}-apple-macosx15.0" \
        --scratch-path "$SCRATCH_PATH"
    PRODUCTS+=("$(find_product "$SCRATCH_PATH")")
done

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

/usr/bin/lipo -create \
    "${PRODUCTS[0]}" \
    "${PRODUCTS[1]}" \
    -output "$MACOS/Countpane"

ARCHS="$(/usr/bin/lipo -archs "$MACOS/Countpane")"
for REQUIRED_ARCH in "${ARCHITECTURES[@]}"; do
    if [[ " $ARCHS " != *" $REQUIRED_ARCH "* ]]; then
        echo "Universal executable is missing $REQUIRED_ARCH: $ARCHS" >&2
        exit 1
    fi
done

cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT_DIR/Sources/Countpane/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
cp "$ROOT_DIR/Sources/Countpane/Resources/AppIcon.png" "$RESOURCES/AppIcon.png"

if [[ ! -f "$RESOURCES/AppIcon.png" ]]; then
    echo "AppIcon.png was not copied into the application resources" >&2
    exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CountpaneBuildTimestamp $BUILD_TIMESTAMP" "$CONTENTS/Info.plist"

RESOURCE_BUNDLE="$(find "$UNIVERSAL_BUILD_ROOT/arm64" -type d -name '*Countpane*.bundle' | head -n 1 || true)"
if [[ -n "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES/"
fi

chmod +x "$MACOS/Countpane"

SIGNING_ARGS=(
    --force
    --deep
    --options runtime
    --entitlements "$ENTITLEMENTS"
)

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    /usr/bin/codesign \
        "${SIGNING_ARGS[@]}" \
        --timestamp \
        --sign "$DEVELOPER_ID_APPLICATION" \
        "$APP_DIR"
else
    /usr/bin/codesign \
        "${SIGNING_ARGS[@]}" \
        --sign - \
        "$APP_DIR"
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DIR"
/usr/bin/codesign -d --entitlements - "$APP_DIR" >/dev/null

printf 'Built %s (build %s, architectures: %s)\n' "$APP_DIR" "$BUILD_TIMESTAMP" "$ARCHS"
