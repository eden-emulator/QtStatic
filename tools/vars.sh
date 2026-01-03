#!/bin/sh -e

## Common variables ##

export VERSION=6.9.3

export PRETTY_NAME="Qt"
export FILENAME="qt"
export DIRECTORY="qt-$VERSION"
export ARTIFACT="$DIRECTORY.tar.zst"

# Download URLs and such
_base="https://github.com/eden-emulator/QtStatic/releases/download/src"
export DOWNLOAD_URL="$_base/$ARTIFACT"

# patches
export OPENBSD_PATCHES_URL="$_base/openbsd-patches-$VERSION.tar.zst"
export SOLARIS_PATCHES_URL="$_base/solaris-patches-$VERSION.tar.zst"

# Qt6Windows7 stuff
_owner=crueter
_repo="qt6windows7"
_sha="fbe8760e8b0d6ad16e940ddec10ac5db6bec585c"

export QT6WINDOWS7_URL="https://github.com/$_owner/$_repo/archive/$_sha.tar.gz"
export QT6WINDOWS7_VERSION=6.9.3
export QT6WINDOWS7_DIR="$_repo-$_sha"