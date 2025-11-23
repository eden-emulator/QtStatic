#!/bin/sh -e

ROOTDIR="$PWD"
ARTIFACTS_DIR="$ROOTDIR"/artifacts
OUT_DIR="$ROOTDIR"/out
BUILD_DIR="$ROOTDIR"/build

: "${QT_VERSION:=6.10.1}"
QT_VERSION_SHORT=$(echo "$QT_VERSION" | cut -d'.' -f1-2)

: "${PLATFORM:=$1}"
: "${ARCH:=$2}"

: "${PLATFORM:?-- Set PLATFORM, or supply it as the first argument.}"
: "${ARCH:?-- Set ARCH, or supply it as the second argument.}"

DOWNLOAD="https://download.qt.io/archive/qt/$QT_VERSION_SHORT/$QT_VERSION/single/qt-everywhere-src-$QT_VERSION.tar.xz"
QT_DIR="$ROOTDIR/qt-everywhere-src-$QT_VERSION"
QT_TARBALL="$ROOTDIR/qt-$QT_VERSION.tar.xz"
OUT_TARBALL="qt-$QT_VERSION-$PLATFORM-$ARCH.tar.gz"

[ ! -f "$QT_TARBALL" ] && curl -L "$DOWNLOAD" -o "$QT_TARBALL"
[ ! -d "$QT_DIR" ] && tar xf "$QT_TARBALL"

mkdir -p "$BUILD_DIR"
mkdir -p "$ARTIFACTS_DIR"
cd "$BUILD_DIR"

# TODO: Windows
"$QT_DIR"/configure -static -ltcg -reduce-exports -gc-binaries -submodules \
    qtbase,qtdeclarative,qttools -skip qtlanguageserver,qtquicktimeline,qtactiveqt \
    -DCMAKE_CXX_FLAGS="-fno-unwind-tables -fomit-frame-pointer -no-pie" \
    -optimize-size -no-feature-icu -release

cmake --build . --parallel
cmake --install . --prefix "$OUT_DIR"

cd "$OUT_DIR"

tar czf "$ARTIFACTS_DIR/$OUT_TARBALL" ./*
