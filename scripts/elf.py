"""Small, checked ELF64 reader used only by the build tooling."""
import struct


class ELF:
    def __init__(self, data):
        self.data = data
        if len(data) < 64 or data[:7] != b'\x7fELF\x02\x01\x01':
            raise ValueError('ELF64 little-endian required')
        self.kind, self.machine = struct.unpack_from('<HH', data, 16)
        self.entry, phoff, shoff = struct.unpack_from('<QQQ', data, 24)
        _, phsize, phnum, shsize, shnum, _ = struct.unpack_from('<6H', data, 52)
        if phsize != 56 or phoff + phnum * phsize > len(data):
            raise ValueError('invalid program header table')
        self.phdrs = [struct.unpack_from('<IIQQQQQQ', data, phoff + i * phsize)
                      for i in range(phnum)]
        self.loads = [p for p in self.phdrs if p[0] == 1 and p[6]]
        self.span = max(p[3] + p[6] for p in self.loads)
        self.image = bytearray(self.span)
        for _, flags, offset, va, _, fs, ms, _ in self.loads:
            if fs > ms or offset + fs > len(data) or flags & 3 == 3:
                raise ValueError('invalid or W+X load segment')
            self.image[va:va + fs] = data[offset:offset + fs]
        self.relocs = []
        if shsize != 64 or shoff + shnum * shsize > len(data):
            raise ValueError('invalid section table')
        for i in range(shnum):
            _, kind, flags, _, offset, size, _, _, _, entsize = struct.unpack_from(
                '<IIQQQQIIQQ', data, shoff + i * shsize)
            if kind == 4 and flags & 2:
                if entsize != 24 or size % 24:
                    raise ValueError('invalid RELA')
                for j in range(0, size, 24):
                    target, info, addend = struct.unpack_from('<QQq', data, offset + j)
                    expected = {62: 8, 183: 1027, 243: 3, 258: 3}[self.machine]
                    if info != expected or not 0 <= target <= self.span - 8:
                        raise ValueError(f'unsupported relocation {info} at {target:x}')
                    self.relocs.append((target, addend))
