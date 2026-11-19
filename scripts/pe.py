"""Package PIC Ada ELF as a relocatable EFI PE32+ application, all four ISAs."""
import struct
from pathlib import Path
from elf import ELF

MACHINES = {62: 0x8664, 183: 0xAA64, 243: 0x5064, 258: 0x6264}


def align(value, boundary):
    return (value + boundary - 1) & -boundary


def convert(source, output):
    elf = ELF(Path(source).read_bytes())
    preferred = 0x10000000
    image = bytearray(elf.image)
    groups = {}
    for target, addend in elf.relocs:
        if not 0 <= addend < elf.span:
            raise ValueError('relocation addend outside image')
        struct.pack_into('<Q', image, target, preferred + addend)
        groups.setdefault(target & ~4095, []).append(0xA000 | (target & 4095))
    reloc = bytearray()
    for page, entries in sorted(groups.items()):
        if len(entries) % 2:
            entries.append(0)
        reloc += struct.pack('<II', page, 8 + 2 * len(entries))
        reloc += struct.pack('<' + 'H' * len(entries), *entries)
    if not reloc:
        reloc = bytearray(struct.pack('<IIHH', 0, 12, 0, 0))
    sections = []
    for index, (_, flags, _, va, _, _, ms, _) in enumerate(elf.loads):
        if va % 4096:
            raise ValueError('PE section is not page aligned')
        chars = 0x40000040
        if flags & 1:
            chars = 0x60000020
        if flags & 2:
            chars = 0xC0000040
        sections.append((f'.seg{index}'.encode(), va, ms, image[va:va + ms], chars))
    reloc_va = align(elf.span, 4096)
    sections.append((b'.reloc', reloc_va, len(reloc), reloc, 0x42000040))
    headers_size = align(0x80 + 24 + 240 + 40 * len(sections), 512)
    header = bytearray(headers_size)
    header[:2] = b'MZ'
    struct.pack_into('<I', header, 0x3C, 0x80)
    header[0x80:0x84] = b'PE\0\0'
    struct.pack_into('<HHIIIHH', header, 0x84, MACHINES[elf.machine], len(sections),
                     0, 0, 0, 240, 0x2022)
    opt = 0x98
    struct.pack_into('<HBBIIIIIQII', header, opt, 0x20B, 1, 0, 0, 0, 0,
                     elf.entry, 0x1000, preferred, 4096, 512)
    struct.pack_into('<HHHHHH', header, opt + 40, 0, 0, 0, 0, 2, 0)
    struct.pack_into('<IIIHHQQQQII', header, opt + 56,
                     align(reloc_va + len(reloc), 4096), headers_size, 0,
                     10, 0x140, 0x200000, 0x10000, 0x200000, 0x10000, 0, 16)
    struct.pack_into('<II', header, opt + 112 + 5 * 8, reloc_va, len(reloc))
    payload = bytearray()
    for index, (name, va, ms, contents, chars) in enumerate(sections):
        raw_size = align(len(contents), 512)
        raw_offset = headers_size + len(payload)
        struct.pack_into('<8sIIIIIIHHI', header, opt + 240 + index * 40,
                         name, ms, va, raw_size, raw_offset, 0, 0, 0, 0, chars)
        payload += contents
        payload += bytes(raw_size - len(contents))
    Path(output).write_bytes(header + payload)
    return len(elf.relocs)
