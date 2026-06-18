#!/bin/sh -e

url="http://mirrors.kernel.org/ubuntu/pool/main/libz/libzstd/zstd_1.5.5+dfsg2-2build1_amd64.deb"
wget "$url" -O zstd.deb
sudo dpkg -i zstd.deb