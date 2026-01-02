#!/bin/sh -ex

pacman -Syu --needed --noconfirm \
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
	mesa