#!/bin/sh -e

_dir="$ROOTDIR/libdrm"
_url="https://gitlab.freedesktop.org/mesa/drm.git"
_name=drm

if [ ! -d "$_dir" ]; then
	_group "Building $_name"
	cd "$ROOTDIR/$BUILD_DIR"

	[ -d "$_name" ] || git clone "$_url" --depth 1
	cd "$_name"

	meson setup build --prefix="$_dir" -Ddefault_library=shared
	cd build

	ninja
	ninja install

	cd "$ROOTDIR"

	_end
fi

export LIBDRM_DIR="$_dir"