# AxiomOS 模块与架构边界

依据 `reports/axiomos.md`，本轮范围限定为四架构 UEFI 菜单与内核的管理子系统（内存、进程、作业、文件系统、设备，以及支撑它们的同步原语）。所有支持状态必须有构建、QEMU 或实机证据。

## 构建与依赖方向

`alr` 管理工程、原生 GNAT 和 GPRbuild；GPR 项目选择目标 Ada 编译器。交叉前端不是用 C 替代 Ada：四架构都必须实际编译相同的 Ada 公共内核。Python 仅用于构建编排、ELF/PE 检查和介质生成。汇编限定在 CPU 指令、ABI 入口、陷入和切换。

```text
boot/uefi -> firmware/uefi + boot/common -> Boot_Info v2
                                            |
                                            v
kernel/main -> memory, smp, scheduler, vfs, io, drivers, process, jobs, sync, syscall
                        |                            |
                        +----------> hal <-----------+
                                      |
                      arch/<isa> + platform/<machine>
```

公共算法不依赖 UEFI、MMIO 地址或 ISA 寄存器。UEFI 退出后，内核不得保留固件函数调用路径。硬件映射、启动次级 CPU 和用户态切换必须有真实硬件后端，单独的状态管理测试不能算硬件功能完成。

## 模块职责

- `boot/common`：固定布局交接协议、ELF64 校验、菜单状态与加载策略。
- `boot/uefi`：菜单交互、内核及 initramfs 加载、最终内存图与退出固件。
- `boot/uefi/axiomos-boot-handoff.*`：构造 Boot_Info，保留内核栈与最终内存图；EFI 入口位于 `boot/uefi/axiomos-boot-loader.adb`，通过目标编译器调用约定接入 `firmware/uefi`。
- `firmware/uefi`：UEFI 表、协议与调用约定；不包含内核管理策略。
- `kernel/memory`：物理区域和页所有权、受限物理地址分配、堆、用户映射/解除映射/改权及回滚；硬件表项交给 HAL。
- `kernel/smp`：CPU 拓扑、启动状态机、统一微秒超时及常驻 AP 工作邮箱；拓扑发现由 platform 负责，CPU 启动机制由 arch 负责。
- `kernel/scheduler`：每 CPU 有界运行队列与调度策略。
- `kernel/jobs`：作业控制块、后备队列、按优先级与页配额的作业调度、完成收集；作业经装载器绑定到进程。
- `kernel/sync`：票据自旋锁、带属主校验的互斥锁与有界信号量，泛型注入 HAL 原子原语（CAS/Fetch_Add/Pause），宿主测试可注入纯 Ada 替身。
- `kernel/vfs`：路径、文件对象、最长分量前缀挂载路由、嵌套卸载及打开引用、tmpfs、只读 ustar initramfs。
- `kernel/io`：带代次句柄、权限收缩复制、退出关闭、seek/stat、流式读写及设备 I/O。
- `kernel/drivers`：设备/驱动匹配、资源冲突、启动/停止回调、PCI 枚举和并发串行化 VirtIO 块驱动；停止须确认 DMA 静止。
- `kernel/process`：进程生命周期、地址空间、凭据与 ELF 用户映像。
- `kernel/syscall`：版本化调用号、参数验证和派发；各 ISA 陷入入口独立。
- `kernel/ipc`：有界消息与背压。
- `kernel/security`：用户区间验证、跨物理映射复制、W^X 与权限规则。
- `hal`：稳定的 CPU、原子、MMU、上下文、日志和 SMP 接口。
- `arch/<isa>`：对应 ISA 的接口实现和汇编。
- `platform/qemu-<isa>`：具体 QEMU 串口及 ACPI/设备树拓扑发现；不包含页表或特权切换实现。
- `runtime`：不依赖 libc/libgnat 的内存原语、panic 等最小支持。
- `tests/hosted`：真实公共 Ada 代码的边界、耗尽与错误路径测试。
- `scripts/build.py`、`elf.py`、`pe.py`：ELF、PE/COFF、交接布局及运行时依赖审计。
- `scripts/run-qemu.py`：从 UEFI 到用户异常及回收的硬件验收，日志保存在忽略的 `build/<isa>/`。
- `scripts/check-architecture.py`：检查公共目录无内联汇编/ISA 选择，四个架构有一致 HAL 后端集合。

## 顺序与验收

1. **工程骨架**：目录职责、接口归属、GPR 场景和跨架构工具链入口齐备。
2. **启动菜单**：四架构原生 EFI 映像；可选正常启动、自检和固件返回；加载独立 ELF 与 initramfs；退出 Boot Services 后运行 Ada 内核。
3. **内存**：真实 EFI 内存图导入，保留加载映像和交接区，分配/释放/对齐/OOM 验证；虚拟内存策略和硬件 MMU 验证分别记录。
4. **SMP**：拓扑、启动握手、超时、运行队列；实际 AP 启动、IPI 与锁竞争单独验收。
5. **文件系统/I/O/驱动**：initramfs、tmpfs、路径与句柄权限、驱动匹配和真实控制台输出；持久化块设备另行记录。
6. **用户态/内核态**：ELF 与系统调用验证；实际特权级切换、地址隔离和异常返回单独验收。

未经测试的硬件后端必须返回 `Unsupported` 或明确 panic，不能空实现返回成功。测试报告不能把宿主模拟通过写成四架构硬件已实现。

## 可复用接口

`HAL.MMU` 为四个后端提供 Create/Map_Page/Query_Page/Unmap_Page/Protect_Page/Activate/Destroy；`Memory.Spaces` 统一承担动态用户区间、配额、零填充和事务回滚。Create 的低地址 supervisor 恒等映射是当前启动契约，尚未实现通用高半区内核或任意内存规模支持。x86-64 后端是按需分裂的四级页表（PML4/PDPT/PD/PT），设计与各级验收见 memory.md。

`HAL.CPU` 原子原语覆盖 Exchange、CAS（`axiom_cas`）与 Fetch_Add（`axiom_fetch_add`），四架构分别以 lock cmpxchg/lock xadd、LDXR/STXR 循环、LR/SC 循环和 LL/SC 循环实现，供票据自旋锁、互斥锁与信号量使用。

`HAL.Counter` 仅提供目标计数器频率，`HAL.Clock` 统一转为微秒；x86 PIT/TSC、ARM CNTFRQ、RISC-V timebase/RHCT、LoongArch CPUCFG 留在 arch。`HAL.Secondary` 提供 Boot_CPU/Prepare/Start，`HAL.Discovery` 只返回平台拓扑；公共 SMP 逻辑不选择 ISA。

VFS 对 Storage.Volumes 使用统一的卷/文件对象，六种磁盘格式不依赖 ISA。驱动公共代码通过 Raw 和 HAL 执行 MMIO/屏障；PCI、VirtIO 是总线/设备协议，不属于 CPU 架构。具体串口地址与指令实现留在平台或 arch。

接口层次不表示所有原始设计目标已完成。当前实现范围、并发前提和未完成部分分别见 README、locking.md、filesystems.md 和 abi.md。
