---
id: T21
title: 多种子对战统计与平衡分析（只出报告）
owner: dsh
status: done
branch: dsh/t21-battle-stats
worktree: ../亡魂王子-t21
allowed: [reports/agents/T21.md]
forbidden: [scripts/, shaders/, docs/, tasks/]
verify: tools/verify/verify.sh battle --seeds 1,2,3,4,5,6,7,8,9,10
retry_limit: 1
max_minutes: 30
escalate_if: [需要改代码才能继续]
---

## 目标
进攻方（亡魂）在已跑过的 3 局里都在 15 秒内夺旗，怀疑偏强。用数据说明问题，给出原因假设，不改代码。

## 要做
1. 运行 `tools/verify/verify.sh battle --seeds 1,2,3,4,5,6,7,8,9,10`，结果 JSON 在 `reports/verify/` 最新文件。
2. 统计：胜率、夺旗用时（均值/最短/最长）、双方各队剩余人数、stats 里各事件（hit/parry/clash/pursue/fall/slide/death）的均值。
3. 阅读 `docs/units.md`、`docs/badnorth-behavior-spec.md` 第 7、12 节、`scripts/main.gd` 的 `_spawn_armies`、`scripts/swordsman.gd`，给出 3 个以内"进攻方为什么偏强"的假设，每个假设写清证据和可以验证它的实验（例如改哪个参数、预期结果）。
4. 只写报告，不修改任何代码。

## 产物
- `reports/agents/T21.md`：统计表 + 假设与实验建议。
