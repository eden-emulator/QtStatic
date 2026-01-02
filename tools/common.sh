#!/bin/bash -e

## Build variables ##

# shellcheck disable=SC1091
. ./tools/vars.sh

# TODO: autodetect platform
# but make android manual specification
ROOTDIR="$PWD"
: "${OUT_DIR:=$PWD/out}"
: "${PLATFORM:?-- You must supply the PLATFORM environment variable.}"
: "${MACOSX_DEPLOYMENT_TARGET:=11.0}"

## Command Checks ##

must_install() {
	for cmd in "$@"; do
		command -v "$cmd" >/dev/null 2>&1 || { echo "-- $cmd must be installed" && exit 1; }
	done
}

must_install curl zstd tar cmake xz ninja unzip

case "$ARTIFACT" in
	*.zip) must_install unzip ;;
	*.tar.*) ;;
	*.7z) must_install 7z ;;
	*) echo "-- Unsupported extension ${ARTIFACT##.*}"; exit 1 ;;
esac

## Utility Functions ##

# download
download() {
	TRIES=0
	[ -f "$ARTIFACT" ] && return

	while [ "$TRIES" -le 30 ]; do
		curl -L "$DOWNLOAD_URL" -o "$ARTIFACT" && return
		TRIES=$((TRIES + 1))
		echo "-- Download failed, trying again in 5 seconds..."
		sleep 0
	done

	echo "-- Download failed after 30 tries, aborting"
	exit 1
}

# extract the archive + apply patches
extract() {
	echo "-- Extracting $PRETTY_NAME $VERSION"
	rm -fr "$DIRECTORY"

	case "$ARTIFACT" in
		*.zip) unzip "$ROOTDIR/$ARTIFACT" >/dev/null ;;
		*.tar.*) tar --use-compress-program xz -xf "$ROOTDIR/$ARTIFACT" >/dev/null ;;
		*.7z) 7z x "$ROOTDIR/$ARTIFACT" >/dev/null ;;
	esac

	# qt6windows7 patch
	echo "-- Patching for Windows 7..."
	_repo="qt6windows7"
	_sha="7ade46564f99453c04d893e070d02d47bcba63dc"

	curl -L "https://github.com/ANightly/$_repo/archive/$_sha.tar.gz" -o w7.tar.gz
	tar xf w7.tar.gz

	cp -r "$_repo-$_sha"/qtbase/src/* "$DIRECTORY"/qtbase/src
	rm w7.tar.gz
}

# generate sha1, 256, and 512 sums for a file
sums() {
	for file in "$@"; do
		for algo in 1 256 512; do
			if ! command -v sha${algo}sum >/dev/null 2>&1; then
				sha${algo} "$file" | awk '{print $4}' | tr -d "\n" > "$file".sha${algo}sum
			else
				sha${algo}sum "$file" | cut -d " " -f1 | tr -d "\n" > "$file".sha${algo}sum
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
package() {
    echo "-- Packaging..."
    mkdir -p "$ROOTDIR/artifacts"

	TARBALL=$FILENAME-$PLATFORM-$ARCH-$VERSION.tar

    cd "$OUT_DIR"
    tar cf "$ROOTDIR/artifacts/$TARBALL" ./*

    cd "$ROOTDIR/artifacts"
    zstd -10 "$TARBALL"
    rm "$TARBALL"

    sums "$TARBALL.zst"
}