# 用户态 ABI v1

调用号由 `kernel/syscall/axiomos-syscall.ads` 定义；Ada 用户入口为 `libs/sysapi/sysapi.ads`。陷入接口支持调用号和三个 64 位参数。成功返回非负值；错误返回 `-(Status'Pos + 1)` 的 64 位补码。状态枚举取自 `AxiomOS.Types`，变更顺序需要更新 ABI。

## 陷入约定

- x86-64：`int 0x80`，RAX 为调用号，RDI/RSI/RDX 为参数，RAX 返回。
- AArch64：`svc #0`，X8 为调用号，X0/X1/X2 为参数，X0 返回。
- RISC-V：`ecall`，A7 为调用号，A0/A1/A2 为参数，A0 返回。
- LoongArch64：`syscall 0`，A7 为调用号，A0/A1/A2 为参数，A0 返回。

`Sysapi.Call` 经汇编把目标函数调用约定转换为陷入寄存器。x86-64 普通裸机函数调用使用 Microsoft x64 ABI，与上述系统调用寄存器不同。用户入口清空通用寄存器，提供独立栈；本版本不提供浮点/SIMD 上下文隔离契约。

## 已实现调用

- 0 Exit_Process(code)：关闭全部句柄，记录退出码，转为 zombie。
- 1 Read(handle, address, length)：验证用户写权限，读取最多 4096 字节。
- 2 Write(handle, address, length)：验证用户读权限，写入最多 4096 字节。
- 3 Open(path_address, path_length, rights)：路径最长 127 字节，不含尾 NUL；rights bit 0 为读，bit 1 为写。打开已有文件或字符设备，不创建文件。
- 4 Close(handle)：关闭带代次句柄，旧句柄失效。
- 6 Wait(child_pid)：仅父进程可回收 zombie；尚未退出返回 Would_Block。
- 7 Map(address, length, permissions)：分配清零匿名用户内存，返回 address。权限 bit 0/1/2 为读/写/执行，必须可读，禁止 W+X。
- 8 Unmap(address, length)：解除一条完整动态映射并回收页，返回 0。
- 11 Clock_Get()：返回内核启动时钟基点后的单调微秒值。跨核使用需目标计数器同步，当前验收范围是 QEMU。
- 13 Protect(address, length, permissions)：修改一条完整动态映射的权限，返回 0；W^X 规则同 Map。
- 14 Seek(handle, offset, origin)：offset 为有符号 64 位二进制补码，origin 0/1/2 表示文件首/当前位置/文件尾；返回新偏移。仅普通文件支持，禁止负位置及超出 I64 最大值。
- 15 Stat_Length(handle)：返回文件长度。
- 16 Duplicate(handle, rights)：复制句柄，权限只能收缩；新句柄从当前偏移开始，之后偏移独立，不采用 POSIX dup 的共享游标语义。

Spawn=5、IPC_Send=9、IPC_Receive=10、Thread_Yield=12 返回 Unsupported。没有实现这些接口的硬件调度或阻塞唤醒路径。

## 内存及执行限制

动态区域为 `[0x10_0000_0000, 0x10_1000_0000)`；起址与长度均须 4 KiB 对齐，单次最多 1 MiB，每进程动态提交最多 16 MiB。Unmap/Protect 必须精确匹配原 Map 范围，不做部分拆分；ELF 和用户栈不可用这两个调用修改。空间最多登记 128 条映射。分配与表页失败均回滚。

Read/Write 先验证整个用户范围，再复制；缓冲可跨相邻映射及不连续物理页。Read 无效目标缓冲在消费文件偏移前被拒绝。实际实现只在 BSP 顺序运行静态 Ada ELF，每个进程使用独立硬件页表；内核页 supervisor、代码不可写、用户数据和栈不可执行。越权异常终止当前进程并回收资源；内核异常进入 panic。

当前没有地址随机化、动态链接、抢占式用户线程、完整 Ada 任务/异常运行时或浮点/SIMD 上下文管理。多核工作接口用于内核回调，不是用户线程调度。
