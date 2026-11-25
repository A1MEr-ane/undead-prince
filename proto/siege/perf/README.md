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
- `sim_ms`：每帧 2 个 1/30 s 固定步的模拟耗时（与 60 FPS 的 2 步/帧对齐）。
- `refresh_ms`：`siege_view.refresh()` 的耗时；`residual_ms` = 帧间隔 − sim − refresh。
- `draw_calls`：`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` 的 P50/P95/max。
- `active`：活跃/场上单位数；`cave_inside_max` 为洞内隐藏人数。
- `breach_sample` / `breach_sim_seconds`：破门发生在第几个样本、对应模拟秒。
- `flow_repairs` / `flow_relaxed_cells` / `dispatches` / `cave_transits`：寻路与调度事件计数。
- `state_hash`：单位位置、血量与 `main.result()` 的哈希；无头与窗口同配置应完全一致。
- `environment`：Godot 版本、OS、CPU、GPU、渲染后端、窗口/视口/纹理尺寸、Debug/Release、内存、节点数。

`perf_siege.gd` 是测量用子类：`simulate()` 与父类逐行同序，只在阶段边界加 `Time.get_ticks_usec()`；`perf_map.gd` 用子类包住 `distance` / `direction` / `field` / `change` 计时。用相同场景和步数对比 `state_hash` 可确认行为一致。普通测量用 `perf_runner.gd` 直接实例化父类，不带这些计时开销。
