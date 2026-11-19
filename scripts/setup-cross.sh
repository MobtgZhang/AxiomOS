#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .toolchains/packages .toolchains/cross
cd .toolchains/packages
apt-get download gnat-15-aarch64-linux-gnu=15.2.0-16ubuntu1cross1 \
  gnat-15-riscv64-linux-gnu=15.2.0-16ubuntu1cross1 \
  gnat-15-loongarch64-linux-gnu=15.2.0-16ubuntu1cross2
for package in ./*.deb; do
  dpkg-deb -x "$package" ../cross
done
