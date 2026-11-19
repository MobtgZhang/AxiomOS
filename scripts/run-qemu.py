#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
FIRMWARE = {
    'x86_64': ('/usr/share/OVMF/OVMF_CODE_4M.fd', '/usr/share/OVMF/OVMF_VARS_4M.fd'),
    'aarch64': ('/usr/share/AAVMF/AAVMF_CODE.fd', '/usr/share/AAVMF/AAVMF_VARS.fd'),
    'riscv64': ('/usr/share/qemu-efi-riscv64/RISCV_VIRT_CODE.fd',
                '/usr/share/qemu-efi-riscv64/RISCV_VIRT_VARS.fd'),
    'loongarch64': ('/usr/share/qemu-efi-loongarch64/QEMU_EFI.fd',
                    '/usr/share/qemu-efi-loongarch64/QEMU_VARS.fd'),
}
MARKERS = ['AXIOM:MENU:READY', 'AXIOM:UEFI:EXITED', 'AXIOM:KERNEL:ENTER',
           'AXIOM:PMM:PASS', 'AXIOM:HEAP:PASS', 'AXIOM:MMU:ROLLBACK:PASS',
           'AXIOM:VFS:PASS', 'AXIOM:IO:PASS',
           'AXIOM:DRIVERS:PASS', 'AXIOM:BLOCK:HARDWARE:PASS', 'AXIOM:ROOT:EXT4:PASS',
           'AXIOM:SMP:HARDWARE:PASS', 'AXIOM:MMU:HARDWARE:PASS',
           'AXIOM:USER:SYSCALL:PASS', 'AXIOM:USER:ISOLATION:PASS',
           'AXIOM:USER:RECLAIM:PASS', 'AXIOM:KERNEL:READY']


def run(arch, smoke=False, timeout=120, cpus=2, graphic=False):
    if not 1 <= cpus <= 64 or timeout <= 0:
        raise SystemExit('cpus must be 1..64 and timeout must be positive')
    directory = ROOT / 'build' / arch
    code, template = FIRMWARE[arch]
    code = os.environ.get('AXIOM_UEFI_CODE', code)
    template = os.environ.get('AXIOM_UEFI_VARS', template)
    for path in [code, template, directory / 'esp.img', directory / 'root.ext4']:
        if not Path(path).exists():
            raise SystemExit(f'missing {path}; see toolchains/README.md')
    variables = directory / 'uefi-vars.fd'
    shutil.copyfile(template, variables)
    machine = 'q35' if arch == 'x86_64' else 'virt'
    args = [f'qemu-system-{arch}', '-machine', machine, '-m', '512M', '-smp', str(cpus),
            '-drive', f'if=pflash,format=raw,readonly=on,file={code}',
            '-drive', f'if=pflash,format=raw,file={variables}',
            '-drive', f'if=none,format=raw,file={directory / "esp.img"},id=esp',
            '-device', 'virtio-blk-pci,drive=esp', '-no-reboot', '-monitor', 'none']
    args += ['-drive', f'if=none,format=raw,file={directory / "root.ext4"},id=root,readonly=on',
             '-device', 'virtio-blk-pci,disable-legacy=on,drive=root']
    if arch == 'aarch64':
        args += ['-cpu', 'cortex-a72']
    if not graphic:
        args += ['-display', 'none']
    args += ['-serial', 'stdio']
    print('+', ' '.join(args), flush=True)
    if not smoke:
        return subprocess.call(args, cwd=ROOT)
    log = directory / 'qemu-boot.log'
    started = time.monotonic()
    outcome = 'timeout'
    with log.open('wb') as output:
        process = subprocess.Popen(args, cwd=ROOT, stdin=subprocess.DEVNULL,
                                   stdout=output, stderr=subprocess.STDOUT)
        try:
            while time.monotonic() - started < timeout:
                data = log.read_bytes()
                if b'AXIOM:KERNEL:READY' in data:
                    outcome = 'passed' if (all(m.encode() in data for m in MARKERS) and
                        data.count(b'AXIOM:SMP:AP:ONLINE') == cpus - 1) else 'missing-markers'
                    break
                if b'AxiomOS PANIC:' in data:
                    outcome = 'panic'
                    break
                if process.poll() is not None:
                    outcome = 'qemu-exited'
                    break
                time.sleep(0.1)
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    report = {'arch': arch, 'outcome': outcome, 'seconds': round(time.monotonic() - started, 2),
              'cpus_configured': cpus, 'command': args,
              'aps_observed': log.read_bytes().count(b'AXIOM:SMP:AP:ONLINE'),
              'markers': {m: m.encode() in log.read_bytes() for m in MARKERS}}
    (directory / 'qemu-result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'{arch}: {outcome}; log: {log}', flush=True)
    if outcome != 'passed':
        print(log.read_text(errors='replace')[-10000:])
        return 1
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--arch', choices=FIRMWARE, default='x86_64')
    parser.add_argument('--test', action='store_true')
    parser.add_argument('--timeout', type=int, default=120)
    parser.add_argument('--cpus', type=int, default=2)
    parser.add_argument('--graphic', action='store_true')
    args = parser.parse_args()
    raise SystemExit(run(args.arch, args.test, args.timeout, args.cpus, args.graphic))
