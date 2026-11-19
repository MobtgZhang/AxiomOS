# Boot_Info ABI v2

正式定义为 `boot/common/axiomos-boot-protocol.ads`。四种目标均采用小端、64 位固定宽度地址；记录大小 136 字节，对齐 8 字节。Ada representation clause 显式规定每个字段的字节偏移，编译每个目标时由 GNAT 检查。设计报告中的示意记录不是当前二进制协议。

```text
偏移  字节数  字段
0       8    Magic = 0x4158494F4D4F5331
8       4    Version = 2
12      4    Structure_Size = 136
16      8    Memory_Map
24      8    Memory_Map_Size（字节数）
32      8    Descriptor_Size（遍历步长）
40      4    Descriptor_Version
44      4    Flags（bit 0：诊断启动）
48      8    Initramfs_Base
56      8    Initramfs_Size
64      8    Kernel_Base
72      8    Kernel_Size
80      8    Stack_Base
88      8    Stack_Size
96      8    ACPI（RSDP 地址，可为 0）
104     8    Device_Tree（FDT 地址，可为 0）
112     8    Framebuffer_Base
120     8    Framebuffer_Size
128     8    Bootstrap_CPU
```

地址均为交接时的物理地址，尚未引入 higher-half 指针转换。内存图使用 UEFI 返回的 descriptor stride，不能将记录数组强制当成固定 40 字节间距。内核当前只把 EfiConventionalMemory 纳入分配器；loader、交接记录、最终内存图、内核、initramfs、栈及固件保留区域均不会作为空闲页回收。保留区的后续回收需要另行实现生命周期管理。

RISC-V 的 Bootstrap_CPU 来自退出固件前的 EFI_RISCV_BOOT_PROTOCOL.GetBootHartId；不能把固件留下的 tp 当成 hart ID。未知值为 U64'Last，RISC-V SMP 会核对该 ID 是否属于枚举的 CPU 集合。其他架构从本机 CPU 标识机制读取 BSP ID，当前不消费此字段。

加载器为内核准备 1 MiB 栈，栈顶按 16 字节对齐；关闭中断并通过各 ISA 的 handoff 汇编跳转。第一个参数是 Boot_Info 地址：x86-64 为 RCX（Microsoft x64 ABI），AArch64 为 X0，RISC-V 为 A0，LoongArch64 为 A0。内核不返回固件，不调用 Boot Services。UEFI Runtime Services 也尚未启用。

最终 GetMemoryMap 与 ExitBootServices 之间不分配、不输出日志。map key 失效时最多重试四次，首次退出尝试后只调用内存图与退出服务。缓冲预留 32 个 descriptor；仍不足时明确失败。ABI v2 不兼容 v1，加载器与内核须配套构建。
