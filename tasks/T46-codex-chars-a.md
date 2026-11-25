---
id: T46
title: 按 Claude 提示词重画人物 A：王室、渡魂人、旧部（29 张）
owner: codex
status: done
branch: codex/t46-chars-a
worktree: ../亡魂王子-t46
images: [/Users/cyy/Projects/亡魂王子/art/style/prince_hero.png, /Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png, /Users/cyy/Projects/亡魂王子/art/ui/ui_hub.png]
allowed: [art/chars/, art/units/]
forbidden: [art/prompts/, art/style/, art/ui/, scripts/, scenes/, docs/, tasks/, project.godot, assets/]
verify: test -f art/chars/RESULTS-T46.json -o -f art/units/RESULTS-T46.json
retry_limit: 3
max_minutes: 200
escalate_if: [连续 5 张按原提示词生成三次仍不合格]
---

## 目标
上一批人物图风格不统一，全部按 **Claude 写好的提示词** 重新生成。你只负责：生成、选版、复制文件、登记。

## 规则（硬性）
- 每张图的提示词**原样使用**对应的 `art/prompts/rendered/*.txt` 文件全文，**不得改写、增删或"优化"**。附图作为风格参考一起传给生图工具。
- 每张图生成 2 个版本，按下面的自查清单选 1 个；落选版本放进同目录的 `alt/`。
- 某张图两个版本都不合格，可以再生成，最多 3 次；还不合格就在报告里写明哪条没过，不要改提示词，**然后继续做下一张，不要停下整个任务**。只有连续 5 张都失败才停止。
- **续做**：上一轮已经交付了 `CHAR-PRINCE-UNDEAD/turnaround.png`（通过），跳过它；`CHAR-PRINCE-UNDEAD__expressions` 按新清单第 5 条重新判定上一轮的 3 个版本，通过就选用，不必重画。
- 产物路径写死，见下表。人物放 `art/chars/<ID>/`，覆盖同名旧文件。旧文件不用另外备份，git 历史里有。

## 自查清单（逐条写进 RESULTS）
1. 粗黑墨线外轮廓清楚可见
2. 阴影是平涂大色块，没有柔和渐变
3. 一侧有指定颜色的轮廓光
4. 背景暗，人物是画面里最亮的部分
5. 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）。**道具只在主立绘和三视图里检查；表情图是半身像，画不到或没拿道具都算通过。**
6. 三视图：正、侧、背三个视图等高、同姿势、空手
7. 王子：左半边脸是骷髅（观众看是右半边），金冠前方有断口

## 清单（提示词 → 产物）
- `art/prompts/rendered/CHAR-PRINCE-UNDEAD__turnaround.txt` → `art/chars/CHAR-PRINCE-UNDEAD/turnaround.png`
- `art/prompts/rendered/CHAR-PRINCE-UNDEAD__expressions.txt` → `art/chars/CHAR-PRINCE-UNDEAD/expressions.png`
- `art/prompts/rendered/CHAR-PRINCE__hero.txt` → `art/chars/CHAR-PRINCE/hero.png`
- `art/prompts/rendered/CHAR-PRINCE__turnaround.txt` → `art/chars/CHAR-PRINCE/turnaround.png`
- `art/prompts/rendered/CHAR-PRINCE__expressions.txt` → `art/chars/CHAR-PRINCE/expressions.png`
- `art/prompts/rendered/CHAR-QUEEN__hero.txt` → `art/chars/CHAR-QUEEN/hero.png`
- `art/prompts/rendered/CHAR-QUEEN__turnaround.txt` → `art/chars/CHAR-QUEEN/turnaround.png`
- `art/prompts/rendered/CHAR-QUEEN__expressions.txt` → `art/chars/CHAR-QUEEN/expressions.png`
- `art/prompts/rendered/CHAR-FERRYMAN__hero.txt` → `art/chars/CHAR-FERRYMAN/hero.png`
- `art/prompts/rendered/CHAR-FERRYMAN__turnaround.txt` → `art/chars/CHAR-FERRYMAN/turnaround.png`
- `art/prompts/rendered/CHAR-FERRYMAN__expressions.txt` → `art/chars/CHAR-FERRYMAN/expressions.png`
- `art/prompts/rendered/CHAR-KING__hero.txt` → `art/chars/CHAR-KING/hero.png`
- `art/prompts/rendered/CHAR-KING__turnaround.txt` → `art/chars/CHAR-KING/turnaround.png`
- `art/prompts/rendered/CHAR-KING__expressions.txt` → `art/chars/CHAR-KING/expressions.png`
- `art/prompts/rendered/CHAR-MOTHER__hero.txt` → `art/chars/CHAR-MOTHER/hero.png`
- `art/prompts/rendered/CHAR-MOTHER__turnaround.txt` → `art/chars/CHAR-MOTHER/turnaround.png`
- `art/prompts/rendered/CHAR-MOTHER__expressions.txt` → `art/chars/CHAR-MOTHER/expressions.png`
- `art/prompts/rendered/CHAR-CAPTAIN__hero.txt` → `art/chars/CHAR-CAPTAIN/hero.png`
- `art/prompts/rendered/CHAR-CAPTAIN__turnaround.txt` → `art/chars/CHAR-CAPTAIN/turnaround.png`
- `art/prompts/rendered/CHAR-CAPTAIN__expressions.txt` → `art/chars/CHAR-CAPTAIN/expressions.png`
- `art/prompts/rendered/CHAR-STITCHER__hero.txt` → `art/chars/CHAR-STITCHER/hero.png`
- `art/prompts/rendered/CHAR-STITCHER__turnaround.txt` → `art/chars/CHAR-STITCHER/turnaround.png`
- `art/prompts/rendered/CHAR-STITCHER__expressions.txt` → `art/chars/CHAR-STITCHER/expressions.png`
- `art/prompts/rendered/CHAR-MAGE__hero.txt` → `art/chars/CHAR-MAGE/hero.png`
- `art/prompts/rendered/CHAR-MAGE__turnaround.txt` → `art/chars/CHAR-MAGE/turnaround.png`
- `art/prompts/rendered/CHAR-MAGE__expressions.txt` → `art/chars/CHAR-MAGE/expressions.png`
- `art/prompts/rendered/CHAR-BUGLER__hero.txt` → `art/chars/CHAR-BUGLER/hero.png`
- `art/prompts/rendered/CHAR-BUGLER__turnaround.txt` → `art/chars/CHAR-BUGLER/turnaround.png`
- `art/prompts/rendered/CHAR-BUGLER__expressions.txt` → `art/chars/CHAR-BUGLER/expressions.png`

## 交付
- `art/chars/RESULTS-T46.json`（或 `art/units/RESULTS-T46.json`）：每张一条，字段为 `file`、`prompt_file`、`alts`、`attempts`、`checklist`（7 条各写通过或不通过）、`status: in_review`。
- 报告 `reports/agents/T46.md`，开头用 docs/collab.md 第 4 节的 YAML 摘要。
