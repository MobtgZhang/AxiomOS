#!/usr/bin/env python3
"""All Ada compilation runs under the Alire environment and through GPRbuild."""
import argparse
import io
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
from pe import convert
from elf import ELF

ROOT = Path(__file__).resolve().parents[1]
(ROOT / 'build/tmp').mkdir(parents=True, exist_ok=True)
os.environ['TMPDIR'] = str(ROOT / 'build/tmp')
TARGETS = {
    'x86_64': (62, 'BOOTX64.EFI', ['-mabi=ms', '-mno-red-zone']),
    'aarch64': (183, 'BOOTAA64.EFI', []),
    'riscv64': (243, 'BOOTRISCV64.EFI', ['-march=rv64imac_zicsr_zifencei',
                                        '-mabi=lp64', '-mno-relax']),
    'loongarch64': (258, 'BOOTLOONGARCH64.EFI', []),
}


def run(args, **kw):
    print('+', ' '.join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=ROOT, check=True, **kw)


def compiler(arch):
    if arch == 'x86_64':
        return 'gcc'
    system = shutil.which(f'{arch}-linux-gnu-gcc')
    if not system:
        raise SystemExit(f'missing {arch}-linux-gnu-gcc (see toolchains/README.md)')
    frontend = subprocess.check_output([system, '-print-prog-name=gnat1'], text=True).strip()
    if Path(frontend).is_file():
        return system
    base = ROOT / '.toolchains/cross/usr'
    exe = base / f'libexec/gcc-cross/{arch}-linux-gnu/15/gnat1'
    includes = base / f'lib/gcc-cross/{arch}-linux-gnu/15/adainclude'
    if not exe.exists() or not includes.exists():
        raise SystemExit(f'missing {arch} Ada frontend; run scripts/setup-cross.sh')
    wrapper = ROOT / f'.toolchains/bin/{arch}-ada-gcc'
    wrapper.parent.mkdir(parents=True, exist_ok=True)
    import shlex
    wrapper.write_text('#!/bin/sh\nexec ' + shlex.quote(system) + ' -B' +
                       shlex.quote(str(exe.parent) + '/') + ' -I' +
                       shlex.quote(str(includes)) + ' "$@"\n')
    wrapper.chmod(0o755)
    return str(wrapper)


def build(arch):
    machine, filename, flags = TARGETS[arch]
    cc = compiler(arch)
    directory = ROOT / 'build' / arch
    user_objects = directory / 'user/obj'
    for unit, entry, output_name in [('user_init.adb', 'user_entry', 'init'),
                                      ('isolation_probe.adb', 'probe_entry', 'isolation-probe'),
                                      ('memory_probe.adb', 'memory_probe_entry', 'memory-probe'),
                                      ('unmap_probe.adb', 'unmap_probe_entry', 'unmap-probe')]:
        run(['gprbuild', '-p', '-c', '-P', 'user.gpr', f'-XARCH={arch}',
             f'-XADA_CC={cc}', unit])
        run([cc, *flags, '-c', ROOT / f'arch/{arch}/syscall.S', '-o', user_objects / 'syscall.o'])
        run([cc, *flags, '-nostdlib', '-static', '-no-pie', '-Wl,--build-id=none,-z,max-page-size=4096',
             f'-Wl,-T,{ROOT / "toolchains/user.ld"},-e,{entry}', '-o', directory / output_name,
             user_objects / unit.replace('.adb', '.o'), user_objects / 'syscall.o'])
        # Debug symbols remain in the original image, not in the bounded initramfs.
        run([('strip' if arch == 'x86_64' else f'{arch}-linux-gnu-strip'),
             '-o', directory / f'{output_name}.elf', directory / output_name])
    for kind, main, entry in [('loader', 'axiomos-boot-loader.adb', 'efi_entry'),
                               ('kernel', 'axiomos-kernel-main.adb', 'axiom_kernel_entry')]:
        objects = directory / kind / 'obj'
        objects.mkdir(parents=True, exist_ok=True)
        run(['gprbuild', '-p', '-c', '-j0', '-P', 'freestanding.gpr',
             f'-XARCH={arch}', f'-XKIND={kind}', f'-XADA_CC={cc}',
             main, 'axiomos-runtime.adb'])
        asm = objects / 'cpu.o'
        run([cc, *flags, '-c', '-fPIC', *(['-DAXIOM_LOADER'] if kind == 'loader' else []), ROOT / f'arch/{arch}/cpu.S', '-o', asm])
        run([cc, *flags, '-c', '-fPIC', ROOT / f'platform/qemu-{arch}/serial.S', '-o', objects / 'serial.o'])
        if kind == 'kernel':
            run([cc, *flags, '-c', '-fPIC', ROOT / f'arch/{arch}/secondary.S', '-o', objects / 'ap.o'])
        if kind == 'kernel':
            run([cc, *flags, '-c', '-fPIC', ROOT / f'arch/{arch}/context.S', '-o', objects / 'context.o'])
        output = directory / f'{kind}.elf'
        run([cc, *flags, '-nostdlib', '-shared', '-Wl,-Bsymbolic,--no-undefined',
             '-Wl,--build-id=none,-z,max-page-size=4096',
             f'-Wl,-T,{ROOT / "toolchains/image.ld"},-e,{entry}',
             '-o', output, *sorted(objects.glob('*.o'))])
        elf = ELF(output.read_bytes())
        if elf.machine != machine or elf.kind != 3:
            raise SystemExit(f'{arch}: wrong ELF target/type')
        undefined = subprocess.check_output(
            [('nm' if arch == 'x86_64' else f'{arch}-linux-gnu-nm'), '-u', output], text=True)
        if undefined.strip():
            raise SystemExit(f'unresolved runtime dependencies: {undefined}')
    esp = directory / 'esp'
    (esp / 'EFI/BOOT').mkdir(parents=True, exist_ok=True)
    (esp / 'axiomos').mkdir(parents=True, exist_ok=True)
    relocations = convert(directory / 'loader.elf', esp / 'EFI/BOOT' / filename)
    shutil.copyfile(directory / 'kernel.elf', esp / 'axiomos/kernel.elf')
    with tarfile.open(esp / 'axiomos/initramfs.tar', 'w', format=tarfile.USTAR_FORMAT) as archive:
        for name, contents in [('etc/', None), ('etc/motd', b'AxiomOS Ada kernel\n'),
                               ('boot/', None), ('boot/version', b'0.1.0-dev\n'),
                               ('bin/', None), ('bin/init', (directory / 'init.elf').read_bytes()),
                               ('bin/isolation-probe', (directory / 'isolation-probe.elf').read_bytes()),
                               ('bin/memory-probe', (directory / 'memory-probe.elf').read_bytes()),
                               ('bin/unmap-probe', (directory / 'unmap-probe.elf').read_bytes())]:
            info = tarfile.TarInfo(name)
            info.mtime = 0
            info.mode = 0o755 if contents is None else 0o444
            if contents is None:
                info.type = tarfile.DIRTYPE
                archive.addfile(info)
            else:
                info.size = len(contents)
                archive.addfile(info, io.BytesIO(contents))
    disk = directory / 'esp.img'
    with disk.open('wb') as stream:
        stream.truncate(64 * 1024 * 1024)
    run(['mkfs.vfat', disk])
    run(['mcopy', '-i', disk, '-s', esp / 'EFI', esp / 'axiomos', '::/'])
    run(['python3', ROOT / 'scripts/make-root.py', f'--arch={arch}'])
    print(f'{arch}: Ada EFI + independent ELF + initramfs; {relocations} EFI fixups')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--arch', choices=[*TARGETS, 'all'], default='x86_64')
    args = parser.parse_args()
    os.chdir(ROOT)
    if not os.environ.get('ALIRE'):
        run(['alr', '-n', 'exec', '--', 'python3', __file__, '--arch', args.arch])
    else:
        for target in TARGETS if args.arch == 'all' else [args.arch]:
            build(target)
