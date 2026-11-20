# 安装与硬件支持现状

本文档如实说明 AxiomOS 当前可以在什么硬件上安装与运行，以及不能运行的原因。所有"支持"均以本仓库的验收证据为准（`docs/platform-support.md`）；没有证据的项一律列为"未支持"。

## 当前验收矩阵

| 硬件 | 状态 | 证据 |
| --- | --- | --- |
| QEMU x86-64（q35 + OVMF） | 已验证 | `scripts/run-qemu.py --arch=x86_64 --test` |
| QEMU AArch64（virt + AAVMF） | 已验证 | `--arch=aarch64` |
| QEMU RISC-V64（virt + EDK2 固件） | 已验证 | `--arch=riscv64` |
| QEMU LoongArch64（virt + EDK2 固件） | 已验证 | `--arch=loongarch64` |
| 实机（笔记本/台式机/开发板） | 未验证 | 无任何实机启动记录 |

## 为什么目前只支持 QEMU

内核的块设备层只实现了 **VirtIO Block** 一个驱动；输入、显示与图形同样只有 QEMU 设备模型。这些是 QEMU 平台专用设备，实机上并不存在：

- **存储**：实机 SATA 盘需要 AHCI 驱动，NVMe 盘需要 NVMe 驱动。二者都未实现，因此在实机上没有任何可用的根文件系统载体。
- **输入**：实机键盘/触控板需要 i8042（PS/2）、USB xHCI/EHCI HID 或 ACPI 按钮路径。内核没有 xHCI，也没有 PS/2 控制器驱动。
- **显示**：实机图形输出需要针对具体 GPU 的显示驱动或至少 VGA/EFI GOP 帧缓冲直写；当前输出依赖 QEMU 的 virtio/serial 控制台与 UEFI 串口。
- **平台细节**：实机固件差异（ACPI 表形态、PCIe BAR 分配、SMM/EL3 设置、非一致性 DMA 与 IOMMU、NUMA、MSI-X 中断）都没有经过测试；VirtIO 驱动依赖的一致性 DMA 在多数实机芯片组上不成立。

## 在 QEMU 中的安装方式

每个架构构建产物为：`build/<arch>/esp.img`（FAT，含 EFI 加载器与内核）与 `build/<arch>/root.ext4`（系统盘）。用 `scripts/build.sh --arch=...` 构建，`scripts/run-qemu.py --test` 运行；磁盘格式支持（EXT2/3/4、FAT16/32、NTFS 只读）由 `scripts/test-storage.sh` 的六种真实 mkfs 镜像验证。没有安装器、没有 GPT/MBR 分区自动识别、不支持写入磁盘——系统盘镜像由脚本预先生成。

## 要在实机运行需要补齐的工作（按最小路径估计）

1. xHCI 或 AHCI/NVMe 驱动之一（存储不可用则无法启动）。
2. PS/2 或 xHCI 键盘，或继续只用串口（需要外接串口线）。
3. 实机串口/UART 驱动与控制台（x86 需要 16550，AArch64 需要 PL011 等）。
4. 非一致性 DMA 的缓存维护或 IOMMU 支持。
5. 针对目标机型的 ACPI/拓扑实测，以及中断框架（当前 QEMU 平台的时钟与 IPI 路径是平台专用的）。

在这些驱动合入并取得实机启动证据之前，任何"可在真实笔记本安装"的说法都不成立。
