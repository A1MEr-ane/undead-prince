# 剑盾兵 UV 精灵管线

本管线的模型、UV、骨骼、动作与示例部位贴图全部由 Python 程序生成。只依据本工程的格式规格实现，没有访问或使用商业游戏的解包模型、贴图、骨骼、动画和角色造型。

## 产出与命令

在工程根目录运行（Blender 5.3，使用其自带的 numpy，无额外依赖）：

```sh
blender -b --factory-startup --python-exit-code 1 -P tools/blender/render_sprites.py -- --supersample 8
```

一次重建模型、烘焙动作、渲染 69 帧并生成全部 PNG/JSON。Cycles CPU，4 线程；本机实测脚本阶段约 7 秒。实际耗时随机器变化。每帧先渲染为 512×512 的线性 32 位浮点 EXR，合成为 64×64；EXR 放在自动清理的临时目录。无需窗口、GPU、外部图片、字体或网络。

```sh
# 独立验证产出、UV、骨骼、步态、命中姿势、循环闭合及线性数值
blender -b --factory-startup --python-exit-code 1 -P tools/blender/validate.py

# 只重做示例部位贴图和换色预览，不重新渲染三维模型
blender -b --factory-startup --python-exit-code 1 -P tools/blender/preview.py

# 单独保存可在 Blender 打开检查的模型、刚性蒙皮和全部 Actions
blender -b --factory-startup --python-exit-code 1 -P tools/blender/build_swordsman.py -- --save /tmp/swordsman-review.blend

# 也可以在全流程末尾保存含相机的 assets/sprites/swordsman.blend
blender -b --factory-startup --python-exit-code 1 -P tools/blender/render_sprites.py -- --save-blend
```

`render_sprites.py` 另支持 `--supersample 2/4/8`、`--threads N`、`--size N`、`--output 目录`。提交产物固定使用 64 像素格和 8 倍超采样；验收脚本检查该 69 帧布局。预览脚本读取本管线写出的 filter-0 PNG，不是通用 PNG 编辑器。

## 从资产规格生成兵种（T17）

【定】盾兵资产使用 `assets/specs/k2_shieldman.yml` 定义比例、部件 UV、装备尺寸、配色与三角面预算。高度以“地面到盔顶 = 1”归一化，`landmarks_from_ground` 全部表示离地高度，不能当成部件自身高度相加。参考图与规格有偏差时，遵守任务卡的升级规则；不在脚本里另定一套比例。

```sh
# 生成 B 比例盾兵：69 帧图集、部位贴图、动作表和普通着色多视角
blender -b --factory-startup --python-exit-code 1 -P tools/blender/render_sprites.py -- --spec assets/specs/k2_shieldman.yml --supersample 8

# 可选：同时保存用于 Blender 检查的模型/15 骨骼/11 个 Actions
blender -b --factory-startup --python-exit-code 1 -P tools/blender/render_sprites.py -- --spec assets/specs/k2_shieldman.yml --save-blend

# 固定验收：同时检查原 T06 swordsman 和盾兵，不需要改变 verify.sh
tools/verify/verify.sh sprites

# 只检查指定规格产物（输出到其他目录时另加 --output）
blender -b --factory-startup --python-exit-code 1 -P tools/blender/validate.py -- --spec assets/specs/k2_shieldman.yml
```

不带 `--spec` 的生成命令保持原 T06 行为。带规格时，所有新文件以 `spec.id` 为前缀，不覆盖 `swordsman_*` 或原有 `parts_preview.png` / `preview_*.png`。

| 盾兵产物 | 内容 |
| --- | --- |
| `k2_shieldman_uv.png` / `.json` | `swordsman_uv_v1`，512×576、64×64 格、8 列、69 帧；通道、动画时长/事件、JSON 字段不变 |
| `k2_shieldman_parts.png` | 512×512，仍为 2×2 个 256 图块；默认外观在 (0,0)，未用图块重复该外观；JSON 只列出已定义外观 |
| `k2_shieldman_preview_kingdom_militia_blue.png` | 每个动作一行、3 倍放大，带帧号与事件标记 |
| `k2_shieldman_preview_walk.png` | 默认外观的 walk 单行预览，8 帧、3 倍放大，保留帧号与左右着地事件标记 |
| `k2_shieldman_preview_uv.png` / `_shading.png` | RG 数据和 B 明暗可视预览 |
| `k2_shieldman_view_front.png` / `_side.png` / `_back.png` | 768×768 普通漫反射材质、区域光；统一尺度、无装备 A 姿势，便于对照三视图 |
| `k2_shieldman_view_equipped.png` | 768×768 普通着色的持剑盾待机姿势，便于检查近侧盾遮挡与装备位置 |
| `k2_shieldman_view_equipped_side.png` | 同尺度的纯侧视持装备待机图，与数据图集的镜头方向一致，直接检查身体和双腿的露出 |
| `k2_shieldman_comparison_v4_B.png` | 旧 v4 / 新 B 版普通着色装备侧视并排，保留相同的相机尺度和地面位置 |

`asset_spec.py` 读取项目使用的 YAML 子集（缩进映射、标量列表、行内映射/列表、引号标量），行内集合可以跨行书写，无需 PyYAML 或 Blender 插件；不支持锚点、标签和块式多行标量。标志点按解剖顺序校验，不依赖 YAML 字段的书写顺序（`tunic_hem` 可以低于先写的 `crotch`）。

## 通用 Q 版身体模板（T27）

`chibi_body.ChibiBody(spec, height=1.92)` 负责身体、15 根骨骼及 11 个共用动作。`build_shieldman.Shieldman` 继承模板，只补上装备、持握位置和盾面旋转。装备网格通过现有手骨驱动；没有添加骨骼、动画名、帧或运行时字段。原 `build_swordsman.py` 的 T06 资产与生成入口保持原样。

尺寸以规格的 `proportions.landmarks_from_ground`、`widths` 为输入；`hand_diameter` 替代旧的 `hand_size`。身高表示脚底到盔顶，不从世界原点量起。模板脚底为 `.035`，各高度为 `.035 + landmark × height`，因此缩小角色不会改变图集脚底锚点。默认 B 身高 `1.92`，站姿实际包围盒高 **41/64（64.0625%）**；原 T06 仍约 69%。相机尺度、中心高度和 JSON 坐标约定均保持不变。

模板包括球形头和圆下巴、贴下巴的领口、向下渐宽的梨形衣身、带前后 V 衩的外衣、短圆柱腿、圆脚印靴子和无指手套。腿关节在 `crotch`，腰带不再作为大腿起点。面部绘在 `skin` 部位的头部子范围 `V=.30..1`：正面脸颊采用正投影 UV，使两颗竖椭圆眼和粗眉正面成对、侧面只露出一只；头部其他表面采样空白皮肤。手套与耳朵使用局部 `V=.02..22`，不会带上脸。小嘴仍使用现有 `eye` 区；短发使用 `leather` 区的上部 `V>.68`。部位贴图保持 512×512 / 2×2 个 256 图块；边缘用 4 倍采样消除绘制锯齿，没有新增分区。

新增兵种的步骤：

1. 复制规格为独立 `id`，填写 B 比例的 `landmarks_from_ground`、`widths`（含 `hand_diameter`）、`lean_degrees`、装备参数和预算。用已有 16 个部位键配置 `parts`，在 `looks` 定义颜色。仅改变同类剑盾兵的尺寸、颜色或盾剑参数时，可直接使用现有 `--spec 新文件` 命令。
2. 不同装备结构建立一个小配方继承 `ChibiBody`，在 `model()` 里先调用 `self.body_model()`，再建装备；不要复制头、四肢、骨骼或共用动作。模板目前要求头/眼/外衣/袖/领/腰带/裤/靴/手的部位映射；无该服饰时沿用相应身体区域。可通过构造参数 `height` 整体缩放，通过规格微调比例；持握位置放在 `self.neutral`，肩部站姿偏移放在 `self.shoulder_offsets`。动画插值字典沿用原有键，静态装备参数放在配方属性中。
3. 装备刚性绑定到原骨骼，通过 `base.mesh` / `profile` 使用现有 UV 分区。装备专属动作只在 `pose_parameters()` 调用 `super()` 后补充旋转或持握目标。当前盾兵使用左近手持盾、右远手持剑；盾面从前方 +X 向镜头 -Y 偏 40°，直径按规格 `.42` 身高，剑刃长 `.45`。
4. 新装备配方需在生成入口与验证入口选择对应配方；不同形状不能只靠修改自然语言 `shape`。相同剑盾结构不需要增加路由。生成后把新规格加入默认验收列表，跑同样的 `validate.py -- --spec ...`，检查动作表和普通着色多视角。需要改变规格、骨骼、动画或图集契约时交 Lead 决定。

盾兵当前实测 **34 个刚性网格、314 个多边形、598 个三角面**（target 400 / max 600），15 根骨骼。圆头、手套与封闭袖口使用了接近面数上限的预算；新增装备须重新计数。实测头高 **44%**、裆到地 **22%**，头宽 **46%**、脚长 **14%**、手直径 **11%**；高度标志点按实际网格/骨骼以及头部 UV 测量，不能用输入值代替测量。

新旧对比图可这样重新生成（先保留任务前的 v4 图；`git show` 可导出旧分支的 PNG）：

```sh
blender -b --factory-startup --python-exit-code 1 -P tools/blender/render_sprites.py -- --spec assets/specs/k2_shieldman.yml --supersample 8 --compare-with /tmp/k2_shieldman_v4_side.png
```

`--compare-with` 接受旧的 `k2_shieldman_view_equipped_side.png`，不重新制造旧造型。新旧两张普通着色侧视使用相同正交尺度 `2.70` 和中心高度 `1.06`。省略此选项时只重建当前角色的常规预览。

【定】按 T17 第 4 次修改要求，待机/走路的盾面朝 +X 向镜头偏 40°，盾心在腰带与肩线之间并位于身体前方。攻击蓄力时盾稍向身体收回；招架命中时向前推出并转向 +X（实际烘焙侧向角约 16.6°）。旋转烘焙到原有左手骨骼，骨骼数、动作表和 JSON 契约不变。盾面与拳头保留前后间距。

T27 沿用 T25 的小碎步与上半身锁定，8 张输出帧、`.667s` 两步循环、`right_step=0` / `left_step=.3335` 不变。按新腿长将每脚原 5% 总行程与 2.5% 抬脚乘以 `.22/.24`，实测分别为身高 **4.58333%** 与 **2.29167%**；身体起伏为 0。Action 内额外烘焙 256 段姿势，以保持短腿 IK 在中间采样时也满足原对称性与支撑漂移阈值，未增加图集帧数。`SPEC_WALK` 输出实测脚行程、抬脚、身体起伏、上半身矩阵变化与支撑漂移；身高分母为 `1.92`。

攻击蓄力时剑在大头远侧，`.333s` 仍为水平前砍。坐地/起身/死亡的脚目标按短腿重设，倒地时由大头先接近地面；fall → sit → rise → idle 关节位置闭合。`SPEC_CHIBI_POSES` 对 69 帧及独立事件时点共 72 个姿势做剑刃到头/盔的实际网格射线检查，不用二维预览猜测穿模。

自动验收保留 T06 检查以及图集布局、透明边界、UV 保护带、实际外观、独立射线 UV/明暗、命中、循环、步态、盾面角度、攻防位移和侧视可见性检查。`SPEC_PROPORTIONS` 从实际鞋底/盔顶归一化，测量全部高度标志点、头宽、肩宽、脚长及手直径，要求相对规格偏差 ≤ 10%；眼线通过头部 UV 对应的几何位置求得。对待机与 8 张走路姿势逐像素发射侧视射线，仍要求外衣上半、远侧肩袖、两侧裤腿与靴子可见，盾不挡头和腿。可见性像素数不代替 Lead 的可爱感与游戏节奏验收。

| 文件 | 用途 |
| --- | --- |
| `tools/blender/build_swordsman.py` | 原 T06 模型及共享网格、15 骨骼、IK、Action 烘焙工具 |
| `tools/blender/chibi_body.py` | 通用 B 比例身体、部位 UV、骨骼位置和 11 个共用姿势 |
| `tools/blender/build_shieldman.py` | 身体模板 + 碗盔/盾/剑装备配方与盾的动作补充 |
| `tools/blender/render_sprites.py` | 纯侧视相机、线性数据材质、超采样、图集、JSON、自检 |
| `tools/blender/preview.py` | 四种程序绘制外观、部位贴图、线性光照合成、带标签预览 |
| `tools/blender/common.py` | 固定布局与动画定义、无颜色转换的 PNG 读写 |
| `tools/blender/validate.py` | 文件与帧布局、姿势、蒙皮、UV、射线数值验收 |
| `tools/blender/.gitignore` | 忽略 Python 缓存 |
| `assets/sprites/swordsman_uv.png` | 游戏使用的 RGBA 数据图集，512×576 |
| `assets/sprites/swordsman_uv.json` | 帧坐标、动画、事件、部位矩形、外观位置、格式与验收信息 |
| `assets/sprites/parts_preview.png` | 2×2 外观图块，每块 256×256，整图 512×512 |
| `assets/sprites/preview_militia.png` | 蓝白王国民兵，全部动作按行展示，3 倍放大 |
| `assets/sprites/preview_veteran.png` | 红金王国老兵，全部动作 |
| `assets/sprites/preview_undead.png` | 暗紫灰、苍白皮肤亡魂兵，全部动作 |
| `assets/sprites/preview_elite.png` | 青绿亡魂精锐，全部动作 |
| `assets/sprites/preview_looks.png` | 四外观并排；待机、命中、招架、死亡终态，4 倍放大 |
| `assets/sprites/preview_uv.png` | RGBA 数据的可视预览，3 倍放大 |
| `assets/sprites/preview_shading.png` | B 通道灰度预览，3 倍放大 |

## 图集契约

- **69 帧、64×64 正方形格、8 列、9 行，按行优先，所有帧索引从 0 开始。** 最后一行后 3 格全透明。
- 图像矩形、外观图块坐标采用左上原点；部位 UV 则采用左下原点，V 向上。
- 原 T06 站姿覆盖约 69% 格高；B 比例盾兵为 60–65%，当前 41/64。脚底距格子底边约 2 像素。固定相机与尺度，动作间不重新居中、不缩放。倒地过程中只对穿地的整体姿势向上补偿，数值记在每帧 `ground_lift` 中。
- **R、G：** 部位贴图一个外观图块内的 U、V，0–1 线性 UNORM8。
- **B：** `clamp(0.5 + 0.5 * dot(N_world, L_world), 0, 1) * side_factor`。0.5 为中性。`L = normalize(0.50, -0.65, 0.70)`，从画面右、相机同侧、上方来。远侧左臂/左腿/左手及远侧眼的 `side_factor = 0.82`，其余为 1。
- **A：** 线性覆盖度，非预乘存储；全透明像素 RGBA 均为 0。超采样覆盖约有 64 个层级，再量化到 8 位。
- 模型 +X 朝右、+Z 朝上；相机位于 -Y，纯侧视正交，`ortho_scale=3.05`、中心高度 1.465。图中未加入游戏镜头 30° 俯角，也未预乘游戏的 1.154700538 竖向补偿。
- 材质直接 emission 输出 UV 和几何法线明暗。Cycles 单采样、固定随机种子、极小 box filter，禁用降噪、合成器和序列器。Raw、曝光 0、gamma 1；浮点 EXR 中转，最终用自写 PNG 编码器保存原始数据，**不含 sRGB、gAMA、ICC 色彩块**。

超采样合并时，A 和 B 对所有覆盖样本积分；RG 先选覆盖最多的部位区域，再只平均该区域中的 UV，防止盾面和上衣的 UV 被混成另一个部位。背景不参与 RG 平均。单个 RG 像素无法同时描述两张不同的表面；细小内部交界仍可能出现一个像素左右的花纹取舍。

## 部位布局

每个外观图块为 256×256，内部 4×4 区域，每区 64×64。每边留 4 像素保护带，有效 UV 为 56×56；贴图程序把边缘颜色延伸到保护带。区域按左下原点编号 `(cx, cy)`：

`uv_rect = ((64*cx+4)/256, (64*cy+4)/256, (64*(cx+1)-4)/256, (64*(cy+1)-4)/256)`

矩形是 `(u_min, v_min, u_max, v_max)`，**不是宽高**。以下均为图块内局部 UV。完整同名映射保存在 JSON 的 `part_texture.regions`。

| 部位键 | 部位 | 区域 (列, 行) | U 范围 | V 范围 | 局部展开 |
| --- | --- | --- | --- | --- | --- |
| `skin` | 头、鼻、手 | (0,3) | .015625–.234375 | .765625–.984375 | 球面/圆柱，V 向上 |
| `helmet` | 盔顶、护鼻 | (1,3) | .265625–.484375 | .765625–.984375 | 盔顶圆柱，护鼻平面 |
| `tunic` | 外衣、外扩下摆 | (2,3) | .515625–.734375 | .765625–.984375 | U 绕身一周，V 从下到上 |
| `cloth_trim` | 领口、下摆镶边 | (3,3) | .765625–.984375 | .765625–.984375 | 圆柱 |
| `sleeves` | 上臂袖 | (0,2) | .015625–.234375 | .515625–.734375 | 圆柱 |
| `trousers` | 大腿、小腿 | (1,2) | .265625–.484375 | .515625–.734375 | 沿骨段圆柱 |
| `boots` | 靴 | (2,2) | .515625–.734375 | .515625–.734375 | 分层圆柱，V 沿高度 |
| `leather` | 腰带、剑柄 | (3,2) | .765625–.984375 | .515625–.734375 | 圆柱 |
| `shield_face` | 盾正面 | (0,1) | .015625–.234375 | .265625–.484375 | 圆形平面，中心 (.5,.5)，半径 .49 |
| `shield_rim` | 厚盾边 | (1,1) | .265625–.484375 | .265625–.484375 | 同盾面径向映射 |
| `shield_back` | 盾背 | (2,1) | .515625–.734375 | .265625–.484375 | 圆形平面 |
| `metal` | 盔缘、盾心、护手 | (3,1) | .765625–.984375 | .265625–.484375 | 圆柱/球面/平面 |
| `blade` | 菱形截面剑刃 | (0,0) | .015625–.234375 | .015625–.234375 | U 横向、V 从护手到剑尖 |
| `hilt` | 剑柄配件、剑首 | (1,0) | .265625–.484375 | .015625–.234375 | 球面 |
| `eye` | 双眼 | (2,0) | .515625–.734375 | .015625–.234375 | 平面 |
| `belt_buckle` | 带扣 | (3,0) | .765625–.984375 | .015625–.234375 | 平面 |

衣服圆柱缝在 +X，U 由 +X 朝 +Y 增长；相机侧 U 约 .75。袖/裤的 V 沿骨段由近端至远端。球面两极共享几何顶点，但每面保留合理的接缝 UV。盾面局部 U 向画面右，V 向上，盾徽可直接在圆里画。示例纹理由程序绘制衣褶、浅色衣襟、缝线、盾面象限、折线与菱形徽记、边缘铆钉、金属亮带及剑脊。

四种外观图块的 `(tile_x,tile_y)` 采用整张部位贴图的左上原点：

| 外观键 | 图块 | 配色 |
| --- | --- | --- |
| `militia` | (0,0) | 王国民兵蓝白 |
| `veteran` | (1,0) | 王国老兵红金 |
| `undead` | (0,1) | 亡魂兵暗紫灰、苍白皮肤 |
| `elite` | (1,1) | 亡魂精锐青绿 |

## 动画与时间

| 动画 | 起始帧 | 帧数 | 时长/秒 | 循环 | 事件/秒 |
| --- | ---: | ---: | ---: | --- | --- |
| idle | 0 | 6 | .667 | 是 | — |
| walk | 6 | 8 | .667 | 是 | left_step=.3335，right_step=0 |
| attack | 14 | 8 | .600 | 否 | hit=.333 |
| parry | 22 | 8 | .650 | 否 | block=.260 |
| clash | 30 | 4 | .350 | 否 | contact=0 |
| fall | 34 | 4 | .350 | 否 | ground_contact=.350 |
| sit | 38 | 6 | 1.000 | 是 | — |
| rise | 44 | 10 | .833 | 否 | standing=.740 |
| death | 54 | 7 | .583 | 否 | ground_contact=.486 |
| ragdoll | 61 | 6 | .517 | 是 | — |
| hit | 67 | 2 | .167 | 否 | impact=0 |

运行时每帧等时长 `frame_duration = duration/frame_count`；播放帧为 `start_frame + min(floor(t/duration*frame_count), frame_count-1)`，循环动作先对 t 取模。事件按实际秒数跨越触发，每次播放只触发一次；循环动作在每个周期重置，0 秒事件在进入/循环重启时触发。时长末尾的事件应在离开动画前触发。

JSON 的 `source_sample_times` 是三维 Action 的采样时间，**不用于决定游戏播放帧长**。循环不重复采样闭合帧；非循环包含精确起终姿势，攻击和招架还刻意采样关键姿势。攻击局部帧 4（全局 18）对应三维的 .333 秒前砍，运行时显示区间 [.300,.375)，涵盖 .333 秒命中事件。`event_frames` 是事件落入的全局播放帧。每帧的 `source_time`、`rect`、`alpha_bbox`、`ground_lift` 可供排查。

原 T06 步态前四帧左脚向前摆动，后四帧右脚，落地腿向后承重，身体每步上下起伏；B 比例模板采用前述小碎步，上半身保持固定。攻击包括后撤屈膝、举剑、前压、下砍跟随及收剑；招架包括缩身、前推、受力回弹。fall 的终态与 sit 起始姿态衔接；rise 从坐地、前压重心、屈膝支撑至站立。death 收到水平仰倒并停留。ragdoll 保持蜷身并绕相机侧的水平深度轴转满一周，整体位移交给游戏。

模型由 33 个刚性蒙皮网格组成，396 个多边形 / 768 个三角面。骨骼是 `root`、`spine`、`head`，以及左右 `upper_arm` / `forearm` / `hand`、`thigh` / `shin` / `foot`。双手控制剑盾。骨骼使用四元数、location/rotation/scale 关键帧；骨段目标由程序 IK 计算，烘焙为独立 Action。Blender 时间线用 1000 fps 表示毫秒，事件有 Action marker；这不改变精灵的运行时帧时长。

## 接入与颜色

接入方读取 JSON 即可，不需要 Blender。帧矩形是整张图的像素坐标。用 `frame % 8` 和 `frame / 8` 也能还原格子位置。

图集是 **data texture**：关闭 sRGB 解码、压缩和 mipmaps，使用 nearest 采样，保持 RGBA 原值；不得把 alpha 预乘到 RG。建议无损导入。避免对整个图集做双线性过滤，以免跨帧或跨部位插值。画面边缘的柔和覆盖已存在 A 中，最终颜色再用该 A 混合。

示例部位贴图 RGB 是普通 sRGB 美术颜色，可用双线性过滤。若引擎纹理原点在左上，则在选中的外观图块中用 `(R,1-G)` 采样；对于当前 2×2 排布：

```text
parts_uv = (vec2(tile_x, tile_y) + vec2(atlas.r, 1.0 - atlas.g)) / vec2(2.0, 2.0)
paint_linear = sRGB_decode(parts_texture(parts_uv).rgb)
colour_linear = paint_linear * (2.0 * atlas.b)
alpha = atlas.a * parts_texture(parts_uv).a
```

若采样器已自动把部位贴图解码为线性颜色，不要重复解码。最终显示时按引擎正常流程编码为 sRGB。四个示例图块当前都不透明；可在部位贴图 alpha 上隐藏部位，但**不会补出原先被其遮住的身体表面**。

本管线只修改独立资产和工具，没有改动 `scripts/`、`shaders/` 或项目导入设置。T27 在沙箱中启动 Godot 窗口失败，未取得游戏截图；可爱感与游戏节奏仍由 Lead 在游戏内验收。接入者应按上述线性纹理契约配置导入与采样。

## 验收与限制

实际后台生成并打开检查了全动作换色预览、四外观对照、RG 图与 B 灰度图。脚本检查帧范围和透明留白、站姿占比、全部 UV 保护带、透明 RGB、AA 像素、部位覆盖、刚性权重、步态交替、命中姿势和循环闭合。独立射线检查使用完整落在同一平面多边形内的像素，比较 PNG 的 RG 与插值几何 UV、B 与几何法线光照，避免把边界的面积积分误当成中心采样。

已知限制：刚性分段关节有少量穿插；64 像素下薄剑与衣褶存在采样取舍；8 位 RG 限制每个区域的有效坐标精度。每格只能保存一个主表面的 UV，部位交界的混合表面无法完整表达。当前只有固定镜头方向和固定烘焙光方向，没有环境遮蔽、动态阴影、布料模拟或物理 ragdoll；击飞轨迹、地形适配及运行时光照由游戏处理。示例贴图是程序绘制的四套配色和花纹，不包含独立的装备造型变体。
