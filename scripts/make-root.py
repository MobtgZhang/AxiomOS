#!/usr/bin/env python3
"""Create the native EXT4 system volume, separate from the FAT UEFI ESP."""
from pathlib import Path
import argparse
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def make(arch):
    directory = ROOT / 'build' / arch
    tree = directory / 'root-tree'
    for name in ('bin', 'etc', 'boot', 'tmp', 'dev'):
        (tree / name).mkdir(parents=True, exist_ok=True)
    (tree / 'etc/motd').write_bytes(b'AxiomOS Ada kernel\n')
    (tree / 'boot/filesystem').write_bytes(b'EXT4 native root\n')
    for name in ('init', 'isolation-probe', 'memory-probe', 'unmap-probe'):
        (tree / 'bin' / name).write_bytes((directory / f'{name}.elf').read_bytes())
    disk = directory / 'root.ext4'
    with disk.open('wb') as output:
        output.truncate(64 * 1024 * 1024)
    subprocess.run(['mkfs.ext4', '-q', '-F', '-b', '4096', '-L', 'AxiomOS',
                    '-d', str(tree), str(disk)], check=True)
    return disk


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--arch', required=True)
    print(make(parser.parse_args().arch))
