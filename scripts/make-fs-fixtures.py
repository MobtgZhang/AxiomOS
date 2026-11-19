#!/usr/bin/env python3
"""Real mkfs fixtures for the Ada parsers, including fragmented/large streams."""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'build/fs-fixtures'
TREE = FIXTURES / 'tree'


def run(*args):
    subprocess.run(list(map(str, args)), check=True, stdout=subprocess.DEVNULL,
                   env={**os.environ, 'TMPDIR': str(ROOT / 'build/tmp')})


def make():
    TREE.mkdir(parents=True, exist_ok=True)
    (TREE / 'hello.txt').write_bytes(b'hello from a real filesystem\n')
    (TREE / 'long-file-name.txt').write_bytes(b'long filename contents\n')
    (TREE / 'large.bin').write_bytes(bytes((i * 17 + i // 256) % 251 for i in range(400000)))
    (TREE / 'empty').write_bytes(b'')
    with (TREE / 'sparse.bin').open('wb') as output:
        output.truncate(1024 * 1024)
        for block in range(0, 256, 2):
            output.seek(block * 4096)
            output.write(bytes([block % 251 + 1]) * 4096)
    (TREE / 'tree').mkdir(exist_ok=True)
    (TREE / 'tree/deep.txt').write_bytes(b'nested directory\n')
    for kind in ('ext2', 'ext3', 'ext4', 'fat16', 'fat32', 'ntfs'):
        disk = FIXTURES / f'{kind}.img'
        with disk.open('wb') as output:
            output.truncate(128 * 1024 * 1024)
        if kind.startswith('ext'):
            run(f'mkfs.{kind}', '-q', '-F', '-b', '1024' if kind == 'ext2' else '4096',
                '-d', TREE, disk)
        elif kind.startswith('fat'):
            run('mkfs.fat', '-F', kind[3:], disk)
            for path in TREE.iterdir():
                run('mcopy', '-i', disk, '-s', path, '::/')
        else:
            run('mkfs.ntfs', '-F', '-Q', disk)
            for path in TREE.iterdir():
                if path.is_file():
                    run('ntfscp', '-f', disk, path, '/' + path.name)
            # Force directory index allocation in addition to the resident root.
            for i in range(80):
                run('ntfscp', '-f', disk, TREE / 'hello.txt', f'/entry-{i:03d}.txt')
    print(FIXTURES)


if __name__ == '__main__':
    make()
