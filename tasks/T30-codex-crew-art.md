---
id: T30
title: 旧部概念图 P0：玛蒂尔达、奥斯温、皮普（主立绘 + 三视图 + 道具）
owner: codex
status: queued
branch: codex/t30-crew-art
worktree: ../亡魂王子-t30
images: [/Users/cyy/Projects/亡魂王子/concept/canon-art/B/u8_prince.png, /Users/cyy/Projects/亡魂王子/concept/canon-art/B/art/ART-B4-BERNARD-R1.png, /Users/cyy/Projects/亡魂王子/concept/canon-art/B/art/ART-B4-FERRYMAN-R1.png]
allowed: [art/canon/]
forbidden: [scripts/, scenes/, docs/, tasks/, project.godot, assets/]
verify: test -d art/canon/CHAR-STITCHER
retry_limit: 2
max_minutes: 150
escalate_if: [需要改动世界观或人物设定, 生成结果与简报冲突且重试两次仍无法纠正]
---

## 目标
按设定包的美术队列，补齐据点旧部里缺的三人：玛蒂尔达（CHAR-STITCHER）、奥斯温（CHAR-MAGE）、皮普（CHAR-BUGLER）。
这些图用于据点对话立绘、增益选择界面和以后的建模参考。

## 输入（先读）
- `docs/canon/CLAUDE-HANDOFF.md`：流程、交付规则。本任务里由 Lead（Claude）审批，你只负责执行。
- `docs/canon/shared/ART-PRODUCTION-QUEUE.json`：三人各自条目里的 `brief_en`、`brief_zh`、`deliverables`。**以简报为准。**
- `docs/canon/B/B4-PRODUCTION-SPEC.md`：只读这三人和通用规格的段落。
- 附图：
  1. `u8_prince.png`：风格基准，低多边形、切面、哑光材质。
  2. `ART-B4-BERNARD-R1.png`：概念板的版式和画风参考。
  3. `ART-B4-FERRYMAN-R1.png`：同上。

## 风格要求（Lead 决定）
- 与附图 2、3 保持同一画风：切面低多边形、暖灰背景、英文标题和视图标注、色板。
- 角色比例与附图 2、3 一致，用成人比例。游戏内小兵的 Q 版比例是另一套规格，这里不用。
- 每个角色单独生成，不要多人同框。

## 要做
1. 每个角色按 `deliverables` 交 3 个文件：`hero.png`、`turnaround.png`、`props.png`。
   - 三视图里正、侧、背等高、同姿势、不拿道具。
   - 如果一次生成的是整张概念板，另外再生成或裁切出这 3 个文件，整板也保留，命名为 `sheet.png`。
2. 文件放在 `art/canon/<任务ID>/`，例如 `art/canon/CHAR-STITCHER/hero.png`。生成图从 `~/.codex/generated_images/` 复制过来。
3. 写 `art/canon/ART-RESULTS.json`，格式照抄 `docs/canon/shared/ART-RESULTS.json`，只写这三条：
   - `status` 填 `in_review`，不要写 accepted，审批由 Lead 做。
   - `outputs` 填文件路径。
   - `reference_sha256` 填三张附图的哈希。
   - `tool` 写生成工具和模型名。
   - `review_notes` 写你自己检查出的问题，例如手指数量、标注拼写、与简报的出入。
4. 自查清单，逐条对照简报：
   - 玛蒂尔达：没有锤子、铁砧、机械义肢。
   - 奥斯温：兜帽、石板、漂浮文稿残页。
   - 皮普：19 岁青年，不要画成儿童。
   - 三人都不戴王冠、不披王室披风。
   - 不从生成图里的偶然文字推出新设定。

## 验收
- [ ] 三个角色各 3 个文件，路径正确
- [ ] ART-RESULTS.json 三条齐全，状态都是 in_review
- [ ] 由 Lead 看图判断：风格是否与伯纳德、渡魂人一致；是否符合简报

## 交付报告
写到 `reports/agents/T30.md`，格式见 docs/collab.md 第 4 节。列出每张图的生成次数和退回原因。
