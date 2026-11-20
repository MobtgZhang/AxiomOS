# 内存管理与四级页表

内核内存子系统由三部分组成：`Memory.Physical` 有界物理页分配器、`Memory.Heap` 有界内核堆，以及 `Memory.Virtual`/`HAL.MMU` 的地址空间层。本文档说明地址空间层的页表结构与四架构差异；物理分配与堆的设计见源码头部注释与 `reports/axiomos.md`。

## 公共接口

`HAL.MMU` 为四个后端提供同一组操作：Create、Map_Page、Query_Page、Unmap_Page、Protect_Page、Activate、Destroy。所有后端都满足同一契约：

- Map_Page 以 4 KiB 为粒度；若上层命中 2 MiB 大页则按需分裂，分裂需要的新表页从调用者传入的分配器取得，失败即中止并保持既有路径不变。
- Create 在表页分配失败时回收已创建的根，返回 Out_Of_Memory，不留部分结构。
- Unmap 回收叶子 PTE 后，若上层表页变空则逐级回收；回收前完成对应 ISA 要求的 TLB 维护。
- Destroy 深度遍历并回收全部表页；内核自测断言回收后可用页数恢复原值。
- Query 沿各级行走，按叶级页长还原物理地址并解码权限位。

## 四级走查自测

`Kernel.Selftest` 中的 `AXIOM:MMU:LEVELS:PASS` 用四个分散的 4 KiB 映射驱动每个后端分配新的上层表并分裂 2 MiB 页，随后逐个 Query 比对物理地址与权限，最后 Destroy 并断言全部表页回收。所有虚拟地址保持在 Sv39 的 2^38 界限以下，使同一份 Ada 源码在四个 ISA 上都合法；在 x86-64 与 AArch64 上这些映射仍遍历全部四级（顶级索引相同是公共子集限制，见下文每架构说明）。

## 每架构实现

| 架构 | 翻译结构 | 虚拟地址界限 | 说明 |
| --- | --- | --- | --- |
| x86-64 | PML4/PDPT/PD/PT 四级 | 2^48 | 需要时分裂 2 MiB 叶；INVLPG 维护 TLB |
| AArch64 | EL1 四级（L0..L3） | 2^48 | 需要时分裂 2 MiB 叶；TLBI 维护 TLB |
| RISC-V64 | Sv39 三级（PGD/PMD/PTE） | 2^38 | 需要时分裂 2 MiB 叶；SFENCE.VMA 维护 |
| LoongArch64 | 内核自有 TLB 表项 + 三级软件走查 | 2^38 | Create 即急切构建 4 GiB / 4 KiB 恒等映射（约 2053 个表页），成本最高；refill 异常路径由内核维护 |

两个限制要如实说明：

1. 公共自测地址低于 2^38，因此在 x86-64/AArch64 上顶级索引恒为 0；四级结构本身被完整遍历，但"不同顶级索引"这一维度未在公共用例中覆盖。更高 VA 的支持由各后端的参数检查（`Virtual_Base >= 2**48` 或 `2**38`）限定。
2. LoongArch 后端的 Create 是急切式全映射，创建一个地址空间需要约 2053 个表页；x86-64/AArch64/RISC-V64 的 Create 只分配根与恒等目录。更换为惰式实现属于后续工作，当前成本在 QEMU 512 MiB 配置下可接受。

## 与内核其他部分的边界

- 用户地址空间、配额、零填充与事务回滚由 `Memory.Spaces` 承担；页表叶只经 HAL 修改。
- 用户根页表只在 BSP 上使用；AP 不访问用户根，这不能推广为同一地址空间多核并发的保证。
- W^X：可写与可执行不共存，开放执行权限前调用 ISA 的指令缓存维护接口。
