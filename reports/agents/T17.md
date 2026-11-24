## 结果：完成

已完成规格驱动的王国盾兵建模、部位贴图、UV 图集、全动作彩色预览、普通着色三视角及文档；固定验证通过。**提交在 git add 阶段被沙箱拒绝，全部改动保留，未产生提交。** 造型是否符合参考图、游戏远近景效果与走路观感，留给 Claude / Lead 验收，本报告不作审美通过结论。

- 分支：`codex/t17-shieldman`
- 工作目录：`/Users/cyy/Documents/ChatGPT/亡魂王子-t17`
- 实际模型：**42 个刚性网格、230 个多边形、494 个三角面**；预算 target 400 / max 600。
- 保留 **15 骨骼、11 动作、69 帧、64×64 格、8 列×9 行、512×576 图集**与 `swordsman_uv_v1` JSON 契约。
- 自我修复：**1 / 3 次**；未触发本次续作的升级条件。按本轮开始时间计算，用时未超过 120 分钟。

## 改动

- `tools/blender/asset_spec.py`：接续工作区已有实现，读取项目 YAML 子集，检查归一化标志点、UV 部位与预算；无需外部包。
- `tools/blender/build_shieldman.py`：新增剑盾兵配方。按规格生成大头、八棱圆顶宽檐盔与护鼻、短发/耳/眉眼、无袖开衩罩袍、靛蓝袖裤、方块拳头、分段高筒靴、近侧大圆盾与单手剑；无盾心凸起。主要比例、部件 UV、盔/盾边数、盾尺寸、剑长和预算从规格读取。
- `tools/blender/build_swordsman.py`：继续已有自定义 model / skeleton / pose 接口，增加额外烘焙时刻入口；清理同名旧 Actions，避免在同一 Blender 进程连续构建时误用旧动作。
- `tools/blender/render_sprites.py`：增加 `--spec`。沿用固定图集/JSON 写入过程，按 `spec.id` 输出新文件；不带规格仍走原 T06 路径。
- `tools/blender/shieldman_preview.py`：读取 `looks`，生成无噪点的 2–3 层平面明暗、金色八芒太阳和暗红斜带；输出 3 倍动作表及普通漫反射材质的模型预览。继续使用 2×2 外观图块布局，默认外观位于 (0,0)。头发借用 leather 区域上部，未增加 UV 分区。
- `tools/blender/validate.py`：固定 sprites 验证同时检查原 swordsman 和盾兵；保留原有检查，并增加规格模型测量、面数、装备尺寸、贴图、预览、步态高度/摆臂与烘焙支撑脚漂移检查。
- `assets/specs/k2_shieldman.yml`：保留续作已有的盔/盾边数、盾直径/厚度、剑长字段，新增数值 `lean_degrees: 4`；未重写离地高度规格。当前 SHA256：`107cb96b9a275096198db1972decb4d678f90d7a5c1e5d37a42a46d5708139e8`。
- `assets/sprites/k2_shieldman_*`：新增 10 个产物文件，完整路径见下文。没有覆盖或修改原 `swordsman_*`、`parts_preview.png`、`preview_*.png`。
- `docs/sprite-pipeline.md`：补充规格字段、生成命令、新兵种流程、配方适用范围、产物与验证方式。
- `reports/agents/T17.md`：本报告（任务明确指定的交付文件）。

开工时 `tasks/T17-codex-shieldman.md` 已有续作说明改动；本轮未修改、未暂存该文件。已有 `reports/agents/T17-attempt1.md` 保留，不纳入本次提交。未修改 scripts / shaders / project.godot / AGENTS.md / 动画表 / UV 分区定义。

提交尝试：显式列出上述允许文件执行 `git add -- ...`，退出码 128；未进入 `git commit` 阶段。原样错误：

```text
fatal: Unable to create '/Users/cyy/Documents/ChatGPT/亡魂王子/.git/worktrees/亡魂王子-t17/index.lock': Operation not permitted
```

没有绕过沙箱、修改 git 元数据或重建仓库。请 Lead 在已有 `codex/t17-shieldman` 分支提交本报告列出的文件，勿把预先存在的 tasks 改动或旧报告一并暂存。预定提交信息（含规定署名）：

```text
feat(sprites): build and render spec-driven kingdom shieldman

Co-Authored-By: GPT-6 <gpt-6@noreply.openai.com>
```

## 验证

### 构建与实际渲染

命令（退出码 0）：

```sh
blender -b --factory-startup --python-exit-code 1 -P tools/blender/render_sprites.py -- --spec assets/specs/k2_shieldman.yml --supersample 8
```

关键输出：

```text
PROCEDURAL_MODEL {'objects': 42, 'bones': 15, 'polygons': 230, 'triangles': 494}
SPRITE 69/69 hit[1] t=0.167
MODEL_VIEW front
MODEL_VIEW side
MODEL_VIEW back
MODEL_VIEW equipped
COMPLETE {"covered_pixels": 51623, "antialiased_pixels": 10618, "shade_range": [36, 255], "all_frames_inside_cell": true, "uv_islands_valid": true, "transparent_rgb_zero": true} 19.6s
```

使用 Blender 5.3.0 后台实际渲染，已打开检查全部动作表及 front / side / back / equipped 图。下列三视角为普通材质加区域光的模型渲染，非 UV 假色图。

### 固定验收

命令：`tools/verify/verify.sh sprites`，最终退出码 **0**。

```text
[通过] sprites
全部通过 → /Users/cyy/Documents/ChatGPT/亡魂王子-t17/reports/verify/20261124-115624.json
```

日志关键行：

```text
VALIDATED swordsman {"covered_pixels": 36251, "antialiased_pixels": 11950, "shade_range": [30, 255], "all_frames_inside_cell": true, "uv_islands_valid": true, "transparent_rgb_zero": true, "standing_alpha_bbox": [26, 18, 49, 62], "ray_samples": 30, "ray_uv_error_p90": 0.00176, "ray_shade_error_p90": 0.00219, "model": {"objects": 33, "bones": 15, "polygons": 396, "triangles": 768}, "loops_close": true, "walk_legs_alternate": true, "exact_hit_pose": true}
SPEC_MODEL k2_shieldman triangles=494 walk_stance_drift=[1.1e-05, 1.1e-05]
VALIDATED k2_shieldman {"covered_pixels": 51623, "antialiased_pixels": 10618, "shade_range": [36, 255], "all_frames_inside_cell": true, "uv_islands_valid": true, "transparent_rgb_zero": true, "standing_alpha_bbox": [23, 18, 54, 62], "ray_samples": 305, "ray_uv_error_p90": 0.00181, "ray_shade_error_p90": 0.00143, "model": {"objects": 42, "bones": 15, "polygons": 230, "triangles": 494}, "loops_close": true, "walk_legs_alternate": true, "exact_hit_pose": true}
```

- 机器报告：`reports/verify/20261124-115624.json`；完整日志：`reports/verify/20261124-115624.log`（均按仓库规则忽略，不提交）。
- `git diff --check`：通过，无输出。
- 额外用 Python 比较原/新 JSON：顶层字段、格式、通道、相机、动画表（含采样时刻/事件）、UV 分区等全部一致，输出 `CONTRACT_MATCH: JSON keys, format, channels, camera, animation table, sample times, events, part regions unchanged`。

### 首轮失败与第 1 次修复

首轮固定验证在同一进程先建 T06、后建盾兵时报告 `AssertionError: [0.06196207425674844, 0.06057420753446274]`（支撑脚漂移）。诊断发现第二套 Actions 被 Blender 自动命名为 `.001`，后续按 `walk` 名取到的是上一套动作。构建前清理同名生成动作后，实际烘焙漂移降至约 `0.000011`，低于未改变的 `.006` 阈值。同时修正三视角审查姿势的手臂可达范围、肩袖衔接和靴筒随胫骨运动。修复后两次固定验证均通过；未放宽已有检查。

### 产物 / 截图路径（相对工作目录）

- 数据：`assets/sprites/k2_shieldman_uv.png`、`assets/sprites/k2_shieldman_uv.json`
- 部位贴图：`assets/sprites/k2_shieldman_parts.png`
- **全动作彩色预览（11 行、3 倍）：** `assets/sprites/k2_shieldman_preview_kingdom_militia_blue.png`
- **正面：** `assets/sprites/k2_shieldman_view_front.png`
- **侧面：** `assets/sprites/k2_shieldman_view_side.png`
- **背面：** `assets/sprites/k2_shieldman_view_back.png`
- **装备姿势：** `assets/sprites/k2_shieldman_view_equipped.png`
- UV 预览：`assets/sprites/k2_shieldman_preview_uv.png`
- 明暗预览：`assets/sprites/k2_shieldman_preview_shading.png`

## 风险与已知不足

- 这是独立精灵资产交付，未接入 Godot 运行时；没有游戏 zoom 15 / zoom 6 的截图。任务禁止修改游戏接入口，远近景辨识与最终造型需 Lead 接入后判断。
- 64 像素精灵与每部位 56×56 有效贴图仍有既有的量化限制；高分辨率普通着色图上也能看到纹章贴图的像素边缘。
- 使用刚性分段蒙皮，关节仍可能有局部穿插或接缝；未引入布料模拟或平滑权重。其余动作复用 T06 姿势目标并适配盾兵比例和持盾侧。
- “无滑步”自动检查针对模型以约 `1.1994` 单位/秒前移时的支撑脚世界位置；游戏移动距离需匹配步态相位。自动检查不能代替 Claude 对动画观感的验收。
- YAML 是项目子集，配方支持相同结构的剑盾兵；任意新兵种不会仅凭自然语言 shape 自动生成新拓扑。

## 未完成

- 任务卡要求的实现和资产导出无剩余项。
- 分支提交未完成：工作树元数据的 index.lock 被沙箱拒绝创建，需 Lead 代为提交。
- Claude 对照参考图的造型验收、Godot 中远近景与走路观感验收尚未进行，属于 Lead 后续审查。

## 疑问（需要用户或 Lead 决定的）

- 无阻塞问题；请 Lead 依据上述实际预览进行视觉验收。未替 Lead 作造型通过结论。
