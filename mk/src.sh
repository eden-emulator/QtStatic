#!/bin/sh -e

# Make a debloated source archive

# shellcheck disable=SC1091
. ./tools/common.sh

DIRECTORY="qt-everywhere-src-$VERSION"
ARTIFACT="$DIRECTORY.tar.xz"
DOWNLOAD_URL="https://download.qt.io/archive/qt/$VERSION_SHORT/$VERSION/single/$ARTIFACT"
out="$ROOTDIR/artifacts/qt-$VERSION.tar.zst"

mkdir -p "$ROOTDIR/artifacts"
rm -rf "$out"

if [ ! -f "$ARTIFACT" ]; then
	echo "-- Downloading Qt $VERSION..."
	curl -L "$DOWNLOAD_URL" -o "$ARTIFACT"
fi

if [ ! -d "$DIRECTORY" ]; then
	echo "-- Extracting..."
	tar xf "$ARTIFACT"
fi

echo "-- Cleaning..."
cd "$DIRECTORY"
rm -rf qtweb* qtscxml qtpositioning qtconnectivity pyside6 qtquicktimeline qtremoteobjects \
	qtvirtualkeyboard tests qtspeech qtserial* qtsensors qtquick3d* qt3d qtcoap qtcharts \
	qtactiveqt qtdatavis3d qtdoc qtgraphs qtgrpc qthttpserver qtlanguageserver qtlocation \
	qtlottie qtmqtt qtnetworkauth qtquickeffectmaker

# remove references to docs
_basehelpers=qtbase/cmake/QtBaseHelpers.cmake
sed 's/add_subdirectory(doc)//g' "$_basehelpers" > "$_basehelpers.tmp"
mv "$_basehelpers.tmp" "$_basehelpers"

# quick controls docs
_qclist=qtdeclarative/src/quickcontrols/CMakeLists.txt
sed 's/doc\/qtquickcontrols.qdocconf//g' "$_qclist" > "$_qclist.tmp"
mv "$_qclist.tmp" "$_qclist"

# we have to || true because sometimes parent directories are removed
find . -type d \( -name examples -o -name tests -o -name demos -o -name docs -o -name doc \) -exec rm -rf {} \; || true

echo "-- Packing..."
cd "$ROOTDIR"

_newdir="qt-$VERSION"
mv "$DIRECTORY" "$_newdir"
tar --zstd -cf "$out" "$_newdir"

echo "-- Done! Source archive is in $out"
ls -lh "$out"