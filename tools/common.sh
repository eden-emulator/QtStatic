#!/bin/sh -e

## Build variables ##

# shellcheck disable=SC1091
. ./tools/vars.sh

## Buildtime/Input Variables ##

: "${ARCH:=amd64}"
: "${BUILD_DIR:=build}"
export ROOTDIR="$PWD"
: "${OUT_DIR:=$PWD/out}"
: "${MACOSX_DEPLOYMENT_TARGET:=13.0}"

mkdir -p "$BUILD_DIR"

## util ##

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

## Command Checks ##

must_install() {
	for cmd in "$@"; do
		command -v "$cmd" >/dev/null 2>&1 || { echo "-- $cmd must be installed" && exit 1; }
	done
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
esac

export TAR
export SHARED

## Platform Utility Functions ##

linux() {
	[ "$PLATFORM" = linux ]
}

macos() {
	[ "$PLATFORM" = macos ]
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

openbsd() {
	[ "$PLATFORM" = openbsd ]
}

freebsd() {
	[ "$PLATFORM" = freebsd ]
}

solaris() {
	[ "$PLATFORM" = solaris ]
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
	linux || freebsd || openbsd || solaris
}
