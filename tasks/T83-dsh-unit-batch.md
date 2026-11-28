---
id: T83
title: 按 T82 手册批量制作其余 6 个兵种（暗影刺客、缝合巨人、巫妖、盾兵、弓兵、骑兵）
owner: dsh
status: superseded   # 被 T88 取代（新基准 2026-11-28）
branch: dsh/t83-unit-batch
worktree: ../亡魂王子-t83
allowed: [assets/specs/units/, assets/sprites/units/, reports/agents/]
forbidden: [assets/specs/units/skeleton.yml, assets/sprites/units/skeleton/, tools/, scripts/, proto/, attempts/, docs/, tasks/, art/]
verify: tools/verify/verify.sh sprites
retry_limit: 3
max_minutes: 360
escalate_if: [涉及精灵格式、着色器接口或额外视角, 形状或动作无法用现有配方表达, 偏离 2.3 头身比例或已批准的画风]
---

## 目标
用户已批准普通骷髅试点（`assets/sprites/units/skeleton/`）。按 `docs/unit-sprites.md` 的附录"DSH 生产手册"，用同一条管线批量做出其余 6 个兵种：
- 亡灵：暗影刺客、缝合巨人、巫妖
- 守军：盾兵、弓兵、骑兵

每个兵种的造型、颜色、动作以 `docs/unit-sprites.md` 第 1–3 节为准。

## 分两步（中间由 Lead 审一次）
1. **草稿**：6 个兵种都用 `--draft` 出草稿，每个都带 `_48px.png` 和 `_actions.png`。草稿全部放进 `reports/agents/T83-drafts/<兵种>/`，然后**停下**写报告，报告里写 `needs_claude: true`，把草稿图路径列出来。Lead 统一审过后会在本卡追加"正式输出"的批准。
2. **正式输出**：等批准后，跑正式构建，产物放 `assets/sprites/units/<兵种>/`，逐件验收。

## 额外要求
- 动作幅度比试点再大一些。攻击的抬手和挥出、行走的迈步，帧与帧之间要明显不同，在 48 像素下也看得出来。这是 Lead 看试点时的意见。
- 巨人按大型单位的画布，骑兵按骑乘单位的画布，参照手册里的体型类别。
- 遇到手册里写明"必须交回 Codex"的情况，立即停下，在报告里写 `handoff: codex`。

## 交付
`reports/agents/T83.md`，开头用 YAML 摘要。
