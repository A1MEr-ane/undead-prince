---
id: T64
title: T45 前置：Blender 精灵管线端到端小规模验证
owner: dsh
status: queued
branch: dsh/t64-sprite-e2e
worktree: ../亡魂王子-t64
allowed: [tools/blender/, assets/sprites/e2e/, reports/agents/, shots/]
forbidden: [scripts/, data/, docs/, shaders/, art/, assets/sprites/k2_*]
verify: blender -b --factory-startup --python-exit-code 1 -P tools/blender/validate.py
retry_limit: 3
max_minutes: 150
escalate_if: [需要改 allowed 以外的文件, 需要改玩法、剧情、美术方向或正式平衡参数, 疑难工程问题（转 Codex）]
---

## 目标
在正式批量做新兵种精灵（T45）之前，用**现有**素材把整条管线小规模跑通一次，找出会卡住批量生产的问题。**不改现有盾兵产物，不改游戏代码。**

## 先读
`docs/sprite-pipeline.md`、`tools/blender/chibi_body.py`、`build_shieldman.py`、`render_sprites.py`、`validate.py`、`assets/specs/k2_shieldman.yml`。

## 要做
1. 用 `chibi_body.py` 的现有模板，复制出一个**测试兵种**（例如换装备比例的"普通亡魂"占位：骷髅头、短剑、圆盾，配色用亡魂阵营），只用于验证，输出到 `assets/sprites/e2e/`。
2. 走完全流程：建模 → 骨骼动画（沿用现有 11 个动作）→ 渲染 UV 图集和部位贴图 → 导出 JSON → `validate.py` 通过。
3. 游戏接入只做验证：写一个独立的 Godot 测试脚本或场景（放在 `assets/sprites/e2e/` 下），用现有着色器加载这套图集，截图到 `shots/t64/`。不改 `scripts/main.gd`。
4. 记录每一步的耗时、失败点和手工步骤，按"能否无人值守批量跑"打分。
5. 报告里列出批量生产 T45 前必须修的管线问题；疑难问题 handoff codex。

## 验收
- `validate.py` 对 e2e 产物通过
- 有游戏内截图（截不了就写明原因）
- 报告里有"批量化阻碍清单"

## 通用要求
- 开工前先看现有代码、`tests/`、`tools/`、`TASKS.md`，**已有的功能不要重做**，只补缺口；报告里列出"已有 / 新增"。
- 能用本地脚本判断对错的，写成脚本；不要改玩法、剧情、美术方向和正式平衡参数（`data/battles/proto.json` 里的数值只读）。
- 常规问题自己修，重试上限见 retry_limit；疑难工程问题（引擎崩溃、渲染管线、跨模块重构）停下，在报告里写 `needs_claude: false`、`handoff: codex` 和最小复现。
- 报告开头用 `docs/collab.md` 第 4 节的 YAML 摘要；Lead 默认只读摘要。
