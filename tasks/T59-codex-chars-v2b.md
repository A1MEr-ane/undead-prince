---
id: T59
title: 立绘 A 风格重画 2：五名仇人（15 张）
owner: codex
status: done
branch: codex/t59-chars-v2b
worktree: ../亡魂王子-t59
images: [/Users/cyy/Projects/亡魂王子/art/compare/EDMUND_A.png, /Users/cyy/Projects/亡魂王子/art/compare/ELEANOR_A.png, /Users/cyy/Projects/亡魂王子/art/compare/BERNARD_A.png]
allowed: [art/chars/]
forbidden: [art/prompts/, art/compare/, art/style/, art/ui/, art/units/, art/story/, scripts/, scenes/, docs/, tasks/, project.godot, assets/]
verify: test -f art/chars/RESULTS-T59.json
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

## 自查清单（写进 RESULTS）
1. 渲染符合附图的 A 风格：成熟比例，墨线粗细有变化且只在转折处出现，一个主光源，大面积暗部，细轮廓光
2. 身份和服装与身份参考一致
3. 体型符合 BUILD 描述，和其他人物明显不同
4. 主立绘的动作符合 POSE，手在做具体的事；表情图三张的身体角度和手势各不相同
5. 三视图：三个视图等高、空手，体型没被画成标准身材
6. 王子：观众看的右半边脸是裸露的骷髅，眼窝里有冥火，清楚可见；金冠前方有断口
7. 没有多余文字（三视图的视图标注除外），没有多余的手和脚

## 清单
- `art/prompts/rendered_v2/CHAR-EARL__hero.txt` → `art/chars/CHAR-EARL/hero.png`；身份参考：`art/chars/CHAR-EARL/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-EARL__turnaround.txt` → `art/chars/CHAR-EARL/turnaround.png`；身份参考：`art/chars/CHAR-EARL/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-EARL__expressions.txt` → `art/chars/CHAR-EARL/expressions.png`；身份参考：`art/chars/CHAR-EARL/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-COUNTESS__hero.txt` → `art/chars/CHAR-COUNTESS/hero.png`；身份参考：`art/chars/CHAR-COUNTESS/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-COUNTESS__turnaround.txt` → `art/chars/CHAR-COUNTESS/turnaround.png`；身份参考：`art/chars/CHAR-COUNTESS/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-COUNTESS__expressions.txt` → `art/chars/CHAR-COUNTESS/expressions.png`；身份参考：`art/chars/CHAR-COUNTESS/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-ARCHBISHOP__hero.txt` → `art/chars/CHAR-ARCHBISHOP/hero.png`；身份参考：`art/chars/CHAR-ARCHBISHOP/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-ARCHBISHOP__turnaround.txt` → `art/chars/CHAR-ARCHBISHOP/turnaround.png`；身份参考：`art/chars/CHAR-ARCHBISHOP/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-ARCHBISHOP__expressions.txt` → `art/chars/CHAR-ARCHBISHOP/expressions.png`；身份参考：`art/chars/CHAR-ARCHBISHOP/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-MARSHAL__hero.txt` → `art/chars/CHAR-MARSHAL/hero.png`；身份参考：`art/chars/CHAR-MARSHAL/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-MARSHAL__turnaround.txt` → `art/chars/CHAR-MARSHAL/turnaround.png`；身份参考：`art/chars/CHAR-MARSHAL/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-MARSHAL__expressions.txt` → `art/chars/CHAR-MARSHAL/expressions.png`；身份参考：`art/chars/CHAR-MARSHAL/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-CHANCELLOR__hero.txt` → `art/chars/CHAR-CHANCELLOR/hero.png`；身份参考：`art/chars/CHAR-CHANCELLOR/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-CHANCELLOR__turnaround.txt` → `art/chars/CHAR-CHANCELLOR/turnaround.png`；身份参考：`art/chars/CHAR-CHANCELLOR/hero.png`（改动前的旧图）
- `art/prompts/rendered_v2/CHAR-CHANCELLOR__expressions.txt` → `art/chars/CHAR-CHANCELLOR/expressions.png`；身份参考：`art/chars/CHAR-CHANCELLOR/hero.png`（改动前的旧图）

## 交付
`art/chars/RESULTS-T59.json`（每张一条：file、prompt_file、alts、attempts、checklist、status: in_review），报告 `reports/agents/T59.md`，开头用 YAML 摘要。
