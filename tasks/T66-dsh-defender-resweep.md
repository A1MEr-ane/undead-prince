---
id: T66
title: 修复僵持后重跑守军参数扫描（T49 续）
owner: dsh
status: parked
branch: dsh/t66-defender-resweep
worktree: ../亡魂王子-t66
allowed: [scripts/squad.gd, scripts/main.gd, data/battles/, reports/agents/]
forbidden: [scripts/unit.gd, scripts/swordsman.gd, scripts/terrain.gd, shaders/, docs/, scripts/campaign/]
verify: tools/verify/verify.sh all
retry_limit: 2
max_minutes: 90
escalate_if: [所有参数组合都达不到目标区间, 需要改兵种数值或单位行为才能达到目标]
---

> **T66 说明（Lead 2026-11-26）**：T49 的机制已合并。Lead 决定：先由 Codex 修掉"1.2 米站立僵持"（T65），**不扩大 capture.time**。T65 合并后，用 `tools/sim/batch.sh --config` 按 T49 的 24 组网格重跑（每组 30 个种子），目标不变：守军夺旗用时中位 30–75 秒，攻方胜率 40–70%，僵持局数小于 5%。下面是 T49 原文，供参考。


## 目标
T21 的结论是进攻方 20 局全胜，平均 13.5 秒夺旗。主因有两个：
- 守军两群互不增援，旗点形成 18 打 8；
- 夺旗条件太宽松，不需要清理山腰的残兵。

本任务加一个最小的守方联动，把夺旗条件改成可配置，再用参数扫描找出落在目标区间的配置。
**不改兵种数值，不改单位行为。**

目标（Lead 设定，开局兵力打 `proto` 这种普通难度的岛）：
- 进攻方胜率 60–80%
- 夺旗用时中位数 30–75 秒

## 要做
1. **守方联动**（`squad.gd` 新增，`main.gd` 每 0.5 秒调用一次）：
   - 任一守方部队"交战"（有敌人进入其任一成员 4 米内）时，同阵营的其他守方部队，只要自身 4 米内没有敌人，且离旗点不超过 `reinforce_radius`，就移动到旗点周围的环形站位。
   - `reinforce_radius` 写进 `data/battles/*.json`，0 表示关闭（即现状）。
2. **夺旗条件**：在 T48 的 `capture` 配置里新增 `contest_pause`（布尔值）。
   - 开启时：旗点 `defender_radius` 内有守军，进度暂停，不衰减。
   - 关闭时：维持现状。
3. **参数扫描**：每组配置跑 30 个种子（1–30），`--quit_at` 改成 180。参数取值：
   - `reinforce_radius`：0、6、10
   - `defender_radius`：2.5、3.5
   - `capture.time`：3、6
   - `contest_pause`：false、true

   共 24 组。为每组生成 `data/battles/sweep_<编号>.json`，用 `--battle=` 运行。
4. 报告里给出一张表：每组的胜率、用时中位数和四分位、双方剩余人数。标出落在目标区间的组。
5. 推荐 1 组作为新的 `proto.json` 默认值，并把它写进 `proto.json`。

## 产物
- `squad.gd` 和 `main.gd` 的改动
- `data/battles/proto.json`（推荐值）
- 扫描用的 `data/battles/sweep_*.json`，合并前由 Lead 决定是否保留
- `reports/agents/T49.md`

## 验收
- [ ] `tools/verify/verify.sh all` 通过。verify 的 battle 检查用 `--quit-at 60`，如果新默认值的夺旗时间超过 60 秒，在报告里说明，不要改阈值
- [ ] 推荐配置在 30 个种子上的胜率落在 60–80%，用时中位数落在 30–75 秒
- [ ] `reinforce_radius=0`、`contest_pause=false`、其余参数取旧值时，结果和 T48 基线一致

## 交付报告
写到 `reports/agents/T49.md`。
