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

| 文件 | 用途 |
| --- | --- |
| `tools/blender/build_swordsman.py` | 网格、部位 UV、15 骨骼、解析双骨 IK、关键帧 Actions |
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
- 站姿覆盖约 69% 格高，脚底距格子底边约 2 像素。固定相机与尺度，动作间不重新居中、不缩放。倒地过程中只对穿地的整体姿势向上补偿，数值记在每帧 `ground_lift` 中。
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

步态前四帧左脚向前摆动，后四帧右脚，落地腿向后承重，身体每步上下起伏。攻击包括后撤屈膝、举剑、前压、下砍跟随及收剑；招架包括缩身、前推、受力回弹。fall 的终态与 sit 起始姿态衔接；rise 从坐地、前压重心、屈膝支撑至站立。death 收到水平仰倒并停留。ragdoll 保持蜷身并绕相机侧的水平深度轴转满一周，整体位移交给游戏。

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

本任务只提供独立资产和工具，没有改动 `scripts/`、`shaders/` 或项目导入设置，也未验证 Godot 接入后的实际效果。接入者应按上述线性纹理契约配置导入与采样。

## 验收与限制

实际后台生成并打开检查了全动作换色预览、四外观对照、RG 图与 B 灰度图。脚本检查帧范围和透明留白、站姿占比、全部 UV 保护带、透明 RGB、AA 像素、部位覆盖、刚性权重、步态交替、命中姿势和循环闭合。独立射线检查使用完整落在同一平面多边形内的像素，比较 PNG 的 RG 与插值几何 UV、B 与几何法线光照，避免把边界的面积积分误当成中心采样。

已知限制：刚性分段关节有少量穿插；64 像素下薄剑与衣褶存在采样取舍；8 位 RG 限制每个区域的有效坐标精度。每格只能保存一个主表面的 UV，部位交界的混合表面无法完整表达。当前只有固定镜头方向和固定烘焙光方向，没有环境遮蔽、动态阴影、布料模拟或物理 ragdoll；击飞轨迹、地形适配及运行时光照由游戏处理。示例贴图是程序绘制的四套配色和花纹，不包含独立的装备造型变体。
