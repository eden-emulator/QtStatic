#!/bin/sh -e

## Common variables ##

: "${VERSION:=6.11.1}"

win7_owner=crueter
win7_repo="qt6windows7"

case "$VERSION" in
	# no qt6windows7 builds yet.
	6.11.1|6.10.2|6.7.3) ;;
	# Qt6Windows7 stuff
	6.9.3)
		win7_commit="78074b12a94b56bb2b929f243fb9351b3f9e2439"
		export QT6WINDOWS7=1
		;;
	*)
		echo "-- ! Qt version $VERSION isn't supported yet. Check back later or submit patches"
		exit 1
		;;
esac

export QT6WINDOWS7_URL="https://github.com/$win7_owner/$win7_repo/archive/$win7_commit.tar.gz"
export QT6WINDOWS7_DIR="$win7_repo-$win7_commit"

VERSION_SHORT=$(echo "$VERSION" | cut -d'.' -f1-2)
export VERSION_SHORT

export PRETTY_NAME="Qt"
export FILENAME="qt"
export DIRECTORY="qt-$VERSION"
export ARTIFACT="$DIRECTORY.tar.zst"

# Download URLs and such
_base="https://github.com/crueter-ci/Qt/releases/download/src"
export DOWNLOAD_URL="$_base/$ARTIFACT"

# patches
export OPENBSD_PATCHES_URL="$_base/openbsd-patches-$VERSION.tar.zst"
export SOLARIS_PATCHES_URL="$_base/solaris-patches-$VERSION.tar.zst"

# Version check functions
qt_67() {
	[ "$VERSION" = 6.7.3 ]
}

qt_69() {
	[ "$VERSION" = 6.9.3 ]
}

qt_610() {
	[ "$VERSION" = 6.10.2 ]
}

qt_611() {
	[ "$VERSION" = 6.11.1 ]
}