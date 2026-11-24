---
id: T48
title: Bad North 本地取证：镜头、精灵、飞行物、特效、地形（只读调查）
owner: codex
status: queued
branch: codex/t48-bn-evidence
worktree: ../亡魂王子-t48
allowed: [docs/research/BAD_NORTH_LOCAL_FINDINGS.md, docs/research/BAD_NORTH_EVIDENCE_INDEX.md]
forbidden: [scripts/, shaders/, scenes/, assets/, art/, tasks/, project.godot, docs/research/FLEET_ART_TECH_DECISION.md]
verify: test -f docs/research/BAD_NORTH_EVIDENCE_INDEX.md
retry_limit: 2
max_minutes: 150
escalate_if: [需要访问加密或受保护内容, 证据和 docs/badnorth-art-spec.md 的已有结论矛盾]
---

## 目标
用本地证据核实并补全 Bad North 的实现，供 `docs/research/FLEET_ART_TECH_DECISION.md` 复核。用户的完整任务书见 `~/Downloads/BAD_NORTH_ART_TECH_RESEARCH.md`，先读它的第 2–6 节和第 10 节。

## 范围（只读）
- 解包目录：`~/Downloads/BadNorth-Unpacked`。反编译源码在 `DecompiledSource/Assembly-CSharp`，资源在 `ExtractedMedia`、`UnityProject/ExportedProject`。
- 已有结论：`docs/badnorth-art-spec.md`。只核对、补充，不要整个重做。
- **不得**把原作代码、着色器、贴图、模型复制进仓库。报告里只写路径、类名或符号名、字段名，以及你自己写的行为摘要。

## 要回答的问题（按优先级）
1. 镜头：投影方式、俯角、偏航输入（连续还是分档）、阻尼、缩放范围、跨 0° 的处理。
2. 公告板与翻转：在哪个类、哪个阶段做的（CPU 还是着色器）；滞回的值；击飞时怎么处理。
3. 装备：盾和武器是 3D 网格还是精灵，怎么挂到动画上；前后遮挡怎么处理。
4. **飞行物**：箭和弩矢的弹道（`ProjectileMath` 等），用什么渲染（网格、公告板还是条带），插在盾上的箭怎么做。
5. **特效**：火、烟、血、水花等特效池的实现：粒子系统、公告板序列图还是网格；地面贴花怎么做；有没有方向性的特效，旋转时怎么处理。
6. 地形：模块数量和兼容规则、网格平滑和法线、地表材质混合、导航和视觉表面的关系。

每条结论都写：相对路径、类名或资源名、可核验的字段或观察、证据等级（LOCAL_CONFIRMED / PUBLIC_CONFIRMED / OBSERVED / HYPOTHESIS / UNKNOWN）。尽量追完整的引用链：Renderer → Material → Shader → Texture/Mesh，追不到就保留不确定。

## 产物
- `docs/research/BAD_NORTH_EVIDENCE_INDEX.md`：一个精简证据表，每行一条结论。
- `docs/research/BAD_NORTH_LOCAL_FINDINGS.md`：按系统写机制说明。第一屏直接回答上面 1–5 问。
- 报告写到 `reports/agents/T48.md`，开头用 docs/collab.md 第 4 节的 YAML 摘要。
