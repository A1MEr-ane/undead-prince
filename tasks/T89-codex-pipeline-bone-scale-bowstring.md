---
id: T89
title: 精灵管线补两项能力：逐骨缩放、跟手弓弦；并重出巨人和弓兵草稿
owner: codex
status: queued
branch: codex/t89-pipeline-ext
worktree: ../亡魂王子-t89
allowed: [tools/blender/, docs/unit-sprites.md, reports/agents/]
forbidden: [assets/, attempts/, scripts/, proto/, shaders/, tasks/, art/, tools/blender/terrain/]
verify: tools/verify/verify.sh sprites
retry_limit: 3
max_minutes: 180
escalate_if: [需要改精灵读取格式或游戏着色器, 改动会让已通过的丧尸和刺客图集变化]
---

## 背景
DSH 在 T88 批量重做兵种时，有两处现有配方表达不了，按规定停了下来：
1. 巨人 `wall_slam` 要双拳过顶再砸下。Lead 只批准**巨人**的手臂骨骼拉长到 1.3 倍，但配方 schema 没有逐骨缩放。
2. 弓兵的弓弦只能刚性绑在一根骨骼上，拉弓时不会跟着手走。用户之前点名说过"弓看着不对"。

## 要做
1. **逐骨缩放**：配方里可以按动作、按骨骼写缩放，比如只在 `wall_slam` 里把上臂和前臂拉长到 1.3 倍，并能在关键帧之间插值。缩放只影响写了它的兵种和动作。
2. **跟手弓弦**：弦是两段，从弓的上下两端连到一个跟着拉弦手的控制点。
   - 搭箭和放箭之外的时间，控制点回到弓的中线，弦是直的。
   - 拉弓时，弦跟着手形成折线。
   - 放箭那一帧弦弹回直线。可以加一帧轻微的过冲。
   - 弦的墨线粗细和其他细物件一致。
3. **重出两个草稿**：用 T88 工作树里的配方，路径是 `../亡魂王子-t88/reports/agents/T88-drafts/_recipes/stitched_giant.yml` 和 `archer.yml`。
   - 把两个配方复制到本任务的 `reports/agents/T89-drafts/`，加上新字段后重出。
   - 每个兵种出 `_in_game.png`、`_actions.png`、`_reactions.png`。
   - 弓兵另出一张"搭箭、满弓、放箭"三帧放大图 `archer_draw_check.png`。
4. **手册**：在 `docs/unit-sprites.md` 的 DSH 生产手册里补上这两个字段的写法。
5. **回归**：丧尸和刺客两套图集重新构建后，必须和现有图集逐像素一致。

## 交付
报告 `reports/agents/T89.md`，开头用 YAML 摘要。
