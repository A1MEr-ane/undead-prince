# T71 攻城原型性能压力探针

只测不改：本目录不修改 `proto/siege/*.gd`。探针在真实 `siege.gd` / `siege_map.gd` / `siege_view.gd` 上直接驱动固定步长模拟，分别测无头模拟与窗口完整帧。

## 运行

```sh
# 冒烟（100 单位、60 样本、仅无头）
python3 proto/siege/perf/run_perf.py --quick

# 完整矩阵：100/200/300/500 × 场景 × 无头/窗口
python3 proto/siege/perf/run_perf.py --units 100,200,300,500 --samples 600

# 单场景单档位（参数在 -- 之后；perf_runner 自己解析）
godot --headless --path . proto/siege/perf/perf_runner.tscn -- \
  --strategy=manual --perf_mode=sim --perf_scenario=melee \
  --perf_units=500 --perf_samples=300

godot --disable-vsync --path . proto/siege/perf/perf_runner.tscn -- \
  --strategy=manual --perf_mode=render --perf_scenario=march \
  --perf_units=500 --perf_samples=300
```

窗口运行会调用 `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`、`Engine.max_fps=0` 和置顶/前台，避免 vsync 把帧时间钳在 16.7 ms。无头运行不会创建 `siege_view.gd`。

## 场景

| 名字 | 内容 |
|---|---|
| `march` | 同路密集行军：N 个亡魂在海岸列队，沿大路走向城门 |
| `multi` | 多线投放：N 个亡魂分三组从大路/侧路/山洞入口推进 |
| `melee` | 密集近战：50% 亡魂 / 40% 盾兵 / 10% 弓兵在广场混战 |
| `gate` | 窄门争夺：城门打开，60% 亡魂从外侧压入，40% 守军在门内侧防守 |
| `breach` | 破墙瞬间：N 个亡魂攻击城门，门血 50，记录破门帧 |
| `reinforce` | 跨区增援：25% 亡魂在海岸，75% 守军分驻三区，调度层实际派兵 |
| `cave` | 山洞转移：N 个亡魂在洞口排队，容量 2、传送 2.5 s |
| `dawn` | 黎明前高回复：从 282 s 开始，广场混战，夜长 300 s |
| `camera` | 镜头缩放和切换：行军场景，每 75 帧在 25/85 正交尺寸和 0/90/180/270° 间切换（仅窗口） |
| `idle` | 辅助基线：N 个亡魂原地散开，隔离移动/近战，只剩索敌、寻路、分离与占领统计的固定成本 |

所有压力场景都用 `main.spawn()` 直接生成单位，并把各兵种 `hp` 放大、`damage/knockback/stun` 归零，保持活跃人数恒定。这样测的是规模负载，不是死亡、经济或平衡；报告里单独标注。压力档位不是人口上限。

## 输出

每行一条 `PERF {json}`，并写到 `results/raw/<场景>_<人数>_<模式>.json`。字段：

- `frame_ms`：窗口模式的完整帧间隔（P50/P95/P99/max/mean）。
- `sim_ms`：每样本 2 个 1/30 s 固定步的模拟耗时（沿用 T71 加压口径；默认速度 1、步长 1/30 s 时，60 FPS 平均每帧 0.5 步）。
- `refresh_ms`：`siege_view.refresh()` 的耗时；`residual_ms` = 帧间隔 − sim − refresh。
- `draw_calls`：`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` 的 P50/P95/max。
- `active`：活跃/场上单位数；`cave_inside_max` 为洞内隐藏人数。
- `breach_sample` / `breach_sim_seconds`：破门发生在第几个样本、对应模拟秒。
- `flow_repairs` / `flow_relaxed_cells` / `dispatches` / `cave_transits`：寻路与调度事件计数。
- `state_hash`：单位位置、血量与 `main.result()` 的哈希；无头与窗口同配置应完全一致。
- `environment`：Godot 版本、OS、CPU、GPU、渲染后端、窗口/视口/纹理尺寸、Debug/Release、内存、节点数。

`perf_siege.gd` 是测量用子类：`simulate()` 与父类逐行同序，只在阶段边界加 `Time.get_ticks_usec()`；`perf_map.gd` 用子类包住 `distance` / `direction` / `field` / `change` 计时。用相同场景和步数对比 `state_hash` 可确认行为一致。普通测量用 `perf_runner.gd` 直接实例化父类，不带这些计时开销。

## T73 优化复测

T69 增加了锁定胜负状态机，旧探针只设置 `won=true` 已无法阻止压力场景提前结束。
现在由 `perf_world.gd` 仅覆盖压力场景的 `resolve_outcome()`；自然局仍执行正式结算。
`perf_siege.gd` 同步正式固定步流程，含输入、集结成员、previous_pos、路线观测、细网格移动维护和独立撤退阶段。
清场时释放原有单位状态，运行器检查异常日志；`first_sim_ms` / `all_sim_ms` 包含原先丢弃的前两帧，可检查首次调度尖峰。
`battle_hash` 不包含参数哈希、流场访问计数，直接散列单位战斗状态与 RNG，用于前后对照。

```sh
# 从固定 git 版本重建基线（目标目录已存在时拒绝覆盖；先归档旧结果）
python3 proto/siege/perf/freeze_t73.py

# 同机同驱动，串行测量。窗口不可用时显式改为 --modes sim，不能称为完整帧。
python3 proto/siege/perf/compare_t73.py --baseline --samples 300 --out proto/siege/perf/results/t73/before-perf
python3 proto/siege/perf/compare_t73.py --samples 300 --out proto/siege/perf/results/t73/after-perf

# 与基线逐步对照，完全相同的单位状态与 RNG（需先冻结基线）
godot --headless --path . --script proto/siege/perf/audit_t73.gd -- --strategy=waves --seed=1

# 固定验收：镜头回放、6×2 策略重复、优化机制和逐字确定性
tools/verify/proto_siege.sh
```

参数：`combat.near_cell_size` 为移动近邻细格边长，默认 1；`combat.sense_steps` 为索敌间隔，默认 4 个逻辑步。
`sense_seconds` 保留首次随机相位；敌人锁定与切换滞后不变。移动、战斗、碰撞均按原固定步执行，不依据镜头位置降频。
粗格在每个固定步的前后重建，细格在每个单位移动后更新；近邻结果仍按原粗格快照边界和遍历次序返回。
分离力直接在原粗格内按原序累计，避免生成候选数组后再次读取位置。
队友协同在细格中取得大致范围内的候选；候选达到队伍半数时遍历原队列，省去密集场景的重复筛选。
再按原 squad 顺序线性选择最近 K 人；入选项或边界存在等距时回退到原完整排序。
因此等距邻居和分离力浮点累加次序保持一致。

流场预热与正式缓存合计不超过 `map.flow_cache_limit`。预热在初始化阶段完成，按首次实际访问进入原 FIFO；
拓扑变化会丢弃尚未使用的预热项，避免沿用另一种等长路径。已使用的流场保留原增量修复规则，
开口只传播距离下降，封口只重建 successor 依赖子树；不可达且不受影响的流场跳过。
`test_perf.gd` 对多目标、洞边、交替开关门及破墙逐格比较完整重算距离，并验证每个 successor 满足最短路方程。

普通地面流场使用距离分层队列，层内原生整数排序，保持原堆的 `(distance, cell_id)` 顺序；山洞加权场保留堆路径。
初始化预热时间计入 `setup_ms`，不隐藏进帧采样。

T69 默认局部感知下，T71 的 `reinforce` 压力摆位可能没有任何调度。首次调度需另用 `director_bench.gd`，
传 `--perf_scenario=reinforce --perf_units=500 --strategy=manual`；该微基准显式开启全图感知，
每次新建战场后计时一次真实 `director.tick()`，重复三次，报告实际 ordered 人数和完整决策。加 `--baseline` 使用冻结源码。

阶段细分中的 `separation` / `adjacent_query`：`mean_ms` 为累计调用时间除逻辑步数，`max_ms` 为单次调用最大值；
其他主阶段的 `max_ms` 为单个逻辑步的阶段最大值。阶段探针有计时开销，正式前后表使用不带阶段计时的父类。

T73 的 `perf_map.field_builds` 在实际 `_build_field()` 处计数，包含初始化预热；FIFO 满缓存替换也能正确计入。
`field_build_us` 同样包含预热构建，主场景 `_ready()` 初始化耗时另见 `setup_ms`；压力摆兵在采样外，沿用 T71 口径。首次调度微基准另列含压力摆兵的完整构造耗时。

自然局不再在主场景初始化后重置战斗 RNG，沿用正式 `--seed` 入口已经推进的状态；压力摆兵仍用 `--perf_seed` 重置后直接生成。
