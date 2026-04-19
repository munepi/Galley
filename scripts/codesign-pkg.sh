#!/bin/bash
#
# Sign a .pkg installer with a Developer ID Installer identity.
#
# Usage:
#   scripts/codesign-pkg.sh <path-to-pkg>
#
# Environment:
#   INSTALLER_CODE_SIGN_IDENTITY   required. e.g. "Developer ID Installer: ..."

set -eu

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-pkg>" >&2
    exit 1
fi

PKG="$1"

if [ -z "${INSTALLER_CODE_SIGN_IDENTITY:-}" ]; then
    echo "ERROR: INSTALLER_CODE_SIGN_IDENTITY is not set." >&2
    exit 1
fi

if [ ! -f "$PKG" ]; then
    echo "ERROR: $PKG does not exist." >&2
    exit 1
fi

echo "Signing $PKG with installer identity: $INSTALLER_CODE_SIGN_IDENTITY"
productsign --sign "$INSTALLER_CODE_SIGN_IDENTITY" "$PKG" "$PKG.signed"
mv "$PKG.signed" "$PKG"
echo "Package signing complete."
