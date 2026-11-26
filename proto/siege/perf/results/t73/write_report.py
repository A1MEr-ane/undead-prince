from pathlib import Path
import json
import statistics

root=Path.cwd(); out=root/'proto/siege/perf/results/t73'
d=json.loads((root/'proto/siege/perf/T73-results.json').read_text())
rows=d['comparisons']; directors=d['director']
med=lambda rows,key: statistics.median(r[key] for r in rows)
ms=lambda x:f'{x:.2f}'
by=lambda scenario,units:next(r for r in rows if r['scenario']==scenario and r['units']==units)
all300=[r['after_ms']['p50'] for r in rows if r['units']==300]
d500=next(r for r in directors if r['units']==500)
text=f'''---
task_id: T73
executor: codex
status: review_required
summary: |
  完成分离力直接累计、移动细网格与最近 K 人选择、参数化错峰索敌、流场局部修复加速及守军调度距离缓存。
  固定验证通过：12 组同种子逐字重放；优化前后 12 局完整 SIEGE 仅参数指纹变化；36 组压力战斗状态哈希一致。
  175 个缓存流场破门更新 793.84 → 71.13 ms；500 单位首次调度评估 {d500['median_before_ms']:.2f} → {d500['median_after_ms']:.2f} ms。
  300 单位两步纯模拟 P50 为 {min(all300):.2f}–{max(all300):.2f} ms，16.7 ms 压力目标未达；窗口完整帧启动失败，需补测。
artifacts:
  - proto/siege/perf/T73-results.json
  - proto/siege/perf/README.md
  - reports/agents/T73.md
  - codex/t73-siege-perf
validation: |
  tools/verify/proto_siege.sh --out proto/siege/perf/results/t73/verify-reviewed 通过。
  12/12 完整 SIEGE 逐字重放、12/12 优化前后自然局结果对照、36/36 压力状态哈希、12/12 首次调度决策对照通过。
  额外 seed 7 两个自然策略、两个逐步状态/RNG 对照、两个阶段探针与正式探针状态对照通过。
  关键数据与哈希已入库 T73-results.json；完整原始日志在本地忽略目录 proto/siege/perf/results/t73/。
issues: |
  完整窗口帧未测：两次启动分别等待 600 秒和 20 秒，均无 PERF 输出。
  密集行军/近战/洞口排队仍超预算；175 个活跃缓存流场同时受影响时仍有约 71 ms 的同步修复。
usage: 本地 Godot 4.7.2 / Python 标准库；未调用付费 API；会话额度和实际费用不可读取
needs_claude: true
reason: 请 Lead 在可启动 Godot 窗口的环境补测完整帧，并决定剩余密集场景的后续优化范围。
---

## 结果：部分完成

实现和无头验收完成，可提交审查。完整帧测量缺少运行环境，300 单位的 T71 两步压力目标仍未达到。所有单位继续按原固定步模拟，未按镜头位置停止或降低模拟频率。

分支：`codex/t73-siege-perf`。报告、代码和数据随该分支同一提交交付。

## 改动

- `siege_spatial.gd`：随移动更新的细网格；查询保留原粗格快照边界和顺序；队友候选在稀疏区域用细网格、达到队伍半数时遍历原队列。
- `siege.gd`：分离力在原网格顺序内直接累计，避免中间候选数组和重复位置读取；索敌直接在网格中查找；计数查询省去排序；占领人数改为单次遍历。
- `siege_swordsman.gd`：最近 K 人线性选择；入选项或边界存在等距时回退原完整排序，保留原等距邻居选择。
- `siege_unit.gd` / `siege_params.json`：`combat.near_cell_size=1`、`combat.sense_steps=4`。首次随机相位沿用 `sense_seconds`，后续每 N 步评估；目标锁定和切换滞后保留。默认周期仍与原先固定步上的实际评估时刻相同。
- `siege_map.gd`：静态地面邻接缓存；普通地面使用距离分层、层内格号排序，与原堆 `(距离, 格号)` 次序一致；山洞加权场保留堆算法。开口传播下降距离，封口修复 successor 依赖子树，跳过不受影响的不可达流场。预热和正式缓存共同受原 `flow_cache_limit=180` 限制。
- `siege_director.gd`：初始化预热常用目标场；正式缓存仍按首次使用顺序插入；未使用预热项在拓扑变化时丢弃。每次排序按比较器实际请求缓存距离，避免重复寻路和额外构建未使用目标场。
- `test_perf.gd` / `tools/verify/proto_siege.sh` / `perf/verify_t73.py`：加入候选顺序、顺序移动、山洞/死亡、逐位分离力、等距 K 邻居、1/4/7 步索敌、全算流场和缓存上限检查；同种子检查加强到完整输出逐字相等。
- `perf/`：修复 T69 合入后压力局提前结束、阶段副本流程过时、自然局初始化后错误重置 RNG 和清场未释放状态的问题；加入首帧计时、战斗状态哈希、基线冻结、前后对照和实际调度微基准。未改 `scripts/`、`shaders/`、`data/`、`docs/`、`tasks/`、`art/`、`assets/`、`project.godot`。

## 验证

### 固定套件与行为一致性

命令：

```sh
tools/verify/proto_siege.sh --out proto/siege/perf/results/t73/verify-reviewed
python3 proto/siege/perf/regression_t73.py \\
  proto/siege/perf/results/t73/before-natural/results.jsonl \\
  proto/siege/perf/results/t73/verify-reviewed/results.jsonl \\
  --out proto/siege/perf/results/t73/regression-reviewed.json
```

关键输出（实际日志）：

```text
'''
log=(out/'verify-reviewed.log').read_text().splitlines()
for line in log:
    if line.startswith(('CAMERA_FEATURES PASS','CAMERA_REPLAY PASS','SIEGE_FEATURES PASS','SIEGE_VERIFY PASS','SIEGE_PERF_FEATURES PASS','T73_BYTE_REPLAY PASS')):
        text+=line+'\n'
text+=(out/'regression-reviewed.log').read_text().strip()+'\n```\n\n'
text+='六个默认策略 × seeds 1/2：胜负、伤亡、经济、路线、调度、拓扑和流场计数等完整输出均相等，仅新增参数导致 `params_sha256` 改变。参数指纹差异已逐局记录在数据文件。\n\n'
text+='逐步对照使用冻结基线；每步比较单位位置、血量、敌人、体力、目标、邻居及 RNG：\n\n```text\n'+'\n'.join(d['audits'])+'\n```\n\n'
text+='流场正确性：分层队列与原堆在完整构建和增量更新中的 `dist` / `next` 逐格相等。增量与从零重建的 `dist` 逐格相等；每条 successor 验证最短路方程及可通行性。原实现允许保留不同的等长路线，本次保留该选择，未强制把增量 `next` 改成从零构建时的另一个等长选择。\n\n'
text+='### 性能口径\n\n'
text+='- 冻结基线：`a058daa4737fab9cfc2cd12775bf487c1e8b498f`，在同机使用修正后的 T71 探针前后对照。\n'
text+=f"- 环境：Apple M1 / 8 核，{d['environment']['os']}，Godot {d['environment']['godot']}，Debug，无头。窗口实际渲染未运行。\n"
text+='- 每样本 **2 × 1/30 s 固定步**；普通场景 300 样本=20 s，breach/dawn 240 样本=16 s。压力局保持单位不死并冻结多数目标重选，沿用 T71 摆位。无并行 Godot 模拟计时。\n'
text+='- 这是 T71 加压口径。默认游戏速度 1、步长 1/30 s 时，60 FPS 平均每帧 0.5 步；不能把本表直接换算成实际游戏 FPS。T71 的 100/200 档原来采 600 样本，本次统一前后采 300，故优化比例使用本次冻结基线，不直接使用 T71 旧窗口数据。\n'
recheck=d['baseline_march_100_recheck_ms']['p50']; initial=by('march',100)['before_ms']['p50']
text+=f'- 基线行军 100 档结束后复测 {initial:.3f} → {recheck:.3f} ms（{(recheck/initial-1)*100:+.2f}%），未见大幅计时漂移。\n\n'
text+='### 压力矩阵：纯模拟 P50（ms / 两步样本）\n\n每格为优化前 → 优化后。P95/P99/max、包含首两帧的 all_sim、首帧耗时和全部哈希见 `proto/siege/perf/T73-results.json`。\n\n| 场景 | 100 | 200 | 300 | 500 |\n|---|---:|---:|---:|---:|\n'
for scenario in ('march','multi','melee','gate','breach','reinforce','cave','dawn','idle'):
    cells=[]
    for units in (100,200,300,500):
        r=by(scenario,units); cells.append(f"{r['before_ms']['p50']:.2f} → {r['after_ms']['p50']:.2f}")
    text+='| '+scenario+' | '+' | '.join(cells)+' |\n'
text+='\n36/36 组压力战斗状态哈希相等；最早四组未记录哈希的基线已补跑。最终调度缓存审查后，reinforce 四档另外复测，表中使用该次数据。\n\n'
text+='### 破门流场微基准\n\n同地图、同目标集合；每档前后松弛格数完全相同。\n\n| 缓存流场 | 构建前 → 后 ms | 破门更新前 → 后 ms | 松弛格数 |\n|---:|---:|---:|---:|\n'
for b,a in zip(d['flows']['before']['results'],d['flows']['after']['results']):
    text+=f"| {b['fields']} | {b['build_ms']:.2f} → {a['build_ms']:.2f} | {b['change_ms']:.2f} → {a['change_ms']:.2f} | {a['relaxed_cells']} |\n"
text+='\n### 首次守军调度\n\n独立 `director_bench.gd`，每档新建战场三次，记录首次 `director.tick()`。显式启用 `global_perception=true` 以确保真实派兵；正式默认仍为局部感知。当前 T69 默认规则下原 reinforce 摆位没有实际出发，不能用该场景首帧代替调度评估成本。\n\n| 单位 | 首评估中位前 → 后 ms | 构造及压力摆兵中位前 → 后 ms | 每次预留人数 |\n|---:|---:|---:|---:|\n'
for r in directors:
    text+=f"| {r['units']} | {r['median_before_ms']:.2f} → {r['median_after_ms']:.2f} | {med(r['before']['repeats'],'setup_ms'):.2f} → {med(r['after']['repeats'],'setup_ms'):.2f} | {r['after']['repeats'][0]['ordered']} |\n"
text+='\n12/12 次前后完整调度决定（含来源、单位、预计时间）相等。初始化成本单列，预热成本未隐藏在未说明的计时区间。\n\n'
text+='### 自然局 seed 7（无压力注入）\n\n自然探针的 main_gate/seed7 完整结果哈希另与正式 CLI 入口相等，确认探针没有重置初始化后的 RNG 或改动对局。真实经济、死亡与完整目标评估；两个策略的战斗状态/RNG 哈希及胜负、结束时间、出生和伤亡一致。表内为纯模拟 P50/P95/P99/max，单位 ms。\n\n| 策略 | 优化前 | 优化后 |\n|---|---:|---:|\n'
for strategy in ('main_gate','waves'):
    vals=[]
    for label in ('before','after'):
        r=next(r for r in d['natural_seed7'] if r['strategy']==strategy and r['label']==label)
        vals.append(' / '.join(f"{r['sim_ms'][k]:.2f}" for k in ('p50','p95','p99','max')))
    text+='| '+strategy+' | '+' | '.join(vals)+' |\n'
rr=d['natural_waves_repeat']
text+=f"\nwaves 首轮最大值由 75.47 升至 125.34 ms；另一次普通复测最大值 {rr[0]['sim_ms']['max']:.2f} ms，带阶段计时复测最大值 {rr[1]['sim_ms']['max']:.2f} ms。两次复测完整状态哈希与首轮相同。该最大值回退未完整归因，不把它直接当作 OS 噪声；阶段明细保留在数据文件。\n"
text+='\n### 剩余热点与截图\n\n阶段探针与正式探针在相同步数下完整 `state_hash` 相等。下表为每逻辑步累计时间均值（ms，含计时开销）：\n\n| 300 单位场景 | 单位移动/战斗整段 | 分离力 | 队友候选查询 | 感知及导航 |\n|---|---:|---:|---:|---:|\n'
for r in d['phase_after']:
    vals=[r['phase'][k]['mean_ms'] for k in ('unit_tick_move_combat','separation','adjacent_query','sense_nearby')]
    text+='| '+r['scenario']+' | '+' | '.join(f'{v:.3f}' for v in vals)+' |\n'
text+='\n阶段细分用于归因，正式前后表不带这些计时器。`separation` / `adjacent_query` 的最大值为单次调用最大值，不能当成单帧最大值。\n\n截图：无视觉样式改动；窗口启动失败，未截图。\n\n'
text+='## 风险与已知不足\n\n'
text+=f'- 300 档压力纯模拟中位仍为 {min(all300):.2f}–{max(all300):.2f} ms，目标未达。密集行军、近战和洞口排队的单位逻辑仍重，空间网格不能消除已进入局部密集范围的全部工作量。\n'
text+='- 缓存满且大量流场同时受影响时仍同步修复；175 场破门微基准为 71.13 ms，尖峰显著降低但仍可见。\n'
text+='- 完整窗口帧、渲染残差和镜头压力没有本次新数据；两次窗口进程分别等 600.01 s / 20.01 s，均无 PERF。所有表格均明确为无头模拟或独立微基准。\n'
text+='- 自然 waves 首轮 max 出现回退；P50/P95/P99 改善，但仍需关注长尾，不能仅凭中位数认定尖峰全部消失。\n'
text+='- 保留原粗格快照边界、顺序移动、等距邻居及等长路径继承规则，避免优化改变对局；本轮一致性证据覆盖所列种子和压力场景，不宣称遍历全部可能输入。\n\n'
text+='## 未完成\n\n- 在可启动窗口的环境用相同探针补齐完整帧前后数据。\n- 达到 300 单位、完整帧中位低于 16.7 ms 的压力目标。该项为任务卡软目标，未据此放宽功能或确定性检查。\n\n'
text+='## 疑问（需要用户或 Lead 决定的）\n\n- 请 Lead 补跑窗口矩阵，并按实际完整帧数据决定后续密集场景性能任务的范围。\n\n'
text+='## 执行记录\n\n- 自我修复共 3 轮：新增测试的类型推断标注；测试夹具改用正式伤害死亡入口；细网格密集场景性能回退修正。未超 retry_limit=3。\n- 最终审查将调度距离缓存改为实际比较请求时才计算，相关机制、自然局、调度和 reinforce 档位均重新验收。\n- 计时中断的初稿结果保留在本地 `perf/results/t73/iteration-1/`，未作为最终优化后数据。\n- 原始日志及冻结源在本地忽略目录；关键数值、哈希和决策已经入库 `T73-results.json`。未提交临时文件。\n'
(root/'reports/agents/T73.md').write_text(text)
print('T73_REPORT_WRITTEN',len(text),'chars')
