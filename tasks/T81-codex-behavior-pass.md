---
id: T81
title: 攻城原型行动逻辑修正（按 behavior-goals 第 1–3 节）
owner: codex
status: queued
branch: codex/t81-behavior
worktree: ../亡魂王子-t81
allowed: [proto/siege/, tools/verify/proto_siege.sh]
forbidden: [proto/siege/tests/, scripts/, shaders/, data/, docs/, tasks/, art/, assets/, project.godot]
verify: tools/verify/proto_siege.sh
retry_limit: 3
max_minutes: 300
escalate_if: [需要改变胜负规则或玩法设计, 需要改 proto/siege 以外的文件]
---

## 目标
用户决定：现阶段只解决行动逻辑。按 `docs/behavior-goals.md` 第 1–3 节，修正攻城原型里亡灵和守军的行为。**胜率不是目标**；同种子结果会因为行为修改而变化，这是预期的，只要求重放确定性（同种子两次逐字一致）。

## 已知问题（来源）
- 1.2 米站着不打（T49）
- 拼刀进度差没取绝对值、蛇形队列末行偏右（T61）
- 路线和目标耦合、拥堵口径（T68、T74 已部分处理）
- 守军派兵比例、任务锁定、撤退路线（T69、T74）
- 刺客捷径、巨人破墙的行为（T74）

## 要做
1. 逐条对照 behavior-goals 的第 1–3 节，先在报告里列出每条的现状：已满足、部分满足、未满足，以及原因。
2. 修正未满足的项。优先级：
   1. 站立超时
   2. 来回折返
   3. 拥堵化解
   4. 穿墙
   5. 守军派兵与任务锁定
   6. 兵种专属行为
   7. 撤退
3. DSH 正在并行写场景测试 B01–B12（T80，目录 `proto/siege/tests/`，你不要改这个目录）。如果 T80 先合并，用 `tools/verify/proto_behavior.sh` 自测；T80 列出的接口需求由你实现。
4. 每修一类问题，录一段窗口回放的逐帧截图到 `shots/t81/<问题>/`。截不了图就写明，由 Lead 补。

## 交付
报告 `reports/agents/T81.md`，开头用 YAML 摘要，并附上修改前后对照表。
