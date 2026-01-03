#!/bin/sh -e

# shellcheck disable=SC1091

. tools/common.sh

# ./mk/openbsd.sh apply = apply patches on qt-$VERSION from current dir
# ./mk/openbsd.sh make  = make a tarball of the patches from ports

ROOTDIR="$PWD"
obsd="$ROOTDIR/mk/openbsd"
PATCHDIR="$obsd/patches"
out="$ROOTDIR/artifacts/openbsd-patches-$VERSION.tar.zst"

if [ "$1" = "apply" ]; then
	echo "-- Applying OpenBSD patches to source tree..."

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

	find "$_patchdir" -type d -not -name patches | while read -r dir; do
		module=$(echo "$dir" | rev | cut -d'/' -f1 | rev)
		echo "-- Applying patches for module: $module"

		cd "$qtdir/$module" || { echo "-- Module $module not found in source tree, skipping"; continue; }

		find "$dir" -type f -maxdepth 1 | sort | while read -r patch; do
			echo "-- * Applying patch $(basename "$patch")"
			patch -p0 < "$patch"
		done

		cd "$ROOTDIR"
	done

	# rm -rf "$_patchdir"
	echo "-- Done! Patches applied to $qtdir"
elif [ "$1" = "make" ]; then
	echo "-- Making OpenBSD patch archive..."

	rm -rf "$obsd" "$out"
	mkdir -p "$PATCHDIR" "$ROOTDIR/artifacts"

	[ ! -f ports.tar.gz ] && curl -L https://github.com/openbsd/ports/archive/refs/heads/master.tar.gz -o ports.tar.gz
	[ ! -d ports-master ] && $TAR xf ports.tar.gz

	cd ports-master/x11/qt6

	# We don't want certain modules
	rm -rf qtquick3dphysics qtwebengine pyside6

	find . -name patches -type d | while read -r dir; do
		module=$(echo "$dir" | cut -d'/' -f2)
		echo "-- Collecting patches for module: $module"
		cp -r "$dir" "$PATCHDIR/$module"
	done

	cd "$obsd"
	# We don't need tests
	find patches -type f \( -name 'patch-tests*' -o -name 'patch-src_testlib*' \) -exec rm {} \;
	tar --zstd -cf "$out" patches

	cd "$ROOTDIR"
	rm -rf ports-master "$obsd"

	echo "-- Done! OpenBSD patches are tarballed in $out"
else
	echo "-- Unknown command. Use 'apply' or 'make'"
	exit 1
fi