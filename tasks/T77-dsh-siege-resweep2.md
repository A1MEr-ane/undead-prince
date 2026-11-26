---
id: T77
title: 攻城原型第二轮矩阵（T74 之后）：目标 3、4 复测 + 阶段 B 新策略对照
owner: dsh
status: queued
branch: dsh/t77-siege-resweep2
worktree: ../亡魂王子-t77
allowed: [proto/siege/params/, reports/agents/]
forbidden: [proto/siege/*.gd, scripts/, docs/, tasks/, art/, assets/]
verify: proto/siege/run_matrix.sh --seeds 3
retry_limit: 3
max_minutes: 300
escalate_if: [需要改原型代码（转 Codex）]
---

## 目标
沿用 T68 的方法和四个目标（见 `tasks/T68-dsh-siege-matrix.md` 与 `reports/agents/T68.md`），在 T74 之后重跑。
1. 基线：T68 最佳的 3 组参数，加上默认参数，8 个策略各跑 20 个种子（原 6 个，加"刺客先手""巨人破墙"）。
2. 目标 3：用解耦后的参数做配对比较。同一路线下，开或关早期弓兵优先，后续胜率差多少。
3. 目标 4：用新的拥堵口径重新评估。
4. 阶段 B 对照：在同样的冥火总投入下，比较"刺客先手""巨人破墙"和"不做准备的分波"。报告胜率差、胜利用时、战损。
5. 只改参数文件；需要改代码就停下，交给 Codex。自动数据只是诊断，不下"好玩"的结论。

## 交付
`reports/agents/T77.md`，开头用 YAML 摘要。
