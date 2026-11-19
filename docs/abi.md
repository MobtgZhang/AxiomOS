# 用户态 ABI v1

调用号由 `kernel/syscall/axiomos-syscall.ads` 定义；Ada 用户入口为 `libs/sysapi/sysapi.ads`。当前裸机陷入接口支持调用号和三个 64 位参数。成功返回非负值；错误返回 `-(Status'Pos + 1)` 的 64 位补码。状态枚举取自 `AxiomOS.Types`，变更顺序需要更新 ABI。

四种陷入约定分别为：

- x86-64：`int 0x80`，RAX 为调用号，RDI/RSI/RDX 为参数，RAX 返回结果。
- AArch64：`svc #0`，X8 为调用号，X0/X1/X2 为参数，X0 返回结果。
- RISC-V：`ecall`，A7 为调用号，A0/A1/A2 为参数，A0 返回结果。
- LoongArch64：`syscall 0`，A7 为调用号，A0/A1/A2 为参数，A0 返回结果。

`Sysapi.Call` 使用各目标的 Ada/C 函数调用约定，经汇编转换为上述陷入寄存器；x86-64 的普通裸机函数调用使用 Microsoft x64 ABI。不能把普通函数调用寄存器与系统调用寄存器混用。

已实现的调用：

- 0 Exit_Process(code)：退出当前进程，关闭句柄，转为 zombie。
- 1 Read(handle, address, length)：验证用户写权限，读取最多 4096 字节。
- 2 Write(handle, address, length)：验证用户读权限，写入最多 4096 字节。
- 3 Open(path_address, path_length, rights)：路径最长 127 字节；rights bit 0 为读，bit 1 为写。路径不包含尾 NUL。
- 4 Close(handle)：关闭带代次的句柄，旧句柄不能重用。
- 6 Wait(child_pid)：只允许父进程回收 zombie，尚未退出时返回 Would_Block。

其余已分配调用号为 Spawn=5、Map=7、Unmap=8、IPC_Send=9、IPC_Receive=10、Clock_Get=11、Thread_Yield=12，当前均返回 Unsupported。不能根据存在枚举或公共数据结构宣称硬件路径已实现。

内核当前在 BSP 顺序运行静态 Ada ELF。每个用户进程使用独立硬件页表，内核页为 supervisor，用户代码不可写、用户数据与栈不可执行。用户复制要求整个缓冲位于单个连续的已登记映射；跨映射复制尚未实现。当前没有地址随机化、动态链接、完整 Ada 任务或异常运行时。
