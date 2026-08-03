#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-0.0.0}"
ARCHITECTURE="${2:-universal}"
BUILD_TIMESTAMP="${BUILD_TIMESTAMP:-$(date +"%Y%m%d-%H%M")}" 
BUILD_NUMBER="${BUILD_NUMBER:-${BUILD_TIMESTAMP//-/}}"
CONFIGURATION="${CONFIGURATION:-release}"
case "$ARCHITECTURE" in
    universal)
        ARCHITECTURES=(arm64 x86_64)
        ARTIFACT_SUFFIX=""
        ;;
    arm64|x86_64)
        ARCHITECTURES=("$ARCHITECTURE")
        ARTIFACT_SUFFIX="-$ARCHITECTURE"
        ;;
    *)
        echo "Usage: $0 [version] [universal|arm64|x86_64]" >&2
        exit 64
        ;;
esac
APP_DIR="$ROOT_DIR/dist/Countpane${ARTIFACT_SUFFIX}.app"
DSYM_DIR="$ROOT_DIR/dist/Countpane${ARTIFACT_SUFFIX}.dSYM"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
UNIVERSAL_BUILD_ROOT="$(mktemp -d "$ROOT_DIR/.build-universal.XXXXXX")"
ENTITLEMENTS="$ROOT_DIR/Packaging/Countpane.entitlements"

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

find_dsym() {
    local build_root="$1"
    local dsym
    dsym="$(find "$build_root" -type d -name Countpane.dSYM | head -n 1 || true)"
    if [[ -z "$dsym" ]]; then
        echo "Unable to locate Countpane.dSYM under $build_root" >&2
        exit 1
    fi
    printf '%s\n' "$dsym"
}

verify_matching_dsym() {
    local executable="$1"
    local dsym="$2"
    local executable_uuids
    local dsym_uuids

    executable_uuids="$(xcrun dwarfdump --uuid "$executable" | awk '/^UUID:/ { print $2 }' | sort)"
    dsym_uuids="$(xcrun dwarfdump --uuid "$dsym" | awk '/^UUID:/ { print $2 }' | sort)"
    if [[ -z "$executable_uuids" || -z "$dsym_uuids" ]] || ! diff -u \
        <(printf '%s\n' "$executable_uuids") \
        <(printf '%s\n' "$dsym_uuids"); then
        echo "dSYM UUIDs do not match the packaged executable" >&2
        exit 1
    fi
}

cleanup() {
    rm -rf "$UNIVERSAL_BUILD_ROOT"
}
trap cleanup EXIT

PRODUCTS=()
DSYMS=()
for ARCH in "${ARCHITECTURES[@]}"; do
    SCRATCH_PATH="$UNIVERSAL_BUILD_ROOT/$ARCH"
    echo "Building Countpane for $ARCH..."
    swift build \
        -c "$CONFIGURATION" \
        --triple "${ARCH}-apple-macosx15.0" \
        --scratch-path "$SCRATCH_PATH"
    PRODUCTS+=("$(find_product "$SCRATCH_PATH")")
    DSYMS+=("$(find_dsym "$SCRATCH_PATH")")
done

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

for PRODUCT in "${PRODUCTS[@]}"; do
    /usr/bin/strip -S "$PRODUCT"
done

if [[ "$ARCHITECTURE" == "universal" ]]; then
    /usr/bin/lipo -create \
        "${PRODUCTS[0]}" \
        "${PRODUCTS[1]}" \
        -output "$MACOS/Countpane"
else
    cp "${PRODUCTS[0]}" "$MACOS/Countpane"
fi

rm -rf "$DSYM_DIR"
cp -R "${DSYMS[0]}" "$DSYM_DIR"
if [[ "$ARCHITECTURE" == "universal" ]]; then
    DSYM_DWARF="$DSYM_DIR/Contents/Resources/DWARF/Countpane"
    /usr/bin/lipo -create \
        "${DSYMS[0]}/Contents/Resources/DWARF/Countpane" \
        "${DSYMS[1]}/Contents/Resources/DWARF/Countpane" \
        -output "$DSYM_DWARF"
fi

ARCHS="$(/usr/bin/lipo -archs "$MACOS/Countpane")"
for REQUIRED_ARCH in "${ARCHITECTURES[@]}"; do
    if [[ " $ARCHS " != *" $REQUIRED_ARCH "* ]]; then
        echo "Universal executable is missing $REQUIRED_ARCH: $ARCHS" >&2
        exit 1
    fi
done

cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT_DIR/Sources/Countpane/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"

if [[ ! -f "$RESOURCES/AppIcon.icns" ]]; then
    echo "AppIcon.icns was not copied into the application resources" >&2
    exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CountpaneBuildTimestamp $BUILD_TIMESTAMP" "$CONTENTS/Info.plist"

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
verify_matching_dsym "$MACOS/Countpane" "$DSYM_DIR"

printf 'Built %s (build %s, architectures: %s)\n' "$APP_DIR" "$BUILD_TIMESTAMP" "$ARCHS"
