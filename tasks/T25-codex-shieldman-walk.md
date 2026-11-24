---
id: T25
title: 盾兵走路改成小碎步（上半身锁定）
owner: codex
status: done
branch: codex/t25-walk
worktree: ../亡魂王子-t25
allowed: [tools/blender/, assets/sprites/, docs/sprite-pipeline.md]
forbidden: [scripts/, shaders/, assets/specs/, project.godot, tasks/]
verify: tools/verify/verify.sh sprites
retry_limit: 2
max_minutes: 60
escalate_if: [需要改动画帧数或时长（游戏依赖）, 需要改规格]
---

## 目标
游戏里小兵每秒迈约 5 步（Bad North 的节奏），现在的走路动画步幅大、手臂和盾前后摆、身体起伏明显，以这个速度播放显得手忙脚乱。改成 Bad North 式的小碎步。

## 要做
1. 读 `assets/specs/k2_shieldman.yml` 的 `animation_notes.walk`（已更新）和 `tools/blender/build_shieldman.py` 里的 walk 姿势。
2. 重做 walk（帧数 8、时长 0.667、左右步事件时间都不变）：
   - 两脚前后交替幅度 ≤ 身高 6%，抬脚 ≤ 3%；
   - 头、躯干、盾、剑全程锁定，不摆臂；
   - 身体竖直起伏 ≤ 身高 1%；
   - 仍是两步一循环、左右脚交替，第 0 帧和第 4 帧分别是右脚、左脚着地。
3. 其他动作不动。重新渲染图集、预览。
4. `validate.py` 里的步态检查如果写死了旧的大步幅阈值，改成按规格检查新幅度（不要放宽其他检查）。

## 验收
- [ ] `tools/verify/verify.sh sprites` 通过
- [ ] 报告附 walk 行的预览图路径和实测的脚步幅度、身体起伏数值
- [ ] Claude 在游戏里看实际效果
