#!/bin/sh

# shellcheck disable=SC1091

set -e

. tools/common.sh

mkdir -p "$OUT_DIR"

must_install cmake ninja

build() {
	cd "$ROOTDIR/$BUILD_DIR/$DIRECTORY"
	cmake --build . --parallel
}

build


