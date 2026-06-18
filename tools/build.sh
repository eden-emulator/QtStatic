#!/bin/sh

# shellcheck disable=SC1091

set -e

. tools/common.sh

build() {
	cd "$ROOTDIR/$BUILD_DIR/$DIRECTORY"
	cmake --build . --parallel
}

build


