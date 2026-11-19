# 平台验收记录

验收环境为 QEMU + EDK2/OVMF 固件，512 MiB 内存，每架构 4 个虚拟 CPU。当前实现已通过从 UEFI 到隔离用户程序的验收；尚未达到设计报告的 kernel-ready 完整条件，因为抢占式线程、完整中断/计时器框架等仍未完成。没有实机验证证据，也没有自动 CI 服务。

四个已验证目标：

- x86-64：q35，OVMF，xAPIC INIT/SIPI 启动 AP，四级页表，Ring 3 + int 0x80。
- AArch64：virt/cortex-a72，AAVMF，ACPI MPIDR + PSCI 启动 AP，EL1 页表，EL0 + SVC。
- RISC-V64：virt，EDK2 RISC-V 固件，EFI boot hart ID + SBI HSM，Sv39，U-mode + ECALL。
- LoongArch64：virt，EDK2 LoongArch 固件，ACPI CorePIC + IOCSR mailbox/IPI 启动 AP，内核自有页表及 refill 路径，PLV3 + SYSCALL。

每个目标分别通过 GNAT 编译公共 Ada 源码及目标后端，生成各自的 EFI PE32+、独立内核 ELF、静态用户 ELF、FAT ESP 与 EXT4 系统盘。ELF 机器类型、重定位与未解析运行时依赖在构建阶段检查。

共同检查项为：UEFI 菜单自动启动、ExitBootServices、真实内存图导入、物理页/堆读写、页表创建 OOM 回滚、VFS/句柄权限、现代 VirtIO PCI 块读取、EXT4 根挂载、三个 AP 握手和锁竞争、自有硬件页表、用户态 Ada 程序、文件系统调用、内核地址访问拒绝、隔离异常终止与物理页回收。

复现入口为 `scripts/test.sh`，可用 `--arch=<架构>` 限定平台。每次运行保存 `build/<arch>/qemu-boot.log` 和 `qemu-result.json`；JSON 包含 QEMU 命令、CPU 数、观测到的 AP 数、检查标记及最终结果。修改源代码后需要重新构建再运行，旧日志只代表生成它时的映像。

磁盘格式解析另外通过宿主 Ada 程序读取六种真实 mkfs 镜像验证。该测试证明公共解析器的所测功能；不能据此扩大为所有特性、可写卷、任意硬件或固件兼容保证。具体限制见 `filesystems.md`。
