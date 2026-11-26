---
id: T73
title: 攻城原型性能优化（近邻查询、索敌、流场增量重算、调度尖峰）
owner: codex
status: done
branch: codex/t73-siege-perf
worktree: ../亡魂王子-t73
allowed: [proto/siege/, tools/verify/proto_siege.sh]
forbidden: [scripts/, shaders/, data/, docs/, tasks/, art/, assets/, project.godot]
verify: tools/verify/proto_siege.sh
retry_limit: 3
max_minutes: 240
escalate_if: [优化会改变战斗结果且无法证明只是浮点顺序差异, 需要改 proto/siege 以外的文件]
---

## 目标
T71 实测：自然对局足够，但 200 个单位时完整帧中位 29–86 毫秒，500 个单位 111–455 毫秒；破墙重算流场 55–113 毫秒，最坏 805 毫秒；500 个单位首次调度出现 340 毫秒尖峰。阶段 B、C 会有更多单位和极端构筑，所以先把瓶颈拿掉。详细数据见 `reports/agents/T71.md`，探针在 `proto/siege/perf/`。

## 要做（按 T71 的瓶颈排序）
1. 分离和近邻查询：均匀网格或空间哈希，每个逻辑步重建或增量更新。
2. 索敌：在空间哈希里查询，错峰评估（每个单位每 N 步评一次，N 进参数），保留目标滞后。
3. 破墙流场：只让受影响的流场失效。先用完整重算作为正确性基线，再做增量或分帧重算，两者的结果要一致。流场缓存设上限。
4. 守军调度：首次评估分帧进行，或预先算好，消除尖峰。
5. 不准为提速停掉镜头外单位的模拟。

## 验收
- `proto_siege.sh` 通过。确定性：同一个种子重放两次，结果逐字一致。
- 优化前后，同种子的胜负和主要统计在误差范围内一致；不一致就逐项解释原因。
- 用 T71 的探针重测 100、200、300、500 个单位，报告前后对比。目标是 300 个单位时完整帧中位低于 16.7 毫秒（这是目标，不是硬门槛）。

## 交付
报告 `reports/agents/T73.md`，开头用 YAML 摘要。
