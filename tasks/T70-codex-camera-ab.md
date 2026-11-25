---
id: T70
title: 镜头 A/B 小试验：固定单向 / 四个固定朝向 / 连续 360°（在攻城原型里）
owner: codex
status: blocked   # 等 T69 合并后改成 queued
branch: codex/t70-camera-ab
worktree: ../亡魂王子-t70
allowed: [proto/siege/camera/, proto/siege/README.md]
forbidden: [scripts/, shaders/, data/, docs/, tasks/, art/, assets/, project.godot, proto/siege/siege_director.gd]
verify: tools/verify/proto_siege.sh
retry_limit: 2
max_minutes: 120
escalate_if: [镜头改动影响战斗逻辑或确定性]
---

## 目标
用户问过镜头能不能不旋转、四个方向行不行，**还没有决定**。在攻城原型里做一个小试验，让用户凭实际手感选择。**不改战斗逻辑。**

## 要做
1. 三种镜头模式，用参数或按键切换：
   - 固定单向
   - 四个固定朝向（相差 90°，围绕当前观察焦点旋转；分"瞬切"和"0.25 秒过渡"两种）
   - 现有的连续旋转
   所有模式都保留平移和缩放，俯角固定。
2. 旋转过程中禁止长按部署，或者在过渡结束后重新计算落点，避免误投兵。
3. 精灵朝向：用相对角度 = 单位朝向 − 镜头朝向来决定左右翻转，检查四个朝向下的翻转和脚底接地是否正确。
4. 同一场回放（固定种子和策略）在三种模式下各录逐帧截图，放 `shots/t70/<模式>/`。重点拍：墙后、山体后、窄路、山洞口、登陆点。
5. 报告里对比遮挡、部署落点、精灵方向、帧时间。

## 交付
报告 `reports/agents/T70.md`，开头用 YAML 摘要。最终选哪种由用户决定。
