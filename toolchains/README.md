# 工具链与运行环境

主要构建入口是 `alr`，`alire.toml` 固定原生 GNAT 16.1.0 和 GPRbuild 26.0.1。`scripts/build.sh` 始终在 Alire 环境下调用 GPRbuild；`.gpr` 决定公共 Ada 源码和架构 body，汇编只提供 CPU/平台机制。Python 负责构建、ELF/PE 检查与镜像生成。

宿主需要 `python3`、`gcc`、`binutils`、`dosfstools`、`mtools`、`e2fsprogs`、`ntfs-3g`，以及四个 `qemu-system-*`。存储测试需要 `mkfs.fat`、`mkfs.ext2/3/4`、`mkfs.ntfs`、`ntfscp`。

交叉目标使用 GCC 15.2：`aarch64-linux-gnu-gcc`、`riscv64-linux-gnu-gcc`、`loongarch64-linux-gnu-gcc` 和对应 binutils。`scripts/setup-cross.sh` 可把缺失的 Ada 前端提取到本地 `.toolchains/cross`，不更改系统安装；具体包固定版本见脚本。已有系统 gnat1 时优先使用系统前端。目标以 freestanding 子集编译，不链接 Linux libc 或系统 libgnat。

已使用的 UEFI 固件路径在 `scripts/run-qemu.py` 中集中定义：OVMF、AAVMF、RISC-V EDK2、LoongArch EDK2。可以用 `AXIOM_UEFI_CODE` / `AXIOM_UEFI_VARS` 指定兼容固件。测试时复制变量模板，每次独立启动。

构建不会依赖 EFI stub 或 GRUB。`toolchains/image.ld` 用于独立 PIC EFI 中间 ELF 与内核 ELF，`scripts/pe.py` 生成各机器类型 PE32+ 及重定位。`toolchains/user.ld` 用于各 ISA 静态用户 ELF。链接强制拒绝未解析的运行时符号。

x86-64 的固件和裸机 Ada 使用 Microsoft x64 ABI；宿主测试使用原生 ABI，二者对象目录分离。ARM/RV/LA 各自使用本机 ABI；RISC-V freestanding Ada 使用 lp64 整数 ABI。所有目标基础页为 4096 字节。
