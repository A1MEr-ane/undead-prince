#!/bin/bash
# T61 现有战斗系统性能基线。
# 用法：tools/sim/perf.sh [--units 50,100,200] [--seconds 30] [--out reports/agents/T61-perf.json]
#
# 无头模式每个规模跑 30 秒模拟时间（1800 帧 @ 60 Hz）。输出两套帧时间：
#   处理帧 = 一帧完整游戏逻辑（_simulate + 胜负检查 + 镜头 + UI）的 CPU 耗时
#   物理帧 = 其中固定步长战斗模拟 _simulate 的 CPU 耗时
# 说明：工程把战斗逻辑放在 _process 的 1/60 固定步长里，没有 _physics_process，
# 所以"物理帧"指战斗模拟步；引擎空转/无头渲染/OS 调度不计入，避免噪声掩盖规模曲线。
set -u
cd "$(dirname "$0")/../.." || exit 1
ROOT=$(pwd)

COUNTS="50,100,200"
SECONDS_PER_RUN=30
OUT="reports/agents/T61-perf.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --units) COUNTS=$2; shift 2;;
    --seconds) SECONDS_PER_RUN=$2; shift 2;;
    --out) OUT=$2; shift 2;;
    --units=*) COUNTS=${1#*=}; shift;;
    --seconds=*) SECONDS_PER_RUN=${1#*=}; shift;;
    --out=*) OUT=${1#*=}; shift;;
    *) echo "未知参数 $1"; exit 2;;
  esac
done

PROBE="tools/sim/.perf_probe.gd"
LOG=$(mktemp "${TMPDIR:-/tmp}/t61-perf.XXXXXX")
cleanup() { rm -f "$PROBE" "$PROBE.uid" "$LOG"; }
trap cleanup EXIT INT TERM

if [ ! -f .godot/global_script_class_cache.cfg ]; then
  godot --headless --path . --import >/dev/null 2>&1
fi

# 探针只在运行时生成，结束后删除；不修改任何玩法/场景文件。
cat > "$PROBE" <<'GD'
extends SceneTree
## T61 性能探针（由 tools/sim/perf.sh 生成，运行后删除）。

const DT := 1.0 / 60.0
const WARMUP := 30

var main
var counts: Array = [50, 100, 200]
var seconds := 30
var run_index := 0
var perf


func _init() -> void:
	_parse_args()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	perf = Perf.new()
	perf.app = self
	root.add_child(perf)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var val := kv[1] if kv.size() > 1 else "1"
		match kv[0]:
			"units":
				counts.clear()
				for s in val.split(","):
					counts.append(int(s))
			"seconds":
				seconds = int(val)


## 清掉场景原有部队，在离岛心最近的可走格上铺开两个阵营。
## 基准用不死单位（damage/knockback/stun = 0，hp 极大），保证 30 秒内人数不变，
## 这样不同规模的 p95/p99 才可比；数值只在探针里用，不影响 data/battles 与玩法。
func spawn_units(n: int) -> void:
	for u in main.units:
		u.free()
	main.units.clear()
	for sq in main.squads:
		sq.free()
	main.squads.clear()
	main.player_squads.clear()
	main.time = 0.0
	main.game_over = false
	main.capture = 0.0
	main.sim_rng.seed = 7
	main.art_rng.seed = 11
	main.presence = [Presence.new(), Presence.new()]
	main.presence[0].setup(main.terrain, 0)
	main.presence[1].setup(main.terrain, 1)

	var teams: Array = []
	for faction in 2:
		var sq := Squad.new()
		sq.main = main
		sq.terrain = main.terrain
		sq.faction = faction
		sq.is_player = faction == 0
		sq.title = "perf_%d" % faction
		main.add_child(sq)
		main.squads.append(sq)
		teams.append(sq)
		if faction == 0:
			main.player_squads.append(sq)

	var tiles: Array[Vector2i] = []
	for z in Terrain.SIZE:
		for x in Terrain.SIZE:
			var t := Vector2i(x, z)
			if main.terrain.is_walkable(t):
				tiles.append(t)
	var mid := Vector2(Terrain.SIZE * 0.5, Terrain.SIZE * 0.5)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a.x + 0.5, a.y + 0.5).distance_squared_to(mid) \
			< Vector2(b.x + 0.5, b.y + 0.5).distance_squared_to(mid))

	var stats := {"hp": 1.0e9, "speed": 2.0, "damage": 0.0,
		"knockback": 0.0, "stun": 0.0, "stun_mult": 0.0}
	for i in n:
		var t: Vector2i = tiles[i % tiles.size()]
		var faction: int = (t.x + t.y) % 2
		var sq: Squad = teams[faction]
		var pos: Vector3 = main.terrain.tile_center(t)
		# 略微朝岛心收拢，让相邻两格的敌对单位进入攻击距离，跑真实的战斗 AI。
		var inward := Vector2(mid.x - pos.x, mid.y - pos.z).normalized() * 0.22
		pos += Vector3(inward.x, 0.0, inward.y)
		var u := Unit.new()
		main.add_child(u)
		u.setup(main, sq, faction, 0, pos, stats)
		u.facing = Vector3(cos(float(i) * 1.7), 0.0, sin(float(i) * 1.7))
		sq.units.append(u)
		main.units.append(u)
		u.slot = u.nav_pos


class Perf:
	extends Node

	var app
	var state := 0          # 0 等待就绪，1 预热，2 采样
	var frames := 0
	var total_frames := 0
	var unit_count := 0
	var samples_frame: Array = []
	var samples_sim: Array = []

	func _ready() -> void:
		await get_tree().process_frame
		await get_tree().process_frame
		app.main.set_process(false)
		total_frames = app.seconds * 60
		_prepare(0)

	func _prepare(index: int) -> void:
		app.run_index = index
		unit_count = int(app.counts[index])
		app.spawn_units(unit_count)
		samples_frame.clear()
		samples_sim.clear()
		frames = 0
		state = 1

	func _process(_delta: float) -> void:
		if state == 0:
			return
		var t0 := Time.get_ticks_usec()
		app.main.time += DT
		AgentState.now = app.main.time
		AgentState.dt = DT
		app.main._simulate(DT)
		var t1 := Time.get_ticks_usec()
		app.main._check_goal(DT)
		app.main._update_camera(0.0)
		app.main._update_ui()
		var t2 := Time.get_ticks_usec()

		samples_sim.append(float(t1 - t0) / 1000.0)
		samples_frame.append(float(t2 - t0) / 1000.0)
		frames += 1

		if state == 1:
			if frames >= WARMUP:
				samples_frame.clear()
				samples_sim.clear()
				frames = 0
				state = 2
			return
		if frames >= total_frames:
			_finish()

	func _finish() -> void:
		var alive := 0
		for sq in app.main.squads:
			alive += sq.alive_units().size()
		var row := {
			"units": unit_count,
			"frames": samples_sim.size(),
			"alive": alive,
			"frame_ms": _stats(samples_frame),
			"sim_ms": _stats(samples_sim),
		}
		print("PERF ", JSON.stringify(row))
		if app.run_index + 1 < app.counts.size():
			_prepare(app.run_index + 1)
		else:
			get_tree().quit(0)

	func _stats(values: Array) -> Dictionary:
		if values.is_empty():
			return {"avg": 0.0, "p95": 0.0, "p99": 0.0}
		var total := 0.0
		for v in values:
			total += float(v)
		var sorted := values.duplicate()
		sorted.sort()
		return {
			"avg": total / values.size(),
			"p95": _pct(sorted, 0.95),
			"p99": _pct(sorted, 0.99),
		}

	func _pct(sorted: Array, p: float) -> float:
		var idx := int(ceil(p * sorted.size())) - 1
		idx = clampi(idx, 0, sorted.size() - 1)
		return float(sorted[idx])
GD

echo "T61 性能基线：units=$COUNTS seconds=$SECONDS_PER_RUN"
godot --headless --path . -s "$PROBE" -- --units="$COUNTS" --seconds="$SECONDS_PER_RUN" >"$LOG" 2>&1
CODE=$?
if [ $CODE -ne 0 ] || ! grep -q '^PERF ' "$LOG"; then
  echo "性能探针失败（exit=$CODE），日志："
  tail -40 "$LOG"
  exit 1
fi

python3 - "$LOG" "$OUT" "$COUNTS" "$SECONDS_PER_RUN" <<'PY'
import json, os, platform, re, subprocess, sys

log_path, out_path, counts, seconds = sys.argv[1:5]
rows = []
for line in open(log_path, encoding="utf-8", errors="replace"):
    if line.startswith("PERF "):
        rows.append(json.loads(line[5:]))
if not rows:
    print("没有 PERF 输出")
    sys.exit(1)

def sh(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

godot = sh("godot --version") or "unknown"
cpu = sh("sysctl -n machdep.cpu.brand_string") or platform.processor() or "unknown"
model = sh("sysctl -n hw.model")
os_name = sh("sw_vers -productVersion")
if os_name:
    os_name = "macOS " + os_name
else:
    os_name = platform.platform()
arch = sh("uname -m") or platform.machine()
machine = {"cpu": cpu, "model": model, "os": os_name, "arch": arch}

report = {
    "task": "T61",
    "godot": godot,
    "machine": machine,
    "seconds_per_run": int(seconds),
    "note": "处理帧=完整 _process 逻辑；物理帧=固定步长 _simulate；单位数不变（基准用不死单位）",
    "counts": rows,
}
os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=1)

print()
print("机器：%s %s / %s / %s" % (cpu, model, os_name, arch))
print("Godot：%s" % godot)
print()
print("| 单位数 | 帧数 | 存活 | 处理帧均值 | 处理帧 p95 | 处理帧 p99 | 物理帧均值 | 物理帧 p95 | 物理帧 p99 |")
print("|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
for r in rows:
    f, s = r["frame_ms"], r["sim_ms"]
    print("| %d | %d | %d | %.2f ms | %.2f ms | %.2f ms | %.2f ms | %.2f ms | %.2f ms |"
          % (r["units"], r["frames"], r["alive"], f["avg"], f["p95"], f["p99"], s["avg"], s["p95"], s["p99"]))
print()
print("写入 %s" % out_path)
PY
