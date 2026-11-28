# 灰潮外岛地形套件

四个固定战区沿用攻城原型的登陆、大路、侧路和山洞拓扑。正面大路过城门入外城，西侧小路经坡道和薄弱墙接入广场，东侧山洞从登陆滩通往城内。外城连到主堡与守军撤离港。

| 机位 ID | 战区 | 画面重点 |
|---|---|---|
| `coast` | 登陆海岸 | 木码头、登陆滩、大路口、城门、山洞入口 |
| `highland` | 松脊高地 | 侧路坡道、弓兵塔、攀爬岩带、薄弱墙 |
| `plaza` | 外城广场 | 城门内侧、民房、石广场、山洞出口 |
| `keep` | 主堡与守军港 | 主堡前场、撤离道路、码头和帆船 |
| `overview` | 总览 | 四战区和守军港同屏 |

## 模块

| 来源 | 模块 |
|---|---|
| `ground.gd` | 不规则海岸、潮间带、泻湖、浅滩、沙滩、高地崖壁、各段坡道、道路、铺石广场 |
| `kit.gd` | 木码头、完整城墙、破口及碎石、木质城门（关、开、破）、石塔、民房、主堡、守军港、撤离船、山洞两端、刺客攀爬岩带、礁石、树、芦苇、木箱 |
| `paint.gdshader`、`tide.gdshader` | 世界坐标笔触、冷暖时段、浅滩渐隐、靠岸断续泡沫、潮涌和远雾 |
| `preview.gd`、`ghostfire.gdshader` | 预览用青绿冥火与固定机位拍照 |

套件在 Godot 运行时生成网格，复用 `../style_frame/coast.gd` 和 `../style_frame/ink_mesh.gd` 的石材、木材和植被做法。静态部件批量成网格，城门、可破墙和撤离船可独立控制。

## T86 接入

在世界原点实例化 `res://attempts/single_battle/terrain/grey_tide.tscn`。地形节点处理视觉，寻路、地形判定、伤害和拓扑更新由单局模拟维护。默认城门关闭，可破墙完好。

```gdscript
const Terrain = preload("res://attempts/single_battle/terrain/terrain.gd")
const Battlefield = preload("res://attempts/single_battle/terrain/grey_tide.tscn")

func add_battlefield(camera: Camera3D) -> void:
    var battlefield := Battlefield.instantiate() as Terrain
    add_child(battlefield)
    battlefield.apply_camera(camera, "coast")
    battlefield.set_time(0.28)
```

- `Terrain.load_layout() -> Dictionary` 读取 `grey_tide.json`。将 `map`、`phase_b` 和部署点合入对应的模拟参数，机位与战区用相同 ID。T86 若自行管理相机可直接读 `cameras`。
- `height_at(point: Vector3) -> float` 从地面坐标的 X/Z 取样，单位和点选可使用同一份 `surfaces` 算出等高的落脚点。是否落在可通行地面由格网判定。
- `apply_camera(camera: Camera3D, zone_id: String) -> bool` 设置已入树相机的正交机位。未知 ID 返回 `false`。
- `set_structure_state(id: String, state: String) -> bool` 切换已入树场景的网格状态。ID `gate` 对应 `closed`、`open`、`broken`。ID `weak_wall`、`wall_west`、`wall_east`、`wall_highland` 对应 `intact`、`breached`。未知 ID 或状态返回 `false`。城门开或破、墙段破口时同步解除相应格的阻挡。
- `set_time(elapsed_fraction: float)` 接收已过夜间时间比例。0 为入夜、0.28 附近为午夜、1 为破晓。五分钟单局可传 `elapsed / 300.0`，范围会截到 0–1。
- `set_boat_progress(progress: float)` 接收已入树船的离港进度，0 为停泊，1 为向东开出 10 个世界单位。登船、撤离计时由模拟推进。

### 通行数据

`grey_tide.json` 使用 `schema_version: 1`。一格边长 1 个 Godot 世界单位，X 向东，Z 向登陆滩，Y 向上，海平面 Y=0。格坐标 `[x,z]` 的中心为 `Vector3(x + 0.5, y, z + 0.5)`。格区矩形 `[x,z,w,d]` 左上含边，右下不含边。

| 字段 | 格式和用途 |
|---|---|
| `map.width`、`map.depth` | 56 × 48 格。原型同款四向相邻。 |
| `map.land_rects`、`map.wall_rects` | 地面矩形取并集，扣除墙、房屋和主堡等阻挡矩形。海水、浅滩以及陈设用栈桥超出格网地面的位置不可行走。 |
| `map.gate_rect`、`map.weak_rect` | 正门与主薄弱墙的动态格区，初始阻挡来自 `wall_rects`。 |
| `map.zones` | 每项为 `id`、`label`、中心格 `center`、归属矩形数组 `rects`、最低驻军 `min_garrison`。 |
| `map.routes`、`deploy_points`、`map.deploy_rect` | `main`、`side`、`cave` 的路线途经格、各路默认出发格、整片部署矩形。部署点仍需满足通行判定。 |
| `map.cave_*` | `cave_a`、`cave_b` 是双向特殊连边的两端，`cave_enabled` 控制是否启用。另有通行时间（秒）、容量和入口半径。调用寻路时按兵种和阵营传洞穴许可。 |
| `map.port`、`map.boat` | 登船集结格、船的海岸侧定位格。撤离途径走到 `port`。 |
| `phase_b` | 洞穴许可 `cave_permission`，刺客攀爬起终格 `cliff_entry`、`cliff_exit` 和耗时 `cliff_seconds`。额外可破墙每项为 `{id, rect, hp}`。攀爬是兵种专用连边。 |
| `surfaces` | 从前到后匹配首个包含该点的 `rim` 多边形。顶点使用连续世界坐标 `[x,z]`（无半格偏移）。平面读 `height`，坡面按 `grade.axis`（`x` 或 `z`）对 `from`、`to` 的 `[轴坐标,高度]` 端点做截断线性插值。未命中时取 `map.base_height`。 |
| `cameras` | 以机位 ID 为键。`focus` 为世界坐标 `[x,y,z]`，`yaw` 从 +Z 转向 +X，`pitch` 为俯角（均用度），`size` 为正交画幅的垂直尺寸。 |

`map.highland_rect`、`keep_rect` 及同名高度值供原型兼容。用 `surfaces` 可还原坡面；通行仍由格网与特殊连边决定。其余 `map` 字段为原型的流场与到达判定参数。测试用 2 单位/秒的行军速度测得开路后从各自部署点到主堡的空场时间为山洞 15.5 秒、正路 17.5 秒、侧路 27.5 秒。山洞值含 2.5 秒转移，实战还会受接敌、等候与砸门耗时影响。

## 预览和验证

从仓库根目录运行。按 **1–4** 切换战区，**5** 看总览，**N／D** 对照午夜与破晓，**G** 切换城门状态，**B** 切换可破墙。

```sh
godot --path . --rendering-method gl_compatibility attempts/single_battle/terrain/preview.tscn -- --zone=highland --time=0.28
godot --path . --rendering-method gl_compatibility --resolution 1280x720 attempts/single_battle/terrain/preview.tscn -- --capture
godot --headless --path . --script attempts/single_battle/terrain/verify.gd
```

`--capture` 需要桌面图形会话，依次把四个战区的 `<id>-night.png` 和 `<id>-daybreak.png` 写到 `shots/t85/`，每张打印一行 `CAPTURE`。截图不入库。
