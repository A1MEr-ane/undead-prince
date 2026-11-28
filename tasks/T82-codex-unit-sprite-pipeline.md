---
id: T82
title: 局内小兵形象、动作清单与 Blender 管线设计（为 DSH 批量建模铺路）
owner: codex
status: parked   # 用户 2026-11-28：先对齐玩法、美术、程序再做
branch: codex/t82-unit-pipeline
worktree: ../亡魂王子-t82
images: [/Users/cyy/Projects/亡魂王子/art/units/chibi_lineup.png, /Users/cyy/Projects/亡魂王子/art/style/battle_mock.png]
allowed: [tools/blender/, assets/specs/, assets/sprites/pilot/, docs/unit-sprites.md, reports/agents/]
forbidden: [scripts/, proto/, shaders/, data/, tasks/, art/, docs/canon/, assets/sprites/k2_*]
verify: tools/verify/verify.sh sprites
retry_limit: 3
max_minutes: 300
escalate_if: [需要改动游戏的精灵格式或着色器接口, 和美术方向文档冲突]
---

## 目标
用户要求：由 Codex 设计局内小兵的形象、动作和 Blender 管线，之后交给 DSH 批量建模。本任务产出**设计、管线和一个试点兵种**，并写一份 DSH 可以照着执行的生产手册。

## 先读
- `docs/art-style.md` 第 4 节（局内：墨线外轮廓、两档平涂、阵营边光、3–4 块色）
- `docs/art-direction.md`（2.3 头身 Q 版比例和形体规则）
- `docs/units.md` 开头（6 个亡魂兵种方向和普通亡魂）、`docs/behavior-goals.md` 第 2–3 节（各兵种的行为，决定需要哪些动作）
- `docs/sprite-pipeline.md`、`tools/blender/chibi_body.py`，以及 `reports/agents/T64.md` 里批量化的 12 项阻碍
- 附图：附图 1 是局内 Q 版阵容（形象参考），附图 2 是局内风格样张

## 要做
1. `docs/unit-sprites.md`（设计稿，标注【议】，由 Lead 审批）。覆盖 7 个亡魂兵种（普通亡魂、盾骷髅、暗影刺客、巫妖、狂战士、死灵骑士、缝合巨人）和 6 个守军兵种（民兵、盾兵、枪兵、弓兵、骑兵、神职者）。每个兵种写：
   - 剪影要点
   - 体型类别（普通、大型、骑乘）
   - 3–4 块主色
   - 部位分区
   - 装备
   - 在 48 像素高度下的辨识要点
2. **动作清单**：
   - 全兵种共用的动作：待机、行走、攻击、受击、倒地、起身、死亡、击飞
   - 每个兵种的专属动作：刺客潜行和背刺、巨人横扫和砸墙、巫妖施法、狂战士跳劈、骑兵冲锋、弓兵射击、神职者施法、守军撤退跑
   - 每个动作的帧数、时长、事件帧（命中点、发射点）
   - 镜头已倾向"战区固定视角"，仍按"单侧面 + 左右翻转"设计。如果需要多方向，列出成本，不要直接做
3. **管线改造**，解决 T64 的阻碍，目标是"新增一个兵种只写一份 YAML 配方，不写 Python"：
   - 验收器不再假设每个兵种都有盾和剑
   - 部位分区按需使用
   - 侧视角下脸要能看清
   - 大型单位和骑乘单位的骨骼与画布尺寸
   - 批量命令：一条命令构建、渲染、验收、出预览图
4. **试点**：用新管线完整做出"盾骷髅"，走完 YAML → 模型 → 动作 → 图集 → 验收 → 预览图，产物放 `assets/sprites/pilot/`。
5. **`docs/unit-sprites.md` 附录：DSH 生产手册**。写明：每个兵种要准备什么、跑哪些命令、自检清单、失败时怎么办，以及哪些情况必须停下交回 Codex。

## 交付
报告 `reports/agents/T82.md`，开头用 YAML 摘要。Lead 审批设计和试点后，再由 DSH 批量建模。
