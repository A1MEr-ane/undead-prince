# T67 灰盒夜袭攻城

独立场景，无美术资产、增益或原项目入口改动。初值用于验证工具及交互，不代表正式平衡。

```sh
# 手玩，默认五分钟，到破晓结束
godot --path . proto/siege/siege.tscn

# 无头单局；结束恰好一行 SIEGE {json}
godot --headless --path . --log-file /tmp/siege.log proto/siege/siege.tscn -- --strategy=feint --seed=7

# 5 种策略 × 20 个种子；串行，避免争抢 CPU
proto/siege/run_matrix.sh
proto/siege/run_matrix.sh --seeds=3 --out=proto/siege/results/smoke

# 参数覆盖文件可以只包含要修改的字段（字典递归合并，数组整体替换）
proto/siege/run_matrix.sh --params=/tmp/variant.json --seeds=20 --out=proto/siege/results/variant

# 固定验收：机制检查 + 5 种策略 × 2 个种子，每局重复一次比较完整 JSON
tools/verify/proto_siege.sh

# 实际窗口截图；按模拟时间 3 / 150 / 285 秒，种子 1
godot --path . proto/siege/siege.tscn -- --strategy=feint --seed=1 --capture --speed=16
# 五种策略共 15 张，需可用的桌面窗口会话
proto/siege/capture_all.sh --speed=16
```

从仓库根目录执行。Godot 4.7.2、Python 3（标准库）、bash；不需安装依赖。批跑可用 `--godot` 或 `GODOT` 指定引擎，`--timeout` 指定单局超时，`--start-seed` 指定首个种子。默认结果在 `proto/siege/results/matrix/`，包括 `summary.md`、`results.jsonl`、有效参数快照及每局日志；该目录被忽略，不入库。`--verify` 固定使用两个种子，不受 `--seeds` 影响。

## 操作与读图

- `1` 选择唯一亡魂剑兵，海岸绿色区域左键长按连续部署；拖动部署点可铺开兵力。绿色落点可部署，红色不可部署。
- `F` 后左键地点：付费集结。有效半径内单位在持续时间内优先前往该点；不能直接逐兵下令。
- `Q/E` 或右键/中键拖动旋转；滚轮缩放；`Esc` 取消；`R` 重开。
- `Tab` 开关调试面板：时间、门墙血量、各区威胁、占领进度及最近的守军派兵决定。
- 青绿为亡魂、橙为盾兵、黄为弓兵、紫为骑兵。棕色门可开关，红灰色侧墙可破，黑方块是山洞两端，右侧港口有撤离船。
- 常规 HUD 没有倒计时，天空和全屏色调从墨蓝向鱼肚白变化。只有调试面板显示秒数。

地图包围盒为 56×48（原岛 24×24 的约 4.67 倍）；陆地面积按道路形状裁切。大路宽 7 格、侧路宽 4 格。山洞入口在东侧海岸、出口在外城，属于带通行耗时和容量的传送边。自然地形不可攻击。城门打开/关闭和破口只更新对应格子，缓存流场局部修复受影响的路径分支。

所有战区采用同一规则：区内没有活守军且有亡魂，连续占据 `capture.seconds` 才攻占；守军进入就清零。亡魂据点被清空后，守军也能连续占据并夺回。主堡攻占立即获胜，所有剩余守军停止反击并实走港口；亡魂继续追杀，到船开走或破晓才结束。全歼也可独立获胜，不必占堡。天亮前若两者都未达成则失败。

## 参数

所有玩法初值在 `siege_params.json`。坐标采用 `[x,z]` 格号，逻辑点位位于格中心；矩形为 `[x,z,宽,深]`。改变地图参数时应同时修改道路、地形、墙门和驻军坐标，避免目标落到水里。

| 区段 | 主要字段与意义 |
|---|---|
| `simulation` | `step` 固定步长，`night_seconds` 夜长；headless/window 每帧最多推进几步只影响执行速度 |
| `economy` | `initial`、`capacity`、`unit_cost`；`regen_curve` 是 `[夜晚比例,冥火/秒]` 的分段线性曲线；部署间隔、波次分组间隔、集结费用/半径/持续时间；击杀回火默认关 |
| `capture` | 攻占/夺回所需秒数；`expanded_deployment` 默认关，开启后可在已占战区陆地部署 |
| `map` | 手搭陆地、城墙、门、薄弱墙、战区边界/旗点/驻防下限、港口船位、路线；`cave_enabled` 默认开，传送时间和容量 |
| `structures` | 门/弱墙血量和每个亡魂每秒攻城伤害；守军安全开门半径、保持开启时间，门破后不可关闭 |
| `units` / `combat` / `brain` | 各兵种血量/速度/伤害、弓兵射程/命中/冷却、碰撞分离、击退、剑兵状态机参数。复用 `scripts/swordsman.gd` 的副本，采用小血量加招架/拼刀节奏 |
| `targeting` | 距离、目标价值和局部拥挤评分；路线承诺、目标重选周期、拥堵后改道阈值/冷却、同格停留判据 |
| `director` | 威胁=区内亡魂数量+靠近旗点程度；评估周期、派兵延迟/冷却/批量。先选预备骑兵，再按行军距离和固定 ID 选兵；先预留兵员，保留驻防下限，再延迟出发；阵亡不补充 |
| `garrisons` | 初始守军列表，种类、人数、所属战区、阵线锚点和是否预备队 |
| `reinforcements` | 最后一分钟王国援军（默认开），出现位置、兵种和数量；一场只出现一次 |
| `retreat` | 撤退船等待秒数、登船半径、亡魂追杀搜索距离；未赶上船者单列 `stranded` |
| `strategies` | 五种机器人部署点、批量、波路线、佯攻牵制比例、挂机倒数 90 秒及一次倾泻窗口、早期弓兵击杀时间阈值 |
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

## 五种机器人

机器人通过与手玩相同的海岸部署接口行动，没有战斗加成或移动单位的特权；出生后由目标评分及拥堵规则自主行动。因此部署路线表达战术意图，拥堵时仍可能自主改道。

| 名字 | 行为 |
|---|---|
| `main_gate` 主门强攻 | 所有部署发生在大路入口，持续小批投兵，目标沿门→外城→主堡 |
| `highland` 侧路高地 | 所有部署发生在西侧，沿高地弓兵→弱墙→外城→主堡 |
| `feint` 佯攻 | 默认每五兵一兵投入主门，其余从东侧山洞；关闭山洞后主力改走侧路 |
| `waves` 分波 | 冥火满额才开始一波，按大路/侧路/山洞轮转；一波按部署间隔倾泻 |
| `idle` 挂机 | 前 210 秒不操作，最后 90 秒开始一次倾泻，随后不再部署 |

`waves[].routes` 是出生时自主选择的路线；`reroutes` 记录后续改道次数。派兵日志的 `ordered` 与 `depart` 是不同事件：前者是作出决定并预留，后者是延迟结束后开始行军，`arrive` 表示实际抵达。

## SIEGE 指标与 T68 接口

每行 JSON 有 `schema_version`、`seed`、`strategy` 和合并后参数 `params_sha256`。同种子、同参数、同机器人与同 Godot 版本的整条 JSON 必须一致；显示随机源独立，窗口速度和截图不影响模拟随机源。手玩结果还取决于实际输入时机。

- `won`、`victory_method`（`annihilation` / `keep_retreat` / `none`）、`victory_time`、`ended_at`。
- `zone_captures`：各区守军失守时间数组；`zone_losses`：亡魂据点再次丢失时间数组；`capture_resets`：反攻导致连续占据计时归零的时间。空数组表示未发生。
- `retreat.started_at`、`boat_depart_at`、`escaped`（已登船）、`intercepted`（开始撤退后被杀）、`stranded`（结束时仍未登船）。胜利时间与追杀结束时间分别记录。
- `casualties.ghost/defender`、`spawned.ghost/defender`；守军伤亡包含撤退截杀，不能把 `intercepted` 再加一次。
- `waves[]` 每波的起止时间、人数、冥火和路线分配；`fire_wasted` 精确累计满额溢出，附带生成、消费和余额以检查收支。
- `defender_dispatches` 以出发人数计，`dispatch_decisions` 逐事件保留决定、出发、到达、王国援军；可按 `event=ordered` 数批次。
- `congestion_events` 是所有双方单位同格停留超过 3 秒的次数，同次停留只计一次。包含站岗和近战；`travel_congestion_events` 额外筛出未到位、没有可见敌人时的停滞；`congestion_per_deployed` 分母是双方出生总人数。
- `archer_kill_times`、`early_archer_kills` 用于分组检查早期打掉高地弓兵的后续胜率；这是观测相关性，需配对种子和受控参数实验才能做因果判断。
- `cave_transits`、`reroutes`、`topology_events`、`flow_repairs`、`flow_relaxed_cells`、`combat_events` 辅助排查行为。

四个目标的判定口径：

1. 按 `strategy` 分组计算 `won` 均值，与 30% 比较；`victory_method` 检查胜法，`waves[].routes` 检查路线差异。
2. 比较 `feint`、`waves`、`idle` 的 `won` 均值；默认“明显”暂按差距 ≥15 个百分点汇总，交 T68 验证。
3. 按 `early_archer_kills > 0` 分组，与 `won`、`victory_time` 联合分析；保留逐次击杀时间支持不同早期阈值，不用胜率差直接声称因果成立。
4. 看 `congestion_events`、`congestion_per_deployed` 和 `travel_congestion_events`；默认参考上限 0.5 次/出生单位，可调。最终可接受程度须结合实际窗口观察。

## 截图与限制

每个策略各运行一次上面的 `--capture` 命令，将 `--strategy` 替换为五个名字，会生成 `shots/t67/<策略>_seed1_003.png`、`_150.png`、`_285.png`。截图按模拟时间，提前结束时会冻结已结算战斗、继续天色到截图时点；`SIEGE` 仍记录真实结束时刻。headless 明确拒绝截图，避免无渲染视口挂起。图片与导入缓存不提交。

灰盒使用连续格子移动、轻量碰撞/击退及共享剑兵大脑，没有移植正式小兵身体追步、落水或精灵资源。弓箭为瞬时命中加短线段提示。该原型验证攻城决策与调度，不代表正式战斗手感。当前默认值未经平衡扫描；完整 20 种子矩阵和参数扫描交 T68。
