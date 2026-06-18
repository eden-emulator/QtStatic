#!/bin/sh

# shellcheck disable=SC1091

set -e

. tools/common.sh

must_install curl "$TAR"

case "$ARTIFACT" in
*.zip) must_install unzip ;;
*.tar.zst) must_install zstd ;;
*.tar.gz) must_install gzip ;;
*.tar.xz) must_install xz ;;
*.7z) must_install 7z ;;
*)
	echo "-- Unsupported extension ${ARTIFACT##.*}"
	exit 1
	;;
esac

# download
download() {
	_group "Downloading $PRETTY_NAME $VERSION"

	echo "-- URL: $DOWNLOAD_URL"

	TRIES=0
	if [ -f "$ARTIFACT" ]; then
		echo "-- Already downloaded, skipping"
		_end
		return
	fi

	while [ "$TRIES" -le 30 ]; do
		if curl -L "$DOWNLOAD_URL" -o "$ARTIFACT"; then
			echo "-- Succeeded"
			_end
			return
		fi

		TRIES=$((TRIES + 1))
		echo "-- Download failed, trying again in 5 seconds..."
		sleep 0
	done

	echo "-- Download failed after 30 tries, aborting"
	_end
	exit 1
}

# extract the archive + apply patches
extract() {
	_group "Extracting $PRETTY_NAME $VERSION"
	cd "$ROOTDIR/$BUILD_DIR"
	rm -fr "$DIRECTORY"

	case "$ARTIFACT" in
	*.zip) unzip "$ROOTDIR/$ARTIFACT" ;;
	*.tar.*) $TAR xf "$ROOTDIR/$ARTIFACT" ;;
	*.7z) 7z x "$ROOTDIR/$ARTIFACT" ;;
	esac

	echo "-- Succeeded"

	_end
}

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

## Download + Extract ##
download
extract
