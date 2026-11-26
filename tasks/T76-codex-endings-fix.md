---
id: T76
title: 结局插画补画：E06、E07、真结局（修订后的提示词）
owner: codex
status: done
branch: codex/t76-endings-fix
worktree: ../亡魂王子-t76
images: []
allowed: [art/story/]
forbidden: [art/prompts/, art/chars/, art/style/, art/ui/, art/units/, scripts/, proto/, docs/, tasks/, project.godot, assets/]
verify: test -f art/story/RESULTS-T76.json
retry_limit: 3
max_minutes: 300
escalate_if: [连续 5 张按原提示词生成三次仍不合格]
---

## 目标
用户要求结局插画有史诗感：强调光影、权力关系和氛围，参考鬼刀式的画法，**画面上不能有任何文字**。按 Claude 写好的提示词生成；你只负责生成、选版、复制、登记。旧的占位图直接覆盖，git 历史里有。

## 本轮范围
只画 **E06、E07、TRUE** 三张。T75 失败的原因是：提示词模板在每张图里都写了"王都上空的人造光环"，于是画面里多出了光环，E06 还冒出了伪文字。Claude 已经改了提示词，每张单独写明天上有没有光环、文书一律空白。其余 7 张已经验收，不要动。

## 规则
- 每张图原样使用 `art/prompts/rendered_endings/*.txt` 的全文，不得改写；人物主立绘作为身份参考一起传入。
- 每张出 2 版选 1 版，落选的放到 `alt/`；不合格最多试 3 次，还不行就记录原因，继续下一张。遇到频率限制就等它恢复后接着做。

## 自查清单（写进 RESULTS）
1. 没有任何文字、字母、签名、题字
2. 史诗厚涂：写实成人比例、体积光、大面积暗部，不是卡通或平涂
3. 构图体现权力关系（提示词里的 POWER AND COMPOSITION 一项）
4. 光照符合提示词：人造永昼只出现在提示词要求的画面里；冥火青绿只出现在亡灵身上
5. 人物身份与参考一致（王子在观众看来的右半边脸是骷髅，金冠断裂）
6. 没有多余的手脚

## 清单
- `art/prompts/rendered_endings/ENDING__E00.txt` → `art/story/ENDING-E00/ending.png`；身份参考：`art/chars/CHAR-FERRYMAN/hero.png`
- `art/prompts/rendered_endings/ENDING__E01.txt` → `art/story/ENDING-E01/ending.png`；身份参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`、`art/chars/CHAR-QUEEN/hero.png`
- `art/prompts/rendered_endings/ENDING__E02.txt` → `art/story/ENDING-E02/ending.png`；身份参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`、`art/chars/CHAR-CAPTAIN/hero.png`
- `art/prompts/rendered_endings/ENDING__E03.txt` → `art/story/ENDING-E03/ending.png`；身份参考：`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-PRINCE-UNDEAD/hero.png`
- `art/prompts/rendered_endings/ENDING__E04.txt` → `art/story/ENDING-E04/ending.png`；身份参考：`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-PRINCE-UNDEAD/hero.png`、`art/chars/CHAR-BUGLER/hero.png`
- `art/prompts/rendered_endings/ENDING__E05.txt` → `art/story/ENDING-E05/ending.png`；身份参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`
- `art/prompts/rendered_endings/ENDING__E06.txt` → `art/story/ENDING-E06/ending.png`；身份参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`
- `art/prompts/rendered_endings/ENDING__E07.txt` → `art/story/ENDING-E07/ending.png`；身份参考：`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-PRINCE-UNDEAD/hero.png`
- `art/prompts/rendered_endings/ENDING__E08.txt` → `art/story/ENDING-E08/ending.png`；身份参考：`art/chars/CHAR-QUEEN/hero.png`、`art/chars/CHAR-BUGLER/hero.png`
- `art/prompts/rendered_endings/ENDING__TRUE.txt` → `art/story/ENDING-TRUE/ending.png`；身份参考：`art/chars/CHAR-PRINCE-UNDEAD/hero.png`、`art/chars/CHAR-FERRYMAN/hero.png`、`art/chars/CHAR-QUEEN/hero.png`

## 交付
`art/story/RESULTS-T76.json`，以及报告 `reports/agents/T76.md`（开头写 YAML 摘要）。
