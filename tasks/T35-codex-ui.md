---
id: T35
title: 新画风 UI 套件：边框、增益卡框、图标、航海图元素、据点/HUD/结局样张
owner: codex
status: queued
branch: codex/t35-ui
worktree: ../亡魂王子-t35
images: [/Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png, /Users/cyy/Projects/亡魂王子/art/style/ui_boons.png, /Users/cyy/Projects/亡魂王子/art/style/battle_mock.png]
allowed: [art/ui/]
forbidden: [scripts/, scenes/, docs/, tasks/, project.godot, assets/, art/style/, art/archive/]
verify: test -f art/ui/RESULTS.json
retry_limit: 3
max_minutes: 180
escalate_if: [需要改动世界观或人物设定, 同一张图重试三次仍不合格]
---

## 目标
按已审批的三张 UI 样张（附图），出一套可以拆进游戏的 UI 素材板，供 Godot 重做界面和设定集使用。

## 产物（放在 `art/ui/`）
1. `kit_frames.png`：边框与面板套件。对话框、名牌、地点面板、按钮（常态/悬停/按下）、滚动条、分隔线。锻铁青铜质感、细金线、缆绳和钟纹。纯色暗背景上排列，元素之间留空，方便以后切图。
2. `kit_boon_frames.png`：五种增益卡框并排，各配图标：伯纳德钢灰加盾，玛蒂尔达锈红加针线，奥斯温石板蓝加石板，皮普铜金加号角，渡魂人墨黑青绿加提灯。另加三种稀有度角标（普通、稀有、史诗）。
3. `kit_icons.png`：图标表，单色墨线加一个强调色。
   - 8 类奖励：旧部增益、招募、魂火、缝补、休整、遗物、航海、知识
   - 5 个增益槽位：刃、阵、行军、冥火、招魂
   - 5 种状态：破阵、缝线、冥燃、惊惶、沉
   - 其他：残响、钟数
   - 每个图标下面写中文标签。
4. `kit_chart.png`：航海图元素。5 档难度节点（绿、黄、橙、红、紫首领）、五名仇人的首领纹章各一、已走航线和可前往航线、罗盘、海浪纹样。
5. `ui_hub.png`：16:9 据点界面样张。沉钟湾沉船甲板，五位旧部站位，顶部显示残响和钟数，入口按钮"出征"。
6. `ui_hud.png`：16:9 战斗 HUD 样张。左上部队卡（兵种图标加人数，选中态），底部冥火能量条，右上首领血条。画面中央可以是简化的战场，构图参照附图 3。
7. `ui_ending.png`：16:9 结局卡样张。用 E01"灰烬王冠"：标题、一段尾声文字、渡魂人台词"那么，陛下。一切都如你所愿吗？"、按钮"回溯到沉钟湾"。

## 先读
- `docs/art-style.md` 第 2 节（UI 方向）
- `docs/boons.md` 第 0 节（槽位、状态）、`docs/roguelike.md` 第 3、5、8、9 节（奖励、残响、难度、首领）

## 风格（硬要求，Lead 已审批的基准）
- 先读 `docs/art-style.md` 第 1–3 节。附图里的风格样张（`art/style/`）就是标准：手绘厚涂加粗细有变化的墨线、修长有棱角的造型、强明暗、平涂阴影、一侧饱和色轮廓光、暗背景。
- canon 简报里凡是写"低多边形、切面、匹配参考图的 3D 质感"的部分**一律忽略**；内容（服装、道具、年龄、配色、禁止项）照简报执行。
- 亡魂用青绿冥火作光色；活人和王国用白金暖光。
- 提示词里不写任何现有游戏、工作室或画师的名字。
- 每张图单独生成，一张一个角色（剧情插画除外）。
- 不从生成图里的偶然文字推出新设定。

## 交付
- 生成图从 `~/.codex/generated_images/` 复制到产物目录；每个主文件另存至少 1 个备选到 `alt/` 子目录。
- `art/ui/RESULTS.json`：每个任务 ID 一条，字段为 `id`、`files`、`alts`、`prompt`、`tool`、`status`（填 `in_review`）、`self_check`（逐条对照简报和风格要求）。
- 交付报告写到 `reports/agents/T35.md`，格式见 docs/collab.md 第 4 节，列出每张图的生成次数和退回原因。
- 自查不过就重画，同一张最多 3 次；仍不过就在报告里写明，不要硬交。
