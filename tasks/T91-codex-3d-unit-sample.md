---
id: T91
title: 实时 3D 低模小兵样张：普通丧尸和缝合巨人，加同屏性能测试
owner: codex
status: queued
branch: codex/t91-3d-units
worktree: ../亡魂王子-t91
allowed: [attempts/single_battle/units3d/, tools/blender/units3d/, assets/models/units/, docs/unit-3d.md, reports/agents/]
forbidden: [attempts/single_battle/siege*.gd, attempts/single_battle/camera/, attempts/single_battle/terrain/, attempts/single_battle/tests/, assets/sprites/, scripts/, proto/, tasks/, art/]
verify: tools/verify/verify.sh parse
retry_limit: 3
max_minutes: 300
escalate_if: [需要改单局的模拟或镜头代码（T90 正在改）, 300 个单位在整图视角下达不到 60 帧且没有可行的优化办法, 卡通着色和描边在三档缩放下都不好看]
---

## 背景
用户试玩单局后决定（`docs/alignment-2026-11-28.md` 第 7 节）：
- 局内改成整体视角加缩放，参考部落冲突（T90 在做镜头）。
- 小兵改用**实时 3D 低模加卡通着色**，用骨骼动画。
- 用户的意见：现在的小兵"没有立体感，动作也很僵硬"。
本任务先做样张，用户通过后才批量做其余兵种。美术由你负责，DSH 不参与。

## 造型（Lead 设计，沿用已通过的 2D 设定）
先看 `docs/unit-sprites.md` 第 5 节和 `assets/sprites/units/zombie/zombie_in_game.png`、`stitched_giant/stitched_giant_in_game.png`。比例、配色、剪影要和它们一致，只是变成真正的立体。
- **共同点**：
  - Q 版 2.3 头身，大头大脚。
  - 下半身是连体的一块，不做两条细腿。
  - 低模面数：普通兵 600–1200 三角面，巨人 2000 以内。
  - 着色：卡通明暗，两到三档，暗部偏冷。
  - 外描边：用反向外壳，线宽随缩放保持在约 1.5–2 像素，延续墨线风格。
  - 阵营边光：亡灵是冥火青绿，守军以后用暖金。
- **普通丧尸**：
  - 外形：溺亡水手。灰青白皮肤，不用绿色。褪色短外套，一只袖子破掉，腰间一根绳子，锈短弯刀，空着的手往前伸。
  - 姿态：上身前倾，一侧肩膀塌下。
- **缝合巨人**：
  - 外形：约 1.7 倍高。头部是方块感的缝合头颅，带几条粗缝线，缝线有微弱的冥火光。身体用明度不同的补丁拼起来。
  - 拳头：大拳头缠深色布条，露出浅色指节。

## 动作（解决"僵硬"）
- 每个兵种做 idle、walk、attack、hit、death；巨人另做 wall_slam。
- 全部 60 帧骨骼动画，动作之间要有过渡混合。
- 打击感要求：
  - **预备要慢，出手要快**：出手 2–3 帧到位，打中时定格 3–4 帧。
  - 出手的方向上要有身体的跟随。
  - 受击时向后仰，有挤压回弹。
- 走路：
  - 丧尸是前倾、拖步的小跑，几个丧尸的步伐要错开，相位随机。
  - 巨人每一步都很重：落地时身体下沉，带扬尘的落脚事件。
- 每个实例的动画播放速度有 ±8% 的随机，避免整齐划一。

## 性能（整体视角是前提）
- 在一个独立测试场景 `attempts/single_battle/units3d/bench.tscn` 里，整图视角下放 300 个单位（丧尸 280 + 巨人 20）一起走和打。目标是本机 60 帧。
- 自己选方案并写明理由，比如：
  - 顶点动画贴图加多实例渲染
  - 骨骼动画加远景细节层级
  - 远处降低动画频率
- 报告里给出帧时间数据。

## 展示
- 在 `attempts/single_battle/units3d/showcase.tscn` 里，把两个兵种放在 T85 的地形上。
- 三档缩放各出一张截图（全图、中等、最近），加一段动作循环的逐帧图。放到 `shots/t91/`，截不了就写明，Lead 会补拍。
- 不接进单局的模拟代码。接入在 T90 完成后另开任务。

## 交付
- 报告 `reports/agents/T91.md`，开头用 YAML 摘要。
- 制作方法写进 `docs/unit-3d.md`，作为以后批量做其余兵种的手册。
