#!/bin/sh -e

pkg_add -u

# OpenBSD compiler situation is sad
pkg_add gawk \
	gsed \
	bash \
	vulkan-headers \
	unzip-6.0p18-iconv \
	curl \
	cmake \
	ninja \
	xz \
	zstd \
	gtar-1.35p1 \
	ccache \
	binutils \
	pkgconf \
	llvm-19.1.7p9 \
	openssl-3.6.0p0v0
