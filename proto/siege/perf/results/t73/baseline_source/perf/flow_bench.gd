extends SceneTree
## 流场重算微基准：只测真实 siege_map.gd 的 field()/change()，不修改原型。
## 目的：把“破墙瞬间”的帧尖峰拆成“缓存了多少个流场 × 一次 change 的修复成本”。

const Map = preload("res://proto/siege/perf/results/t73/baseline_source/siege_map.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var params: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://proto/siege/perf/results/t73/baseline_source/siege_params.json"))
	var results: Array = []
	for count in [1, 10, 30, 58, 100, 180]:
		var terrain = Map.new()
		terrain.setup(params)
		var goals := _goals(terrain, params, count)
		var build_us := 0
		for goal in goals:
			var t0 := Time.get_ticks_usec()
			terrain.field(goal, false)
			build_us += Time.get_ticks_usec() - t0
		var before: int = terrain.repaired_cells
		var t1 := Time.get_ticks_usec()
		terrain.change(params.map.gate_rect, true, 0.0, "flow_bench")
		var change_us := Time.get_ticks_usec() - t1
		results.append({
			"fields": terrain.fields.size(),
			"build_ms": snappedf(float(build_us) / 1000.0, 0.01),
			"change_ms": snappedf(float(change_us) / 1000.0, 0.01),
			"relaxed_cells": terrain.repaired_cells - before,
		})
		terrain = null
	print("FLOW_BENCH " + JSON.stringify({"results": results, "map": [int(params.map.width), int(params.map.depth)]}))
	quit(0)

func _goals(terrain, params: Dictionary, count: int) -> Array:
	var out: Array = []
	var width := int(params.map.width)
	var depth := int(params.map.depth)
	var step := maxi(2, int(floor(sqrt(float(width * depth) / maxf(1.0, float(count))))))
	for z in range(2, depth - 1, step):
		for x in range(2, width - 1, step):
			var p := Vector3(x + 0.5, 0, z + 0.5)
			if terrain.is_walkable_at(p):
				out.append(p)
			if out.size() >= count:
				return out
	# 兜底：网格点不够时沿可走格补齐（正常不会用到）。
	for i in terrain.land.size():
		if out.size() >= count:
			break
		var p: Vector3 = terrain.point(i)
		if terrain.is_walkable_at(p):
			out.append(p)
	return out
