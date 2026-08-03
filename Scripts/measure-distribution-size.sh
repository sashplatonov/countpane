#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 [options] <app> [dmg]" >&2
    echo "Options: --architecture universal|arm64|x86_64|any --max-application-bytes N --max-executable-bytes N --max-dmg-bytes N" >&2
    exit 64
}

ARCHITECTURE="universal"
MAX_APPLICATION_BYTES=""
MAX_EXECUTABLE_BYTES=""
MAX_DMG_BYTES=""
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --architecture)
            [[ $# -ge 2 ]] || usage
            ARCHITECTURE="$2"
            shift 2
            ;;
        --max-application-bytes)
            [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || usage
            MAX_APPLICATION_BYTES="$2"
            shift 2
            ;;
        --max-executable-bytes)
            [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || usage
            MAX_EXECUTABLE_BYTES="$2"
            shift 2
            ;;
        --max-dmg-bytes)
            [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || usage
            MAX_DMG_BYTES="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done

[[ $# == 1 || $# == 2 ]] || usage
APP_PATH="$1"
DMG_PATH="${2:-}"

case "$ARCHITECTURE" in
    universal|arm64|x86_64|any) ;;
    *) echo "Unsupported architecture requirement: $ARCHITECTURE" >&2; exit 64 ;;
esac

[[ -d "$APP_PATH" && "$APP_PATH" == *.app ]] || {
    echo "Application bundle does not exist or is not a .app directory: $APP_PATH" >&2
    exit 66
}

EXECUTABLE="$APP_PATH/Contents/MacOS/Countpane"
[[ -f "$EXECUTABLE" ]] || {
    echo "Application executable is missing: $EXECUTABLE" >&2
    exit 66
}

if [[ -n "$DMG_PATH" && ! -f "$DMG_PATH" ]]; then
    echo "DMG does not exist: $DMG_PATH" >&2
    exit 66
fi

bundle_bytes=0
while IFS= read -r -d '' file; do
    size="$(stat -f '%z' "$file")"
    bundle_bytes=$((bundle_bytes + size))
done < <(find "$APP_PATH" -type f -print0)

executable_bytes="$(stat -f '%z' "$EXECUTABLE")"
archs="$(lipo -archs "$EXECUTABLE")"

case "$ARCHITECTURE" in
    universal)
        [[ " $archs " == *" arm64 "* ]] && [[ " $archs " == *" x86_64 "* ]] || {
            echo "Expected a Universal executable containing arm64 and x86_64, found: $archs" >&2
            exit 65
        }
        ;;
    arm64|x86_64)
        arch_count="$(printf '%s\n' "$archs" | wc -w | tr -d '[:space:]')"
        [[ " $archs " == *" $ARCHITECTURE "* ]] && [[ "$arch_count" == 1 ]] || {
            echo "Expected a single-architecture $ARCHITECTURE executable, found: $archs" >&2
            exit 65
        }
        ;;
esac

echo "application=$APP_PATH"
echo "application_bytes=$bundle_bytes"
echo "application_kib=$(( (bundle_bytes + 1023) / 1024 ))"
echo "executable=$EXECUTABLE"
echo "executable_bytes=$executable_bytes"
echo "architectures=$archs"

if [[ -n "$MAX_APPLICATION_BYTES" && "$bundle_bytes" -gt "$MAX_APPLICATION_BYTES" ]]; then
    echo "Application exceeds size budget: $bundle_bytes > $MAX_APPLICATION_BYTES bytes" >&2
    exit 67
fi
if [[ -n "$MAX_EXECUTABLE_BYTES" && "$executable_bytes" -gt "$MAX_EXECUTABLE_BYTES" ]]; then
    echo "Executable exceeds size budget: $executable_bytes > $MAX_EXECUTABLE_BYTES bytes" >&2
    exit 67
fi

while IFS= read -r -d '' file; do
    size="$(stat -f '%z' "$file")"
    printf 'resource_bytes=%s path=%s\n' "$size" "$file"
done < <(find "$APP_PATH/Contents/Resources" -type f -print0)

if [[ -n "$DMG_PATH" ]]; then
    dmg_bytes="$(stat -f '%z' "$DMG_PATH")"
    echo "dmg=$DMG_PATH"
    echo "dmg_bytes=$dmg_bytes"
    echo "dmg_kib=$(( (dmg_bytes + 1023) / 1024 ))"
    if [[ -n "$MAX_DMG_BYTES" && "$dmg_bytes" -gt "$MAX_DMG_BYTES" ]]; then
        echo "DMG exceeds size budget: $dmg_bytes > $MAX_DMG_BYTES bytes" >&2
        exit 67
    fi
fi
