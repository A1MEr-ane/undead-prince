---
id: T39
title: 新画风场景 2：地点 13 张
owner: codex
status: queued
branch: codex/t39-env2
worktree: ../亡魂王子-t39
images: [/Users/cyy/Projects/亡魂王子/art/style/ui_chart.png, /Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png, /Users/cyy/Projects/亡魂王子/art/style/battle_mock.png]
allowed: [art/env/]
forbidden: [scripts/, scenes/, docs/, tasks/, project.godot, assets/, art/style/, art/archive/]
verify: test -f art/env/RESULTS-T39.json
retry_limit: 3
max_minutes: 180
escalate_if: [需要改动世界观或人物设定, 同一张图重试三次仍不合格]
---

## 目标
按新画风重画地点概念图。用途：航海图地点面板的插图（构图参照附图 1 右上角）、设定集、以后搭建 3D 关卡的参考。

## 每个地点交 1 张（放在 `art/env/<地点任务ID，例如 ENV-BAY>/site.png`）
- 16:9 横版，手绘厚涂加墨线，强明暗，暗调灰海；冥火和日光作为画面里最亮的颜色。
- 构图：斜俯视的场景全景，能看出登陆点、目标建筑和主要地形（简报里的"Capture / Secure ..."就是战斗目标，要在画面里可辨）。
- 无人物或只有很小的人影；不要文字。
- 地区归属和材质先看 `docs/canon/C/C4-ENVIRONMENT-ART.md` 的"地区模块"一节，同一地区的地点用同一套材质和色调。

## 先读
- `docs/canon/C/C4-ENVIRONMENT-ART.md`：地区模块，以及每个地点自己的美术卡（比简报更详细，以美术卡为准）
- `docs/canon/C/CAMPAIGN-DATA.json`：地点的 scene、plot 字段

## 地点与 canon 简报
### ENV-GRANARY · 万谷仓（The Great Granary）
- 简报（中）：阶梯式石粮仓、三个可防御入口及通风干燥仓储。 夺取三处仓门，压制守军而不焚毁粮储。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Tiered stone warehouses with three defensible entrances, ventilated dry stores. Seize three warehouse gates; suppress the garrison without burning the food stores. Use regional kit; concept or blockout only as needed.

### ENV-LOCK · 王闸（King’s Lock）
- 简报（中）：水闸与两岸，渡船登陆和桥路并存。 控制两岸并操作水闸；桥路与渡船为不同进路。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Sluice gates and dual banks with ferry and bridge landings. Control both banks and operate the sluice; bridge and ferry provide distinct approaches. Use regional kit; concept or blockout only as needed.

### ENV-SILENT · 寂礁群（Silent Shoals）
- 简报（中）：落潮露出的低葬碑与风化渡魂信物，无需怪物。 落潮时辨读葬碑，选择安全渡线或遗物。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Low burial stones revealed by tide, weathered ferryman token, no monsters required. Read the burial stones at low tide; choose a safe ferry route or a relic cache. Use regional kit; concept or blockout only as needed.

### ENV-ARCHIVE · 沉水藏书阁（The Drowned Archive）
- 简报（中）：积水下厅、高处阅览台与水线上方书架。 穿过积水下厅；优先抄录盟约或查看奥斯温批注，安全时可兼取。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Flooded lower hall, elevated reading ledges, shelves above the water line. Navigate the flooded lower hall; choose to copy the founding charter or inspect Oswin’s notes, with both readable if safe. Use regional kit; concept or blockout only as needed.

### ENV-OLD · 旧王堡（Old Crown Keep）
- 简报（中）：废弃王家渡阶、风化纪念室及永昼前石构。 勘察古渡阶梯与纪念室，回收王朝遗物。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Abandoned royal ferry stairs and weathered memorial rooms, pre-Day masonry. Survey the old ferry stairs and memorial rooms; recover a dynastic relic. Use regional kit; concept or blockout only as needed.

### ENV-ORCHARD · 旧王果园（The King’s Orchard）
- 简报（中）：庄园花园、浅引水沟与果树；无战场杂物。 探访破损庄园，找到童年速写，不要求战斗。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Country house garden, shallow irrigation ditch and fruit trees; no battlefield clutter. Visit the damaged country house; recover a childhood sketch, with no garrison encounter required. Use regional kit; concept or blockout only as needed.

### ENV-GRAVES · 无碑墓园（Hollow Graves）
- 简报（中）：潮间石地的无名墓，路下隐藏刻名石板。 涨潮前辨读隐藏姓名；证人可自愿作证。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Unmarked graves among tidal stones; hidden inscribed slabs beneath paths. Read concealed names before the tide rises; a witness may volunteer to speak. Use regional kit; concept or blockout only as needed.

### ENV-ABBEY · 苍白圣堂（The Pale Abbey）
- 简报（中）：钟塔、回廊、档案室及清晰圣光作用区域。 压制钟楼圣光区域，再夺取档案室。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Bell tower, cloister, archive room and visible holy-field footprint. Silence the bell tower’s holy field, then seize the record room. Use regional kit; concept or blockout only as needed.

### ENV-FUNERAL · 灵渡码头（Funeral Landing）
- 简报（中）：仪式石码头与肃穆的遮蔽货棚。 控制仪式码头，阻止转运且不毁记录。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Ceremonial stone jetty and sombre covered cargo shelters. Secure the ceremonial jetty and stop the transfer without destroying the records. Use regional kit; concept or blockout only as needed.

### ENV-MERCHANT · 白港门（Merchant Gate）
- 简报（中）：白石海关码头、商人印记与市政守卫岗。 控制海关码头，守卫投降后与商人协商通行。 复用地区组件；按需概念图或灰盒。
- 简报（英）：White-stone customs quay, merchant seals and civic guard post. Secure the customs quay and negotiate a passage with merchants after the local guard yields. Use regional kit; concept or blockout only as needed.

### ENV-LION · 雄狮门（Lion Gate）
- 简报（中）：重闸军港门、白金军事标志。 以军事压力或承认合法君主打开军港门。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Naval gate with heavy portcullis and white-gold military insignia. Open the naval gate through military pressure or recognition of the lawful ruler. Use regional kit; concept or blockout only as needed.

### ENV-PROVISION · 粮运门（Provision Gate）
- 简报（中）：宽阔粮运登陆场、吊架、查验台与粮册。 控制粮运登陆点，取得可用粮储清单。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Broad grain landing with cranes, inspection tables and supply records. Secure the grain landing and obtain a statement of available stocks. Use regional kit; concept or blockout only as needed.

### ENV-PROCESSION · 圣仪门（Processional Gate）
- 简报（中）：安静仪式阶梯、遮蔽登陆区及文书查验入口。 沿仪式水道控制登陆点，取得本轮通行文书。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Quiet processional steps, covered landing and documented access threshold. Follow the ceremonial waterway, secure its landing and obtain current access papers. Use regional kit; concept or blockout only as needed.

## 风格（硬要求，Lead 已审批的基准）
- 先读 `docs/art-style.md` 第 1–3 节。附图里的风格样张（`art/style/`）就是标准：手绘厚涂加粗细有变化的墨线、修长有棱角的造型、强明暗、平涂阴影、一侧饱和色轮廓光、暗背景。
- canon 简报里凡是写"低多边形、切面、匹配参考图的 3D 质感"的部分**一律忽略**；内容（服装、道具、年龄、配色、禁止项）照简报执行。
- 亡魂用青绿冥火作光色；活人和王国用白金暖光。
- 提示词里不写任何现有游戏、工作室或画师的名字。
- 每张图单独生成，一张一个角色（剧情插画除外）。
- 不从生成图里的偶然文字推出新设定。

## 交付
- 生成图从 `~/.codex/generated_images/` 复制到产物目录；每个主文件另存至少 1 个备选到 `alt/` 子目录。
- `art/env/RESULTS-T39.json`：每个任务 ID 一条，字段为 `id`、`files`、`alts`、`prompt`、`tool`、`status`（填 `in_review`）、`self_check`（逐条对照简报和风格要求）。
- 交付报告写到 `reports/agents/T39.md`，格式见 docs/collab.md 第 4 节，列出每张图的生成次数和退回原因。
- 自查不过就重画，同一张最多 3 次；仍不过就在报告里写明，不要硬交。
