---
id: T87
title: 小兵画质与可读性升级：128 像素图集、关键姿势、受击分类，重做骷髅和刺客作为新基准
owner: codex
status: queued
branch: codex/t87-sprite-quality
worktree: ../亡魂王子-t87
images: [/Users/cyy/Projects/亡魂王子/shots/t84/02-midnight.png, /Users/cyy/Projects/亡魂王子/shots/t83/shadow_assassin_48px.png, /Users/cyy/Projects/亡魂王子/shots/t83/archer_48px.png]
allowed: [tools/blender/, assets/specs/units/, assets/sprites/units/, docs/unit-sprites.md, reports/agents/]
forbidden: [tools/blender/terrain/, attempts/, scripts/, proto/, shaders/, data/, tasks/, art/]
verify: tools/verify/verify.sh sprites
retry_limit: 3
max_minutes: 300
escalate_if: [需要改游戏的着色器或精灵读取接口, 128 像素方案在性能或图集上明显不可行]
---

## 目标
用户审了 6 个兵种的草稿，认为辨识度太低。修订要求写在 `docs/unit-sprites.md` 第 5 节，那是本任务的规格：
- 画质更高
- 看得出在做什么动作
- 受击表现能区分
- 具体问题：弓、骷髅披风、刺客成团、巨人太小

本任务先改管线并做两个新基准，再由 DSH 重做其余兵种。

## 比例统一（用户 2026-11-28 追加）
所有兵种都必须是**小短腿 Q 版**（2.3 头身，腿约占身高 0.22，大头大脚），包括巨人和骑兵：只整体放大，不改头身比。在验收器里加比例检查，超出容差（±0.03）就判失败。细则见 `docs/unit-sprites.md` 第 5 节最后一条。两个新基准（骷髅、刺客）必须先通过这项检查。

## 走路方式（用户已定）
按"小碎步加身体跳步"做，细则见 `docs/unit-sprites.md` 第 5 节最后一条：约 4 帧小碎步、脚基本不离地、上身锁定，前进感由引擎跳步负责；步点事件和引擎跳步对齐。给 T86 的接口说明里写清楚步点事件和跳步参数，T86 要接上原型的跳步。

## 要做
1. **管线**：图集单格改为 128 像素（超采样、墨线粗细、验收器、预览图都跟着改）。读图基准是"1080p 下普通步兵约 72 像素"。预览图按这个实际大小出，并且**不再把所有兵种缩放到同一高度**，巨人和骑兵按真实比例显示。
2. **受击分类**：把第 5 节表里的受击和死亡动作加进共用模板，所有兵种都继承。
3. **关键姿势**：在模板层面加强预备、出手、收势，并给手册写出检查方法（关键帧剪影差异）。
4. **重做两个基准**：
   - **普通骷髅**（去掉披风）
   - **暗影刺客**（修正成团的问题）
   刺客最难读，用来验证新标准够不够。
5. **更新手册**：`docs/unit-sprites.md` 附录"DSH 生产手册"按新标准改写；把弓兵和巨人的修正要点写进对应配方的注意事项（配方本身由 DSH 重做）。
6. **预览**：两个基准各出新的实际大小预览、动作表、受击表，放到 `shots/t87/`。

## 给 T86 的接口说明
`attempts/single_battle/` 由 T86 负责。你不要改它，在报告里写明：精灵尺寸和读取格式有哪些变化、镜头要拉近多少，由 Lead 转给 T86。

## 交付
报告 `reports/agents/T87.md`，开头用 YAML 摘要。用户审过两个基准后，DSH 再重做其余 5 个兵种。

## 修订 2（用户 2026-11-28 审基准后）
用户意见："这个小短腿本质还是倒 V 交叉。"两条细腿分开站、迈步时张成倒 V，是不合格的。
按 `docs/unit-sprites.md` 第 5 节"腿部造型"改：下半身做成连体口袋形，站立只在底部有浅圆缺口，迈步时缺口变成圆拱，不出现直线腿和尖角透空。
- 改共用模板和验收器（加"裆部透空"检查），重出骷髅和刺客两个基准。
- 预览照旧放 `shots/t87/`，另加一张"站姿、迈步、弓步"三帧的下半身放大对比图 `shots/t87/legs_check.png`。
- 动作、受击、比例其他部分已通过，不要重做。
