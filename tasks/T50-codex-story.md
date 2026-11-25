---
id: T50
title: 按 Claude 提示词生成剧情插画 8 张 + 结局图 10 张
owner: codex
status: queued
branch: codex/t50-story
worktree: ../亡魂王子-t50
images: [/Users/cyy/Projects/亡魂王子/art/style/prince_hero.png, /Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png]
allowed: [art/story/]
forbidden: [art/prompts/, art/style/, art/ui/, art/chars/, art/units/, scripts/, scenes/, docs/, tasks/, project.godot, assets/]
verify: test -f art/story/RESULTS-T50.json
retry_limit: 3
max_minutes: 240
escalate_if: [连续 5 张按原提示词生成三次仍不合格]
---

## 目标
按 **Claude 写好的提示词** 生成剧情插画和结局图。你只负责生成、选版、复制文件、登记。

## 规则（硬性）
- 每张图的提示词**原样使用**对应的 `art/prompts/rendered/*.txt` 全文，不得改写。
- 参考图：附图两张风格样张，加上清单里列出的人物主立绘（这些文件在仓库里，传给生图工具作为参考）。
- 每张图生成 2 个版本，选 1 个，落选版本放进同目录的 `alt/`。两个都不合格可以再生成，最多 3 次；还不行就记下原因，**继续做下一张**。
- 碰到生图频率限制就等待恢复，然后继续，不要结束任务。

## 自查清单（逐条写进 RESULTS）
1. 粗黑墨线、平涂阴影，画风和人物参考一致
2. 出场人物的脸、服装、颜色和参考一致（亡灵王子：骷髅脸在观众看的右半边，金冠前方有断口；生前的人物是完整人脸）
3. 场景内容和提示词一致，焦点清楚
4. 光照和提示词一致：冥火青绿只出现在亡灵身上；结局 E05、E07、E08 和真结局是自然光，其他结局在王都时是不自然的白色日光
5. 没有文字，没有多余的手和脚

## 清单（提示词 → 产物）
- `art/prompts/rendered/STORY__ART_B02_01.txt` → `art/story/ART_B02_01/scene.png`；人物参考：`art/chars/CHAR-PRINCE/hero.png`、`art/chars/CHAR-QUEEN/hero.png`
- `art/prompts/rendered/STORY__ART_B02_02.txt` → `art/story/ART_B02_02/scene.png`；人物参考：`art/chars/CHAR-PRINCE/hero.png`、`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-KING/hero.png`
- `art/prompts/rendered/STORY__ART_B02_03.txt` → `art/story/ART_B02_03/scene.png`；人物参考：`art/chars/CHAR-KING/hero.png`、`art/chars/CHAR-ARCHBISHOP/hero.png`
- `art/prompts/rendered/STORY__ART_B02_04.txt` → `art/story/ART_B02_04/scene.png`；人物参考：`art/chars/CHAR-PRINCE/hero.png`、`art/chars/CHAR-CAPTAIN/hero.png`、`art/chars/CHAR-BUGLER/hero.png`
- `art/prompts/rendered/STORY__ART_B02_05.txt` → `art/story/ART_B02_05/scene.png`；人物参考：`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-CHANCELLOR/hero.png`
- `art/prompts/rendered/STORY__ART_B02_06.txt` → `art/story/ART_B02_06/scene.png`；人物参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`、`art/chars/CHAR-CAPTAIN/hero.png`、`art/chars/CHAR-STITCHER/hero.png`、`art/chars/CHAR-MAGE/hero.png`、`art/chars/CHAR-BUGLER/hero.png`
- `art/prompts/rendered/STORY__ART_B02_07.txt` → `art/story/ART_B02_07/scene.png`；人物参考：`art/chars/CHAR-FERRYMAN/hero.png`
- `art/prompts/rendered/STORY__ROYAL-FAMILY-PORTRAIT.txt` → `art/story/ROYAL-FAMILY-PORTRAIT/scene.png`；人物参考：`art/chars/CHAR-PRINCE/hero.png`、`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-KING/hero.png`、`art/chars/CHAR-MOTHER/hero.png`
- `art/prompts/rendered/ENDING__E00.txt` → `art/story/ENDING-E00/ending.png`；人物参考：`art/chars/CHAR-FERRYMAN/hero.png`
- `art/prompts/rendered/ENDING__E01.txt` → `art/story/ENDING-E01/ending.png`；人物参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`、`art/chars/CHAR-QUEEN/hero.png`
- `art/prompts/rendered/ENDING__E02.txt` → `art/story/ENDING-E02/ending.png`；人物参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`、`art/chars/CHAR-CAPTAIN/hero.png`
- `art/prompts/rendered/ENDING__E03.txt` → `art/story/ENDING-E03/ending.png`；人物参考：`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-PRINCE-UNDEAD/hero.png`
- `art/prompts/rendered/ENDING__E04.txt` → `art/story/ENDING-E04/ending.png`；人物参考：`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-PRINCE-UNDEAD/hero.png`、`art/chars/CHAR-BUGLER/hero.png`
- `art/prompts/rendered/ENDING__E05.txt` → `art/story/ENDING-E05/ending.png`；人物参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`
- `art/prompts/rendered/ENDING__E06.txt` → `art/story/ENDING-E06/ending.png`；人物参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`
- `art/prompts/rendered/ENDING__E07.txt` → `art/story/ENDING-E07/ending.png`；人物参考：`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-PRINCE-UNDEAD/hero.png`
- `art/prompts/rendered/ENDING__E08.txt` → `art/story/ENDING-E08/ending.png`；人物参考：`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-BUGLER/hero.png`
- `art/prompts/rendered/ENDING__TRUE.txt` → `art/story/ENDING-TRUE/ending.png`；人物参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`、`art/chars/CHAR-FERRYMAN/hero.png`、`art/chars/CHAR-QUEEN/hero.png`

## 交付
- `art/story/RESULTS-T50.json`：每张一条，字段为 `file`、`prompt_file`、`alts`、`attempts`、`checklist`、`status: in_review`。
- 报告 `reports/agents/T50.md`，开头用 docs/collab.md 第 4 节的 YAML 摘要。
