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
	if [ "$PLATFORM" = openbsd ]; then
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
	case "$PLATFORM" in
		mingw|windows|macos) LTO="$LTO -no-ltcg" ;;
		*) LTO="$LTO -ltcg" ;;
	esac

	# Omit frame pointer and unwind tables on non-Windows platforms
	# saves a bit of space
	case "$PLATFORM" in
		mingw|windows) ;;
		*) FLAGS="$FLAGS -fomit-frame-pointer -fno-unwind-tables" ;;
	esac

	# QPA selection
	case "$PLATFORM" in
		mingw|windows)
			dqpa=windows
			;;
		macos)
			dqpa=cocoa
			;;
		linux)
			dqpa=xcb
			QPA="-xcb -qpa xcb;wayland -feature-wayland -gtk"
			;;
		*)
			dqpa=xcb
			QPA="-xcb -qpa xcb -gtk"
			;;
	esac

	QPA="$QPA -default-qpa $dqpa"

	# Multimedia backends
	case "$PLATFORM" in
		mingw|windows) MM="-feature-wasapi -feature-wmf" ;;
		macos) MM="-feature-avfoundation -feature-videotoolbox" ;;
		linux) MM="-feature-pulseaudio" ;;
		*) MM="-feature-alsa" ;;
	esac

	# FFmpeg
	case "$PLATFORM" in
		macos|linux) MM="$MM -feature-ffmpeg -feature-thread"
	esac

	if [ "$CCACHE" = true ]; then
		echo "-- Using ccache at: $CCACHE_PATH"
		set -- "$@" -DCMAKE_CXX_COMPILER_LAUNCHER="${CCACHE_PATH}" -DCMAKE_C_COMPILER_LAUNCHER="${CCACHE_PATH}"
	fi

	# I have no idea what's going on with MSVC, you almost have to wonder if it has something to do
	# with them firing every single one of their developers in 2023
	if [ "$PLATFORM" = "windows" ] && [ "$ARCH" = arm64 ]; then
		LTO="$LTO -static-runtime"
	fi

	# UNIX builds shared because you do not want to bundle every Qt plugin under the sun
	set -- "$@" -DBUILD_SHARED_LIBS="$SHARED"

	# also, gc-binaries can't be done on shared
	[ "$SHARED" = true ] || LTO="$LTO -gc-binaries"

	# Submodules
	SUBMODULES="qtbase,qtdeclarative,qttools,qtmultimedia"
	case "$PLATFORM" in
		windows|mingw|macos) ;;
		*) SUBMODULES="$SUBMODULES,qtwayland"
	esac

	# ffmpeg and openssl SUCK
	if command -v pkg-config >/dev/null 2>&1; then
		# ubuntu
		if [ "$PLATFORM" = linux ]; then
			PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH"
		# macos
		elif [ "$PLATFORM" = macos ]; then
			FFMPEG_DIR=$(brew --prefix ffmpeg 2>/dev/null || true)
			if [ -n "$FFMPEG_DIR" ]; then
				PKG_CONFIG_PATH="$FFMPEG_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
				set -- "$@" -DFFMPEG_DIR="$FFMPEG_DIR"
			fi
		fi
		export PKG_CONFIG_PATH

		FFMPEG_PKGS="libavcodec libavformat libavutil libswresample libswscale openssl"

		# shellcheck disable=SC2086
		PKG_LIBS=$(pkg-config --static --libs $FFMPEG_PKGS 2>/dev/null || true)
		if [ -n "$PKG_LIBS" ]; then
			PKG_LIBS="-Wl,--start-group $PKG_LIBS -Wl,--end-group"
			LDFLAGS="$LDFLAGS $PKG_LIBS"
			set -- "$@" -DOPENSSL_ROOT_DIR=/usr -DOPENSSL_USE_STATIC_LIBS=ON
		fi
	fi

	# These are the recommended configuration options from Qt
	# We skip snca like quick3d, activeqt, etc.
	# Also disable zstd, icu, and renderdoc; these are useless
	# and cause more issues than they solve.
	# shellcheck disable=SC2086
	./configure $LTO $QPA $MM -nomake tests -nomake examples -optimize-size -no-pch \
		-submodules "$SUBMODULES" \
		-skip qtlanguageserver,qtquicktimeline,qtactiveqt,qtquick3d,qtquick3dphysics,qtdoc,qt5compat \
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
