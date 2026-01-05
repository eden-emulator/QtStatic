#!/bin/sh -e

# shellcheck disable=SC1091
. tools/common.sh

# ./mk/openbsd.sh apply = apply patches on qt-$VERSION from current dir
# ./mk/openbsd.sh make  = make a tarball of the patches from oi-userland

ROOTDIR="$PWD"
PATCHDIR="$ROOTDIR/patches"
out="$ROOTDIR/artifacts/solaris-patches-$VERSION.tar.zst"

if [ "$1" = "apply" ]; then
	echo "-- Applying OpenIndiana patches to source tree..."

	_patchdir="$ROOTDIR/patches"
	if [ ! -d "$_patchdir" ]; then
		if [ ! -f "$out" ]; then
			echo "-- Patch directory and/or archive not found. Run mk/openbsd.sh make first"
			exit 1
		fi

		echo "-- Extracting patch archive $out..."
		mkdir -p "$_patchdir"
		$TAR xf "$out" -C "$ROOTDIR"
	fi

	qtdir="$ROOTDIR/qt-$VERSION"
	cd "$qtdir"

	find "$_patchdir" -maxdepth 1 -type f | sort | while read -r patch; do
		echo "-- * Applying patch $(basename "$patch")"
		patch -p1 < "$patch"
	done

	rm -rf "$_patchdir"
	echo "-- Done! Patches applied to $qtdir"
elif [ "$1" = "make" ]; then
	echo "-- Making OpenIndiana patch archive..."

	rm -rf "$out" "$PATCHDIR"
	mkdir -p "$PATCHDIR" "$ROOTDIR/artifacts"

	artifact=hipster.tar.gz
	download="https://github.com/OpenIndiana/oi-userland/archive/refs/heads/oi/$artifact"
	dir=oi-userland-oi-hipster
	[ ! -f "$artifact" ] && curl -L "$download" -o "$artifact"
	[ ! -d "$dir" ] && $TAR xf "$artifact"

	cd "$dir"/components/library/qt6

	# OI makes this easy on us, since they also work with qt-everywhere
	# However we do want to remove all files that patch qt*3d, so we filter those out
	# however the FFmpeg-related patches are outdated, and realistically we don't care
	# because those only care about "encumbered" stuff.
	find patches -type f ! -exec grep -qE 'qt3d|qtquick3d|FFmpeg' {} \; -print | while read -r patch; do
		echo "-- * Adding patch $(basename "$patch")"
		cp "$patch" "$PATCHDIR"
	done

	cd "$ROOTDIR"

	tar --zstd -cf "$out" patches

	cd "$ROOTDIR"
	rm -rf "$dir" "$PATCHDIR"

	echo "-- Done! OpenIndiana patches are tarballed in $out"
else
	echo "-- Unknown command. Use 'apply' or 'make'"
	exit 1
fi