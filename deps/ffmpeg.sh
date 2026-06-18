#!/bin/sh -e

_version=8.2-f16c3cc5aa
_repo=FFmpeg-Qt
_name=ffmpeg
_dir="$ROOTDIR/$_name-$PLATFORM-$ARCH-$_version"

_download="https://github.com/crueter-ci/$_repo/releases/download/v$_version/$_name-$PLATFORM-$ARCH-$_version.tar.zst"
_artifact="$_name-$PLATFORM-$ARCH-$_version.tar.zst"

if [ ! -d "$_dir" ]; then
	_group "Downloading $_repo"
	echo "$_download"
	[ -f "$_artifact" ] || curl -L "$_download" -o "$_artifact"
	mkdir -p "$_dir"
	$TAR xf "$_artifact" -C "$_dir"
	rm -f "$_dir"/CMakeLists.txt
	_end
fi

export FFMPEG_DIR="$_dir"
