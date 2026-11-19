# AxiomOS 实现骨架

依据 `reports/axiomos.md`，本轮范围限定为四架构 UEFI 菜单与内核的六个管理子系统。所有支持状态必须有构建、QEMU 或实机证据。

## 构建与依赖方向

`alr` 管理工程、原生 GNAT 和 GPRbuild；GPR 项目选择目标 Ada 编译器。交叉前端不是用 C 替代 Ada：四架构都必须实际编译相同的 Ada 公共内核。Python 仅用于构建编排、ELF/PE 检查和介质生成。汇编限定在 CPU 指令、ABI 入口、陷入和切换。

```text
boot/uefi -> firmware/uefi + boot/common -> boot/handoff
                                            |
                                            v
kernel/main -> memory, smp, scheduler, vfs, io, drivers, process, syscall
                        |                            |
                        +----------> hal <-----------+
                                      |
                      arch/<isa> + platform/<machine>
```

公共算法不依赖 UEFI、MMIO 地址或 ISA 寄存器。UEFI 退出后，内核不得保留固件函数调用路径。硬件映射、启动次级 CPU 和用户态切换必须有真实硬件后端，单独的状态管理测试不能算硬件功能完成。

## 模块职责

- `boot/common`：固定布局交接协议、ELF64 校验、菜单状态与加载策略。
- `boot/uefi`：菜单交互、内核及 initramfs 加载、最终内存图与退出固件。
- `boot/handoff`：每 ISA 独立栈与入口约定。
- `firmware/uefi`：UEFI 表、协议与调用约定；不包含内核管理策略。
- `kernel/memory`：物理区域和页所有权、虚拟区间权限、堆；硬件页表交给 HAL。
- `kernel/smp`：CPU 拓扑、启动状态机与超时；CPU 实际启动由平台负责。
- `kernel/scheduler`：每 CPU 有界运行队列与调度策略。
- `kernel/vfs`：路径、文件对象、挂载语义、tmpfs、只读 ustar initramfs。
- `kernel/io`：带代次句柄、权限、偏移、流式读写及设备 I/O。
- `kernel/drivers`：设备与驱动匹配、资源冲突校验、生命周期；串口等驱动独立。
- `kernel/process`：进程生命周期、地址空间、凭据与 ELF 用户映像。
- `kernel/syscall`：版本化调用号、参数验证和派发；各 ISA 陷入入口独立。
- `kernel/ipc`：有界消息与背压。
- `kernel/security`：用户区间验证、W^X 与权限规则。
- `hal`：稳定的 CPU、原子、MMU、上下文、日志和 SMP 接口。
- `arch/<isa>`：对应 ISA 的接口实现和汇编。
- `platform/qemu-<isa>`：具体 QEMU 设备和 CPU 启动路径。
- `runtime`：不依赖 libc/libgnat 的内存原语、panic 等最小支持。
- `tests/hosted`：真实公共 Ada 代码的边界、耗尽与错误路径测试。
- `tests/abi`：ELF、PE/COFF、交接布局与运行时依赖审计。
- `tests/qemu`：从 UEFI 到退出固件后的日志证据。

## 顺序与验收

1. **工程骨架**：目录职责、接口归属、GPR 场景和跨架构工具链入口齐备。
2. **启动菜单**：四架构原生 EFI 映像；可选正常启动、自检和固件返回；加载独立 ELF 与 initramfs；退出 Boot Services 后运行 Ada 内核。
3. **内存**：真实 EFI 内存图导入，保留加载映像和交接区，分配/释放/对齐/OOM 验证；虚拟内存策略和硬件 MMU 验证分别记录。
4. **SMP**：拓扑、启动握手、超时、运行队列；实际 AP 启动、IPI 与锁竞争单独验收。
5. **文件系统/I/O/驱动**：initramfs、tmpfs、路径与句柄权限、驱动匹配和真实控制台输出；持久化块设备另行记录。
6. **用户态/内核态**：ELF 与系统调用验证；实际特权级切换、地址隔离和异常返回单独验收。

未经测试的硬件后端必须返回 `Unsupported` 或明确 panic，不能空实现返回成功。测试报告不能把宿主模拟通过写成四架构硬件已实现。
