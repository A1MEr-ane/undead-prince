---
id: T56
title: UI 动效与转场原型（增益选择、对话、出航涨潮、败北钟声）+ 中文字体候选
owner: codex
status: done
branch: codex/t56-ui-motion
worktree: ../亡魂王子-t56
allowed: [proto/ui_motion/, docs/research/FONT_CANDIDATES.md]
forbidden: [scripts/, shaders/, scenes/, assets/, art/, tasks/, project.godot, docs/ui-motion.md]
verify: test -f proto/ui_motion/README.md
retry_limit: 3
max_minutes: 180
escalate_if: [需要改生产代码, 规格里的时长或曲线在原型里明显不好用]
---

## 目标
把 `docs/ui-motion.md` 第 3 节的动效规格做成可以操作的 Godot 原型，供 Lead 校准手感。**不需要最终美术**：用纯色块、细金线（1 像素）、占位文字和简单着色器即可。只在 `proto/ui_motion/` 里做，不改生产代码。

## 先读
`docs/ui-motion.md` 全文。第 1 节的审美原则是硬要求：克制、一种材质、细金线、暗不是黑、一屏最多两种字体。

## 要做
1. 一个原型场景，按数字键切换演出：
   1. 增益选择：背景压暗，半身像占位从左侧滑入，台词逐字出现，三张卡依次带回弹进场，悬停焦点，确认后化光飞向槽位
   2. 对话：两侧半身像，换人说话时明度交叉过渡，表情切换用交叉淡化
   3. 出航：金线沿航路流动，船标滑过，然后"涨潮"转场（墨色海水着色器从下往上漫过屏幕）
   4. 败北与回溯：去饱和加暗角，钟声的声波扫过屏幕，全黑，提灯亮起，再展开新画面
   5. 三种转场单独演示：涨潮、钟声、提灯
2. 所有时长和曲线写在一个参数文件里（例如 `proto/ui_motion/motion.json`），改数值不用改代码。
3. 所有超过 300 毫秒的演出，点击都能跳到结尾状态。
4. 占位音效：用 Godot 生成的简单合成音，或者留出接口并打日志，标明每个声音应该出现的时间点。
5. 录屏替代品：`--capture` 参数把每段演出按 30 帧/秒导出逐帧 PNG 到 `shots/t56/<演出名>/`，Lead 用它审时长。
6. 字体调研写进 `docs/research/FONT_CANDIDATES.md`：
   - 3–5 个可商用的中文宋体或楷体（标题用），2–3 个黑体（正文用），2 个窄体衬线拉丁字体
   - 每个写明授权条款原文链接、是否可以嵌入游戏、字重数量
   - 原型里装 2 套组合，可以切换对比

## 交付
- `proto/ui_motion/README.md`：怎么运行、按键说明、参数文件说明。
- 报告 `reports/agents/T56.md`，开头用 docs/collab.md 第 4 节的 YAML 摘要。
