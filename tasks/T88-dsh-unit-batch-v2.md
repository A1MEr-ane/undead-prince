---
id: T88
title: 按新基准批量重做其余 5 个兵种（缝合巨人、巫妖、盾兵、弓兵、骑兵）
owner: dsh
status: queued
branch: dsh/t88-unit-batch-v2
worktree: ../亡魂王子-t88
allowed: [assets/specs/units/, assets/sprites/units/, reports/agents/]
forbidden: [assets/specs/units/zombie.yml, assets/sprites/units/zombie/, assets/specs/units/shadow_assassin.yml, assets/sprites/units/shadow_assassin/, assets/archive/, tools/, scripts/, proto/, attempts/, docs/, tasks/, art/]
verify: tools/verify/verify.sh sprites
retry_limit: 3
max_minutes: 360
escalate_if: [涉及精灵格式、着色器接口或额外视角, 形状或动作无法用现有配方表达, 验收器的比例、裆部透空或明度检查无法通过且不是配方问题]
---

## 目标
用户已通过两个新基准：**普通丧尸**（`assets/sprites/units/zombie/`）和**暗影刺客**（`assets/sprites/units/shadow_assassin/`）。T83 的旧草稿作废。
按 `docs/unit-sprites.md` 第 5 节和附录"DSH 生产手册"，用同一条管线重做其余 5 个兵种：
- 亡灵：缝合巨人、巫妖
- 守军：盾兵、弓兵、骑兵

## 必须遵守的标准（用户逐条审过）
- 128 px 单格；预览按 1080p 下普通兵约 72 px 的实际大小出图。
- B 比例（2.3 头身，大头大脚）。巨人约 1.7 倍、骑兵约 1.65 倍，等比放大，不改比例。
- **下半身连体**：裤子、腿、脚连成一块，站立时底部只有浅圆缺口；迈步和弓步时缺口张开成圆拱，不能出现倒 V 或直线细腿。巫妖是长袍漂浮，没有腿。马的四条腿也用短粗的团块处理，不画细长的马腿。
- **手脚和衣身分开**：鞋和手的颜色要比衣身明显深，参照刺客修订 4b 的做法。
- 走路是 4 帧小碎步，上身锁住；关键姿势分清预备、出手、收势；受击和死亡沿用共用模板（5 类受击、3 种死亡）。
- 每个兵种各自的修正要点写在手册里：弓兵用长弓，要有搭箭、满弓、放箭三拍；巨人要够大。
- 每个兵种完成后，自己先看一遍实际大小预览。不放大也能分清兵种、手脚和武器，才算完成。

## 分两步（中间 Lead 审一次）
1. **草稿**：5 个兵种都出 `_in_game.png`、`_actions.png`、`_reactions.png`，放进 `reports/agents/T88-drafts/<兵种>/`。然后**停下**写报告，写 `needs_claude: true`，列出图片路径。
2. **正式输出**：Lead 在本卡追加批准后，正式构建，产物放 `assets/sprites/units/<兵种>/`，逐件过验收器。

## 交付
`reports/agents/T88.md`，开头用 YAML 摘要。
