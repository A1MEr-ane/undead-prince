---
id: T86
title: 基础单局程序：attempts/single_battle（4 种亡灵 + 3 种守军、战区视角与地图界面、指挥）
owner: codex
status: queued
branch: codex/t86-single-battle
worktree: ../亡魂王子-t86
allowed: [attempts/single_battle/, tools/verify/single_battle.sh]
forbidden: [attempts/single_battle/terrain/, attempts/single_battle/style_frame/, assets/, tools/blender/, scripts/, proto/, shaders/, data/, docs/, tasks/, art/, project.godot]
verify: tools/verify/single_battle.sh
retry_limit: 3
max_minutes: 360
escalate_if: [需要改 allowed 以外的文件, 设计稿互相矛盾, 需要改变已定的玩法规则]
---

## 续做（2026-11-28）
上一轮做到一半就因为 Codex 额度用尽而中断，工作目录里保留了已经完成的部分。先检查现有文件，接着往下做，不要从头重来。

## 目标
用户已批准基础单局 v1，并通过了局内风格样张。本任务做单局的程序：一个独立的尝试版 demo，和原有路径分开。
- 地形由 T85 提供，放在 `attempts/single_battle/terrain/`。
- 正式小兵精灵由 T82 和之后的 DSH 批量任务提供，放在 `assets/sprites/units/`。
- 这两样到位之前，用样张里的临时精灵和 proto/siege 的灰盒地图，接口要留好，到位后能直接替换。

## 先读
- `docs/single-battle-v1.md`（全部）
- `docs/behavior-goals.md`
- `proto/siege/`：复制已经验证过的系统作为起点（冥火、部署、守军调度、战区视角、行为测试），复制后独立演化，不改原型
- `attempts/single_battle/style_frame/`：画风、着色器、光照

## 要做
1. **工程**：
   - 入口 `attempts/single_battle/main.tscn`，从 proto/siege 复制起步。
   - 无头模式和确定性沿用原型的做法；同种子跑两次结果必须一致。
2. **兵种**：按 single-battle-v1 第 2 节实现：
   - 4 种亡灵：骨堆重组、潜行背刺加崖壁、破城加横扫、冥火弹加眩晕。
   - 3 种守军：盾兵、弓兵、骑兵。
   - 每个兵种的数值放进参数文件。
3. **指挥**：
   - 兵种卡加长按部署、集结。
   - 狂化和虚弱两种法术都做，用参数切换，每局限 2 次。
4. **镜头和地图界面**：
   - 局内是单战区固定视角。
   - 地图界面（Tab 或按钮）显示全图、各战区战况和增援动向，点哪个战区就切过去。
5. **光照**：夜到黎明，时间就是 5 分钟倒计时；画风沿用样张。
6. **UI（功能版）**：兵种卡加冥火条、法术按钮、战区标签和提醒、胜负画面。按 `docs/ui-motion.md` 的原则，克制即可，不追求最终美术。
7. **测试**：
   - 把 proto 的 B01–B12 行为场景移植过来，加上 4 种亡灵各自的专属行为场景。
   - `tools/verify/single_battle.sh` 负责跑这些场景和确定性检查。
8. **接口**：
   - 地形：读 T85 的通行数据。
   - 精灵：读 `assets/sprites/units/<兵种>/` 的图集和 JSON（格式以 T82 的 `docs/unit-sprites.md` 为准；T82 还没出来时先自定一个，写进报告）。

## 交付
报告 `reports/agents/T86.md`，开头用 YAML 摘要。截不了图就写明，Lead 会补拍并请用户试玩。
