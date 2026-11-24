---
id: T17
title: 盾兵试点 P2：按规格建模并渲染 UV 精灵
owner: codex
status: done
branch: codex/t17-shieldman
worktree: ../亡魂王子-t17
images: [/Users/cyy/Projects/亡魂王子/concept/turnaround/t_k2_shieldman_turn.png, /Users/cyy/Projects/亡魂王子/concept/turnaround/t_k2_shieldman_props.png, /Users/cyy/Projects/亡魂王子/concept/simple/s_k2_shieldman.png]
allowed: [tools/blender/, assets/sprites/, assets/specs/, docs/sprite-pipeline.md]
forbidden: [scripts/, shaders/, project.godot, AGENTS.md, tasks/]
verify: tools/verify/verify.sh sprites
retry_limit: 3
max_minutes: 120
escalate_if: [规格里的比例或部件与三视图冲突, 需要改图集格式或动画表（会影响游戏接入）, 三角面超出预算仍达不到造型]
---

## 目标
把 T06 的程序化剑盾兵管线改成"按资产规格建模"，第一个落地的是王国盾兵。造型以附带的三视图、道具图和简化版为准；比例、部件、配色、验收以 `assets/specs/k2_shieldman.yml` 为准。

## 要做
1. 读 `assets/specs/k2_shieldman.yml`、`docs/sprite-pipeline.md`、`tools/blender/` 全部脚本。
2. 让建模脚本读取规格文件（比例、部件、三角面预算）；保留 15 骨骼、11 个动作、69 帧图集格式和 JSON 契约**不变**（游戏接入依赖它）。
3. 按三视图重建盾兵低模：大头（约 1/3 身高）、八棱圆顶宽檐盔带护鼻、象牙白无袖罩袍、靛蓝袖子和裤子、棕色高筒靴、方块拳头、大圆盾（侧视时在近侧挡住身体前半）、单手剑。三角面 400 左右，最多 600。
4. 按规格 animation_notes 改进走路：每步"着地—过渡—蹬地"、过渡时身体最高、手臂与腿反向、不滑步。其余动作沿用。
5. 按规格 looks 生成该外观的部位贴图（手绘感的 2–3 层平面明暗，太阳纹章 + 暗红斜带清楚），输出到 `assets/sprites/`（新文件名带 k2_shieldman 前缀，不要覆盖现有 swordsman_* 文件）。
6. 导出：图集 PNG + JSON、彩色预览（每个动作一行，3 倍放大）、三视角预览（正、侧、背各渲染一张普通着色的图，便于和三视图对照）。
7. 更新 `docs/sprite-pipeline.md`：怎么用规格文件出一个新兵种。

## 验收
- [ ] `tools/verify/verify.sh sprites` 通过（必要时扩展 validate.py 让它也检查 k2_shieldman 的产物，但不要放宽已有检查）
- [ ] 三角面数在预算内（报告里写实际数字）
- [ ] 预览图路径写进报告，由 Claude 对照三视图判断造型（你不用自己下审美结论）

## 交付报告
reports/agents/T17.md

## 续作说明（2026-11-24 11:15 追加）
- 规格已改为"离地高度"写法（`proportions.landmarks_from_ground`），与三视图偏差 10% 以内照三视图做，不必上报。
- 上一次执行因 Codex 额度用尽中断，工作区里有**未提交的改动**（已开始让 build_swordsman.py 支持自定义 model/skeleton/pose 构建函数）。先 `git status` 和 `git diff` 查看，在其基础上继续，不要从头重来。

## Claude 视觉验收意见（2026-11-24 12:00，第 3 次产出）→ 第 4 次修改
通过：盔（圆顶宽檐护鼻）、大头、方块拳、靴子、太阳纹章清晰度。
不通过：**盾太大且正对镜头，侧视几乎挡住整个人**——罩袍和袖子看不见、走路时腿被挡住、远景只剩"盾 + 盔 + 脚"。
修改（规格已更新 `shield`）：
1. 盾直径 0.55 → **0.42** 身高。
2. 盾面朝前方（+X）偏向镜头约 **40°**，不是正对镜头；盾心在腰带与肩线之间、身体前方。
3. 侧视必须露出：头盔完整轮廓、罩袍上半部、远侧肩与袖子、双腿迈步（规格 `must_show_in_side_view`）。
4. 各动作里盾的姿态同步调整（attack 时盾稍收到身前、parry 时盾向前推出并转成更正对前方）。
5. 其他不变。重新渲染图集和预览，`verify.sh sprites` 通过，报告附新的 view_equipped 和动作表路径。
