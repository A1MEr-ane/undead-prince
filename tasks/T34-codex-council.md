---
id: T34
title: 新画风人物 3：五名仇人（伯爵、女伯爵、大主教、元帅、宰相）
owner: codex
status: queued
branch: codex/t34-council
worktree: ../亡魂王子-t34
images: [/Users/cyy/Projects/亡魂王子/art/style/prince_hero.png, /Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png]
allowed: [art/chars/]
forbidden: [scripts/, scenes/, docs/, tasks/, project.godot, assets/, art/style/, art/archive/]
verify: test -f art/chars/CHAR-EARL/hero.png && test -f art/chars/RESULTS-T34.json
retry_limit: 3
max_minutes: 180
escalate_if: [需要改动世界观或人物设定, 同一张图重试三次仍不合格]
---

## 目标
用户决定全部人物改成新画风（docs/art-style.md）。本批重画以下角色，供对话立绘、设定集和以后建模使用。
五人是首领，各自要有一眼能分的剪影和一个代表物（简报里的账本、钥匙、印章、训练剑、印匣）。全部是活人：白金暖光，身上带摄政红斜带标记。不要丑化成反派脸，canon 要求他们各有理由。

## 每个角色交 3 张（放在 `art/chars/<任务ID>/`）
1. `hero.png`：全身主立绘，竖版约 2:3，有姿态和戏剧张力，暗背景。
2. `turnaround.png`：横版，正、侧、背三视图，同一中性站姿、等高、空手；道具单独排在右侧；左上英文名字，视图标注只用 FRONT / SIDE / BACK / PROPS。用于建模参考，所以三视图要比例一致、服装细节对应。
3. `expressions.png`：横版，同一角色的三张对话半身像并排（构图同附图 2 里的半身像）：平静，以及两种最能体现该角色性格的表情（从 `docs/canon/B/B1-CORE-CHARACTERS.md`、`B2-HOUSE-AND-COUNCIL.md` 的人物语气推出，在 RESULTS.json 里写明选了哪两种、为什么）。

## 先读
- `docs/canon/B/B4-PRODUCTION-SPEC.md` 中对应角色的段落
- `docs/canon/B/B1-CORE-CHARACTERS.md`、`B2-HOUSE-AND-COUNCIL.md` 中对应角色（性格、年龄、外貌）
- `docs/art-style.md` 第 3 节的角色主色

## 角色与 canon 简报
### CHAR-EARL · 罗德里克伯爵（Earl Roderick）
- 简报（中）：毛边商贸贵族外衣，海蓝与暖棕，账簿、税印，整洁胡须。 善交际、讲究、自然微笑；避免贪婪 caricature。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Fur-edged merchant noble coat, navy and warm brown, ledger and customs seal, neat moustache or beard. Sociable, polished, easy smile; not a caricature of greed. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-COUNTESS · 阿格尼丝女伯爵（Countess Agnes）
- 简报（中）：深赭黄及橄榄色实用贵族服，仓库钥匙、蜡板。 果断的庄园管理者，不套用邪恶女王形象。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Structured practical gown in deep ochre and olive, warehouse keys, wax tablet. Decisive estate administrator, not a wicked queen archetype. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-ARCHBISHOP · 安塞姆大主教（Archbishop Anselm）
- 简报（中）：白色日纹祭服、暗金刺绣、旧祈祷书、官印；高直剪影。 诚恳神情、仪式性克制，不用邪眼或恶魔元素。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：White sun vestments, muted gold stitching, old prayer book, official seal; upright tall silhouette. Earnest expression, ceremonial restraint; no sinister eyes or demonic elements. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-MARSHAL · 休元帅（Lord Marshal Hugh）
- 简报（中）：方正钢甲、海军蓝披风、指挥旗、实用佩剑；练习剑是独立故事道具。 严肃守纪的老兵，横向肩部剪影鲜明。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Squared steel armour, navy mantle, command pennant, practical blade. A training sword is a separate story prop. Disciplined, austere veteran; strong horizontal shoulders. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

### CHAR-CHANCELLOR · 沃尔特宰相（Lord Chancellor Walter）
- 简报（中）：暗酒红与炭灰官服，细摄政徽记、印盒、整齐捆扎的文书。 礼貌镇定的文官；不戴王冠、不穿甲、不做戏剧化邪恶造型。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。
- 简报（英）：Dark burgundy and charcoal official robes, thin regency insignia, seal case and neatly tied papers. Polite, composed bureaucrat; no crown, armour, or theatrical evil. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

## 风格（硬要求，Lead 已审批的基准）
- 先读 `docs/art-style.md` 第 1–3 节。附图里的风格样张（`art/style/`）就是标准：手绘厚涂加粗细有变化的墨线、修长有棱角的造型、强明暗、平涂阴影、一侧饱和色轮廓光、暗背景。
- canon 简报里凡是写"低多边形、切面、匹配参考图的 3D 质感"的部分**一律忽略**；内容（服装、道具、年龄、配色、禁止项）照简报执行。
- 亡魂用青绿冥火作光色；活人和王国用白金暖光。
- 提示词里不写任何现有游戏、工作室或画师的名字。
- 每张图单独生成，一张一个角色（剧情插画除外）。
- 不从生成图里的偶然文字推出新设定。

## 交付
- 生成图从 `~/.codex/generated_images/` 复制到产物目录；每个主文件另存至少 1 个备选到 `alt/` 子目录。
- `art/chars/RESULTS-T34.json`：每个任务 ID 一条，字段为 `id`、`files`、`alts`、`prompt`、`tool`、`status`（填 `in_review`）、`self_check`（逐条对照简报和风格要求）。
- 交付报告写到 `reports/agents/T34.md`，格式见 docs/collab.md 第 4 节，列出每张图的生成次数和退回原因。
- 自查不过就重画，同一张最多 3 次；仍不过就在报告里写明，不要硬交。
