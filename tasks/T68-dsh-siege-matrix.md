---
id: T68
title: 灰盒攻城原型的策略矩阵与参数扫描（T67 续）
owner: dsh
status: blocked   # 等 T67 合并后改成 queued
branch: dsh/t68-siege-matrix
worktree: ../亡魂王子-t68
allowed: [proto/siege/params/, reports/agents/]
forbidden: [proto/siege/*.gd, scripts/, docs/, tasks/, art/, assets/]
verify: proto/siege/run_matrix.sh --seeds 3
retry_limit: 3
max_minutes: 240
escalate_if: [需要改原型代码（转 Codex）, 找不到任何参数组合满足任一验证目标]
---

## 目标
用 T67 做好的原型和工具，回答"单场攻城好不好玩"的四个可量化问题。**只改参数文件，不改代码**；需要改代码就停下，写明交给 Codex。

## 要做
1. 默认参数下，5 个策略各跑 20 个种子，用 `run_matrix.sh` 出基线表。
2. 参数扫描：每轮只改 1–2 个参数，新参数文件放在 `proto/siege/params/`。优先扫这几项：
   - 冥火回复曲线（前期与黎明前的倍率）
   - 储存上限
   - 守军派兵延迟和驻防下限
   - 攻占所需秒数
   - 王国援军的规模
3. 目标（四条同时成立最好，做不到就找最接近的组合）：
   1. 至少 3 种策略胜率 ≥ 30%，赢法不同
   2. 挂机胜率比佯攻、分波低至少 15 个百分点
   3. "早期打掉高地弓兵"对比"不打"，后续胜率高至少 10 个百分点
   4. 拥堵指标不超过 T67 报告给出的可接受值
4. 每组结果附上同种子复跑检查（结果一致）。

## 交付
- `reports/agents/T68.md`，开头用 YAML 摘要。正文包括：基线表、最佳 3 组参数和它们的完整表、扫描过程的结论（哪个参数对哪个目标影响最大），以及哪些问题只能靠改机制解决。
- 最佳参数文件放进 `proto/siege/params/best_*.json`。
