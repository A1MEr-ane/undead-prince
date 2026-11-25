---
id: T57
title: 立绘高级化对比：3 种风格 × 3 个角色（Claude 提示词）
owner: codex
status: queued
branch: codex/t57-portrait-compare
worktree: ../亡魂王子-t57
images: [/Users/cyy/Projects/亡魂王子/art/chars/CHAR-PRINCE-UNDEAD/turnaround.png, /Users/cyy/Projects/亡魂王子/art/chars/CHAR-QUEEN/hero.png, /Users/cyy/Projects/亡魂王子/art/chars/CHAR-CAPTAIN/hero.png]
allowed: [art/compare/]
forbidden: [art/prompts/, art/chars/, art/style/, art/ui/, scripts/, scenes/, docs/, tasks/, project.godot, assets/]
verify: test -f art/compare/RESULTS-T57.json
retry_limit: 2
max_minutes: 90
escalate_if: [连续 3 张生成失败]
---

## 目标
用户要把现有立绘改得更高级。先出对比稿：3 种风格（A 精炼墨线、B 电影光影、C 铜版海图）× 3 个角色（埃德蒙、埃莉诺、伯纳德），共 9 张。你只负责生成、选版、登记。

## 规则
- 提示词在 `art/prompts/compare/<角色>_<风格>.txt`，**原样使用全文**，不得改写。
- 每张只传入该角色自己的参考图：EDMUND 用附图 1，ELEANOR 用附图 2，BERNARD 用附图 3。
- 每张生成 2 版，选 1 版；落选放 `art/compare/alt/`。
- 产物：`art/compare/<角色>_<风格>.png`，例如 `art/compare/ELEANOR_B.png`。
- 碰到生图频率限制就等待恢复，然后继续。

## 自查（写进 RESULTS）
1. 身份和服装与参考一致（王子的骷髅脸在观众看的右半边，金冠前方有断口）
2. 渲染风格明显符合提示词里的 A、B、C 描述，三种风格彼此区分得开
3. 没有文字，没有多余的手和脚

## 交付
`art/compare/RESULTS-T57.json`，加报告 `reports/agents/T57.md`（开头用 YAML 摘要）。
