---
id: T33
title: 新画风人物 2：据点旧部（伯纳德、玛蒂尔达、奥斯温、皮普）
owner: codex
status: queued
branch: codex/t33-crew
worktree: ../亡魂王子-t33
images: [/Users/cyy/Projects/亡魂王子/art/style/prince_hero.png, /Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png]
allowed: [art/chars/]
forbidden: [scripts/, scenes/, docs/, tasks/, project.godot, assets/, art/style/, art/archive/]
verify: test -f art/chars/CHAR-CAPTAIN/hero.png && test -f art/chars/RESULTS-T33.json
retry_limit: 3
max_minutes: 180
escalate_if: [需要改动世界观或人物设定, 同一张图重试三次仍不合格]
---

## 目标
用户决定全部人物改成新画风（docs/art-style.md）。本批重画以下角色，供对话立绘、设定集和以后建模使用。
伯纳德的造型以附图 2 右侧（已审批）为准。四人都是亡灵，亡灵特征要明显（灰白皮肤、局部露骨、青绿冥火光），但不血腥。这四人还是增益提供者，增益卡框颜色见 docs/art-style.md 第 2 节，表情里要有一张"给你增益时"的神态。

## 每个角色交 3 张（放在 `art/chars/<任务ID>/`）
1. `hero.png`：全身主立绘，竖版约 2:3，有姿态和戏剧张力，暗背景。
2. `turnaround.png`：横版，正、侧、背三视图，同一中性站姿、等高、空手；道具单独排在右侧；左上英文名字，视图标注只用 FRONT / SIDE / BACK / PROPS。用于建模参考，所以三视图要比例一致、服装细节对应。
3. `expressions.png`：横版，同一角色的三张对话半身像并排（构图同附图 2 里的半身像）：平静，以及两种最能体现该角色性格的表情（从 `docs/canon/B/B1-CORE-CHARACTERS.md`、`B2-HOUSE-AND-COUNCIL.md` 的人物语气推出，在 RESULTS.json 里写明选了哪两种、为什么）。

## 先读
- `docs/canon/B/B4-PRODUCTION-SPEC.md` 中对应角色的段落
- `docs/canon/B/B1-CORE-CHARACTERS.md`、`B2-HOUSE-AND-COUNCIL.md` 中对应角色（性格、年龄、外貌）
- `docs/art-style.md` 第 3 节的角色主色

## 角色与 canon 简报
### CHAR-CAPTAIN · 伯纳德卫队长（Captain Bernard）
- 简报（中）：宽厚稳固剪影、封闭海军头盔、磨损纹章、旧盾牌；面罩缝内少量青绿光。 专业、沉稳，爱惜装备；不使用夸张骨角。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Wide sturdy silhouette, enclosed naval helm, scratched insignia, worn shield, restrained turquoise in visor slit. Professional, grounded, careful with equipment; no ornate horns. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-STITCHER · 玛蒂尔达缝合匠（Matilda — the Stitcher）
- 简报（中）：单独一张38岁亡灵海军军医玛蒂尔达的概念板。紧凑结实，赤棕头发扎起，灰白皮肤有整齐缝线，腕部露骨与微弱青绿冥火，无血腥。皮质医用围裙、褪色海军服、卷袖手套及器械卷。主立绘持弯针线；无铁匠锤、铁砧、机械义肢、王冠与王室披风。 沿用参考图低多边形材质、暖灰背景；单角色主立绘与同姿势等高正侧背全身视图，三视图卸下道具，独立配件与色板；仅英文标题和视图标注。 最终交付主立绘、精确三视图与道具分文件。
- 简报（英）：A single standalone production concept sheet of Matilda, a 38-year-old undead naval field surgeon. Compact sturdy build, tied-back auburn hair, ashen skin with small neat seams and one exposed bone wrist, tiny teal soul-light, no gore. Practical brown leather surgical apron over faded navy tunic, rolled sleeves, gloves, belt instrument roll. Hero holding curved surgical needle and thread; no hammer, anvil, mechanical prosthesis, crown or royal cape. Separate needle, thread spool, surgical shears and instrument roll. Match the supplied stylized faceted low-poly 3D game-art reference, simple matte material, neutral warm-grey background. One character identity only, with one large hero render and three equally scaled full-body orthographic-style FRONT / SIDE / BACK views in identical neutral stance, no held props in the three views. Show detachable props and small palette. English title and view labels only. No other characters, no group lineup, no narrative text, no parchment collage. For final delivery, split the hero, measured turnaround and props into separate files.

### CHAR-MAGE · 奥斯温宫廷法师（Oswin — the Court Mage）
- 简报（中）：单独一张43岁巫妖学者奥斯温的概念板。瘦长，有实体双脚，明显骨质骷髅脸及微弱青绿眼火，褪墨蓝短兜帽，窄灰袍，略佝偻。主立绘持批注手稿及石板，少量漂浮残页；无光环、冠冕、巨杖或悬浮身体。 沿用参考图低多边形材质、暖灰背景；单角色主立绘与同姿势等高正侧背全身视图，三视图卸下道具，独立配件与色板；仅英文标题和视图标注。 最终交付主立绘、精确三视图与道具分文件。
- 简报（英）：A single standalone production concept sheet of Oswin, a 43-year-old undead lich scholar. Thin solid-footed figure, clearly skeletal bone face, dim teal eye lights, short faded ink-blue scholarly hood, narrow layered grey robes, slightly hunched silhouette. Hero holding annotated manuscript and slate with a few detached floating pages. No halo, crown, giant staff or floating body. Separate manuscript and slate. Match the supplied stylized faceted low-poly 3D game-art reference, simple matte material, neutral warm-grey background. One character identity only, with one large hero render and three equally scaled full-body orthographic-style FRONT / SIDE / BACK views in identical neutral stance, no held props in the three views. Show detachable props and small palette. English title and view labels only. No other characters, no group lineup, no narrative text, no parchment collage. For final delivery, split the hero, measured turnaround and props into separate files.

### CHAR-BUGLER · 皮普号手（Pip — the Bugler）
- 简报（中）：单独一张19岁年轻成年亡灵海军号手皮普的概念板。小巧活泼，卡通骷髅脸或局部骨质下颌，青绿眼火，俏皮动作。褪蓝短海军衣、铁锈红领巾、靴、略大铜号和小碎王冠旗；非活人、非儿童。 沿用参考图低多边形材质、暖灰背景；单角色主立绘与同姿势等高正侧背全身视图，三视图卸下道具，独立配件与色板；仅英文标题和视图标注。 最终交付主立绘、精确三视图与道具分文件。
- 简报（英）：A single standalone production concept sheet of Pip, a 19-year-old young adult undead naval bugler. Short lively build, stylized skull or partially skeletal jaw, teal eye lights, expressive mischievous posture. Faded navy short sailor tunic, rust-red scarf, boots, oversized brass bugle and small broken-crown pennant. Not a living human and not a child. Separate brass bugle and pennant. Match the supplied stylized faceted low-poly 3D game-art reference, simple matte material, neutral warm-grey background. One character identity only, with one large hero render and three equally scaled full-body orthographic-style FRONT / SIDE / BACK views in identical neutral stance, no held props in the three views. Show detachable props and small palette. English title and view labels only. No other characters, no group lineup, no narrative text, no parchment collage. For final delivery, split the hero, measured turnaround and props into separate files.

## 风格（硬要求，Lead 已审批的基准）
- 先读 `docs/art-style.md` 第 1–3 节。附图里的风格样张（`art/style/`）就是标准：手绘厚涂加粗细有变化的墨线、修长有棱角的造型、强明暗、平涂阴影、一侧饱和色轮廓光、暗背景。
- canon 简报里凡是写"低多边形、切面、匹配参考图的 3D 质感"的部分**一律忽略**；内容（服装、道具、年龄、配色、禁止项）照简报执行。
- 亡魂用青绿冥火作光色；活人和王国用白金暖光。
- 提示词里不写任何现有游戏、工作室或画师的名字。
- 每张图单独生成，一张一个角色（剧情插画除外）。
- 不从生成图里的偶然文字推出新设定。

## 交付
- 生成图从 `~/.codex/generated_images/` 复制到产物目录；每个主文件另存至少 1 个备选到 `alt/` 子目录。
- `art/chars/RESULTS-T33.json`：每个任务 ID 一条，字段为 `id`、`files`、`alts`、`prompt`、`tool`、`status`（填 `in_review`）、`self_check`（逐条对照简报和风格要求）。
- 交付报告写到 `reports/agents/T33.md`，格式见 docs/collab.md 第 4 节，列出每张图的生成次数和退回原因。
- 自查不过就重画，同一张最多 3 次；仍不过就在报告里写明，不要硬交。
