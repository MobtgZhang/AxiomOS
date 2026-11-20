# 作业管理

作业管理（经典五管理器中的 job management）由 `AxiomOS.Jobs` 提供，映射到现有进程模型上：作业是"已提交的程序 + 资源估计值"，由内核作业调度器按优先级录取，再由装载器绑定到进程执行。实现为纯 Ada、有界、静态：无分配器、无运行时，`Kernel.State` 持有全局 `Job_Table`。

## 模型

- **作业槽**：`Max_Jobs = 8` 个静态槽位。每槽携带状态机 `Empty → Held → Admitted → Running → Done`、代次（Generation）、优先级、类别（System/Interactive/Batch）、用户编号、页估计值、程序路径（≤31 字符）、工作进程 PID、退出码与启动失败标志。
- **代次**：`Job_Id = 0` 表示无作业；槽位复用时代次递增，携带旧编号的 Wait/Cancel 调用按失效句柄拒绝，不会命中新作业。
- **页预算**：`Set_Page_Limit` 配置全局预算（0 表示不限制）。Admit 预留估计页数，完成/失败/取消时归还；`Reserved_Pages` 查询当前预留量。

## 生命周期

1. **Submit**：把程序放入后备队列（Held）。队列满返回 Busy 类错误。
2. **Admit**：在 Held 作业中按"优先级最高、同级 FIFO"选择一个；预算不为 0 时，若该作业超过剩余预算则跳过（全部超预算返回 Out_Of_Memory，队列空返回 Not_Found）。返回程序路径与页估计值，状态转为 Admitted 并预留页数。
3. **Bind**：装载器把已录取作业绑定到一个进程 PID；绑定后状态为 Running。只接受 Admitted 状态与有效 PID。
4. **Complete / Fail**：进程正常退出以退出码 Complete（Done）；进程启动失败经 Fail 标记为 `Failed_To_Start`，Wait 时返回退出码 127。
5. **Wait**：收集 Done 作业的退出码并释放槽位，供下一代作业使用。
6. **Cancel**：只允许取消仍处于 Held 的作业；已录取/运行的作业先由进程路径结束。

## 验收

内核自测（`AXIOM:JOBS:PASS`，四架构 QEMU）与宿主测试覆盖同一语义：

- 优先级与同级 FIFO 录取顺序；页预算下的录取/拒绝（全超预算返回 Out_Of_Memory）。
- Bind 的忙冲突（同一槽重复绑定）与坏句柄（旧代次）拒绝。
- Complete 记录退出码 42；Fail 对应退出码 127；Cancel 只对 Held 生效。
- Wait 回收槽位后代次变化，旧句柄失效；Count 按状态统计正确。

宿主测试 `tests/hosted/test_jobs.adb` 用进程打桩验证同一包；内核自测在真实进程表上运行完整生命周期。当前没有抢占、阻塞等待或作业间通信：Wait 是非阻塞收集，等待策略属于调用者。页预算只约束录取时的预留，不强制运行中的进程内存用量。
