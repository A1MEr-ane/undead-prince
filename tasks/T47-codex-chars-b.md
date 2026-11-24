---
id: T47
title: 按 Claude 提示词重画人物 B：五名仇人 + 兵种阵容（18 张）
owner: codex
status: queued
branch: codex/t47-chars-b
worktree: ../亡魂王子-t47
images: [/Users/cyy/Projects/亡魂王子/art/style/prince_hero.png, /Users/cyy/Projects/亡魂王子/art/style/ui_dialogue.png, /Users/cyy/Projects/亡魂王子/art/ui/ui_hub.png]
allowed: [art/chars/, art/units/]
forbidden: [art/prompts/, art/style/, art/ui/, scripts/, scenes/, docs/, tasks/, project.godot, assets/]
verify: test -f art/chars/RESULTS-T47.json -o -f art/units/RESULTS-T47.json
retry_limit: 3
max_minutes: 200
escalate_if: [某张图按原提示词生成三次仍不合格]
---

## 目标
上一批人物图风格不统一，全部按 **Claude 写好的提示词** 重新生成。你只负责：生成、选版、复制文件、登记。

## 规则（硬性）
- 每张图的提示词**原样使用**对应的 `art/prompts/rendered/*.txt` 文件全文，**不得改写、增删或"优化"**。附图作为风格参考一起传给生图工具。
- 每张图生成 2 个版本，按下面的自查清单选 1 个；落选版本放进同目录的 `alt/`。
- 某张图两个版本都不合格，可以再生成，最多 3 次；还不合格就在报告里写明哪条没过，不要改提示词。
- 产物路径写死，见下表。人物放 `art/chars/<ID>/`，覆盖同名旧文件。旧文件不用另外备份，git 历史里有。

## 自查清单（逐条写进 RESULTS）
1. 粗黑墨线外轮廓清楚可见
2. 阴影是平涂大色块，没有柔和渐变
3. 一侧有指定颜色的轮廓光
4. 背景暗，人物是画面里最亮的部分
5. 提示词里的身份特征全部出现（年龄、服装、亡灵或活人）。道具只在主立绘和三视图里检查；表情图是半身像，没拿道具也算通过。
6. 三视图：正、侧、背三个视图等高、同姿势、空手
7. 王子：左半边脸是骷髅（观众看是右半边），金冠前方有断口

## 清单（提示词 → 产物）
- `art/prompts/rendered/CHAR-EARL__hero.txt` → `art/chars/CHAR-EARL/hero.png`
- `art/prompts/rendered/CHAR-EARL__turnaround.txt` → `art/chars/CHAR-EARL/turnaround.png`
- `art/prompts/rendered/CHAR-EARL__expressions.txt` → `art/chars/CHAR-EARL/expressions.png`
- `art/prompts/rendered/CHAR-COUNTESS__hero.txt` → `art/chars/CHAR-COUNTESS/hero.png`
- `art/prompts/rendered/CHAR-COUNTESS__turnaround.txt` → `art/chars/CHAR-COUNTESS/turnaround.png`
- `art/prompts/rendered/CHAR-COUNTESS__expressions.txt` → `art/chars/CHAR-COUNTESS/expressions.png`
- `art/prompts/rendered/CHAR-ARCHBISHOP__hero.txt` → `art/chars/CHAR-ARCHBISHOP/hero.png`
- `art/prompts/rendered/CHAR-ARCHBISHOP__turnaround.txt` → `art/chars/CHAR-ARCHBISHOP/turnaround.png`
- `art/prompts/rendered/CHAR-ARCHBISHOP__expressions.txt` → `art/chars/CHAR-ARCHBISHOP/expressions.png`
- `art/prompts/rendered/CHAR-MARSHAL__hero.txt` → `art/chars/CHAR-MARSHAL/hero.png`
- `art/prompts/rendered/CHAR-MARSHAL__turnaround.txt` → `art/chars/CHAR-MARSHAL/turnaround.png`
- `art/prompts/rendered/CHAR-MARSHAL__expressions.txt` → `art/chars/CHAR-MARSHAL/expressions.png`
- `art/prompts/rendered/CHAR-CHANCELLOR__hero.txt` → `art/chars/CHAR-CHANCELLOR/hero.png`
- `art/prompts/rendered/CHAR-CHANCELLOR__turnaround.txt` → `art/chars/CHAR-CHANCELLOR/turnaround.png`
- `art/prompts/rendered/CHAR-CHANCELLOR__expressions.txt` → `art/chars/CHAR-CHANCELLOR/expressions.png`
- `art/prompts/rendered/UNITS__undead_lineup.txt` → `art/units/undead_lineup.png`
- `art/prompts/rendered/UNITS__kingdom_lineup.txt` → `art/units/kingdom_lineup.png`
- `art/prompts/rendered/UNITS__chibi_lineup.txt` → `art/units/chibi_lineup.png`

## 交付
- `art/chars/RESULTS-T47.json`（或 `art/units/RESULTS-T47.json`）：每张一条，字段为 `file`、`prompt_file`、`alts`、`attempts`、`checklist`（7 条各写通过或不通过）、`status: in_review`。
- 报告 `reports/agents/T47.md`，开头用 docs/collab.md 第 4 节的 YAML 摘要。
