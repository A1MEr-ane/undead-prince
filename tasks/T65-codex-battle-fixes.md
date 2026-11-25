---
id: T65
title: 战斗 bug 修复：1.2 米站立僵持、拼刀进度差、蛇形末行偏移
owner: codex
status: parked
branch: codex/t65-battle-fixes
worktree: ../亡魂王子-t65
allowed: [scripts/swordsman.gd, scripts/squad.gd, scripts/unit.gd, tests/test_battle_baseline.gd, tests/run_tests.gd]
forbidden: [scripts/main.gd, data/, docs/, shaders/, art/, assets/, tasks/]
verify: tools/verify/verify.sh all
retry_limit: 3
max_minutes: 150
escalate_if: [修复需要改玩法规则或 data/battles 的数值, 需要改 scripts/main.gd]
---

## 目标
DSH 的测试找到三个行为 bug，按规格修好。**不改平衡数值**：数值在 `data/battles/proto.json`，只读。

## 输入
- `reports/agents/T49.md`：9/30 局出现单位在约 1.2 米处站着不攻击的僵持，原始数据在 `reports/agents/T49-sweep.jsonl`。
- `reports/agents/T61.md`：
  - 拼刀进度差没有取绝对值（`swordsman.gd:335-336`）
  - 蛇形队列末行人数不满时整体偏右（`squad.gd:60-73`）
  - 报告里有最小复现
- 行为规格：`docs/badnorth-behavior-spec.md` 第 7、11 节。

## 要做
1. 用 T49 的僵持种子复现"1.2 米站立"，按规格第 7.4 节（备战）和 7.7 节（攻击）的出手距离找出原因并修复。
2. 修 T61 的两个 bug，并把 T61 测试里对应的 known issue 改成正常断言。
3. 同种子的结果会因为修 bug 而变化，这是预期的。`determinism.sh`（同种子两次一致）必须仍然通过。
4. 用 `tools/sim/batch.sh 50` 前后各跑一次，报告里对比胜率、用时、僵持局数。

## 交付
报告 `reports/agents/T65.md`，开头用 YAML 摘要。
