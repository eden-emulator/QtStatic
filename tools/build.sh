#!/bin/bash

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

# Deps
if [ "$PACKAGE" != "true" ]; then
	! unix || . deps/libva.sh
	! linux || . deps/libdrm.sh
fi

! msvc || . deps/vulkan.sh

if linux || macos; then
	. deps/ffmpeg.sh
fi

if linux; then
	. deps/openssl.sh
fi

# get submodules to skip
skip_submodules() {
	#########################################
	# Skipped submodules.                   #
	#########################################

	skippable=(qtlanguageserver qtquicktimeline qtactiveqt qtquick3dphysics qtdoc qt5compat qtquick3d qtmultimedia qtdeclarative)
	declare -a newskip
	for i in "${skippable[@]}"; do
		if ! echo "$SUBMODULES" | grep "$i" >/dev/null 2>&1; then
			newskip+=("$i")
		fi
	done

	IFS=,
	SKIP="${newskip[*]}"
	export SKIP
	IFS=" "
}

# cmake
configure() {
	_group "Setting up configure flags"

	## Conditionals ##
	[[ $SUBMODULES != *multimedia* ]] || multimedia=true
	[[ $SUBMODULES != *declarative* ]] || declarative=true

	#########################################
	# C/CXX flags.                          #
	#########################################
	FLAGS="-g0 -Os"

	# Custom MSVC options, and also frame pointer stuff.
	case "$PLATFORM" in
		windows)
			# /Gy - function-sectors
			# /Gw - data-sections
			# /EHs- /EHc- - EXCEPTIONS ARE FOR LOSERS
			# /await:strict - force new coroutine abi
			FLAGS="/Gy /Gw /EHs- /EHc- /await:strict"

			# /DYNAMICBASE:NO - disable ASLR on amd64 bcz why not
			arm || FLAGS="$FLAGS /DYNAMICBASE:NO"
			set -- "$@" -DQT_BUILD_QDOC=OFF
			;;
		mingw) ;;
		*) FLAGS="$FLAGS -fomit-frame-pointer -fno-unwind-tables" ;;
	esac

	# PIC/PIE handling
	case "$PLATFORM" in
		openbsd|linux) FLAGS="$FLAGS -fPIC" ;;
		freebsd|macos|ios|mingw) FLAGS="$FLAGS -fno-pie" ;;
		*) ;;
	esac

	#########################################
	# QPA Handling.                         #
	#########################################
	case "$PLATFORM" in
		mingw|windows) dqpa=windows ;;
		macos) dqpa=cocoa ;;
		ios) dqpa=ios ;;
		linux) dqpa=xcb
			CONFIG+=(
				-xcb
				-qpa "xcb;wayland"
				-gtk
			)

			FEATURES+=(wayland)
			;;
		*    )
			dqpa=xcb
			CONFIG+=(-xcb -qpa xcb -gtk)
			;;
	esac

	if qt_67; then
		CONFIG+=(-qpa "$dqpa")
	else
		CONFIG+=(-default-qpa "$dqpa")
	fi

	#########################################
	# Multimedia Handling.                  #
	#########################################

	# backends
	if [ "$multimedia" = true ]; then
		case "$PLATFORM" in
			# TODO(crueter): Figure out iOS FFmpeg situation
			mingw|windows|ios) ;;
			macos) FEATURES+=(avfoundation videotoolbox) ;;
			*)
				FEATURES+=(pulseaudio)
				DISABLED_FEATURES+=(gstreamer)
				;;
		esac
	fi

	# FFmpeg (Linux/macOS only)
	# Windows uses wmf/wasapi
	if linux || macos; then
		if [ "$multimedia" = true ]; then
			FEATURES+=(ffmpeg thread)
		fi

		CMAKE+=(
			-DFFMPEG_DIR="$FFMPEG_DIR"
			-DCMAKE_FIND_LIBRARY_SUFFIXES=".a"
		)

		echo "-- * FFmpeg dir: $FFMPEG_DIR"
	fi

	# OpenSSL (Linux only)
	# Windows uses schannel, macOS uses secureTransport
	if linux; then
		CONFIG+=(-openssl-linked)
		CMAKE+=(
			-DOPENSSL_USE_STATIC_LIBS=ON
			-DOPENSSL_ROOT_DIR="$OPENSSL_DIR"
			-DCMAKE_PREFIX_PATH="$OPENSSL_DIR"
			-DOpenSSL_ROOT="$OPENSSL_DIR"
		)

		export PKG_CONFIG_PATH="$OPENSSL_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"

		echo "-- * OpenSSL dir: $OPENSSL_DIR"
	elif macos || ios; then
		FEATURES+=(securetransport)
		DISABLED_FEATURES+=(openssl)
	elif windows; then
		FEATURES+=(schannel)
		DISABLED_FEATURES+=(openssl)
	fi

	#########################################
	# Dependency Handling.                  #
	#########################################

	# libva
	if unix; then
		export PKG_CONFIG_PATH="$LIBVA_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
		printf -- "-- * libva pkg-config: "
		pkg-config --cflags --libs libva
		printf -- "-- * libva-drm pkg-config: "
		pkg-config --cflags --libs libva-drm

		# force libva custom dir into the thing
		FLAGS="$FLAGS $(pkg-config --cflags --libs libva-drm) "
		LDFLAGS="$LDFLAGS $(pkg-config --cflags --libs libva-drm) "
	fi

	# libdrm
	if linux; then
		export PKG_CONFIG_PATH="$LIBDRM_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
		printf -- "-- * libdrm pkg-config: "
		pkg-config --cflags --libs libdrm
	fi

	# CCache
	if [ "${CCACHE:-true}" = true ]; then
		echo "-- Using ccache at: $CCACHE_PATH"

		CMAKE+=(
			-DCMAKE_CXX_COMPILER_LAUNCHER="${CCACHE_PATH}"
			-DCMAKE_C_COMPILER_LAUNCHER="${CCACHE_PATH}"
		)
	fi

	# MSVC on ARM needs static runtime for some glorious reason.
	# TODO(crueter): Cause seems to be LLVM--possible to disable?
	if msvc && [ "$ARCH" = arm64 ] && [ "$declarative" = true ]; then
		CONFIG+=(-static-runtime)
	fi

	# UNIX builds are shared.
	CMAKE+=(-DBUILD_SHARED_LIBS="$SHARED")

	# also, gc-binaries can't be done on shared
	[ "$SHARED" = true ] || CONFIG+=(-gc-binaries)

	# Cross comp builds need a specific target and host path.
	if [ "$CROSS" = true ]; then
		CONFIG+=(-qt-host-path "$QT_HOST_PATH")
		CMAKE+=(-DQT_HOST_PATH_CMAKE_DIR="$QT_HOST_PATH"/lib/cmake)
		case "$PLATFORM" in
			ios) CONFIG+=(-platform macx-ios-clang)
		esac
	fi

	#########################################
	# Options passed directly to configure. #
	#########################################
	CONFIG+=(
		-optimize-size -no-pch -no-ltcg
		-nomake tests -nomake examples
	)

	msvc || CONFIG+=(-reduce-exports)

	#########################################
	# Disabled features.                    #
	#########################################

	DISABLED_FEATURES+=(
		icu libresolv dladdr wayland-server
		sql printdialog printer printsupport
		androiddeployqt windeployqt macdeployqt
		designer assistant pixeltool testlib
	)

	if [ "$declarative" = true ]; then
		DISABLED_FEATURES+=(
			qml-network qml-preview qml-profiler
		)

		if ! qt_67; then
			DISABLED_FEATURES+=(quickcontrols2-fluentwinui3)
		fi
	fi

	if qt_610 || qt_611; then
		DISABLED_FEATURES+=(localserver)
	fi

	if mingw; then
		DISABLED_FEATURES+=(
			system-jpeg system-zlib system-freetype system-pcre2
		)
		CONFIG+=(-qt-libmd4c -qt-webp)
	fi

	DISABLED+=(zstd)

	# DBus disabled on everything not named linux
	if linux; then
		FEATURES+=(dbus)
	else
		DISABLED_FEATURES+=(dbus)
	fi

	for feat in "${DISABLED_FEATURES[@]}"; do
		CONFIG+=(-no-feature-"$feat")
	done

	for feat in "${DISABLED[@]}"; do
		CONFIG+=(-no-"$feat")
	done

	#########################################
	# Enabled features.                     #
	#########################################

	macos || FEATURES+=(vulkan)
	FEATURES+=(filesystemwatcher)

	for feat in "${FEATURES[@]}"; do
		CONFIG+=(-feature-"$feat")
	done

	#########################################
	# Enabled submodules.                   #
	#########################################

	if unix; then SUBMODULES+=,qtwayland; fi

	CONFIG+=(-submodules "$SUBMODULES")

	skip_submodules
	if [ -n "$SKIP" ]; then
		CONFIG+=(-skip "$SKIP")
	fi

	#########################################
	# Linker flags.                         #
	#########################################

	# all of these are just garbage collection basically, also identical code folding
	case "$PLATFORM" in
		windows) LDFLAGS+="/OPT:REF /OPT:ICF" ;;
		macos|ios) LDFLAGS+="-Wl,-dead_strip -Wl,-dead_strip" ;;
		*) LDFLAGS+="-Wl,--gc-sections" ;;
	esac

	#########################################
	# CMake options.                        #
	#########################################
	CMAKE+=(
		-DCMAKE_CXX_FLAGS="$FLAGS"
		-DCMAKE_C_FLAGS="$FLAGS"
		-DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
		-DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS"
	)

	if qt_69; then
		CMAKE+=(-DQT_FEATURE_cpp_winrt=OFF)
	fi

	# package target (arch linux)
	if [ "$PACKAGE" = true ]; then
		CMAKE+=(
			-DCMAKE_INSTALL_PREFIX=/usr
			-DINSTALL_BINDIR=lib/qt6/bin
			-DINSTALL_PUBLICBINDIR=usr/bin
			-DINSTALL_LIBEXECDIR=lib/qt6
			-DINSTALL_DOCDIR=share/doc/qt6
			-DINSTALL_ARCHDATADIR=lib/qt6
			-DINSTALL_DATADIR=share/qt6
			-DINSTALL_INCLUDEDIR=include/qt6
			-DINSTALL_MKSPECSDIR=lib/qt6/mkspecs
		)
	fi


	#########################################
	## NOW CONFIGURE!                      ##
	#########################################

	IFS=" "

	echo "-- Compiler flags: $FLAGS"
	echo "-- Linker flags: $LDFLAGS"
	echo "-- Enabled features: ${FEATURES[*]}"
	echo "-- Disabled features: ${DISABLED_FEATURES[*]}"
	echo "-- Disabled flags: ${DISABLED[*]}"
	echo "-- Configure flags: ${CONFIG[*]}"
	echo "-- CMake flags: ${CMAKE[*]}"
	echo "-- Submodules: $SUBMODULES"
	echo "-- Skipping: $SKIP"

	_end

	_group "Configuring $PRETTY_NAME"
	./configure "${CONFIG[@]}" -- "${CMAKE[@]}"
	_end
}

build() {
    _group "Building $PRETTY_NAME"
    cmake --build . --parallel
	_end
}

# minimal host qt
build_host() {
	_group "Configuring host Qt"
	host="$ROOTDIR/$BUILD_DIR/host"
	ins="$ROOTDIR/$BUILD_DIR/host-install"
	mkdir -p "$host"

	pushd "$host"

	## SUBMODULES ##
	skip_submodules
	config=(-submodules "$SUBMODULES")
	if [ -n "$SKIP" ]; then
		config+=(-skip "$SKIP")
	fi

	## CCACHE ##
	if [ "${CCACHE:-true}" = true ]; then
		echo "-- Using ccache at: $CCACHE_PATH"

		cmake+=(
			-DCMAKE_CXX_COMPILER_LAUNCHER="${CCACHE_PATH}"
			-DCMAKE_C_COMPILER_LAUNCHER="${CCACHE_PATH}"
		)
	fi

	"$ROOTDIR/$BUILD_DIR/$DIRECTORY"/configure -developer-build -nomake tests -skip qtdoc \
		-no-feature-doc_snippets "${config[@]}" -- "${cmake[@]}"
	_end

	_group "Building host Qt"

	cmake --build . --target host_tools
	cmake --install . --prefix "$ins"
	export QT_HOST_PATH="$ins"
	popd

	_end
}

## Packaging ##
copy_build_artifacts() {
    _group "Copying artifacts"

	cd "$ROOTDIR/$BUILD_DIR/$DIRECTORY"
	cmake --install . --prefix "$OUT_DIR"
    rm -rf "$OUT_DIR"/doc

	# TODO(crueter): See if some unnecessary executables can be cleaned out. They take up >half of the
	# space on MinGW and Windows.

	# TODO(crueter): Some of the stuff like qtdiag, qmljsrootgen, qml.exe seem unnecessary.
	# Run some tests to confirm.

	if ! unix; then
		rm -f "$OUT_DIR"/bin/*dbus*
	fi

	_end
}

## Cleanup ##
# rm -rf "$BUILD_DIR" # "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

## Download + Extract ##
download
cd "$ROOTDIR/$BUILD_DIR"
extract

rm -f CMakeCache.txt

## cross comp host build ##
if [ "$CROSS" = true ]; then
	build_host
fi

## Configure ##
cd "$ROOTDIR/$BUILD_DIR/$DIRECTORY"
configure

## Build ##
build
copy_build_artifacts

## Package ##
package

echo "-- Done! Artifacts are in $ROOTDIR/artifacts, raw lib/include data is in $OUT_DIR"
