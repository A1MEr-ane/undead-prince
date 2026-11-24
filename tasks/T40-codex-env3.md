---
id: T40
title: 新画风场景 3：地点 13 张
owner: codex
status: queued
branch: codex/t40-env3
worktree: ../亡魂王子-t40
images: [/Users/cyy/Projects/亡魂王子/art/style/ui_chart.png, /Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png, /Users/cyy/Projects/亡魂王子/art/style/battle_mock.png]
allowed: [art/env/]
forbidden: [scripts/, scenes/, docs/, tasks/, project.godot, assets/, art/style/, art/archive/]
verify: test -f art/env/RESULTS-T40.json
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
### ENV-SUNHOLD · 永昼王城（Sunhold）
- 简报（中）：白石阶城：会面厅、议会厅、集结庭、冬政会议及地下秘印，分层制作。 王室会面、摄政对质、军团集结、冬政会议、秘印、尾声；选择分开作出。 复用地区组件；按需概念图或灰盒。
- 简报（英）：White stone terraces: audience hall, council chamber, muster court, winter council and hidden Seal beneath; separate scene layers. Audience, Council confrontation, Muster, Winter Council, Seal, epilogue; choices are separated. Use regional kit; concept or blockout only as needed.

### ENV-NORTHRELIEF · 北望港（Northhaven）
- 简报（中）：寒冷外港、空赈粮仓、岸边等待的家属。 攻占外港并检查空赈粮仓，保护等待救济的家庭。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Cold outer harbour, empty relief store, waiting families at the waterfront. Seize the outer harbour and inspect the empty relief store; spare the waiting families. Use regional kit; concept or blockout only as needed.

### ENV-WATCHSKERRY · 孤哨礁（Watchman’s Skerry）
- 简报（中）：孤立礁石岗哨塔、暴露登陆点与信号台。 从岗哨塔下登陆，在巡逻队抵达北峡前切断警报。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Isolated rock watchtower, exposed landing and signal platform. Land below the watch tower and disable the alert before a patrol reaches the northern passage. Use regional kit; concept or blockout only as needed.

### ENV-SALTMARKET · 盐市港（Saltmarket）
- 简报（中）：盐棚、晒盐池、税关与避风商码头。 控制税关；可保全盐仓而非悉数掠夺。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Salt sheds and drying pans, tollhouse, sheltered merchant docks. Secure the tollhouse; choose to preserve the salt depots rather than seize everything as spoils. Use regional kit; concept or blockout only as needed.

### ENV-FOUNDRY · 灰铁工坊（Ashen Foundry）
- 简报（中）：炉场庭院、炉门与独立甲具仓，危险区清晰。 横穿暴露炉场，关闭炉门并控制甲具库。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Furnace courtyards, blast gates and separate armour stores, readable hazard zones. Cross exposed furnace yards, shut the blast gates and capture the armour depot. Use regional kit; concept or blockout only as needed.

### ENV-BANNERS · 万旗冢（Field of Broken Banners）
- 简报（中）：古战场纪念地、残旗、石台及相互矛盾的铭文。 探索古战场纪念地，对照王室与投降士兵记录。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Old memorial field with ruined standards, stone terraces and competing inscriptions. Search the old memorial field and compare royal and surrendered soldiers’ accounts. Use regional kit; concept or blockout only as needed.

### ENV-TITHEFORD · 十税渡（Titheford）
- 简报（中）：税渡、账房、狭窄河岸与小市场摊。 控制税渡与账房；守军依托狭窄河道。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Toll ferry, ledger office, narrow river banks and modest market stalls. Control the toll ferry and ledger office; defending formations use narrow river approaches. Use regional kit; concept or blockout only as needed.

### ENV-BARLEYHALL · 金麦府（Barley Hall）
- 简报（中）：地方行政厅、请愿档案室、遮棚市场及中心庭院。 控制行政庭院并保护请愿档案。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Regional civic hall with a petition archive, covered market and central courtyard. Capture the civic courtyard and protect the petition archive from destruction. Use regional kit; concept or blockout only as needed.

### ENV-REEDCROSS · 芦苇渡（Reedcross）
- 简报（中）：芦苇浅滩、低渡口及限制重装通行的高堤。 控制芦苇渡口；重装守军守堤时利用浅水路线。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Reed-lined shallows, low ferry and raised embankment with limited heavy access. Secure a reed-lined crossing; use shallow approaches while heavy defenders hold the embankment. Use regional kit; concept or blockout only as needed.

### ENV-HOSPICE · 静息院（Saint Orlan’s Hospice）
- 简报（中）：安静照护院落、名册台与避开进路的病床。 与照护者交谈并检查名册，不打扰住民。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Quiet care courtyard, register desk, beds screened from the approach. Speak to caretakers and inspect registers; let residents remain undisturbed. Use regional kit; concept or blockout only as needed.

### ENV-WINTERPALACE · 寒宫（The Winter Palace）
- 简报（中）：冰封宫厅与下方废港可见，无强制驻军。 勘察冰封宫厅并找到寒冬账册，不强制首领战。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Ice-filled court halls, abandoned harbour visible below, no compulsory garrison. Survey frozen halls and recover the winter accounts; no compulsory boss. Use regional kit; concept or blockout only as needed.

### ENV-OLDBRIDGE · 旧王冠桥（Old Crown Bridge）
- 简报（中）：古石桥中央拱坍塌，保留可用渡船绕行。 控制桥头渡船与断桥；用船绕过坍塌中拱。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Ancient stone bridge with central arch collapsed and usable ferry bypass. Secure the bridgehead ferry and collapsed span; boats bypass the broken central arch. Use regional kit; concept or blockout only as needed.

### ENV-SEALQUAY · 封印码头（The Sealed Wharf）
- 简报（中）：封印石仓、受守卫的记录室与仪式驳船。 在货册被转移前夺取封印仓库，控制仪式驳船。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Sealed stone warehouses, guarded record office and a ritual barge. Capture the sealed warehouse before the cargo register is removed; secure the ritual barge. Use regional kit; concept or blockout only as needed.

## 风格（硬要求，Lead 已审批的基准）
- 先读 `docs/art-style.md` 第 1–3 节。附图里的风格样张（`art/style/`）就是标准：手绘厚涂加粗细有变化的墨线、修长有棱角的造型、强明暗、平涂阴影、一侧饱和色轮廓光、暗背景。
- canon 简报里凡是写"低多边形、切面、匹配参考图的 3D 质感"的部分**一律忽略**；内容（服装、道具、年龄、配色、禁止项）照简报执行。
- 亡魂用青绿冥火作光色；活人和王国用白金暖光。
- 提示词里不写任何现有游戏、工作室或画师的名字。
- 每张图单独生成，一张一个角色（剧情插画除外）。
- 不从生成图里的偶然文字推出新设定。

## 交付
- 生成图从 `~/.codex/generated_images/` 复制到产物目录；每个主文件另存至少 1 个备选到 `alt/` 子目录。
- `art/env/RESULTS-T40.json`：每个任务 ID 一条，字段为 `id`、`files`、`alts`、`prompt`、`tool`、`status`（填 `in_review`）、`self_check`（逐条对照简报和风格要求）。
- 交付报告写到 `reports/agents/T40.md`，格式见 docs/collab.md 第 4 节，列出每张图的生成次数和退回原因。
- 自查不过就重画，同一张最多 3 次；仍不过就在报告里写明，不要硬交。
