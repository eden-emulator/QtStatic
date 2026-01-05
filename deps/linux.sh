#!/bin/sh -e
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
	build-essential cmake ninja-build git unzip gcc python3 \
	libvulkan-dev libgl1-mesa-dev libglu1-mesa-dev libglvnd-dev \
	pkg-config libx11-dev libxcb1-dev libx11-xcb-dev libxrandr-dev \
	libxrender-dev libxkbcommon-dev libxkbcommon-x11-dev zstd \
	libssl-dev zlib1g-dev libfreetype6-dev libpng-dev libjpeg-dev \
	libasound2-dev libpulse-dev libdbus-1-dev libfontconfig1-dev \
	tar xz-utils ccache
