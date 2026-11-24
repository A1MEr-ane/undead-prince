---
id: T38
title: 新画风场景 1：地区套件 7 张 + 地点 13 张
owner: codex
status: queued
branch: codex/t38-env1
worktree: ../亡魂王子-t38
images: [/Users/cyy/Projects/亡魂王子/art/style/ui_chart.png, /Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png, /Users/cyy/Projects/亡魂王子/art/style/battle_mock.png]
allowed: [art/env/]
forbidden: [scripts/, scenes/, docs/, tasks/, project.godot, assets/, art/style/, art/archive/]
verify: test -f art/env/RESULTS-T38.json
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

## 另交 7 张地区套件板（放在 `art/env/KIT-<英文名>/kit.png`）
地区：Greywake、Pilot Waters、Pinewatch、Grainlands、Saltmarsh、Old Realm、Sunhold。每张横版，排列该地区可复用的建筑和地形模块：码头、民居、城墙、地表、植被、标志性小物件。暗纯色底，元素分开排列，方便建模参考。

## 地点与 canon 简报
### ENV-BAY · 沉钟湾（Bellgrave Bay）
- 简报（中）：黑岩环湾、沉钟、升起的旗舰与避风码头；甲板留足旧部互动空间。 唤醒基础军团，选择开局倾向，与旧部交谈。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Black rock amphitheatre, submerged bell, raised flagship and a sheltered pier; broad quiet deck for the crew. Wake the company; choose a starting doctrine and speak to the crew. Use regional kit; concept or blockout only as needed.

### ENV-WRECK · 断桅滩（Wrecker’s Rest）
- 简报（中）：两处登陆滩由船肋隔开；打捞吊架、绞盘与船棚。 抢占打捞码头，防止守军转移小艇；两处登陆滩。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Two beaches separated by wreck ribs; salvage crane, winch and boat sheds. Take the salvage pier before defenders move the boats; two beach approaches. Use regional kit; concept or blockout only as needed.

### ENV-LIGHT · 天涯灯塔（The Last Lighthouse）
- 简报（中）：岬角上的收分灯塔；盘旋阶梯及低码头。 在灯塔发出警报前夺取它；低处码头更安全但绕路。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Tall tapered beacon on a headland; winding stair and lower pier. Capture the beacon before its warning reaches the next garrison; the lower pier is a safer but longer approach. Use regional kit; concept or blockout only as needed.

### ENV-OAR · 折桨港（Broken Oar Harbour）
- 简报（中）：石板屋顶货仓、窄巷、工作码头与渔民住屋。 穿过仓库巷道或突击暴露码头；避免误毁民用货物。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Slate-roofed warehouses, narrow alleys, working quay and fishing homes. Fight through warehouse alleys or cross the exposed quay; protect civilian cargo from incidental damage. Use regional kit; concept or blockout only as needed.

### ENV-PILOT · 引航岛（Pilot’s Rest）
- 简报（中）：潮汐小岛上的两间海图房与半淹堤道。 夺取潮汐堤道连接的两处海图房；随潮位选择登陆点。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Two low chart houses on tidal islets with a partly flooded causeway. Secure two chart huts linked by a tidal causeway; choose a landing while the tide changes. Use regional kit; concept or blockout only as needed.

### ENV-GATE · 锁海之门（The Iron Gate）
- 简报（中）：海峡双巨塔、横水铁链与独立绞盘院。 攻破双锁链塔，压制守军后控制绞盘。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Paired massive towers with an iron chain over a channel, a separate winch yard. Break the two chain towers; occupy the winch after suppressing the defending formation. Use regional kit; concept or blockout only as needed.

### ENV-YARD · 黑浪船厂（Blackwake Yard）
- 简报（中）：木质船肋、干船坞、下水滑道与制绳长廊。 阻止援船离港，控制滑道和船坞。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Timber ribs of ships, dry dock, slipways and ropewalk. Disable launch ramps and seize the dry dock before a relief ship departs. Use regional kit; concept or blockout only as needed.

### ENV-KINGS · 沉王群像（The Drowned Kings）
- 简报（中）：潮水上露出的先王巨像，基座保留可辨铭文。 调查巨像铭文，在两处遗物中选择其一，无强制战斗。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Weathered royal stone heads emerging above the tide; readable pedestal inscriptions. Inspect the monument inscriptions; choose one of two relic caches instead of a compulsory battle. Use regional kit; concept or blockout only as needed.

### ENV-ROADS · 王冠海道（Crown Roads）
- 简报（中）：低矮港堡、受保护的泊位区与巡逻船活动水面。 在巡逻船威胁登陆区时攻下锚地堡垒。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Low harbour bastion and protected mooring field; open water for patrol craft. Capture the harbour fort while patrol boats threaten the landing zone. Use regional kit; concept or blockout only as needed.

### ENV-LANTERN · 长灯岛（Lantern Isle）
- 简报（中）：灯油铺、暖窗与住人小屋之间的狭窄水道。 夺取引航码头并保护民居；浅水通道限制大型阵形。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Oil shops, warm windows and narrow channels between occupied cottages. Secure the pilot pier without destroying occupied homes; shallow channels limit large formations. Use regional kit; concept or blockout only as needed.

### ENV-WEST · 西庇港（Westhaven）
- 简报（中）：淤积港池、废置吊架与旧石砌海关厅。 勘察淤积港池并询问工人；选择修港建议或补给储藏。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Silted harbour basin, unused cranes, former stone customs hall. Inspect the silted basin and interview harbour workers; choose repair advice or a supply cache. Use regional kit; concept or blockout only as needed.

### ENV-MILL · 磨桥渡（Miller’s Crossing）
- 简报（中）：磨桥相邻的水磨与清楚的上游河道。 在援兵过桥前控制磨桥，尽量保全磨坊。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Watermill beside a working bridge and a clear upstream channel. Control the mill bridge before reinforcements cross; keep the mill intact if possible. Use regional kit; concept or blockout only as needed.

### ENV-HARVEST · 麦尽村（Harvest End）
- 简报（中）：普通农舍、配粮站与民用粮仓视觉分离。 夺取配粮站瓦解征发守军，避开民用粮仓。 复用地区组件；按需概念图或灰盒。
- 简报（英）：Ordinary farm cottages, ration post and civilian grain barn separated visually. Break the levy garrison by taking its ration station; avoid the civilian granary. Use regional kit; concept or blockout only as needed.

## 风格（硬要求，Lead 已审批的基准）
- 先读 `docs/art-style.md` 第 1–3 节。附图里的风格样张（`art/style/`）就是标准：手绘厚涂加粗细有变化的墨线、修长有棱角的造型、强明暗、平涂阴影、一侧饱和色轮廓光、暗背景。
- canon 简报里凡是写"低多边形、切面、匹配参考图的 3D 质感"的部分**一律忽略**；内容（服装、道具、年龄、配色、禁止项）照简报执行。
- 亡魂用青绿冥火作光色；活人和王国用白金暖光。
- 提示词里不写任何现有游戏、工作室或画师的名字。
- 每张图单独生成，一张一个角色（剧情插画除外）。
- 不从生成图里的偶然文字推出新设定。

## 交付
- 生成图从 `~/.codex/generated_images/` 复制到产物目录；每个主文件另存至少 1 个备选到 `alt/` 子目录。
- `art/env/RESULTS-T38.json`：每个任务 ID 一条，字段为 `id`、`files`、`alts`、`prompt`、`tool`、`status`（填 `in_review`）、`self_check`（逐条对照简报和风格要求）。
- 交付报告写到 `reports/agents/T38.md`，格式见 docs/collab.md 第 4 节，列出每张图的生成次数和退回原因。
- 自查不过就重画，同一张最多 3 次；仍不过就在报告里写明，不要硬交。
