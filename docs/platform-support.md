# 平台验收记录

验收环境为 QEMU + EDK2/OVMF 固件，512 MiB 内存，每架构 4 个虚拟 CPU。当前实现已通过从 UEFI 到隔离用户程序的验收；尚未达到设计报告的 kernel-ready 完整条件，因为抢占式线程、完整中断/计时器框架等仍未完成。没有实机验证证据，也没有自动 CI 服务。

四个已验证目标：

- x86-64：q35，OVMF，xAPIC INIT/SIPI 启动 AP，四级页表，Ring 3 + int 0x80。
- AArch64：virt/cortex-a72，AAVMF，ACPI MPIDR + PSCI 启动 AP，EL1 页表，EL0 + SVC。
- RISC-V64：virt，EDK2 RISC-V 固件，EFI boot hart ID + SBI HSM，Sv39，U-mode + ECALL。
- LoongArch64：virt，EDK2 LoongArch 固件，ACPI CorePIC + IOCSR mailbox/IPI 启动 AP，内核自有页表及 refill 路径，PLV3 + SYSCALL。

每个目标分别通过 GNAT 编译公共 Ada 源码及目标后端，生成各自的 EFI PE32+、独立内核 ELF、静态用户 ELF、FAT ESP 与 EXT4 系统盘。ELF 机器类型、重定位与未解析运行时依赖在构建阶段检查。

共同检查项包括：

- UEFI 菜单自动启动、ExitBootServices、真实内存图、物理页/堆读写及统一单调时钟。
- 页表根创建 OOM 回滚、动态叶映射在 0/1/2 个表页预算下的失败/成功/回收，自有硬件页表。
- 三个 AP 启动、两轮共享锁任务、邮箱 Busy/旧票据拒绝、Wait 超时后完成收取。
- VirtIO 块读取、设备停止确认/三页 DMA 回收/重启、BSP 与各 AP 同时读取同一扇区并比对。
- EXT4 默认根、VFS/句柄权限、用户匿名内存零填充、重映射清零、W^X/对齐/重叠拒绝、跨映射用户复制。
- 用户态 tmpfs 文件写入、带符号 seek、长度查询、权限收缩复制/独立游标、旧句柄拒绝及退出后解除挂载。
- 三个独立用户异常程序：写 supervisor 地址、写只读用户页、写已解除映射页；分别核对异常地址，并检查进程资源回收。

完整验收标记由 `scripts/run-qemu.py` 的 MARKERS 定义；缺少任一标记或 AP 数量不符都会失败。源码边界由 `scripts/check-architecture.py` 检查，不能代替运行证据。

复现入口为 `scripts/test.sh`，可用 `--arch=<架构>` 限定平台。每次运行保存 `build/<arch>/qemu-boot.log` 和 `qemu-result.json`；JSON 包含 QEMU 命令、CPU 数、观测到的 AP 数、检查标记及最终结果。修改源代码后需要重新构建再运行，旧日志只代表生成它时的映像。

磁盘格式解析另外通过宿主 Ada 程序读取六种真实 mkfs 镜像验证。该测试证明公共解析器的所测功能；不能据此扩大为所有特性、可写卷、任意硬件或固件兼容保证。具体限制见 `filesystems.md`。

本轮验证使用 `scripts/build.sh --arch=all`、`alr -n run`、`scripts/test-storage.sh`，四架构分别通过 `--cpus=4 --test` 和 `--cpus=1 --test`，共八次启动验收，每次通过 27 项标记检查。单核补测覆盖没有 AP 时的空任务集合路径，不表示执行了 AP 并发工作。单核与四核结果分别另存为 `build/<arch>/qemu-1cpu-result.json`、`qemu-4cpu-result.json`，对应日志为 `qemu-1cpu-boot.log`、`qemu-4cpu-boot.log`。测试只验证这些有界场景，尚未包含抢占调度、跨核用户页表、磁盘写入、断电恢复或实机压力测试。
