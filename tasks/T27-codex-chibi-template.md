---
id: T27
title: 通用 Q 版身体模板 + 按 B 比例重建盾兵
owner: codex
status: done
branch: codex/t27-chibi
worktree: ../亡魂王子-t27
images: [/Users/cyy/Projects/亡魂王子/concept/turnaround/t_k2_shieldman_B_turn.png, /Users/cyy/Projects/亡魂王子/concept/turnaround/t_k2_shieldman_B_props.png, /Users/cyy/Projects/亡魂王子/concept/proportion/prop_shieldman.png]
allowed: [tools/blender/, assets/sprites/, docs/sprite-pipeline.md]
forbidden: [scripts/, shaders/, assets/specs/, project.godot, tasks/]
verify: tools/verify/verify.sh sprites
retry_limit: 3
max_minutes: 150
escalate_if: [需要改图集格式、帧数、动画名或时长（游戏依赖）, 规格与三视图偏差超过 10%, 需要改规格]
---

## 目标
用户觉得"腿不够短"、要"可爱"，已选定 **B 比例（2.3 头身）**（docs/art-direction.md【定】）。把 Blender 管线改成**通用 Q 版身体模板**，并用它重建王国盾兵。以后每个兵种只定义装备、配色和少量比例偏移。

## 输入
- 规格：`assets/specs/k2_shieldman.yml`（proportions 已按 B 重写：landmarks_from_ground、widths、shape_notes）
- 形体规则：`docs/art-direction.md` 第 3 节
- 参考图：附图 1 新三视图（B）、附图 2 道具、附图 3 比例对比图（中间那个是 B）
- **比例以规格数值为准**（Claude 美术决定）：新三视图的头约 0.38、外衣偏长、露出的腿约 0.16，与用户选定的 B（头 0.44、腿 0.22）有偏差——**按规格数值做**（头更大、外衣下摆在 0.19、腿露出到 0.22），三视图只参考形状、配色和细节（碗形盔、粗眉豆豆眼、梨形外衣、大圆头靴、圆手套）。附图 3 中间那个 B 是比例的视觉目标。这一项不算"规格与三视图偏差超过 10%"，不必上报。

## 要做
1. 新建 `tools/blender/chibi_body.py`：参数化 Q 版身体——球形头/圆下巴、几乎无脖子、梨形躯干、短粗无膝圆柱腿、大圆头鞋、无手指圆手套；所有尺寸来自规格的 proportions，部件 UV 落在现有 16 个部位分区里。骨骼名称和数量沿用（15 根），只改长度和位置以适配短腿大头。
2. 盾兵改为"模板 + 装备"：碗形盔带帽檐和护鼻、外衣/袖/裤/皮带、圆盾（直径约 0.40 身高、朝前偏镜头 40°）、单手剑。三角面预算仍 target 400 / max 600。
3. 脸：在部位贴图 skin 区的头部范围画豆豆眼和粗眉，侧视可见一只眼一道眉；颜色按规格 looks。
4. 动作：11 个动作的名字、帧数、时长、事件不变。按新比例重新调姿势，避免穿模（例如剑不穿头、盾不穿脸）；walk 保持小碎步（规格 animation_notes.walk，腿短所以幅度按新腿长换算）；fall/sit/rise/death/ragdoll 要适应大头（倒地时头着地的姿势要自然）。允许 Q 版的夸张：受击和倒地可以有更明显的挤压拉伸感（通过姿势表现）。
5. 图集：格式和 JSON 契约不变；人物站姿高度约占格高 60–65%；脚底锚点位置不变。
6. 预览：动作表、正/侧/背/装备侧视普通着色图，以及一张"新旧对比"（旧盾兵 v4 与新 B 版侧视并排）。
7. `validate.py`：增加按规格 landmarks 检查比例（偏差 ≤ 10%），保留其他检查。更新 `docs/sprite-pipeline.md`：怎么用模板加一个新兵种。

## 验收
- [ ] `tools/verify/verify.sh sprites` 通过
- [ ] 报告写明实测比例（头/腿占比）、三角面数、预览路径
- [ ] Claude 对照三视图与游戏内截图判断可爱感
