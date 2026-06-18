#!/bin/sh

# shellcheck disable=SC1091

set -e

. tools/common.sh

must_install patch

cd "$ROOTDIR/$DIRECTORY"

find "$ROOTDIR/patches/$VERSION" -type f -name "*.patch" | while read -r patch; do
	echo "-- Applying patchset $(basename -- "$patch")"
	patch -p1 <"$patch"
done

# lmao
# -i isn't POSIX compliant but MinGW environments are strictly GNU so it's fine.
if mingw && arm; then
	sed -i '10i #include <arm_acle.h>' /qtbase/src/corelib/thread/qyieldcpu.h
fi
