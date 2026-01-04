#!/bin/sh -ex

if command -v sudo >/dev/null 2>&1; then
    SUDO=sudo
else
    SUDO=""
fi

$SUDO pacman -Syu --needed --noconfirm \
    cmake \
    base-devel \
    git \
    unzip \
    gcc \
    vulkan-headers \
	ninja \
	python3 \
	glu \
	libglvnd \
	mesa \
	ccache