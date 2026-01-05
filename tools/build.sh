#!/bin/sh

set -e

# shellcheck disable=SC1091

. tools/common.sh

## Buildtime/Input Variables ##

: "${ARCH:=amd64}"
: "${BUILD_DIR:=build}"

## Build Functions ##

CCACHE_PATH=$(which ccache || echo "ccache")
if [ "$PLATFORM" = windows ] || [ "$PLATFORM" = mingw ]; then
	CCACHE_PATH=$(cygpath -w "$CCACHE_PATH")
fi

echo "Using ccache at: $CCACHE_PATH"

show_stats() {
	"$CCACHE_PATH" -s
}

# cmake
configure() {
	echo "-- Configuring $PRETTY_NAME..."

	FLAGS="-g0"
	if [ "$PLATFORM" = "windows" ]; then
		# /Gy - function-sectors
		# /Gw - data-sections
		# /OPT:REF - gc-sections
		# /OPT:ICF - identical code folding
		# /EHs- /EHc- - EXCEPTIONS ARE FOR LOSERS
		FLAGS="/Gy /Gw /OPT:REF /OPT:ICF /EHs- /EHc-"

		# /DYNAMICBASE:NO - disable ASLR on amd64 bcz why not
		[ "$ARCH" != amd64 ] || FLAGS="$FLAGS /DYNAMICBASE:NO"
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

	# average openbsd moment
	if [ "$PLATFORM" = openbsd ]; then
		set -- "$@" -DCMAKE_AR="$(which llvm-ar-19)" -DCMAKE_RANLIB="$(which llvm-ranlib-19)"
	fi

	# saves some linker time, but of course macOS doesn't support it :/
	if [ "$PLATFORM" != macos ] && [ "$PLATFORM" != windows ]; then
		LDFLAGS="-Wl,--gc-sections"
	fi

	# mingw and windows get absolutely clobbered if you try to LTO
	if [ "$PLATFORM" = mingw ] || [ "$PLATFORM" = windows ]; then
		LTO="$LTO -no-ltcg"
	else
		LTO="$LTO -ltcg"
		# saves a good chunk of space otherwise
		FLAGS="$FLAGS -fomit-frame-pointer -fno-unwind-tables"
	fi

	if [ "$CCACHE" = true ]; then
		set -- "$@" -DCMAKE_CXX_COMPILER_LAUNCHER="${CCACHE_PATH}" -DCMAKE_C_COMPILER_LAUNCHER="${CCACHE_PATH}"
	fi

	# I have no idea what's going on with MSVC, you almost have to wonder if it has something to do
	# with them firing every single one of their developers in 2023
	if [ "$PLATFORM" = "windows" ] && [ "$ARCH" = arm64 ]; then
		LTO="$LTO -static-runtime"
	fi

	# UNIX builds shared because you do not want to bundle every Qt plugin under the sun
	set -- "$@" -DBUILD_SHARED_LIBS="$SHARED"

	[ "$SHARED" = true ] || LTO="$LTO -gc-binaries"

	# These are the recommended configuration options from Qt
	# We skip snca like quick3d, activeqt, etc.
	# Also disable zstd, icu, and renderdoc; these are useless
	# and cause more issues than they solve.
	# shellcheck disable=SC2086
	./configure $LTO \
		-submodules qtbase,qtdeclarative,qttools,qtmultimedia -optimize-size -no-pch \
		-skip qtlanguageserver,qtquicktimeline,qtactiveqt,qtquick3d,qtquick3dphysics,qtdoc,qt5compat \
		-nomake tests -nomake examples \
		-no-feature-icu -release -no-zstd -no-feature-qml-network -no-feature-libresolv -no-feature-dladdr \
		-no-feature-sql -no-feature-xml -no-feature-dbus -no-feature-printdialog -no-feature-printer -no-feature-printsupport \
		-no-feature-linguist -no-feature-designer -no-feature-assistant -no-feature-pixeltool -feature-filesystemwatcher -- "$@" \
		-DCMAKE_CXX_FLAGS="$FLAGS" -DCMAKE_C_FLAGS="$FLAGS" -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
		-DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"
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

## Download + Extract ##
download
cd "$BUILD_DIR"
extract

## Configure ##
cd "$ROOTDIR/$BUILD_DIR/$DIRECTORY"
configure

## Build ##
build
copy_build_artifacts

## Package ##
package

echo "-- Done! Artifacts are in $ROOTDIR/artifacts, raw lib/include data is in $OUT_DIR"
