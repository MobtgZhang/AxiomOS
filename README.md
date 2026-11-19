# AxiomOS

以 Ada 2022 为主体的独立操作系统，采用 Alire → GPRbuild → GNAT 工具链。四个 QEMU 平台为 x86-64/q35、AArch64/virt、RISC-V64/virt、LoongArch64/virt。工程规范见 [设计报告](reports/axiomos.md)，分层与目录职责见 [架构](docs/architecture.md)。

目前可运行的完整链路：原生 UEFI PE32+ 菜单 → 独立 Ada 内核 ELF → ExitBootServices → 物理页/堆管理 → VirtIO Block → EXT4 根文件系统 → 多核启动及锁竞争 → 内核自有页表 → 静态 Ada 用户程序 → 系统调用 → 故意越权访问并回收进程。四个平台分别生成机器码，不依赖 Linux 内核运行。

FAT16、FAT32、NTFS、EXT2、EXT3、EXT4 已接入公共 Ada 存储/VFS 层，当前磁盘挂载为**只读**，tmpfs 可写；默认根文件系统为 EXT4。具体支持特性和限制见 [文件系统说明](docs/filesystems.md)。

## 构建与启动

依赖和固定工具链见 [工具链说明](toolchains/README.md)。在仓库目录运行：

```sh
alr -n build
alr -n run
scripts/build.sh --arch=all
python3 scripts/run-qemu.py --arch=x86_64 --cpus=4 --test
python3 scripts/run-qemu.py --arch=aarch64 --cpus=4 --test
python3 scripts/run-qemu.py --arch=riscv64 --cpus=4 --test
python3 scripts/run-qemu.py --arch=loongarch64 --cpus=4 --test
scripts/test-storage.sh
# 依次执行宿主测试、六种存储测试、四架构构建及四核 QEMU 验收
scripts/test.sh
```

`--arch` 也接受单一架构。QEMU 不加 `--test` 时保留运行；加 `--graphic` 显示固件窗口。启动菜单支持上下键、Enter 和数字 1/2/3，五秒后默认启动。构建生成 `build/<arch>/esp.img` 和 `root.ext4`；测试保存串口日志与 JSON 结果。`build/` 为生成目录。

统一测试入口可指定 `--arch=<架构>`、`--cpus=<核数>`、`--timeout=<秒>`；`--host-only` 仅运行宿主算法与磁盘镜像测试。硬件测试还检查 0–4 页预算下的页表创建失败回滚，以及用户进程退出/隔离异常后的页数回收。

二进制交接协议见 [Boot_Info ABI v2](docs/boot-info.md)，用户陷入约定和已实现调用见 [用户态 ABI v1](docs/abi.md)。
已验证的平台及检查项见 [平台验收记录](docs/platform-support.md)，并发前提与资源回收约定见 [并发说明](docs/locking.md)。

如果宿主 `/tmp` 配额不足，先创建 `build/tmp`，运行宿主 Alire 命令时设置 `TMPDIR="$PWD/build/tmp"`；裸机构建和存储测试脚本已自动设置。

## 当前边界

这是可启动、可验证的内核实现，尚未完成原设计范围内的全部功能：尚无抢占式线程调度、完整中断设备框架、跨核 IPI/TLB shootdown、磁盘写入与日志恢复、完整挂载命名空间或生产级驱动支持。AP 启动和共享锁压力测试结束后进入停止等待；用户程序在 BSP 顺序运行。`spawn/map/ipc/thread` 等未实现的系统调用返回 Unsupported。用户态 Ada 运行时仅支持当前静态程序需要的子集。

当前验收针对固定 QEMU/UEFI 组合；未进行实机验收。不要把“编译通过”当成硬件支持，也不要把只读挂载当成完整文件系统读写支持。

包名保留 `AxiomOS` 根命名空间，文件名遵循 GNAT 默认规则。公共策略位于 `kernel/`，ISA 机制位于 `arch/`，板级设备位于 `platform/`；不使用自定义短文件名映射。
