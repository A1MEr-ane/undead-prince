---
id: T42
title: 新画风兵种阵容：亡魂、王国、局内 Q 版
owner: codex
status: queued
branch: codex/t42-units
worktree: ../亡魂王子-t42
images: [/Users/cyy/Projects/亡魂王子/art/style/prince_hero.png, /Users/cyy/Projects/亡魂王子/art/style/battle_mock.png]
allowed: [art/units/]
forbidden: [scripts/, scenes/, docs/, tasks/, project.godot, assets/, art/style/, art/archive/]
verify: test -f art/units/RESULTS.json
retry_limit: 3
max_minutes: 180
escalate_if: [需要改动世界观或人物设定, 同一张图重试三次仍不合格]
---

## 目标
按新画风出两张兵种阵容图，用于设定集和以后重做战斗精灵。兵种以 `docs/units.md` 第一、二节为准。

## 产物（放在 `art/units/`）
1. `undead_lineup.png`：16:9。亡魂大军全部兵种站成一排，从左到右是：普通亡魂、复仇亡魂、缝合巨人、盾骷髅、死灵骑士、巫妖、旗手亡魂、亡魂王子。
   - 每个兵种下面写中文名。
   - 骷髅或灰白皮肤，青绿冥火光，破旧海军服饰，紫色破布和碎王冠军旗元素。
   - 缝合巨人参考 canon 里的码头工人加兰（`docs/canon/B/B3-LIVES-BETWEEN-THE-RETURNS.md` 里有描述）。
2. `kingdom_lineup.png`：16:9。王国守军全部兵种站成一排，从左到右是：民兵、盾兵、枪兵、弓兵、弩手、修士、传令兵、王国骑士。
   - 全部是**活人**，白金暖光。
   - 王室纹章是白底金八芒日；摄政军旗加红斜带。
3. `chibi_lineup.png`：16:9。上面两排兵种的**局内 Q 版**（2.3 头身，深色墨线外轮廓、两档平涂、阵营边光），风格照附图 2 的小兵放大。用来指导 Blender 精灵重做。

## 先读
- `docs/units.md` 第一、二、七节（兵种、走路性格）
- `docs/art-style.md` 第 4 节（局内美术方案）
- `docs/art-direction.md` 第 2–3 节（Q 版比例与形体规则）

## 风格（硬要求，Lead 已审批的基准）
- 先读 `docs/art-style.md` 第 1–3 节。附图里的风格样张（`art/style/`）就是标准：手绘厚涂加粗细有变化的墨线、修长有棱角的造型、强明暗、平涂阴影、一侧饱和色轮廓光、暗背景。
- canon 简报里凡是写"低多边形、切面、匹配参考图的 3D 质感"的部分**一律忽略**；内容（服装、道具、年龄、配色、禁止项）照简报执行。
- 亡魂用青绿冥火作光色；活人和王国用白金暖光。
- 提示词里不写任何现有游戏、工作室或画师的名字。
- 每张图单独生成，一张一个角色（剧情插画除外）。
- 不从生成图里的偶然文字推出新设定。

## 交付
- 生成图从 `~/.codex/generated_images/` 复制到产物目录；每个主文件另存至少 1 个备选到 `alt/` 子目录。
- `art/units/RESULTS.json`：每个任务 ID 一条，字段为 `id`、`files`、`alts`、`prompt`、`tool`、`status`（填 `in_review`）、`self_check`（逐条对照简报和风格要求）。
- 交付报告写到 `reports/agents/T42.md`，格式见 docs/collab.md 第 4 节，列出每张图的生成次数和退回原因。
- 自查不过就重画，同一张最多 3 次；仍不过就在报告里写明，不要硬交。
