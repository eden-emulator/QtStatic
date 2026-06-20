#!/bin/bash -e

## Build variables ##

# shellcheck disable=SC1091
. ./tools/vars.sh

_group() {
    if [ -n "$GITHUB_RUN_ID" ]; then
		echo "##[group]$*"
	else
		echo "======= $* ======="
	fi
}

_end() {
	if [ -n "$GITHUB_RUN_ID" ]; then
		echo "##[endgroup]"
	fi
}

# default platform
case "$(uname -s)" in
Linux) : "${PLATFORM:=linux}" ;;
Darwin) : "${PLATFORM:=macos}" ;;
FreeBSD) : "${PLATFORM:=freebsd}" ;;
OpenBSD) : "${PLATFORM:=openbsd}" ;;
SunOS) : "${PLATFORM:=solaris}" ;;
*) : "${PLATFORM:?-- You must supply the PLATFORM environment variable.}" ;;
esac

# TODO: autodetect architecture
# but make android manual specification
ROOTDIR="$PWD"
: "${OUT_DIR:=$PWD/out}"
: "${MACOSX_DEPLOYMENT_TARGET:=13.0}"

mkdir -p "$ROOTDIR"/artifacts

## Command Checks ##

must_install() {
	for cmd in "$@"; do
		command -v "$cmd" >/dev/null 2>&1 || { echo "-- $cmd must be installed" && exit 1; }
	done
}

must_install curl zstd cmake xz ninja unzip patch

case "$ARTIFACT" in
*.zip) must_install unzip ;;
*.tar.*) ;;
*.7z) must_install 7z ;;
*)
	echo "-- Unsupported extension ${ARTIFACT##.*}"
	exit 1
	;;
esac

## Utility Functions ##

# download
download() {
	_group "Downloading $PRETTY_NAME $VERSION"

	echo "-- URL: $DOWNLOAD_URL"

	TRIES=0
	if [ -f "$ARTIFACT" ]; then
		echo "-- Already downloaded, skipping"
		_end
		return
	fi

	while [ "$TRIES" -le 30 ]; do
		if curl -L "$DOWNLOAD_URL" -o "$ARTIFACT"; then
			echo "-- Succeeded"
			_end
			return
		fi

		TRIES=$((TRIES + 1))
		echo "-- Download failed, trying again in 5 seconds..."
		sleep 0
	done

	echo "-- Download failed after 30 tries, aborting"
	_end
	exit 1
}

# extract the archive + apply patches
extract() {
	_group "Extracting $PRETTY_NAME $VERSION"
	rm -fr "$DIRECTORY"

	case "$ARTIFACT" in
	*.zip) unzip "$ROOTDIR/$ARTIFACT" >/dev/null ;;
	*.tar.*) $TAR xf "$ROOTDIR/$ARTIFACT" >/dev/null ;;
	*.7z) 7z x "$ROOTDIR/$ARTIFACT" >/dev/null ;;
	esac

	# qt6windows7 patch
	if [ "$QT6WINDOWS7" = "1" ] && msvc && amd64; then
		echo "-- Patching for Windows 7"

		curl -L "$QT6WINDOWS7_URL" -o w7.tar.gz
		$TAR xf w7.tar.gz

		cp -r "$QT6WINDOWS7_DIR"/qtbase/src/* "$DIRECTORY"/qtbase/src
		rm w7.tar.gz
	fi

	# solaris patches
	if [ "$PLATFORM" = "solaris" ]; then
		cd "$ROOTDIR"
		curl -L "$SOLARIS_PATCHES_URL" -o "$ROOTDIR/artifacts/solaris-patches-$VERSION.tar.zst"
		mk/solaris.sh apply
	fi

	# misc in-tree patches
	cd "$ROOTDIR/$BUILD_DIR/$DIRECTORY"

	find "$ROOTDIR/patches/$VERSION" -type f -name "*.patch" | while read -r patch; do
		echo "-- Applying patchset $(basename -- "$patch")"
		patch -p1 <"$patch"
	done

	# lmao
	# -i isn't POSIX compliant but MinGW environments are strictly GNU so it's fine.
	if mingw && arm; then
		cd "$ROOTDIR/$BUILD_DIR"
		sed -i '10i #include <arm_acle.h>' "$DIRECTORY"/qtbase/src/corelib/thread/qyieldcpu.h
	fi

	_end
}

# generate sha1, 256, and 512 sums for a file
sums() {
	for file in "$@"; do
		for algo in 1 256 512; do
			if ! command -v sha${algo}sum >/dev/null 2>&1; then
				sha${algo} "$file" | awk '{print $4}' | tr -d "\n" >"$file".sha${algo}sum
			else
				sha${algo}sum "$file" | cut -d " " -f1 | tr -d "\n" >"$file".sha${algo}sum
			fi
		done
	done
}

# nproc
num_procs() {
	# default to 4 because github actions
	if command -v nproc >/dev/null 2>&1; then
		nproc
	elif command -v sysctl >/dev/null 2>&1; then
		sysctl -n hw.logicalcpu
	elif command -v getconf >/dev/null 2>&1; then
		getconf _NPROCESSORS_ONLN
	else
		echo 4
	fi
}

## Packaging ##
strip_libs() {
	if macos; then
		find "$OUT_DIR" -type f -name '*.dylib*' -exec strip -u -r {} \;
	elif unix; then
		find "$OUT_DIR" -type f -name '*.so*' -exec strip {} \;
	elif mingw; then
		find "$OUT_DIR" -type f -name '*.dll' -exec strip {} \;
	fi
}

package() {
	_group "Packaging"

	# strip shared libs
	strip_libs

	# remove superfluous fluentwinui3 stuff
	rm -rf "$OUT_DIR"/qml/QtQuick/Controls/FluentWinUI3

	mkdir -p "$ROOTDIR/artifacts"

	: "${PKGNAME:=$PLATFORM}"

	TARBALL="$FILENAME-$PKGNAME-$ARCH-$VERSION.tar"

	cd "$OUT_DIR"
	$TAR cf "$ROOTDIR/artifacts/$TARBALL" ./*

	cd "$ROOTDIR/artifacts"
	zstd -10 "$TARBALL"
	rm "$TARBALL"

	sums "$TARBALL.zst"

	_end
}

## Platform Stuff ##
TAR="tar"
SHARED=false

case "$PLATFORM" in
freebsd | openbsd | solaris)
	TAR="gtar"
	SHARED=true
	;;
linux)
	SHARED=true
	;;
ios)
	CROSS=true
	;;
esac

export TAR
export SHARED
export CROSS

## Platform Utility Functions ##

linux() {
	[ "$PLATFORM" = linux ]
}

macos() {
	[ "$PLATFORM" = macos ]
}

ios() {
	[ "$PLATFORM" = ios ]
}

msvc() {
	[ "$PLATFORM" = windows ]
}

mingw() {
	[ "$PLATFORM" = mingw ]
}

windows() {
	msvc || mingw
}

arm() {
	[ "$ARCH" = arm64 ] || [ "$ARCH" = aarch64 ]
}

amd() {
	[ "$ARCH" = amd64 ]
}

# get me a unix with no macOS
# "UNIX with no macOS? Ay Tony, get me a pizza with nuthin'!"
unix() {
	linux
}
