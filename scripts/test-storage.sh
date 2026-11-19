#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export TMPDIR="$(pwd)/build/tmp"
mkdir -p "$TMPDIR"
python3 scripts/make-fs-fixtures.py > build/fixtures.log 2>&1
alr -n exec -- gprbuild -p -P hosted.gpr storage_tests.adb
for kind in ext2 ext3 ext4 fat16 fat32 ntfs; do
    build/hosted/storage_tests "build/fs-fixtures/$kind.img"
done
