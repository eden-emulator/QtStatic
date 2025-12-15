#!/bin/sh -e

## Common variables ##

export VERSION=6.9.3
VERSION_SHORT=$(echo "$VERSION" | cut -d'.' -f1-2)

export PRETTY_NAME="Qt"
export FILENAME="qt"
export DIRECTORY="qt-everywhere-src-$VERSION"
export ARTIFACT="$DIRECTORY.tar.xz"
export DOWNLOAD_URL="https://download.qt.io/archive/qt/$VERSION_SHORT/$VERSION/single/$ARTIFACT"