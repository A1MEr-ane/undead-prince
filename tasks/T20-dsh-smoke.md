---
id: T20
title: DSH 能力冒烟测试
owner: dsh
status: queued
branch: dsh/t20-smoke
worktree: ../亡魂王子-t20
allowed: [reports/agents/T20.md]
forbidden: [scripts/, shaders/, docs/, tasks/, AGENTS.md, CLAUDE.md]
verify: tools/verify/verify.sh parse
retry_limit: 1
max_minutes: 15
escalate_if: [任何一步不可用]
---

## 目标
实测 DeepSeek Harness 在本项目里能做什么，结果决定以后给它派哪些活。

## 要做（每一步都如实记录成功/失败和原始输出，不要猜）
1. 用 bash 运行 `godot --version`、`blender --version | head -1`、`git --version`。
2. 运行 `tools/verify/verify.sh parse`，报告结果。
3. 运行 `godot --path . -- --zoom=8 --yaw=35 --focus=12,12.5 --out=$PWD/shots/t20 --shots=3` 截一张游戏图（会开一个窗口几秒）；如果失败，记录错误。
4. 查看 `shots/t20/shot_0.png`（如果第 3 步失败，就看仓库外的 `../亡魂王子/shots/m2/overview.png`），用两三句话描述画面：地形、单位、颜色。如果你的工具无法查看图片，明确写"无法看图"。
5. 在分支 `dsh/t20-smoke` 上提交一个空提交（`git commit --allow-empty -m "test: dsh commit check"`），报告能否提交。
6. 报告你使用的模型名、本次大约用了多少 token（如果能看到）。

## 产物
- `reports/agents/T20.md`：每一步一行"可用/不可用 + 证据"。
