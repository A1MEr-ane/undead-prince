---
id: T32
title: 新画风人物 1：王子（生前/亡灵）、女王、国王、王后、渡魂人
owner: codex
status: queued
branch: codex/t32-royals
worktree: ../亡魂王子-t32
images: [/Users/cyy/Projects/亡魂王子/art/style/prince_hero.png, /Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png]
allowed: [art/chars/]
forbidden: [scripts/, scenes/, docs/, tasks/, project.godot, assets/, art/style/, art/archive/]
verify: test -f art/chars/CHAR-PRINCE-UNDEAD/hero.png && test -f art/chars/RESULTS-T32.json
retry_limit: 3
max_minutes: 180
escalate_if: [需要改动世界观或人物设定, 同一张图重试三次仍不合格]
---

## 目标
用户决定全部人物改成新画风（docs/art-style.md）。本批重画以下角色，供对话立绘、设定集和以后建模使用。
亡灵王子的造型以附图 1（`art/style/prince_hero.png`，已审批）为准，三视图和表情必须和它一致；hero.png 可以直接复用这张（复制即可，不必重画）。生前埃德蒙与亡灵版是同一张脸。兄妹要有家族相似（深色头发、眉形）。渡魂人：无脸兜帽、完整幽冥祭服、半透明悬浮袍尾，不露种族。

## 每个角色交 3 张（放在 `art/chars/<任务ID>/`）
1. `hero.png`：全身主立绘，竖版约 2:3，有姿态和戏剧张力，暗背景。
2. `turnaround.png`：横版，正、侧、背三视图，同一中性站姿、等高、空手；道具单独排在右侧；左上英文名字，视图标注只用 FRONT / SIDE / BACK / PROPS。用于建模参考，所以三视图要比例一致、服装细节对应。
3. `expressions.png`：横版，同一角色的三张对话半身像并排（构图同附图 2 里的半身像）：平静，以及两种最能体现该角色性格的表情（从 `docs/canon/B/B1-CORE-CHARACTERS.md`、`B2-HOUSE-AND-COUNCIL.md` 的人物语气推出，在 RESULTS.json 里写明选了哪两种、为什么）。

## 先读
- `docs/canon/B/B4-PRODUCTION-SPEC.md` 中对应角色的段落
- `docs/canon/B/B1-CORE-CHARACTERS.md`、`B2-HOUSE-AND-COUNCIL.md` 中对应角色（性格、年龄、外貌）
- `docs/art-style.md` 第 3 节的角色主色

## 角色与 canon 简报
### CHAR-PRINCE-UNDEAD · 亡灵埃德蒙（Edmund — The Undead Prince）
- 简报（中）：保留原图半骷髅下颌、青绿眼火与冥火剑、断冠、白金旧甲及破紫披风。每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Preserve original half-skeletal jaw, teal eye and soul blade, broken crown, worn ivory armour and torn purple cape. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-PRINCE · 生前埃德蒙（Edmund — before the wreck）
- 简报（中）：王室海军军官；深色侧扫发型、完整窄金冠、带完整王冠徽的白金甲、紫披风、普通钢剑。沿用原亡灵图头身与四肢比例。 克制的骄傲；挺拔，一手扶剑柄。不出现冥火、裸骨或沉船损伤。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Royal naval officer; dark swept hair, intact narrow gold crown, white-gold plate with unbroken crown badge, purple mantle, ordinary steel sword. Keep the original undead head and limb proportions. Controlled pride; upright stance, one hand on sword pommel. No soul-fire, exposed bone or wreck damage. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-QUEEN · 埃莉诺女王（Eleanor — the Queen）
- 简报（中）：二十岁；深发与眉形体现家族相似。象牙白长袍、暗金边、细红摄政绶带、完整简冠、修过的木船。 成年女王，沉着专注，站姿端正；正式宫廷服，不用战甲。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Age twenty; family resemblance through dark hair and brow shape. Ivory gown with muted gold edging, narrow red regency sash, simple intact crown, repaired wooden boat. Composed adult sovereign, attentive and upright; formal court dress, not battle armour. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-KING · 阿尔德里克国王（King Aldric）
- 简报（中）：宽厚而衰老的脸，家族眉形，银黑短须，克制的白金宫廷袍与深紫内衬，王室印玺。正式肖像佩完整王冠。 责任压出的疲惫威仪；可坐于案前或站立。不使用反派化符号。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Broad, ageing face with family brow, silver-black beard, sober white and gold court robe, dark purple lining, royal signet. Full crown for formal portraits. Authority worn down by responsibility; seated or standing over documents. No villain coding. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-MOTHER · 贝阿特丽斯王后（Queen Beatrice）
- 简报（中）：沿海贵族服饰，柔和米白与海灰蓝，带波浪纹的简洁金扣。只设计生前形象。 温和专注，有务实判断。不做幽灵版本。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Coastal noble dress, soft cream and marine blue-grey, modest gold clasp with a wave motif. Living figure only. Warm attention and practical judgement; no spectral version. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-FERRYMAN · 渡魂人（The Ferryman）
- 简报（中）：高瘦悬浮剪影；完整层叠海葬祭服，深炭蓝、象牙白与暗铜。兜帽内无可辨认面孔，青绿半透明袍尾，旧桨与一盏冥火灯。不设神环或能确认身份的裸露形体。 静穆庄严，具有亡魂失重感，动作克制；不确认其种族。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Tall floating silhouette; intact layered maritime funerary vestments in midnight charcoal, ivory and muted bronze. Faceless hood, translucent cyan-green hems, old oar and single soulfire lantern. No halo or visible anatomy that confirms his nature. Still and dignified; spectral weightlessness, restrained gestures. Never confirm his species. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

## 风格（硬要求，Lead 已审批的基准）
- 先读 `docs/art-style.md` 第 1–3 节。附图里的风格样张（`art/style/`）就是标准：手绘厚涂加粗细有变化的墨线、修长有棱角的造型、强明暗、平涂阴影、一侧饱和色轮廓光、暗背景。
- canon 简报里凡是写"低多边形、切面、匹配参考图的 3D 质感"的部分**一律忽略**；内容（服装、道具、年龄、配色、禁止项）照简报执行。
- 亡魂用青绿冥火作光色；活人和王国用白金暖光。
- 提示词里不写任何现有游戏、工作室或画师的名字。
- 每张图单独生成，一张一个角色（剧情插画除外）。
- 不从生成图里的偶然文字推出新设定。

## 交付
- 生成图从 `~/.codex/generated_images/` 复制到产物目录；每个主文件另存至少 1 个备选到 `alt/` 子目录。
- `art/chars/RESULTS-T32.json`：每个任务 ID 一条，字段为 `id`、`files`、`alts`、`prompt`、`tool`、`status`（填 `in_review`）、`self_check`（逐条对照简报和风格要求）。
- 交付报告写到 `reports/agents/T32.md`，格式见 docs/collab.md 第 4 节，列出每张图的生成次数和退回原因。
- 自查不过就重画，同一张最多 3 次；仍不过就在报告里写明，不要硬交。
