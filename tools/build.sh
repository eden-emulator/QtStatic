#!/bin/sh

# shellcheck disable=SC1091

set -e

. tools/common.sh

## Buildtime/Input Variables ##

: "${ARCH:=amd64}"
: "${BUILD_DIR:=build}"
mkdir -p "$BUILD_DIR"

## Build Functions ##

CCACHE_PATH=$(which ccache || echo "ccache")
if [ "$PLATFORM" = windows ] || [ "$PLATFORM" = mingw ]; then
	CCACHE_PATH=$(cygpath -w "$CCACHE_PATH")
fi

show_stats() {
	"$CCACHE_PATH" -s
}

# Deps
! unix || . deps/libva.sh
! linux || . deps/libdrm.sh
! msvc || . deps/vulkan.sh

if ! windows; then
	. deps/ffmpeg.sh
	. deps/openssl.sh
fi

# cmake
configure() {
	echo "-- Configuring $PRETTY_NAME..."

	FLAGS="-g0"
	if msvc; then
		# /Gy - function-sectors
		# /Gw - data-sections
		# /EHs- /EHc- - EXCEPTIONS ARE FOR LOSERS
		FLAGS="/Gy /Gw /EHs- /EHc-"

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
	if openbsd; then
		set -- "$@" -DCMAKE_AR="$(which llvm-ar-19)" -DCMAKE_RANLIB="$(which llvm-ranlib-19)"
	fi

	# linker flags that save some time during link phase
	# all of these are just garbage collection basically, also identical code folding
	case "$PLATFORM" in
		windows) LDFLAGS="/OPT:REF /OPT:ICF" ;;
		macos) LDFLAGS="-Wl,-dead_strip -Wl,-dead_strip" ;;
		*) LDFLAGS="-Wl,--gc-sections" ;;
	esac

	# LTO
	# For some reason it seems like MacOS and Windows get horrifically clobbered by LTO.
	if unix; then
		LTO="$LTO -ltcg"
	else
		LTO="$LTO -no-ltcg"
	fi

	# Omit frame pointer and unwind tables on non-Windows platforms
	# saves a bit of space
	windows || FLAGS="$FLAGS -fomit-frame-pointer -fno-unwind-tables"

	# QPA selection
	case "$PLATFORM" in
		mingw|windows) dqpa=windows ;;
		macos) dqpa=cocoa ;;
		linux) dqpa=xcb
			QPA="-xcb -qpa xcb;wayland -feature-wayland -gtk" ;;
		*    ) dqpa=xcb
			QPA="-xcb -qpa xcb -gtk" ;;
	esac

	QPA="$QPA -default-qpa $dqpa"

	# Multimedia backends
	case "$PLATFORM" in
		mingw|windows) MM="-feature-wasapi -feature-wmf" ;;
		macos) MM="-feature-avfoundation -feature-videotoolbox" ;;
		*) MM="-feature-pulseaudio" ;;
	esac

	# FFmpeg + OpenSSL
	# Windows is actually better off without this since we can just use the system
	# wmf + wasapi + schannel.

	if ! windows; then
		MM="$MM -feature-ffmpeg -feature-thread -openssl-linked"

		set -- "$@" -DOPENSSL_USE_STATIC_LIBS=ON -DFFMPEG_DIR="$FFMPEG_DIR" -DOPENSSL_ROOT_DIR="$OPENSSL_DIR"

		echo "-- * FFmpeg dir: $FFMPEG_DIR"
		echo "-- * OpenSSL dir: $OPENSSL_DIR"
	fi

	# if windows; then
	# 	FFMPEG_DIR="$(cygpath -w "$FFMPEG_DIR")"
	# 	OPENSSL_DIR="$(cygpath -w "$OPENSSL_DIR")"
	# fi

	# libva
	if unix; then
		export PKG_CONFIG_PATH="$LIBVA_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
		printf -- "-- * libva pkg-config: "
		pkg-config --cflags --libs libva
		printf -- "-- * libva-drm pkg-config: "
		pkg-config --cflags --libs libva-drm

		# force libva custom dir into the thing
		FLAGS="$FLAGS $(pkg-config --cflags --libs libva-drm)"
		LDFLAGS="$LDFLAGS $(pkg-config --cflags --libs libva-drm)"
	fi

	# libdrm
	if linux; then
		export PKG_CONFIG_PATH="$LIBDRM_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
		printf -- "-- * libdrm pkg-config: "
		pkg-config --cflags --libs libdrm
	fi

	if [ "$CCACHE" = true ]; then
		echo "-- Using ccache at: $CCACHE_PATH"
		set -- "$@" -DCMAKE_CXX_COMPILER_LAUNCHER="${CCACHE_PATH}" -DCMAKE_C_COMPILER_LAUNCHER="${CCACHE_PATH}"
	fi

	# I have no idea what's going on with MSVC, you almost have to wonder if it has something to do
	# with them firing every single one of their developers in 2023
	if msvc && [ "$ARCH" = arm64 ]; then
		LTO="$LTO -static-runtime"
	fi

	# UNIX builds shared because you do not want to bundle every Qt plugin under the sun
	set -- "$@" -DBUILD_SHARED_LIBS="$SHARED"

	# also, gc-binaries can't be done on shared
	[ "$SHARED" = true ] || LTO="$LTO -gc-binaries"

	# Submodules
	SUBMODULES="qtbase,qtdeclarative,qttools,qtmultimedia"
	! unix || SUBMODULES="$SUBMODULES,qtwayland"

	# Vulkan is on for everything except macos
	macos || VK="-feature-vulkan"

	# These are the recommended configuration options from Qt
	# We skip snca like quick3d, activeqt, etc.
	# Also disable zstd, icu, and renderdoc; these are useless
	# and cause more issues than they solve.
	# shellcheck disable=SC2086
	./configure $LTO $QPA $MM $VK -nomake tests -nomake examples -optimize-size -no-pch \
		-submodules "$SUBMODULES" \
		-skip qtlanguageserver,qtquicktimeline,qtactiveqt,qtquick3d,qtquick3dphysics,qtdoc,qt5compat \
		-no-feature-icu -release -no-zstd -no-feature-qml-network -no-feature-libresolv -no-feature-dladdr \
		-no-feature-sql -no-feature-printdialog -no-feature-printer -no-feature-printsupport \
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
