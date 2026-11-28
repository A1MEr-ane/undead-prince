---
id: T85
title: 灰潮外岛地形套件与基础单局战场（模块、材质、夜到黎明光照）
owner: codex
status: queued
branch: codex/t85-terrain-kit
worktree: ../亡魂王子-t85
images: [/Users/cyy/Projects/亡魂王子/shots/t84/02-midnight.png, /Users/cyy/Projects/亡魂王子/shots/t84/04-daybreak.png]
allowed: [attempts/single_battle/terrain/, tools/blender/terrain/, reports/agents/]
forbidden: [attempts/single_battle/*.gd, attempts/single_battle/units/, scripts/, proto/, shaders/, data/, docs/, tasks/, art/, assets/]
verify: test -f attempts/single_battle/terrain/README.md
retry_limit: 3
max_minutes: 300
escalate_if: [需要改 allowed 以外的文件, 地图拓扑和玩法需求冲突]
---

## 续做（2026-11-28）
上一轮做到一半就因为 Codex 额度用尽而中断，工作目录里保留了已经完成的部分。先检查现有文件，接着往下做，不要从头重来。

## 目标
用户已通过局内风格样张（附图），开始生产。本任务产出基础单局所用的**灰潮外岛地形套件**和**一整张战场**（3–4 个战区），画风沿用样张。程序部分（T86）会从 `attempts/single_battle/terrain/` 加载这张图。

## 先读
- `docs/single-battle-v1.md`
- `docs/map-design.md` 第 3–7 节：战区、按战术时间定标、战区固定视角
- `attempts/single_battle/style_frame/`（样张的实现，能复用就复用）
- `proto/siege/` 的地图拓扑（海岸、高地、外城广场、主堡、城门、薄弱墙、山洞），玩法上已经验证过

## 要做
1. **模块**：
   - 海岸、礁石、浅滩、木码头
   - 地面和坡道、高地崖壁（含刺客能攀的崖壁段）
   - 城墙段（完好和破口两种状态）、城门（开、关、破三种状态）、塔
   - 民房、主堡、守军港口和船、山洞入口和出口
   - 树、杂物
2. **战场**：
   - 照 proto/siege 的拓扑搭一张完整战场，包括登陆区、大路、小路、山洞、高地、外城、主堡和港口。
   - 每个战区配一个手工机位（单战区固定视角）。
   - 输出导航和通行数据，与视觉分开，供 T86 使用；格式写进 README。
3. **光照**：夜到黎明。修正样张的问题：
   - 夜晚要更暗，冥火更突出。
   - 地形边缘的墨线细一点。
   - 岛屿不要像一块切下来的平台：边缘做成自然海岸，加水线泡沫。
4. **截图**：每个战区的机位各拍夜、黎明两张，放到 `shots/t85/`。截不了图就写明，由 Lead 补拍。
5. `README.md`：写明模块清单、怎么加载、通行数据的格式。

## 交付
报告 `reports/agents/T85.md`，开头用 YAML 摘要。
