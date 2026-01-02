#!/bin/sh

set -e

# shellcheck disable=SC1091

. tools/common.sh

## Buildtime/Input Variables ##

: "${ARCH:=amd64}"
: "${BUILD_DIR:=build}"

## Build Functions ##

# cmake
configure() {
	echo "-- Configuring $PRETTY_NAME..."

	FLAGS="-fno-unwind-tables -fomit-frame-pointer -fno-pie"
	if [ "$PLATFORM" = "windows" ]; then
		FLAGS="/O2 /Oy /EHs- /EHc- /DYNAMICBASE:NO /Zd"
		set -- "$@" -DQT_BUILD_QDOC=OFF
	else
		LTO="-reduce-exports"
	fi

	if [ "$PLATFORM" = mingw ]; then
		LTO="$LTO -no-ltcg"
	else
		LTO="$LTO -ltcg"
	fi

	if [ "$CCACHE" = true ]; then
		command -v cygpath >/dev/null 2>&1 && SCCACHE_PATH=$(cygpath -u "${SCCACHE_PATH}")
		set -- "$@" -DCMAKE_CXX_COMPILER_LAUNCHER="${SCCACHE_PATH}" -DCMAKE_C_COMPILER_LAUNCHER="${SCCACHE_PATH}"
	fi

	# TEST PLEASE DO NOT MERGE THIS
	LTO="-no-ltcg"

	# These are the recommended configuration options from Qt
	# We also skip snca like quick3d, activeqt, etc.
	# Also disable zstd, icu, and renderdoc; these are useless
	# and cause more issues than they solve.
	# shellcheck disable=SC2086
	./configure -static -gc-binaries $LTO \
		-submodules qtbase,qtdeclarative,qttools \
		-skip qtlanguageserver,qtquicktimeline,qtactiveqt,qtquick3d,qtquick3dphysics \
		-DCMAKE_CXX_FLAGS="$FLAGS -O3 -g0" -DCMAKE_C_FLAGS="$FLAGS -O3 -g0" \
		-optimize-size -no-feature-icu -release -no-zstd -no-feature-qml-network -no-feature-libresolv \
		-DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
		-nomake tests -nomake examples -no-compile-examples \
		-no-feature-sql -no-feature-xml -no-feature-dbus -no-feature-printdialog -no-feature-printer

		"$*"
}

build() {
    echo "-- Building $PRETTY_NAME..."
    cmake --build . --parallel
}

## Packaging ##
copy_build_artifacts() {
    echo "-- Copying artifacts..."

	cmake --install . --prefix "$OUT_DIR"

    rm -rf "$OUT_DIR"/doc
}

## Cleanup ##
rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# ## Download + Extract ##
download
cd "$BUILD_DIR"
extract

## Configure ##
cd "$DIRECTORY"
configure

## Build ##
build
copy_build_artifacts

## Package ##
package

echo "-- Done! Artifacts are in $ROOTDIR/artifacts, raw lib/include data is in $OUT_DIR"
