#!/bin/sh

# shellcheck disable=SC1091

set -e

. tools/common.sh

cd "$ROOTDIR/$BUILD_DIR"

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
