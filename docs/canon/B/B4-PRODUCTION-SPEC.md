# B.4 — Character & Narrative Art Production / 人物与叙事美术生产

**Art production delegated to Claude → Codex.** All existing images are reference drafts, not final orthographic assets. Do not generate more images in the current narrative chat. / 美术生产交给Claude指挥Codex。已有图是参考稿，不是最终正交资产；本叙事对话不再生图。

## Authoritative production queue / 生产任务表

`shared/ART-PRODUCTION-QUEUE.json` is the source of tasks and dependencies. Character identity must be approved before modelling; props and orthographic views are separate output files. Use English labels only. / 上述JSON为任务及依赖基准；角色身份确认后再建模，道具与正交图单文件交付，仅英文标注。

## Review gate / 验收门

- Subject: only one identity per character sheet, right age, occupation, living/undead state, no unrelated figures. / 单人身份正确、年龄职业及生死状态正确，无他人。
- Orthographic: neutral stance, matched height and ground line, actual side profile, front/back symmetry and consistent asymmetric features; detachable equipment outside views. Compare crown, seams, insignia and cloak; no accidental mirrored left/right. / 中性姿势、等高同地线、真侧面、正背及不对称细节一致，卸下道具，核对冠、缝线、纹章、披风，避免误镜像。
- Render quality: original prince's stylised faceted volumes, restrained material wear. No invented lore from generated text. / 原王子卡通低多边形体块、克制磨损；不采信图内自动生成的设定。
- Failure: quarantine and record actual discrepancy. Retry once with isolated input, then route to manual revision instead of unbounded generation. Cause of earlier identity drift remains unknown. / 错图隔离并记录差异；隔离输入后最多自动重试一次，仍错转人工修订，避免无限抽图。此前串题技术原因未确认。
- Only mark accepted after reviewing all views. Generated concept is never labelled model-ready without geometric review. / 审阅全部视图后方可标记验收；未做几何审查不得宣称可直接建模。

## CHAR-PRINCE · Edmund — before the wreck / 生前埃德蒙

Royal naval officer; dark swept hair, intact narrow gold crown, white-gold plate with unbroken crown badge, purple mantle, ordinary steel sword. Keep the original undead head and limb proportions. Controlled pride; upright stance, one hand on sword pommel. No soul-fire, exposed bone or wreck damage. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

王室海军军官；深色侧扫发型、完整窄金冠、带完整王冠徽的白金甲、紫披风、普通钢剑。沿用原亡灵图头身与四肢比例。 克制的骄傲；挺拔，一手扶剑柄。不出现冥火、裸骨或沉船损伤。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-QUEEN · Eleanor — the Queen / 埃莉诺女王

Age twenty; family resemblance through dark hair and brow shape. Ivory gown with muted gold edging, narrow red regency sash, simple intact crown, repaired wooden boat. Composed adult sovereign, attentive and upright; formal court dress, not battle armour. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

二十岁；深发与眉形体现家族相似。象牙白长袍、暗金边、细红摄政绶带、完整简冠、修过的木船。 成年女王，沉着专注，站姿端正；正式宫廷服，不用战甲。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `concept_review_then_turnaround`

## CHAR-FERRYMAN · The Ferryman / 渡魂人

Tall floating silhouette; intact layered maritime funerary vestments in midnight charcoal, ivory and muted bronze. Faceless hood, translucent cyan-green hems, old oar and single soulfire lantern. No halo or visible anatomy that confirms his nature. Still and dignified; spectral weightlessness, restrained gestures. Never confirm his species. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

高瘦悬浮剪影；完整层叠海葬祭服，深炭蓝、象牙白与暗铜。兜帽内无可辨认面孔，青绿半透明袍尾，旧桨与一盏冥火灯。不设神环或能确认身份的裸露形体。 静穆庄严，具有亡魂失重感，动作克制；不确认其种族。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `concept_review_then_turnaround`

## CHAR-KING · King Aldric / 阿尔德里克国王

Broad, ageing face with family brow, silver-black beard, sober white and gold court robe, dark purple lining, royal signet. Full crown for formal portraits. Authority worn down by responsibility; seated or standing over documents. No villain coding. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

宽厚而衰老的脸，家族眉形，银黑短须，克制的白金宫廷袍与深紫内衬，王室印玺。正式肖像佩完整王冠。 责任压出的疲惫威仪；可坐于案前或站立。不使用反派化符号。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-MOTHER · Queen Beatrice / 贝阿特丽斯王后

Coastal noble dress, soft cream and marine blue-grey, modest gold clasp with a wave motif. Living figure only. Warm attention and practical judgement; no spectral version. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

沿海贵族服饰，柔和米白与海灰蓝，带波浪纹的简洁金扣。只设计生前形象。 温和专注，有务实判断。不做幽灵版本。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-CAPTAIN · Captain Bernard / 伯纳德卫队长

Wide sturdy silhouette, enclosed naval helm, scratched insignia, worn shield, restrained turquoise in visor slit. Professional, grounded, careful with equipment; no ornate horns. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

宽厚稳固剪影、封闭海军头盔、磨损纹章、旧盾牌；面罩缝内少量青绿光。 专业、沉稳，爱惜装备；不使用夸张骨角。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `concept_review_then_turnaround`

## CHAR-STITCHER · Matilda — the Stitcher / 玛蒂尔达缝合匠

Compact silhouette, patched surgeon apron over old naval clothes, instrument roll, gloves; small seams and subtle soulfire, not gore. Busy, amused and competent; hands engaged with tools. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

紧凑剪影，旧军服外穿补丁军医围裙、器械卷、手套；细小缝线与少量冥火，不做血腥效果。 忙碌、风趣、专业；双手操持工具。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-MAGE · Oswin — the Court Mage / 奥斯温宫廷法师

Thin lich silhouette, scholarly hood, layered faded cloth, slate and a few floating manuscript fragments, teal soul-light. Exacting scholar rather than battle sorcerer. Keep silhouette distinct from the Ferryman. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

瘦长巫妖剪影、学者兜帽、层叠褪色布料、石板及少数漂浮残页、青绿魂光。 严谨学者而非战斗术士；剪影必须与渡魂人区分。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-BUGLER · Pip — the Bugler / 皮普号手

Small lively young undead sailor, oversized brass bugle, frayed crown pennant, simple naval tunic, boots. Impish posture, exaggerated movement rather than grotesque face. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

活泼年轻亡灵水手，小巧体态，略大的铜号、破王冠军旗、简洁海军衣与靴。 俏皮姿势，靠夸张动作而非怪诞面部表现。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-EARL · Earl Roderick / 罗德里克伯爵

Fur-edged merchant noble coat, navy and warm brown, ledger and customs seal, neat moustache or beard. Sociable, polished, easy smile; not a caricature of greed. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

毛边商贸贵族外衣，海蓝与暖棕，账簿、税印，整洁胡须。 善交际、讲究、自然微笑；避免贪婪 caricature。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-COUNTESS · Countess Agnes / 阿格尼丝女伯爵

Structured practical gown in deep ochre and olive, warehouse keys, wax tablet. Decisive estate administrator, not a wicked queen archetype. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

深赭黄及橄榄色实用贵族服，仓库钥匙、蜡板。 果断的庄园管理者，不套用邪恶女王形象。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-ARCHBISHOP · Archbishop Anselm / 安塞姆大主教

White sun vestments, muted gold stitching, old prayer book, official seal; upright tall silhouette. Earnest expression, ceremonial restraint; no sinister eyes or demonic elements. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

白色日纹祭服、暗金刺绣、旧祈祷书、官印；高直剪影。 诚恳神情、仪式性克制，不用邪眼或恶魔元素。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-MARSHAL · Lord Marshal Hugh / 休元帅

Squared steel armour, navy mantle, command pennant, practical blade. A training sword is a separate story prop. Disciplined, austere veteran; strong horizontal shoulders. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

方正钢甲、海军蓝披风、指挥旗、实用佩剑；练习剑是独立故事道具。 严肃守纪的老兵，横向肩部剪影鲜明。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-CHANCELLOR · Lord Chancellor Walter / 沃尔特宰相

Dark burgundy and charcoal official robes, thin regency insignia, seal case and neatly tied papers. Polite, composed bureaucrat; no crown, armour, or theatrical evil. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

暗酒红与炭灰官服，细摄政徽记、印盒、整齐捆扎的文书。 礼貌镇定的文官；不戴王冠、不穿甲、不做戏剧化邪恶造型。 每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `pending`

## CHAR-PRINCE-UNDEAD · Edmund — The Undead Prince / 亡灵埃德蒙

Preserve original half-skeletal jaw, teal eye and soul blade, broken crown, worn ivory armour and torn purple cape. Only one character identity per output file; hero, turnaround and props are separate deliverables. Neutral warm-grey background, faceted low-poly 3D, matte surfaces. English labels only. No story text or collage of other characters. Hero pose and separate full-body neutral front, exact side, back views at matched scale and ground line; detachable props shown separately. Concept must be checked before measured turnaround production.

保留原图半骷髅下颌、青绿眼火与冥火剑、断冠、白金旧甲及破紫披风。每份输出仅一个角色身份；主立绘、三视图、道具分文件；暖灰底、低多边形块面、哑光材质；纯英文标注，不混入其他角色或剧情文字。主立绘及独立等高同地线正侧背全身中性姿态，配件另列；概念通过审阅后再做精确建模三视图。

Status / 状态: `concept_review_then_turnaround`

