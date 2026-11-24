---
id: T23
title: 同种子对战结果可复现
owner: dsh
status: done
branch: dsh/t23-determinism
worktree: ../亡魂王子-t23
allowed: [scripts/main.gd, scripts/unit.gd, scripts/swordsman.gd, scripts/squad.gd, scripts/presence.gd, scripts/beats.gd, tools/verify/determinism.sh]
forbidden: [shaders/, scripts/terrain.gd, scripts/sprite_factory.gd, docs/, tasks/, project.godot]
verify: tools/verify/verify.sh all
retry_limit: 2
max_minutes: 90
escalate_if: [需要改变战斗规则或数值才能复现, 需要改 allowed 以外的文件, verify.sh 的阈值看起来要改]
---

## 目标
同一个 `--seed` 跑两次无头对战，`RESULT` 必须完全一致（用时、胜负、剩余人数、stats）。现在不一致（T21 发现 seed 2 两次结果不同），这会让回归测试和平衡测试不可靠。

## 要做
1. 先写 `tools/verify/determinism.sh`：对 seeds 1,2,3 各跑两次 `godot --headless --path . -- --auto --quit_at=60 --quit_on_end --seed=N`，比较两次的 RESULT 行，不一致就打印差异并退出码 1。
2. 找出不确定性来源。常见嫌疑：`randf()` / `randi()` 用的全局随机源在不同时机被调用（例如特效、粒子、视觉抖动也消耗了同一个随机源）；`_process(delta)` 用的是真实帧时间（无头模式下帧时间不固定）；遍历 Dictionary 或 `units` 的顺序；浮点累计。
3. 修复原则：**不改变规则和数值**。推荐做法：模拟用固定步长（例如在无头验证模式下 `Engine.physics_ticks_per_second` / 固定 delta = 1/60，或者 `_simulate` 内部按固定步长累加执行），模拟逻辑用独立的 `RandomNumberGenerator`（由 `--seed` 初始化），视觉特效用另一个随机源。
4. 改完后 `tools/verify/determinism.sh` 通过，`tools/verify/verify.sh all` 通过（战斗阈值不变）。
5. 在报告里说明：找到的不确定来源、改了什么、对正常游玩（有窗口、可变帧率）有没有影响。

## 产物
- `tools/verify/determinism.sh`
- 修复后的脚本
- `reports/agents/T23.md`
