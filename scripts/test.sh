#!/bin/sh
# Reproduce the current acceptance path using the project's Alire environment.
set -eu
cd "$(dirname "$0")/.."
export TMPDIR="$(pwd)/build/tmp"
mkdir -p "$TMPDIR"
arch=all
cpus=4
timeout=120
host_only=false
for option in "$@"; do
    case "$option" in
        --arch=*) arch=${option#*=} ;;
        --cpus=*) cpus=${option#*=} ;;
        --timeout=*) timeout=${option#*=} ;;
        --host-only) host_only=true ;;
        --help)
            echo 'Usage: scripts/test.sh [--arch=all|x86_64|aarch64|riscv64|loongarch64] [--cpus=4] [--timeout=120] [--host-only]'
            exit 0 ;;
        *) echo "Unknown option: $option" >&2; exit 2 ;;
    esac
done
case "$arch" in
    all) targets='x86_64 aarch64 riscv64 loongarch64' ;;
    x86_64|aarch64|riscv64|loongarch64) targets=$arch ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 2 ;;
esac
for value in "$cpus" "$timeout"; do
    case "$value" in
        ''|*[!0-9]*) echo 'cpus and timeout must be positive integers' >&2; exit 2 ;;
    esac
    if [ "$value" -le 0 ]; then echo 'cpus and timeout must be positive' >&2; exit 2; fi
done
if [ "$cpus" -gt 64 ]; then echo 'cpus must be 1..64' >&2; exit 2; fi
alr -n build
alr -n run
scripts/test-storage.sh
if "$host_only"; then exit 0; fi
scripts/build.sh "--arch=$arch"
for target in $targets; do
    python3 scripts/run-qemu.py "--arch=$target" "--cpus=$cpus" "--timeout=$timeout" --test
done
