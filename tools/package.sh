#!/bin/sh

# shellcheck disable=SC1091

set -e

. tools/common.sh

mkdir -p "$ROOTDIR"/artifacts

must_install cmake zstd "$TAR"

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

# generate sha512 sum for a file
sums() {
	for file in "$@"; do
		if ! command -v sha512sum >/dev/null 2>&1; then
			must_install sha512
			sha512 "$file" | awk '{print $4}' | tr -d "\n" >"$file".sha512sum
		else
			must_install sha512sum
			sha512sum "$file" | cut -d " " -f1 | tr -d "\n" >"$file".sha512sum
		fi
	done
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

copy_build_artifacts
package

echo "-- Done! Artifacts are in $ROOTDIR/artifacts, raw lib/include data is in $OUT_DIR"