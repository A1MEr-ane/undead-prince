# 美术资产自动检查 — 2026-11-25 22:07:28

- 根目录：`/Users/cyy/Projects/亡魂王子-t63`
- 扫描范围：`/Users/cyy/Projects/亡魂王子-t63/art` + `assets/sprites/`
- 结论：**26 项硬性失败 / 3 项需人工确认**；PNG 200/200 合法，提示词 110 份，RESULTS 81 条
- 工具：Python 3.15.2 标准库；缩略用 sips-316；Pillow 未使用
- 生成时 HEAD：`d3b6d48`

## 摘要

| 项目 | 结果 |
|---|---|
| 提示词文件（rendered*） | 110 |
| 提示词规格（含 style/ui/compare） | 131 |
| 唯一产物路径 | 86 |
| 缺少产物 | 5 |
| 多余主图 | 0 |
| 未登记备选图 | 1 |
| PNG 总数 / 合法 | 200 / 200 |
| 主图 / 备选 / 精灵 | 81 / 97 / 21 |
| 长宽比异常 | 5 |
| 文件过小 | 0 |
| 疑似重复对 | 2 |
| RESULTS 文件 / 记录 | 6 / 81 |
| status 非法 | 1 |
| RESULTS 引用文件缺失 | 0 |
| checklist 不通过 / 待确认 | 13 / 2 |
| 暗背景通过 / 失败 | 132 / 0 |
| 透明通过 / 失败 | 0 / 0 |

## 需要 Lead 看

### 硬性失败（26）

**清单**

- 提示词缺少产物: art/story/ENDING-E05/ending.png — 来源: art/prompts/rendered/ENDING__E05.txt
- 提示词缺少产物: art/story/ENDING-E06/ending.png — 来源: art/prompts/rendered/ENDING__E06.txt
- 提示词缺少产物: art/story/ENDING-E07/ending.png — 来源: art/prompts/rendered/ENDING__E07.txt
- 提示词缺少产物: art/story/ENDING-E08/ending.png — 来源: art/prompts/rendered/ENDING__E08.txt
- 提示词缺少产物: art/story/ENDING-TRUE/ending.png — 来源: art/prompts/rendered/ENDING__TRUE.txt

**规格**

- 长宽比不符: art/chars/CHAR-CHANCELLOR/alt/hero-v1.png 实际 1.500，规格 0.667（偏差 125.0% > 10%）
- 长宽比不符: art/chars/CHAR-CHANCELLOR/alt/hero-v2.png 实际 1.500，规格 0.667（偏差 125.0% > 10%）
- 长宽比不符: art/ui/alt/kit_boon_frames_B.png 实际 2.000，规格 1.778（偏差 12.5% > 10%）
- 长宽比不符: art/ui/alt/kit_icons_A.png 实际 1.333，规格 1.778（偏差 25.0% > 10%）
- 长宽比不符: art/ui/kit_boon_frames.png 实际 2.000，规格 1.778（偏差 12.5% > 10%）

**重复**

- 疑似重复: art/ui/alt/ui_ending_A.png ↔ art/ui/ui_ending.png — 感知哈希过近 (dHash 2, 色彩 RMS 1.72) — 同一资产的备选
- 疑似重复: art/style/alt/battle_mock_B.png ↔ art/style/battle_mock.png — 感知哈希过近 (dHash 1, 色彩 RMS 2.06) — 同一资产的备选

**RESULTS**

- checklist 不通过: art/chars/CHAR-PRINCE/hero.png — 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 — 不通过：三版均将要求完好的紫披风画成破损下摆；第 1、3 版甲胄还有裂痕。成年活人、完整金冠、胸前完整冠徽及海图出现。
- checklist 不通过: art/chars/CHAR-PRINCE/turnaround.png — 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 — 不通过：三版均有破紫披风和甲胄裂纹，与生前的干净甲胄、完整披风不符；活人面孔、完整金冠、完整胸徽、独立海图和玩具船齐全。
- checklist 不通过: art/chars/CHAR-MAGE/expressions.png — 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 — 不通过：三版均把默认表情画成带唇部软组织的干尸面孔，未明确表现提示词的骷髅脸；其余蓝兜帽、灰袍、皮带、亡灵眼光与三种情绪齐全。表情道具非必需。
- checklist 不通过: art/chars/CHAR-BUGLER/turnaround.png — 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 — 不通过：三版都借用了王子的半脸骷髅和单侧眼眶魂火，偏离皮普灰肤、双青绿眼、下颌裸骨的角色差异；其余成年比例、乱棕发、蓝水手服、红领巾、卷袖、腰带、靴与独立铜号、断冠破旗齐全。
- checklist 不通过: art/chars/CHAR-BUGLER/expressions.png — 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 — 不通过：三版均复制王子式半脸骷髅与单侧眼眶魂火，偏离皮普灰肤、双青绿眼及下颌裸骨的身份特征；成年比例、乱棕发、水手服、红领巾、卷袖和三表情齐全。半身像道具按新规则不作为强制要求。
- checklist 不通过: art/units/chibi_lineup.png — 王子：左半边脸是骷髅（观众看是右半边），金冠前方有断口 — 不通过：放大检查三版，观众右半脸均为骷髅，但金冠前缘均连续，未出现清楚的前方断口。三次原提示词生成后仍不合格，触发escalate_if，停止。
- status 非法: 'review_required'（只允许 in_review / accepted / rejected） — art/compare/RESULTS-T57.json 顶层
- checklist 不通过: art/story/ART_B02_04/scene.png — 人物脸、服装、颜色与参考一致；亡灵王子观众右半脸骷髅、前方断冠；生前完整人脸 — 三人均完整人脸且无冥火；三版王子披风均有裂口，未满足原文 intact purple cape。
- checklist 不通过: art/story/ART_B02_04/scene.png — 场景与提示词一致，焦点清楚 — 伏击、燃船、敌舰、吹号、拒绝救生艇均清楚；三版旗帜布面均破损，保留冠徽完整版本。
- checklist 不通过: art/story/ENDING-E00/ending.png — 人物脸、服装、颜色与参考一致；亡灵王子观众右半脸骷髅、前方断冠；生前完整人脸 — 渡魂人与参考一致，但三版均重复出前景渡魂人，另加王子和队长。
- checklist 不通过: art/story/ENDING-E00/ending.png — 场景与提示词一致，焦点清楚 — 旗帜入水、松手魂火、远船齐全；额外群像占焦点，偏离单一沉旗叙事。
- checklist 不通过: art/story/ENDING-E00/ending.png — 光照与提示词、任务清单一致 — 三版均有多处青灯/冥火；原文要求单青灯，未满足。
- checklist 不通过: art/story/ENDING-E03/ending.png — 场景与提示词一致，焦点清楚 — 女王坐王座、王子扶椅背、朝臣鞠躬齐全；三版都仍像向两人同时行礼，未明确只向王子。
- checklist 不通过: art/story/ENDING-E04/ending.png — 没有文字，没有多余的手和脚 — 三版钟面均有罗马数字，违反无文字；未见多余手脚。

### 需人工确认（3）

- checklist 待确认: art/story/ART_B02_03/scene.png — 光照与提示词、任务清单一致 — 原提示词明确装置青光，与清单冥火只在亡灵身上冲突；按原文保留。人物无青绿冥火。
- checklist 待确认: art/story/ART_B02_07/scene.png — 光照与提示词、任务清单一致 — 原文指定青绿灯照空座；灯及反光不在亡灵身体上，是原文要求，与清单字面冲突。
- 备选图未在 RESULTS 登记: art/story/ENDING-E05/alt/ending-v1.png

## 程序已判定通过

- PNG 完整性：200 个文件签名、chunk CRC、zlib 流和扫描行长度全部通过
- 提示词清单：81/86 个目标路径存在产物；多余主图 0 个
- 长宽比：170/175 张通过；5 张异常见上
- 文件大小：没有小于阈值的图（art 200KB / 精灵 8KB）
- 重复检测：200 张中仅 2 对达到提醒阈值，见上
- RESULTS 结构：81 条记录有文件与 status 字段；status 枚举异常 1 处见上
- RESULTS checklist：81 条记录已解析；13 个“不通过”/ 2 个待确认已单列
- 暗背景：明确要求暗背景的 132 张四角平均亮度均 ≤ 90
- 透明精灵：当前没有要求透明背景的正式资产（--selftest 覆盖 alpha 正反例）

### 通过的主图（68）

| 资产 | 尺寸 | 长宽比 | 规格 | 备注 |
|---|---:|---:|---|---|
| `art/chars/CHAR-ARCHBISHOP/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-ARCHBISHOP/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-ARCHBISHOP/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-BUGLER/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-CAPTAIN/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-CAPTAIN/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-CAPTAIN/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-CHANCELLOR/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-CHANCELLOR/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-CHANCELLOR/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-COUNTESS/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-COUNTESS/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-COUNTESS/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-EARL/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-EARL/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-EARL/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-FERRYMAN/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-FERRYMAN/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-FERRYMAN/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-KING/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-KING/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-KING/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-MAGE/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-MAGE/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-MARSHAL/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-MARSHAL/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-MARSHAL/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-MOTHER/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-MOTHER/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-MOTHER/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-PRINCE/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-PRINCE-UNDEAD/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-PRINCE-UNDEAD/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-QUEEN/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-QUEEN/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-QUEEN/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/chars/CHAR-STITCHER/expressions.png` | 1536×1024 | 1.500 | 1536x1024 (1.500) |  —  |
| `art/chars/CHAR-STITCHER/hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/chars/CHAR-STITCHER/turnaround.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/compare/BERNARD_A.png` | 1122×1402 | 0.800 | 1024x1280 (0.800) | 规格 1024x1280，实际 1122x1402（等比缩放） |
| `art/compare/BERNARD_B.png` | 1122×1402 | 0.800 | 1024x1280 (0.800) | 规格 1024x1280，实际 1122x1402（等比缩放） |
| `art/compare/BERNARD_C.png` | 1122×1402 | 0.800 | 1024x1280 (0.800) | 规格 1024x1280，实际 1122x1402（等比缩放） |
| `art/compare/EDMUND_A.png` | 1122×1402 | 0.800 | 1024x1280 (0.800) | 规格 1024x1280，实际 1122x1402（等比缩放） |
| `art/compare/EDMUND_B.png` | 1122×1402 | 0.800 | 1024x1280 (0.800) | 规格 1024x1280，实际 1122x1402（等比缩放） |
| `art/compare/EDMUND_C.png` | 1122×1402 | 0.800 | 1024x1280 (0.800) | 规格 1024x1280，实际 1122x1402（等比缩放） |
| `art/compare/ELEANOR_A.png` | 1122×1402 | 0.800 | 1024x1280 (0.800) | 规格 1024x1280，实际 1122x1402（等比缩放） |
| `art/compare/ELEANOR_B.png` | 1122×1402 | 0.800 | 1024x1280 (0.800) | 规格 1024x1280，实际 1122x1402（等比缩放） |
| `art/compare/ELEANOR_C.png` | 1122×1402 | 0.800 | 1024x1280 (0.800) | 规格 1024x1280，实际 1122x1402（等比缩放） |
| `art/story/ART_B02_01/scene.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/story/ART_B02_02/scene.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/story/ART_B02_05/scene.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/story/ART_B02_06/scene.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/story/ENDING-E01/ending.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/story/ENDING-E02/ending.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/story/ROYAL-FAMILY-PORTRAIT/scene.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/style/battle_mock.png` | 1672×941 | 1.777 | 无规格 |  —  |
| `art/style/prince_hero.png` | 1024×1536 | 0.667 | 1024x1536 (0.667) |  —  |
| `art/style/ui_boons.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/style/ui_chart.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/style/ui_dialogue.png` | 1672×941 | 1.777 | 比例 1.778 |  —  |
| `art/ui/kit_chart.png` | 1672×941 | 1.777 | 比例 1.778 |  —  |
| `art/ui/kit_frames.png` | 1672×941 | 1.777 | 比例 1.778 |  —  |
| `art/ui/kit_icons.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/ui/ui_ending.png` | 1672×941 | 1.777 | 比例 1.778 |  —  |
| `art/ui/ui_hub.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/ui/ui_hud.png` | 1671×941 | 1.776 | 比例 1.778 |  —  |
| `art/units/kingdom_lineup.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |
| `art/units/undead_lineup.png` | 1672×941 | 1.777 | 2048x1152 (1.778) | 规格 2048x1152，实际 1672x941（等比缩放） |

## 明细

### 感知重复最近邻

| RMS | dHash | 同组 | A | B |
|---:|---:|---|---|---|
| 1.72 | 2 | 是 | `art/ui/alt/ui_ending_A.png` | `art/ui/ui_ending.png` |
| 2.06 | 1 | 是 | `art/style/alt/battle_mock_B.png` | `art/style/battle_mock.png` |
| 5.79 | 18 | 是 | `art/ui/alt/kit_frames_A.png` | `art/ui/kit_frames.png` |
| 6.76 | 5 | 是 | `art/chars/CHAR-STITCHER/alt/turnaround-v1.png` | `art/chars/CHAR-STITCHER/turnaround.png` |
| 7.44 | 6 | 否 | `art/style/battle_mock.png` | `art/ui/ui_hud.png` |
| 7.74 | 7 | 否 | `art/style/alt/battle_mock_B.png` | `art/ui/ui_hud.png` |
| 8.16 | 3 | 是 | `art/chars/CHAR-BUGLER/alt/turnaround-v2.png` | `art/chars/CHAR-BUGLER/turnaround.png` |
| 8.58 | 3 | 是 | `art/chars/CHAR-BUGLER/alt/turnaround-v1.png` | `art/chars/CHAR-BUGLER/alt/turnaround-v2.png` |
| 9.54 | 2 | 是 | `art/chars/CHAR-BUGLER/alt/turnaround-v1.png` | `art/chars/CHAR-BUGLER/turnaround.png` |
| 9.96 | 5 | 是 | `art/chars/CHAR-MARSHAL/alt/turnaround-v2.png` | `art/chars/CHAR-MARSHAL/turnaround.png` |
| 10.30 | 16 | 是 | `art/chars/CHAR-FERRYMAN/alt/turnaround-v2.png` | `art/chars/CHAR-FERRYMAN/turnaround.png` |
| 10.32 | 14 | 是 | `art/ui/alt/kit_boon_frames_B.png` | `art/ui/kit_boon_frames.png` |
| 10.66 | 23 | 是 | `art/units/alt/chibi_lineup-v1.png` | `art/units/alt/chibi_lineup-v3.png` |
| 10.68 | 13 | 是 | `art/units/alt/chibi_lineup-v3.png` | `art/units/chibi_lineup.png` |
| 10.83 | 10 | 是 | `art/chars/CHAR-EARL/alt/turnaround-v1.png` | `art/chars/CHAR-EARL/turnaround.png` |

### checklist 不通过 / 待确认

| 类型 | 文件 | 检查项 | 备注 |
|---|---|---|---|
| 不通过 | `art/chars/CHAR-PRINCE/hero.png` | 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 | 不通过：三版均将要求完好的紫披风画成破损下摆；第 1、3 版甲胄还有裂痕。成年活人、完整金冠、胸前完整冠徽及海图出现。 |
| 不通过 | `art/chars/CHAR-PRINCE/turnaround.png` | 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 | 不通过：三版均有破紫披风和甲胄裂纹，与生前的干净甲胄、完整披风不符；活人面孔、完整金冠、完整胸徽、独立海图和玩具船齐全。 |
| 不通过 | `art/chars/CHAR-MAGE/expressions.png` | 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 | 不通过：三版均把默认表情画成带唇部软组织的干尸面孔，未明确表现提示词的骷髅脸；其余蓝兜帽、灰袍、皮带、亡灵眼光与三种情绪齐全。表情道具非必需。 |
| 不通过 | `art/chars/CHAR-BUGLER/turnaround.png` | 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 | 不通过：三版都借用了王子的半脸骷髅和单侧眼眶魂火，偏离皮普灰肤、双青绿眼、下颌裸骨的角色差异；其余成年比例、乱棕发、蓝水手服、红领巾、卷袖、腰带、靴与独立铜号、断冠破旗齐全。 |
| 不通过 | `art/chars/CHAR-BUGLER/expressions.png` | 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）；道具仅检查主立绘和三视图，表情半身像可不出现道具 | 不通过：三版均复制王子式半脸骷髅与单侧眼眶魂火，偏离皮普灰肤、双青绿眼及下颌裸骨的身份特征；成年比例、乱棕发、水手服、红领巾、卷袖和三表情齐全。半身像道具按新规则不作为强制要求。 |
| 不通过 | `art/units/chibi_lineup.png` | 王子：左半边脸是骷髅（观众看是右半边），金冠前方有断口 | 不通过：放大检查三版，观众右半脸均为骷髅，但金冠前缘均连续，未出现清楚的前方断口。三次原提示词生成后仍不合格，触发escalate_if，停止。 |
| 待确认 | `art/story/ART_B02_03/scene.png` | 光照与提示词、任务清单一致 | 原提示词明确装置青光，与清单冥火只在亡灵身上冲突；按原文保留。人物无青绿冥火。 |
| 不通过 | `art/story/ART_B02_04/scene.png` | 人物脸、服装、颜色与参考一致；亡灵王子观众右半脸骷髅、前方断冠；生前完整人脸 | 三人均完整人脸且无冥火；三版王子披风均有裂口，未满足原文 intact purple cape。 |
| 不通过 | `art/story/ART_B02_04/scene.png` | 场景与提示词一致，焦点清楚 | 伏击、燃船、敌舰、吹号、拒绝救生艇均清楚；三版旗帜布面均破损，保留冠徽完整版本。 |
| 待确认 | `art/story/ART_B02_07/scene.png` | 光照与提示词、任务清单一致 | 原文指定青绿灯照空座；灯及反光不在亡灵身体上，是原文要求，与清单字面冲突。 |
| 不通过 | `art/story/ENDING-E00/ending.png` | 人物脸、服装、颜色与参考一致；亡灵王子观众右半脸骷髅、前方断冠；生前完整人脸 | 渡魂人与参考一致，但三版均重复出前景渡魂人，另加王子和队长。 |
| 不通过 | `art/story/ENDING-E00/ending.png` | 场景与提示词一致，焦点清楚 | 旗帜入水、松手魂火、远船齐全；额外群像占焦点，偏离单一沉旗叙事。 |
| 不通过 | `art/story/ENDING-E00/ending.png` | 光照与提示词、任务清单一致 | 三版均有多处青灯/冥火；原文要求单青灯，未满足。 |
| 不通过 | `art/story/ENDING-E03/ending.png` | 场景与提示词一致，焦点清楚 | 女王坐王座、王子扶椅背、朝臣鞠躬齐全；三版都仍像向两人同时行礼，未明确只向王子。 |
| 不通过 | `art/story/ENDING-E04/ending.png` | 没有文字，没有多余的手和脚 | 三版钟面均有罗马数字，违反无文字；未见多余手脚。 |

### 说明

- 7 条 RESULTS 的 self_check 是文字清单，没有机器可读的 result/status，按“字段存在”处理，未计入不通过。
- art/archive/ 为历史低模产物，默认不纳入清单、重复和背景检查。
- 剧情插画/结局图的光照由场景决定，未按“暗背景”强制检查；只检查提示词明确要求暗背景的资产。
- 像素尺寸与提示词目标不同但长宽比在 ±10% 内的，记为等比缩放，不判失败。
- rendered_v2/ 与 rendered/ 的提示词共用同一产物路径；脚本只能确认路径存在，不能判断文件是否已按 v2 提示词重生成。
- assets/sprites/ 里的 preview/parts/uv/comparison/view 历史管线预览图只查 PNG 与文件大小，不参与重复、暗背景和透明检查；其余精灵默认检查 alpha，也可用 --transparent-glob 指定。

