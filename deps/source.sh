#!/bin/sh -e

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
	build-essential cmake ninja-build git unzip gcc python3 \
	tar xz-utils zstd
