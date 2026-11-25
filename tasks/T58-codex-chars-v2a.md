---
id: T58
title: 立绘 A 风格重画 1：王室、渡魂人、旧部（30 张）
owner: codex
status: queued
branch: codex/t58-chars-v2a
worktree: ../亡魂王子-t58
images: [/Users/cyy/Projects/亡魂王子/art/compare/EDMUND_A.png, /Users/cyy/Projects/亡魂王子/art/compare/ELEANOR_A.png, /Users/cyy/Projects/亡魂王子/art/compare/BERNARD_A.png]
allowed: [art/chars/]
forbidden: [art/prompts/, art/compare/, art/style/, art/ui/, art/units/, art/story/, scripts/, scenes/, docs/, tasks/, project.godot, assets/]
verify: test -f art/chars/RESULTS-T58.json
retry_limit: 3
max_minutes: 300
escalate_if: [连续 5 张按原提示词生成三次仍不合格]
---

## 目标
用户选定立绘风格 A（精炼墨线）。按 **Claude 写好的提示词** 重画人物，同时换上新的体型和动作。你只负责生成、选版、复制、登记。

## 规则（硬性）
- 每张图**原样使用**对应的 `art/prompts/rendered_v2/*.txt` 全文，不得改写。
- 参考图：附图三张是已审批的 A 风格样张（渲染风格的标准），再加上清单里该角色的身份参考图（只用于长相和服装）。**开始前先把身份参考图复制一份到 `art/chars/<ID>/v1/`**，因为新图会覆盖同名旧文件。
- 每张生成 2 版选 1；落选放 `art/chars/<ID>/alt/`。不合格最多重试到 3 次，仍不合格就记录原因并继续下一张。碰到频率限制就等待后继续。

## 续做（2026-11-26 额度重置后）
- 跳过 RESULTS 里已经选版、自查通过的项。只做未生成的、只有 1 版候选的、以及下面这一条。
- **亡灵王子的 3 张全部重画**：Lead 审图后认为骷髅半脸仍然太弱。身份参考改用 `art/style/prince_hero.png`（这张的骷髅半脸是对的），再加上原来的参考图。自查第 6 条必须看得出：观众右侧的半张脸是裸骨，牙齿外露，眼窝里有火。

## 自查清单（写进 RESULTS）
1. 渲染符合附图的 A 风格：成熟比例，墨线粗细有变化且只在转折处出现，一个主光源，大面积暗部，细轮廓光
2. 身份和服装与身份参考一致
3. 体型符合 BUILD 描述，和其他人物明显不同
4. 主立绘的动作符合 POSE，手在做具体的事；表情图三张的身体角度和手势各不相同
5. 三视图：三个视图等高、空手，体型没被画成标准身材
6. 王子：观众看的右半边脸是裸露的骷髅，眼窝里有冥火，清楚可见；金冠前方有断口
7. 没有多余文字（三视图的视图标注除外），没有多余的手和脚

## 清单
- `art/prompts/rendered_v2/CHAR-PRINCE-UNDEAD__hero.txt` → `art/chars/CHAR-PRINCE-UNDEAD/hero.png`；身份参考：`art/chars/CHAR-PRINCE-UNDEAD/turnaround.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-PRINCE-UNDEAD__turnaround.txt` → `art/chars/CHAR-PRINCE-UNDEAD/turnaround.png`；身份参考：`art/chars/CHAR-PRINCE-UNDEAD/turnaround.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-PRINCE-UNDEAD__expressions.txt` → `art/chars/CHAR-PRINCE-UNDEAD/expressions.png`；身份参考：`art/chars/CHAR-PRINCE-UNDEAD/turnaround.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-PRINCE__hero.txt` → `art/chars/CHAR-PRINCE/hero.png`；身份参考：`art/chars/CHAR-PRINCE/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-PRINCE__turnaround.txt` → `art/chars/CHAR-PRINCE/turnaround.png`；身份参考：`art/chars/CHAR-PRINCE/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-PRINCE__expressions.txt` → `art/chars/CHAR-PRINCE/expressions.png`；身份参考：`art/chars/CHAR-PRINCE/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-QUEEN__hero.txt` → `art/chars/CHAR-QUEEN/hero.png`；身份参考：`art/chars/CHAR-QUEEN/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-QUEEN__turnaround.txt` → `art/chars/CHAR-QUEEN/turnaround.png`；身份参考：`art/chars/CHAR-QUEEN/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-QUEEN__expressions.txt` → `art/chars/CHAR-QUEEN/expressions.png`；身份参考：`art/chars/CHAR-QUEEN/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-FERRYMAN__hero.txt` → `art/chars/CHAR-FERRYMAN/hero.png`；身份参考：`art/chars/CHAR-FERRYMAN/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-FERRYMAN__turnaround.txt` → `art/chars/CHAR-FERRYMAN/turnaround.png`；身份参考：`art/chars/CHAR-FERRYMAN/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-FERRYMAN__expressions.txt` → `art/chars/CHAR-FERRYMAN/expressions.png`；身份参考：`art/chars/CHAR-FERRYMAN/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-KING__hero.txt` → `art/chars/CHAR-KING/hero.png`；身份参考：`art/chars/CHAR-KING/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-KING__turnaround.txt` → `art/chars/CHAR-KING/turnaround.png`；身份参考：`art/chars/CHAR-KING/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-KING__expressions.txt` → `art/chars/CHAR-KING/expressions.png`；身份参考：`art/chars/CHAR-KING/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-MOTHER__hero.txt` → `art/chars/CHAR-MOTHER/hero.png`；身份参考：`art/chars/CHAR-MOTHER/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-MOTHER__turnaround.txt` → `art/chars/CHAR-MOTHER/turnaround.png`；身份参考：`art/chars/CHAR-MOTHER/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-MOTHER__expressions.txt` → `art/chars/CHAR-MOTHER/expressions.png`；身份参考：`art/chars/CHAR-MOTHER/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-CAPTAIN__hero.txt` → `art/chars/CHAR-CAPTAIN/hero.png`；身份参考：`art/chars/CHAR-CAPTAIN/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-CAPTAIN__turnaround.txt` → `art/chars/CHAR-CAPTAIN/turnaround.png`；身份参考：`art/chars/CHAR-CAPTAIN/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-CAPTAIN__expressions.txt` → `art/chars/CHAR-CAPTAIN/expressions.png`；身份参考：`art/chars/CHAR-CAPTAIN/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-STITCHER__hero.txt` → `art/chars/CHAR-STITCHER/hero.png`；身份参考：`art/chars/CHAR-STITCHER/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-STITCHER__turnaround.txt` → `art/chars/CHAR-STITCHER/turnaround.png`；身份参考：`art/chars/CHAR-STITCHER/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-STITCHER__expressions.txt` → `art/chars/CHAR-STITCHER/expressions.png`；身份参考：`art/chars/CHAR-STITCHER/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-MAGE__hero.txt` → `art/chars/CHAR-MAGE/hero.png`；身份参考：`art/chars/CHAR-MAGE/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-MAGE__turnaround.txt` → `art/chars/CHAR-MAGE/turnaround.png`；身份参考：`art/chars/CHAR-MAGE/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-MAGE__expressions.txt` → `art/chars/CHAR-MAGE/expressions.png`；身份参考：`art/chars/CHAR-MAGE/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-BUGLER__hero.txt` → `art/chars/CHAR-BUGLER/hero.png`；身份参考：`art/chars/CHAR-BUGLER/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-BUGLER__turnaround.txt` → `art/chars/CHAR-BUGLER/turnaround.png`；身份参考：`art/chars/CHAR-BUGLER/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-BUGLER__expressions.txt` → `art/chars/CHAR-BUGLER/expressions.png`；身份参考：`art/chars/CHAR-BUGLER/hero.png`（改动前的旧图）

## 交付
`art/chars/RESULTS-T58.json`（每张一条：file、prompt_file、alts、attempts、checklist、status: in_review），报告 `reports/agents/T58.md`，开头用 YAML 摘要。
