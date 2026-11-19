# 存储与文件系统

默认启动布局为 FAT ESP + 独立 EXT4 系统盘。固件从 ESP 读取原生 EFI 应用、内核 ELF 和救援 initramfs；退出 Boot Services 后，Ada VirtIO 驱动读取系统盘，VFS 挂载 EXT4，用户 ELF 和 `/etc/motd` 从 EXT4 读取。系统盘挂载失败会明确 panic，不会用 initramfs 冒充 EXT4 启动。

## 模块边界

- `Drivers.PCI`：MCFG/ECAM 枚举及 VirtIO PCI 能力结构。
- `Drivers.Virtio_Block`：现代 VirtIO PCI、split virtqueue、DMA 缓冲、同步超时和扇区读取。
- `Storage`：带长度和基址的块设备视图，统一字节范围检查。
- `Storage.Endian` / `Storage.Checksums`：有界小端字段读取、名字比较、CRC32C。
- `Storage.FAT`：BPB、簇链、FAT16 固定根目录、FAT32 簇根目录、8.3/LFN。
- `Storage.Ext`：超级块、组描述符、inode、目录、直接/三级间接块、EXT4 extent 树、稀疏数据。
- `Storage.NTFS`：卷参数、MFT、USA 修复、属性、驻留/非驻留数据、带符号数据运行表、目录索引和分配位图。
- `Storage.Volumes`：格式识别、逐分量路径查找、统一读取接口。
- `VFS.Mounts`：根挂载、磁盘 inode 缓存、只读权限、与 tmpfs/控制台节点结合。
- `IO.Handles` / `IO.Streams`：句柄代次、权限、偏移与实际流读取。

磁盘文件按需读取，不复制进 tmpfs；文件读取不受 tmpfs 的 32 KiB 上限限制。当前静态用户 ELF 装载缓冲仍限制为 32 KiB，VFS 文件大小上限为 `Natural'Last`，节点缓存 64 个。上限耗尽必须返回错误。

## 当前实现边界

六种磁盘格式当前均为**只读实现**；tmpfs 可写。没有实现磁盘分配/释放、文件创建删除、日志提交或断电恢复，不能据此宣称完整可写文件系统。EXT3/4 需要干净的文件系统，需恢复日志的卷会拒绝挂载；NTFS dirty 卷同样拒绝。磁盘写入与日志重放需要独立的事务设计和故障注入验收。

FAT 支持 FAT16/FAT32（不支持 FAT12/exFAT），短文件名与 ASCII LFN，读取簇链有上限；尚未实现完整 Unicode 名称转换。NTFS 支持 ASCII 路径、不分大小写比较、普通未压缩未加密数据、稀疏 run；拒绝扩展属性列表和压缩/加密属性；不实现重解析点、硬链接管理、命名流、NTFS 日志恢复或完整 `$UpCase` Unicode 语义。非驻留目录索引通过位图筛选有效 INDX 页，目前采用有界扫描。

EXT2/3 支持直接及单/双/三级间接寻址。EXT4 支持至 4 KiB 块、64bit 描述符、flex_bg、metadata_csum_seed、extent 树及未初始化 extent 零读取。启用 metadata_csum 时检查超级块、组描述符、inode、extent 索引块与普通目录块校验和；文件数据本身没有额外校验。索引目录、bigalloc、加密、inline data、meta_bg 等未实现布局明确返回 Unsupported。普通路径不跟随符号链接。

当前 QEMU 使用独立原始文件系统镜像作为整块系统盘，没有实现 GPT/MBR 分区自动选择。PCI 后端针对四个 QEMU 根总线平台，现代 VirtIO Block；不承诺任意 PCI 桥、多功能设备、NVMe/SATA、IOMMU 或非一致性 DMA 硬件。设备队列当前单请求同步轮询，不能在多个 CPU 并发调用。

## 验证入口

`python3 scripts/make-fs-fixtures.py` 使用系统 mkfs 工具产生六种真实镜像；`scripts/test-storage.sh` 经 Alire/GPRbuild 编译并运行 Ada 测试。覆盖空文件、长文件名、普通与嵌套目录、NTFS 分配目录索引、400000 字节文件跨块/不同偏移、EOF、路径逃逸、VFS 权限、越界和截断设备。测试使用与内核相同的 Ada 解析器。

`scripts/build.sh --arch=all` 构建每架构独立 EXT4 系统盘；`scripts/run-qemu.py --arch=<arch> --test` 检查从 UEFI 到磁盘根文件系统、用户态系统调用与隔离异常的日志。

镜像测试另覆盖 1 MiB 交替数据/空洞文件、EXT4 外部 extent 节点、FAT 簇链自循环、EXT4 超级块校验和损坏和 NTFS torn-sector 拒绝。FAT/NTFS 测试文件的零区域也要返回相同内容，但镜像工具不一定把这些零区域编码为稀疏分配。
