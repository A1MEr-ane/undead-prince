# T69 灰盒夜袭攻城（T67 最小修正）

独立场景，无美术资产、增益或原项目入口改动。初值用于验证工具及交互，不代表正式平衡。

## T70 镜头实验入口

T70 使用独立场景，复用同一套五分钟模拟。原 `siege.tscn` 继续保持 T69 操作。下列命令均在仓库根目录运行：

```sh
# 主方案：战区固定机位，默认 0.2 秒推移
godot --path . proto/siege/camera/siege_camera.tscn
# 同一主方案直接切换；也可在游戏中按 C 切换
godot --path . proto/siege/camera/siege_camera.tscn -- --camera_transition=cut
# 连续 360° 对照
godot --path . proto/siege/camera/siege_camera.tscn -- --camera_mode=continuous
# 镜头与输入边界测试，不要求窗口
godot --headless --path . --script proto/siege/camera/test_camera.gd
# 完整回放：原无头入口 vs 两组实际显示节点；完整 SIEGE 行必须逐字一致
python3 proto/siege/camera/verify_replay.py
# 串行录制相同策略、种子的 A/B PNG 序列，并拍四个机位静帧
python3 proto/siege/camera/capture.py --seed=7 --strategy=feint --fps=10
```

- `1–4` 分别跳海岸、高地、外城广场、主堡；也可点右上总览或底部战区标签。固定模式不响应旋转，`WASD` 或右键/中键拖动可小范围平移，滚轮只在本机位的有限范围缩放。连续模式保留 `Q/E` 与拖动旋转，也能按战区定位。
- 亡魂默认已选中。左键长按只向**当前战区、画面内的合法部署地面**投兵。默认只有海岸能部署；切换、展开总览、鼠标进入 UI 或拖动时禁止部署，松开鼠标会结束长按。`F+左键` 仍通过原接口付费集结，`Space` 跳过撤退，`R` 重开。
- `Tab` 展开/收起全屏战术图，`F3` 开关原调试面板，`C` 对比 0.2 秒推移与直切。总览消费鼠标事件，只跳转、不投兵；显示实际区内人数、实际仍在行军的守军箭头、视口边界、旗帜归属、门墙状态、冥火和倒计时。山洞转移中的单位暂不计入区内人数。
- 离屏受伤、增援出发、破门/破墙、攻占和失守会进入提醒日志；底部标签闪烁，左侧最多显示三个战区的一行可点击提示，跳转抵达后确认。受伤提示每区冷却 8 秒，同批同路线增援合并，重要状态优先保留到查看。增援同时提醒**来源和目的战区**，两端独立确认；当前正在查看的战区无需闪烁，正文包含来源与目的地。
- 手工机位在 `camera/map_camera.json` 的 `map.camera.zones` 中：`focus` 为世界坐标 `[x,y,z]`，`yaw/pitch` 为度，`distance` 与它们共同决定位置，`size` 为正交尺寸，另有平移与缩放限制。显示层默认读取此文件，不回写模拟参数；可用原 `--params=覆盖.json` 覆盖 `map.camera`，或用 `--camera_mode=zones/continuous`、`--camera_transition=slide/cut`、`--zone=coast/highland/plaza/keep` 选择实验。
- T69 没有正式单位精灵；实验入口用一张带鼻尖/武器的程序侧影、脚底锚点和相对镜头左右翻转检查表现。两组都使用同样的侧影。墙和地形继续正常遮挡，没有透视显示单位的特殊处理。正式精灵仍需另行验收。

录制输出在 `shots/t70/zones/`、`continuous/` 和 `stills/<战区>/`，不提交图片。序列每秒模拟时间采样 10 帧（可调 1–60），不是桌面原生刷新率录像；`frames.jsonl` 记录每张对应的逻辑步、时间和战区。`--camera_patrol` 每 15 秒按 1–4 巡览，连续组缓慢旋转，仅用于重复观察。机器人照常在全图部署，镜头限制只约束手玩输入，避免改变同场回放。脚本比较两组完整 `SIEGE` JSON，任何差异都停止。

`camera_metrics.json` 保存每次切换、各条提醒及确认时刻、显示层更新耗时（微秒）和实际帧间隔（毫秒）。自动巡览次数不能当作玩家平均切换次数；未确认提醒也不能直接当作玩家错过事件。录制时的帧间隔含截图开销，性能应关闭录制、`--speed=1` 单独测。当前执行环境无法连接 macOS 桌面，尚未生成 T70 实际截图，遮挡和帧时间仍需在有桌面会话的环境补验。

```sh
# 手玩，默认五分钟；破晓前满足任一胜利条件即锁定
godot --path . proto/siege/siege.tscn

# 无头单局；结束恰好一行 SIEGE {json}
godot --headless --path . --log-file /tmp/siege.log proto/siege/siege.tscn -- --strategy=feint --seed=7

# 6 种策略 × 20 个种子；串行，避免争抢 CPU
proto/siege/run_matrix.sh
proto/siege/run_matrix.sh --seeds=3 --out=proto/siege/results/smoke

# 参数覆盖文件可以只包含要修改的字段（字典递归合并，数组整体替换）
proto/siege/run_matrix.sh --params=/tmp/variant.json --seeds=20 --out=proto/siege/results/variant

# 固定验收：机制检查 + 24 局 + 镜头功能 + 显示节点完整回放对照
tools/verify/proto_siege.sh

# 实际窗口截图；按模拟时间 3 / 150 / 285 秒，种子 1
godot --path . proto/siege/siege.tscn -- --strategy=feint --seed=1 --capture --speed=16
# 六种策略共 18 张，需可用的桌面窗口会话
proto/siege/capture_all.sh --speed=16
```

从仓库根目录执行。Godot 4.7.2、Python 3（标准库）、bash；不需安装依赖。批跑可用 `--godot` 或 `GODOT` 指定引擎，`--timeout` 指定单局超时，`--start-seed` 指定首个种子。默认结果在 `proto/siege/results/matrix/`，包括 `summary.md`、`results.jsonl`、有效参数快照及每局日志；该目录被忽略，不入库。`--verify` 固定使用两个种子，不受 `--seeds` 影响。

## 操作与读图

- `1` 选择唯一亡魂剑兵，海岸绿色区域左键长按连续部署；拖动部署点可铺开兵力。绿色落点可部署，红色不可部署。
- `F` 后左键地点：付费集结。有效半径内单位在持续时间内优先前往该点；不能直接逐兵下令。
- `Q/E` 或右键/中键拖动旋转；滚轮缩放；`Esc` 取消；`R` 重开。
- `Tab` 开关调试面板：时间、门墙血量、各区威胁、占领进度及最近的守军派兵决定。
- 青绿为亡魂、橙为盾兵、黄为弓兵、紫为骑兵。棕色门可开关，红灰色侧墙可破，黑方块是山洞两端，右侧港口有撤离船。
- HUD 始终显示 `MM:SS` 破晓倒计时；天空和全屏色调仍从墨蓝向鱼肚白变化。
- 集结点有黄色范围圆环，受令单位变黄，HUD 显示剩余秒数、半径与受令人数。命令在目标周围半径 16 格内持续 18 秒；后来进入或新生成在范围内的单位也会接令，沿用 T67 动态作用域。
- 占堡后可按空格或点击“跳过撤退”立即结束表现阶段；批跑可加 `--skip_retreat`，或设 `retreat.skip_by_default=true`。

地图网格包围盒为 56×48（网格面积为原岛 24×24 的约 4.67 倍）；实际陆地并未铺满包围盒，面积与路径时间由 `SIEGE.map_scale` 计算。大路宽 7 格、侧路宽 4 格。山洞入口在东侧海岸、出口在外城，属于带通行耗时和容量的传送边。自然地形不可攻击。城门打开/关闭和破口只更新对应格子，缓存流场局部修复受影响的路径分支。

所有战区采用同一规则：区内没有活守军且有亡魂，连续占据 `capture.seconds` 才攻占；守军进入就清零。亡魂据点被清空后，守军也能连续占据并夺回。主堡攻占立即锁定 `WON`，所有剩余守军停止反击并实走港口；亡魂可继续追杀。撤退属于独立表现阶段，45 秒后停止登船，船航行 4 秒后自然结束；破晓不会截断已胜战斗。全歼也可独立获胜，不必占堡。状态只从 `ACTIVE` 转到 `WON` 或 `LOST`，同一步先判断攻占/全歼，再判断破晓。全歼仅计入关卡登记的有效活守军：排除 `victory_eligible=false` 的残影、已登船/撤退单位，以及从所有部署区经可破门/薄弱墙与启用山洞仍不可达的单位；暂时被闭门隔开的守军仍有效。

## 参数

所有玩法初值在 `siege_params.json`。坐标采用 `[x,z]` 格号，逻辑点位位于格中心；矩形为 `[x,z,宽,深]`。改变地图参数时应同时修改道路、地形、墙门和驻军坐标，避免目标落到水里。

| 区段 | 主要字段与意义 |
|---|---|
| `simulation` | `step` 固定步长，`night_seconds` 夜长；headless/window 每帧最多推进几步只影响执行速度 |
| `economy` | `initial`、`capacity`、`unit_cost`；`regen_curve` 是 `[夜晚比例,冥火/秒]` 的分段线性曲线；部署间隔、波次分组间隔、集结费用/半径/持续时间；击杀回火默认关 |
| `capture` | 攻占/夺回所需秒数；`expanded_deployment` 默认关，开启后可在已占战区陆地部署 |
| `map` | 手搭陆地、城墙、门、薄弱墙、战区边界/旗点/驻防下限、港口船位、路线；`cave_enabled` 默认开，传送时间和容量 |
| `structures` | 门/弱墙血量和每个亡魂每秒攻城伤害；普通亡魂可破弱墙：至少 1 人，人数伤害直接叠加，24 HP / 每人每秒 1.8，持续贴墙无干扰时单人 13.333 秒、三人 4.444 秒（固定步长向上取整）；普通墙没有可攻击接口。守军安全开门半径、保持开启时间，门破后不可关闭 |
| `units` / `combat` / `brain` | 各兵种血量、速度和伤害，弓兵射程、命中和冷却，以及剑兵状态机、受击和追击半径参数 |
| `targeting` | 从部署点选择可达入口。索敌独立计算，近敌锁定、切换滞后和改道阈值可调。主动换目标、支援或改道合计每 10 秒最多两次，目标死亡可以立即重选 |
| `director` | 默认只计入距任一有效活守军 `perception_radius=12` 格内的亡魂，按区内数量+靠近旗点程度评分；不读取玩家资源。`global_perception=false` 可独立实验全图感知。抵达任务目标后锁定 `mission_lock_seconds=12` 秒；评估周期、派兵延迟/冷却/批量。先选预备骑兵，再按行军距离和固定 ID 选兵；按威胁和阈值之比计算支援需求，扣除已经接到该任务的守军。先预留兵员，保留驻防下限，再延迟出发 |
| `garrisons` | 初始守军列表，种类、人数、所属战区、阵线锚点和是否预备队 |
| `reinforcements` | 最后一分钟王国援军（默认关），出现位置、兵种和数量；一场只出现一次 |
| `retreat` | 撤退船等待/离港秒数、跳过开关、登船半径、亡魂追杀搜索距离；未赶上船者单列 `stranded` |
| `strategies` | 六种机器人部署点、批量、波路线、佯攻牵制比例、挂机倒数 90 秒及一次倾泻窗口、早期弓兵击杀时间阈值 |
| `metrics` | T68 的胜率、挂机差距及拥堵初始参考判据；不影响战斗 |
| `view` | 相机、窗口、调色和截图时间；只影响显示。截图 `--speed` 与 `--out` 可覆盖默认速度、输出目录 |

参数例子：禁用山洞/王国援军，部署仍只限海岸。

```json
{
  "map": {"cave_enabled": false},
  "reinforcements": {"enabled": false},
  "capture": {"expanded_deployment": false}
}
```

## 六种机器人

机器人通过与手玩相同的海岸部署接口行动，没有战斗加成或移动单位的特权；出生后由目标评分及拥堵规则自主行动。因此部署路线表达战术意图，拥堵时仍可能自主改道。

| 名字 | 行为 |
|---|---|
| `main_gate` 主门强攻 | 所有部署发生在大路入口，持续小批投兵，目标沿门→外城→主堡 |
| `highland` 侧路高地 | 所有部署发生在西侧，沿高地弓兵→弱墙→外城→主堡 |
| `feint` 佯攻 | 默认每五兵一兵投入主门，其余从东侧山洞；关闭山洞后主力改走侧路 |
| `waves` 分波 | 冥火满额才开始一波，按大路/侧路/山洞轮转；一波按部署间隔倾泻 |
| `idle` 挂机 | 前 210 秒不操作，最后 90 秒开始一次倾泻，随后不再部署 |
| `late_batches` 晚开始、分批投 | 第 2 分钟开始（t=60 秒），冥火达到上限 60% 即按部署间隔投完当批；持续补投，沿主门，作为相同入口挂机的对照 |

`waves[].routes` 是出生时自主选择的路线；`reroutes` 记录后续改道次数。任务锁定覆盖待派发和行军过程，抵达后再保持 12 秒。派兵日志的 `ordered` 与 `depart` 是不同事件：前者是作出决定并预留，后者是延迟结束后开始行军，`arrive` 表示实际抵达。

## SIEGE 指标与 T68 接口

每行 JSON 有 `schema_version`、`seed`、`strategy` 和合并后参数 `params_sha256`。同种子、同参数、同机器人与同 Godot 版本的整条 JSON 必须一致；显示随机源独立，窗口速度和截图不影响模拟随机源。手玩结果还取决于实际输入时机。

- `schema_version=2`，保留 T67 旧字段；`outcome` 为 `WON/LOST` 终态，`presentation` 为 `COMPLETE`。撤退可跨过夜长，`ended_at` 不再必须小于夜长，`victory_time` 仍必须在破晓前（含同一步边界）。
- `won`、`victory_method`（`annihilation` / `keep_retreat` / `none`）、`victory_time`、`ended_at`。
- `zone_captures`：各区守军失守时间数组；`zone_losses`：亡魂据点再次丢失时间数组；`capture_resets`：反攻导致连续占据计时归零的时间。空数组表示未发生。
- `retreat.started_at`、`boat_depart_at`、`escaped`（已登船）、`intercepted`（开始撤退后被杀）、`stranded`（结束时仍未登船）。胜利时间与追杀结束时间分别记录。
- `casualties.ghost/defender`、`spawned.ghost/defender`；守军伤亡包含撤退截杀，不能把 `intercepted` 再加一次。
- `waves[]` 每波的起止时间、人数、冥火和路线分配；`fire_wasted` 精确累计满额溢出，附带生成、消费和余额以检查收支。
- `zone_history[]` 每次调度评估记录时间、战区、感知威胁、实际驻防人数与已分配人数。
- `dispatch_decisions[]` 的 `ordered` 保留原来的批次 `units` 列表，并在 `members` 加入每兵来源和预计到达时间；`depart/arrive` 按单兵记录来源、目的地、原因、预计到达时间；抵达时另记录实际时间、行军秒数及估算误差。估算允许守军开门，不包含等待、交战和拥堵。未到达者只有前两类事件，不能当作已到达。
- `defender_dispatches` 以出发人数计，`dispatch_decisions` 逐事件保留决定、出发、到达、王国援军；可按 `event=ordered` 数批次。
- `congestion_events` 和 `travel_congestion_events` 均记录有行进意图、没有实际进展并超过阈值的次数，同一次堵塞只计一次。驻防、实际交战和受击停顿排除在外；`congestion_per_deployed` 分母是双方出生总人数。
- `archer_kill_times`、`early_archer_kills` 用于分组检查早期打掉高地弓兵的后续胜率；这是观测相关性，需配对种子和受控参数实验才能做因果判断。
- `structure_work` 记录门/薄弱墙开始受击时间、破口时间、有效工作秒数与累计“攻击人数×秒”；未受击/未破口为 -1，破墙实际总历时为 `breached_at - started_at`。
- `map_scale` 记录实际陆地/闭墙可通行/全破口可通行面积、可通行包围盒线性尺寸；三条进攻路线的无战斗接敌时间、到主堡旗点时间、门/弱墙单人耗时；12 条有向战区增援路径的距离及三类守军行军秒数。无战斗路径估算把该路线的门或弱墙预先打开，不包含战斗、占领、拥堵；山洞计入 2.5 秒传送。无法连通的参数变体输出 null。
- `route_observations` 按初始路线记录首次接敌与进入主堡战区的实测绝对时间/出生后秒数，未发生为 null；和上面的无战斗旗点估算口径分开。
- `recovery_events` 记录局部绕障。路径上排队持续 5 秒后，有可达替代入口的单位可改道，默认每兵最多改道一次。
- `input_events` 记录手动输入的固定步号、坐标与接受状态；手动长按部署/集结/跳过都在模拟步执行。
- `hook_counts` / `hook_suppressed` 记录事件派发与递归抑制计数，当前无构筑监听器。
- `cave_transits`、`reroutes`、`topology_events`、`flow_repairs`、`flow_relaxed_cells`、`combat_events` 辅助排查行为。

四个目标的判定口径：

1. 按 `strategy` 分组计算 `won` 均值，与 30% 比较；`victory_method` 检查胜法，`waves[].routes` 检查路线差异。
2. 比较 `feint`、`waves`、`idle` 的 `won` 均值；默认“明显”暂按差距 ≥15 个百分点汇总，交 T68 验证。
3. 按 `early_archer_kills > 0` 分组，与 `won`、`victory_time` 联合分析；保留逐次击杀时间支持不同早期阈值，不用胜率差直接声称因果成立。
4. 看 `congestion_events`、`congestion_per_deployed` 和 `travel_congestion_events`；默认参考上限 0.5 次/出生单位，可调。最终可接受程度须结合实际窗口观察。

## 截图与限制

每个策略各运行一次上面的 `--capture` 命令，将 `--strategy` 替换为六个名字，会生成 `proto/siege/results/captures/<策略>_seed1_003.png`、`_150.png`、`_285.png`。截图按模拟时间，提前结束时会冻结已结算战斗、继续天色到截图时点；`SIEGE` 仍记录真实结束时刻。headless 明确拒绝截图，避免无渲染视口挂起。图片与导入缓存不提交。

灰盒使用连续格子移动、轻量碰撞/击退及共享剑兵大脑，没有移植正式小兵身体追步、落水或精灵资源。弓箭为瞬时命中加短线段提示。该原型验证攻城决策与调度，不代表正式战斗手感。当前默认值未经平衡扫描；完整 20 种子矩阵和参数扫描交 T68。

## 模拟与事件接口

窗口与无头都调用 `siege.gd.simulate()`；胜负、资源、出生/伤亡、攻占、破墙、调度使用同一固定步长（默认 1/30 秒）与独立模拟 RNG。窗口把输入变成意图/队列，在逻辑步执行。展示用上一步/当前单位位置和累加器比例插值，不回写模拟；船移动和天色也只读取模拟时间。跨平台逐位一致未承诺。

`world.hooks.subscribe(event, Callable)` 预留六种事件：`spawn`、`hurt`、`near_death`、`kill`、`death`、`resource_changed`。载荷包含单位/来源或资源前后值，以及逻辑步号。濒死在血量越过最大血量 25% 时触发（含致命伤），不附加任何规则效果。同一同步调用链不重复派发同名事件，深度上限 8；结束后新的顶层事件仍可触发。测试覆盖“击杀→生成→击杀”和固定输入时序，不实现增益、复生或构筑。

T70 的 `camera/verify_replay.py` 已接入固定验收，显式使用相同 `feint / seed 7 / --params` 分别运行原无头场景和 `zones`、`continuous` 显示节点回放。显示回放保持模拟固定步长，独立改变显示 delta、插值、推移/直切和总览状态，每三步刷新一次；比较完整 `SIEGE` 行的 UTF-8 字节，不忽略任何字段，不加浮点容差。证据在验收输出目录的 `camera/` 下。此项构造真实显示节点，但不启用 GPU 渲染，不能代替桌面截图。

不要直接把 `world.result()` 内存字典与 `JSON.parse_string()` 读取的日志字典做相等验收：JSON 数字的十进制序列化/解析可能改变 double 的最低位，解析还会把整数变成 float；即使两次模拟的原始日志逐字一致，解析后的字典也可能不与内存字典相等。回放脚本会额外打印往返诊断，正式通过条件始终是两个原始 `SIEGE` 行逐字一致。

## T74：阶段 B 与 T68 新分析口径（默认均关闭）

原始 `siege_params.json` 没有修改；不传覆盖文件时继续输出 schema 2，保持 T73 整条 `SIEGE` 行逐字一致。T68 的旧统计不能用于解释新实验：新分析输出 schema 3 / `metrics_version=T74-movement-intent-v1`，应从新基线重新采样。两个入口可分开使用：

```sh
# 只修正 T68 的路线/索敌与埋点，不开放新兵种、破墙或山洞权限
godot --path . proto/siege/siege.tscn -- --params=res://proto/siege/params/analysis_v2.json
# 开放阶段 B（同时使用新分析口径）
godot --path . proto/siege/siege.tscn -- --params=res://proto/siege/params/phase_b.json
# 两个新机器人及等投入分波对照（种子 1–3 的烟测已接入固定验证）
godot --headless --path . proto/siege/siege.tscn -- --params=res://proto/siege/params/phase_b.json --strategy=assassin_first --seed=1
godot --headless --path . proto/siege/siege.tscn -- --params=res://proto/siege/params/phase_b.json --strategy=giant_breach --seed=1
godot --headless --path . proto/siege/siege.tscn -- --params=res://proto/siege/params/phase_b.json --strategy=prep_control --seed=1
```

`phase_b.enabled` 为总开关；`assassin`、`giant`、`walls` 可分别关闭。阶段 B 覆盖文件包含兵种属性、三段墙和通路坐标，改参数时以它为起点。不要只传 `enabled=true`。不必修改原项目入口或正式战斗脚本。

- 手玩原 `siege.tscn`：`1` 亡魂（5）、`2` 暗影刺客（20）、`3` 缝合巨人（30），或点底部费用卡片；左键长按使用当前兵种。卡片显示资源是否足够，点击卡片会停止正在进行的长按。阶段 B 请使用原 `siege.tscn`；T70 的底部战区按钮尚未适配新卡片位置，会遮盖卡片。
- 刺客 0.75 HP、速度 2.6、近战伤害 4；不使用剑盾招架，能秒杀当前弓兵。紫色踏点标出唯一崖壁转移通路 `[12,37] -> [12,21]`，耗时 4 秒；普通兵不能选择 `cliff` 路线。转移期间离开可攻击空间，不占领据点，仍计入存活兵力。进入高地后先找可达的弓兵/神职者，清空后沿侧路推进；本图没有神职者。
- 感知采用模拟规则：刺客出生未发现；有效守军距其不超过 `detection_radius=1.4` 格且 `terrain.line_clear`（二维陆地/墙体通视）时被发现。主动近战出手或受到正伤害也会暴露。发现永久保持，记录原因和时间。未发现者既不能被守军索敌，也不进入调度威胁；`global_perception=true` 仍不能看穿潜行。发现检查每个固定步在调度前执行；不依赖镜头、画面遮挡或听觉。
- 巨人 18 HP、速度 1.05、结构伤害 14/秒；周围 1.6 格内至少三名守军时每 3.5 秒横扫，伤害 1.6。巨人可顶着近敌继续攻击指定墙体；普通兵有近敌时停止攻城。新兵种沿用原有受伤、击退、事件、死亡及占领/全歼规则。
- 新可破墙为 `wall_west [26,28,1,1] / 60 HP`、`wall_east [31,28,2,1] / 75 HP`、`wall_highland [14,20,1,2] / 50 HP`，原弱墙保留。红色墙段被破坏后逐格开放，调用 T73 的 `terrain.change` 修复流场；其他墙和自然地形没有受击入口。选择 `breach:<墙 ID>` 路线后，单位先攻击该墙，再实际穿过破口推进主堡。
- `phase_b.cave_permission` 可设 `all` / `undead` / `assassin`。`all` 下双方都能按寻路结果进洞，`undead` 仅进攻方，`assassin` 仅进攻方刺客；仍受原容量、转移时间、`map.cave_enabled` 约束。无权限者不能选山洞路线；参数变化后已有山洞路线也会改选合法路线。

三个准备实验统一 `total_budget=120` 冥火，主力从 t=80 秒起每满 30 冥火分波，波间隔略大于 4 秒，按同一部署间隔投入；准备花费计入这 120。`assassin_first` 开局两刺客（40），主力走大路；`giant_breach` 开局两巨人（60）打西侧墙，主力也从该破口进入；`prep_control` 不准备，全预算用于大路亡魂。可以调整 `prep_*`、`main_start`、`main_wave_fire`、`total_budget`、`breach_target`，但正式比较必须核查实际 `fire_spent`。默认烟测强制三组实际投入均为 120；提前胜利或破晓未花完预算会直接验证失败，不把“相同上限”当成“相同实际投入”。这些小样本只确认工具可用，不证明准备攻势提高胜率。

T68 的路线和目标参数现在独立：

- `analysis.route_values` 只影响自主选路线，和 `targeting.values.archer` 无关。
- 机器人可用 `strategies.route_by_strategy` 指定路线意图，例如 `{"main_gate":"main"}`；`archer_focus_by_strategy` 独立指定是否优先索敌弓兵。默认使用该机器人的部署路线意图，拥堵时仍保留原有有限改道。
- 有效敌人评分为平面距离减去目标价值权重；弓兵偏好接入实际近敌选择与切换滞后，能在同一条路线改变到场后的作战目标。可用 `analysis_main_archers.json` / `analysis_main_no_archers.json` 做相同大路、不同目标偏好的配对实验。
- 新拥堵口径：有移动意图、尚未到达，连续 `congestion_seconds`（3 秒）净位移不足 `progress_epsilon`（0.15 格）才计一次；有进展后可重新计数。排除站岗、近距离交战、攻击结构、眩晕、转移和撤退。慢速持续前进不会因为还在同一格而被计入。新口径同时用于 `congestion_events` / `travel_congestion_events`，分母仍为双方累计出生人数。
- `phase_live_peaks` 记录初夜 `[0,120)`、中夜 `[120,240)`、黎明前 `[240,300]` 及撤退的双方/总数/各兵种存活峰值；包含转移中的活兵。各列独立取峰，不能把它们相加当同一时刻人数。
- `route_choice_distribution` 按路线记录部署选择数、兵种分布和改道进入数；`unit_results` 记录各进攻兵种投入人数/冥火/伤亡/有效伤害/击杀/弓兵击杀/结构伤害/横扫次数，伤害按实际可扣血量截断。`assassination_events` 给出逐次关键目标击杀时间，`detection_events` 记录发现时间/原因，`cliff_transits` 统计攀崖次数；额外墙体在 `breakable_walls`，所有墙的开始/破口时间在 `structure_work`。

固定验收追加 `test_phase_b.gd`、三种策略 × 三种子、每策略种子 1 的逐字复跑及六策略新分析基线。`validation/t74/default_before_hashes.json` 保存本任务开工前六策略 × 两种子的整行 SHA256 和来源提交；标准默认参数时会与本轮默认矩阵逐字哈希比较。新分析基线和阶段 B 结果写入验收输出目录的 `t74/`。
