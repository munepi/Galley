#!/bin/bash
#
# Code-sign a .app bundle with a Developer ID Application identity.
#
# Usage:
#   scripts/codesign.sh <path-to-app-bundle>
#
# Environment:
#   CODE_SIGN_IDENTITY   required. e.g. "Developer ID Application: ..."

set -eu

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-app-bundle>" >&2
    exit 1
fi

APP_BUNDLE="$1"

if [ -z "${CODE_SIGN_IDENTITY:-}" ]; then
    echo "ERROR: CODE_SIGN_IDENTITY is not set." >&2
    exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo "ERROR: $APP_BUNDLE is not a directory." >&2
    exit 1
fi

CODESIGN_FLAGS=(--force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY")

echo "Signing nested components in $APP_BUNDLE (deepest first)..."

# Collect signing targets:
#   - nested .app / .framework directories
#   - any Mach-O file (executables, dylibs, helpers)
# Sort by path length descending so that the deepest items are signed first.
TARGETS=$(
    {
        find "$APP_BUNDLE" -type d \( -name '*.app' -o -name '*.framework' \) ! -path "$APP_BUNDLE"
        find "$APP_BUNDLE" -type f -perm -u+x -exec sh -c '
            for f; do
                if file -b "$f" | grep -q "Mach-O"; then
                    echo "$f"
                fi
            done
        ' _ {} +
        find "$APP_BUNDLE" -type f -name '*.dylib'
    } | sort -u | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-
)

while IFS= read -r target; do
    [ -z "$target" ] && continue
    echo "  codesign: $target"
    codesign "${CODESIGN_FLAGS[@]}" "$target"
done <<< "$TARGETS"

echo "Signing outer bundle: $APP_BUNDLE"
codesign "${CODESIGN_FLAGS[@]}" "$APP_BUNDLE"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "Code signing complete."
