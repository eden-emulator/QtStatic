#!/bin/sh

set -e

# shellcheck disable=SC1091

. tools/common.sh

## Buildtime/Input Variables ##

: "${ARCH:=amd64}"
: "${BUILD_DIR:=build}"

## Build Functions ##

[ -z "$SCCACHE_PATH" ] && SCCACHE_PATH=$(which sccache || which ccache || echo "")

show_stats() {
	if [ -n "$SCCACHE_PATH" ]; then
		"$SCCACHE_PATH" --show-stats
	fi
}

# cmake
configure() {
	echo "-- Configuring $PRETTY_NAME..."

	FLAGS="-fno-unwind-tables -g0"
	if [ "$PLATFORM" = "windows" ]; then
		FLAGS="/Oy /EHs- /EHc- /DYNAMICBASE:NO"
		set -- "$@" -DQT_BUILD_QDOC=OFF
	else
		LTO="-reduce-exports"
	fi

	# PIC/PIE handling
	case "$PLATFORM" in
		openbsd|linux) FLAGS="$FLAGS -fPIC" ;;
		freebsd|macos|mingw) FLAGS="$FLAGS -fno-pie" ;;
		*) ;;
	esac

	if [ "$PLATFORM" != macos ] && [ "$PLATFORM" != windows ]; then
		FLAGS="$FLAGS -Wl,--gc-sections"
	fi

	if [ "$PLATFORM" = mingw ]; then
		LTO="$LTO -no-ltcg"
	else
		LTO="$LTO -ltcg"
		FLAGS="$FLAGS -fomit-frame-pointer"
	fi

	if [ "$CCACHE" = true ]; then
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
		-submodules qtbase,qtdeclarative,qttools -optimize-size \
		-skip qtlanguageserver,qtquicktimeline,qtactiveqt,qtquick3d,qtquick3dphysics \
		-nomake tests -nomake examples \
		-no-feature-icu -release -no-zstd -no-feature-qml-network -no-feature-libresolv -no-feature-dladdr \
		-no-feature-sql -no-feature-xml -no-feature-dbus -no-feature-printdialog -no-feature-printer -no-feature-printsupport \
		-no-feature-linguist -no-feature-designer -no-feature-assistant -no-feature-pixeltool -feature-filesystemwatcher -- "$@" \
		-DCMAKE_CXX_FLAGS="$FLAGS" -DCMAKE_C_FLAGS="$FLAGS" -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}"
}

build() {
    echo "-- Building $PRETTY_NAME..."
    cmake --build . --parallel || { show_stats; exit 1; }
	show_stats
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
