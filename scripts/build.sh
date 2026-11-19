#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export TMPDIR="$(pwd)/build/tmp"
mkdir -p "$TMPDIR"
exec alr -n exec -- python3 scripts/build.py "$@"
