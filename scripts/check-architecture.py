#!/usr/bin/env python3
"""Check the source boundary between common policy, ISA and board backends."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ARCHES = ('x86_64', 'aarch64', 'riscv64', 'loongarch64')
BACKENDS = ('context', 'counter', 'mmu', 'secondary')
errors = []

for directory in ('kernel', 'hal'):
    for path in sorted((ROOT / directory).rglob('*')):
        if path.suffix.lower() == '.s':
            errors.append(f'{path.relative_to(ROOT)}: assembly belongs in arch/ or platform/')
        if path.suffix not in ('.ads', '.adb'):
            continue
        # Ignore Ada comments, while retaining strings such as import names.
        source = '\n'.join(line.split('--', 1)[0] for line in path.read_text().splitlines())
        if re.search(r'\bSystem\.Machine_Code\b|\bAsm\s*\(', source, re.I):
            errors.append(f'{path.relative_to(ROOT)}: inline assembly in common code')
        if re.search(r'\b(?:x86_64|aarch64|riscv64|loongarch64)\b', source, re.I):
            errors.append(f'{path.relative_to(ROOT)}: ISA selection in common code')

for arch in ARCHES:
    for backend in BACKENDS:
        name = f'axiomos-hal-{backend}.adb'
        if not (ROOT / 'hal' / name.replace('.adb', '.ads')).is_file():
            errors.append(f'{name}: missing shared HAL contract')
        if not (ROOT / 'arch' / arch / name).is_file():
            errors.append(f'arch/{arch}/{name}: missing backend')
        if (ROOT / 'platform' / f'qemu-{arch}' / name).exists():
            errors.append(f'platform/qemu-{arch}/{name}: ISA backend belongs in arch/')
    for name in ('axiomos-architecture.ads', 'context.S', 'cpu.S', 'secondary.S', 'syscall.S'):
        if not (ROOT / 'arch' / arch / name).is_file():
            errors.append(f'arch/{arch}/{name}: missing ISA mechanism')
    if not (ROOT / 'platform' / f'qemu-{arch}' / 'axiomos-hal-discovery.adb').is_file():
        errors.append(f'platform/qemu-{arch}: missing board topology discovery')

if errors:
    raise SystemExit('\n'.join(errors))
print('PASS architecture boundary: common Ada policy, four ISA backends, board discovery')
