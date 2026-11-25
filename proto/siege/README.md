# T69 灰盒夜袭攻城（T67 最小修正）

独立场景，无美术资产、增益或原项目入口改动。初值用于验证工具及交互，不代表正式平衡。

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

# 固定验收：机制检查 + 6 种策略 × 2 个种子，每局重复一次比较完整 JSON
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
| `structures` | 门/弱墙血量和每个亡魂每秒攻城伤害；唯一亡魂剑兵可破弱墙：至少 1 人，人数伤害直接叠加，24 HP / 每人每秒 1.8，持续贴墙无干扰时单人 13.333 秒、三人 4.444 秒（固定步长向上取整）；普通墙没有可攻击接口。守军安全开门半径、保持开启时间，门破后不可关闭 |
| `units` / `combat` / `brain` | 各兵种血量/速度/伤害、弓兵射程/命中/冷却、碰撞分离、击退、剑兵状态机参数。复用 `scripts/swordsman.gd` 的副本，采用小血量加招架/拼刀节奏 |
| `targeting` | 距离、目标价值和局部拥挤评分；目标锁定 2 秒，评分提升至少 3 才切换（死亡/失效和新集结可打断）；近敌锁定 1 秒，距离改善至少 0.75 格才切换。路线承诺、目标重选周期、拥堵后改道阈值/冷却、同格停留判据 |
| `director` | 默认只计入距任一有效活守军 `perception_radius=12` 格内的亡魂，按区内数量+靠近旗点程度评分；不读取玩家资源。`global_perception=false` 可独立实验全图感知。抵达任务目标后锁定 `mission_lock_seconds=12` 秒；评估周期、派兵延迟/冷却/批量。先选预备骑兵，再按行军距离和固定 ID 选兵；先预留兵员，保留驻防下限，再延迟出发；阵亡不补充 |
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
- `congestion_events` 是所有双方单位同格停留超过 3 秒的次数，同次停留只计一次。包含站岗和近战；`travel_congestion_events` 额外筛出未到位、没有可见敌人时的停滞；`congestion_per_deployed` 分母是双方出生总人数。
- `archer_kill_times`、`early_archer_kills` 用于分组检查早期打掉高地弓兵的后续胜率；这是观测相关性，需配对种子和受控参数实验才能做因果判断。
- `structure_work` 记录门/薄弱墙开始受击时间、破口时间、有效工作秒数与累计“攻击人数×秒”；未受击/未破口为 -1，破墙实际总历时为 `breached_at - started_at`。
- `map_scale` 记录实际陆地/闭墙可通行/全破口可通行面积、可通行包围盒线性尺寸；三条进攻路线的无战斗接敌时间、到主堡旗点时间、门/弱墙单人耗时；12 条有向战区增援路径的距离及三类守军行军秒数。无战斗路径估算把该路线的门或弱墙预先打开，不包含战斗、占领、拥堵；山洞计入 2.5 秒传送。无法连通的参数变体输出 null。
- `route_observations` 按初始路线记录首次接敌与进入主堡战区的实测绝对时间/出生后秒数，未发生为 null；和上面的无战斗旗点估算口径分开。
- `recovery_events` 记录无敌人且持续无进展时的局部绕障；改路线次数每兵上限 1，避免两路反复折返。
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
