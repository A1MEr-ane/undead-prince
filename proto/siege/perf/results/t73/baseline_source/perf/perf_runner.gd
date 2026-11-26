extends Node3D
## T71 性能探针：在真实 siege.tscn 上驱动固定步长模拟，分别测无头模拟与窗口完整帧。
## 只测不改：不修改 proto/siege/*.gd；压力场景直接用 main.spawn() 摆放单位。
## 用法见 proto/siege/perf/README.md；命令行参数在 -- 之后。

const BaseSiege = preload("res://proto/siege/perf/results/t73/baseline_source/perf/perf_world.gd")
const PhaseSiege = preload("res://proto/siege/perf/results/t73/baseline_source/perf/perf_siege.gd")

var opts := {}
var main
var view
var mode := "sim"
var scenario := "march"
var target_units := 100
var target_samples := 900
var steps_per_frame := 2
var warmup := 0
var phase_mode := false
var natural := false
var out_path := ""
var seed_value := 7

var warm_i := 0
var skip_left := 2
var last_frame_us := 0
var running := false
var done := false

var frame_us: Array = []
var sim_us: Array = []
var all_sim_us: Array = []
var refresh_us: Array = []
var residual_us: Array = []
var active: Array = []
var draw_calls: Array = []
var cave_inside: Array = []

var breach_sample := -1
var breach_seen := false
var camera_moves := 0
var dynamic_camera := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
		opts[parts[0]] = parts[1] if parts.size() > 1 else "true"
	mode = str(opts.get("perf_mode", "sim"))
	scenario = str(opts.get("perf_scenario", "march"))
	target_units = int(opts.get("perf_units", "100"))
	target_samples = int(opts.get("perf_samples", "900"))
	steps_per_frame = int(opts.get("perf_steps_per_frame", "2"))
	warmup = int(opts.get("perf_warmup", "0"))
	phase_mode = str(opts.get("perf_phase", "false")) == "true"
	natural = str(opts.get("perf_natural", "false")) == "true"
	out_path = str(opts.get("perf_out", ""))
	seed_value = int(opts.get("perf_seed", "7"))

	var script = PhaseSiege if phase_mode else BaseSiege
	main = script.new()
	add_child(main)
	main.set_process(false)
	if not natural:
		main.seed_value = seed_value
		main.sim_rng.seed = seed_value
	view = main.view
	if view != null:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		DisplayServer.window_move_to_foreground()
		Engine.max_fps = 0
		if warmup <= 0:
			warmup = 30
	else:
		warmup = 0
	if natural:
		target_samples = mini(target_samples, 4500)
	else:
		_configure_stress()
		_clear_units()
		_setup_scenario()
		_reset_counters()
	if view != null:
		view.refresh()
	running = true
	set_process(true)

func _arg(name: String, fallback: String = "") -> String:
	return str(opts.get(name, fallback))

func _configure_stress() -> void:
	# 压力模式：人数恒定，隔离死亡/经济，只测规模负载；所有模式说明写入报告。
	for kind in main.params.units:
		var s: Dictionary = main.params.units[kind]
		s["hp"] = 1.0e9
		s["knockback"] = 0.0
		s["stun"] = 0.0
		if s.has("damage"):
			s["damage"] = 0.0
		if s.has("melee_damage"):
			s["melee_damage"] = 0.0
	main.params.reinforcements.enabled = false
	main.params.structures.gate_auto_open = false
	main.params.targeting.reroute_after_seconds = 1.0e9
	main.params.targeting.route_crowd_threshold = 1000000
	main.params.capture.seconds = 1.0e9
	main.params.capture.defender_seconds = 1.0e9
	main.director.next_think = 1.0e9
	main.director.reinforcements_arrived = true
	# 压力场景没有完整守军；锁定 win 标志，避免第一步触发全歼 finish()。
	main.won = true
	main.victory_method = "perf_hold"

func _clear_units() -> void:
	for u in main.units:
		u.dispose()
	main.units.clear()
	main.sides[0]["units"].clear()
	main.sides[1]["units"].clear()
	main.spatial.clear()
	main.spawned = [0, 0]
	main.director.decisions.clear()
	main.director.dispatches = 0
	for z in main.params.map.zones:
		main.zones[z.id] = {"owner": "defender", "progress": 0.0, "retake": 0.0, "captures": [], "losses": [], "contested_resets": []}

func _reset_counters() -> void:
	main.terrain.flow_repairs = 0
	main.terrain.repaired_cells = 0
	main.terrain.topology_events.clear()
	main.cave_transits = 0
	main.director.dispatches = 0
	main.director.decisions.clear()
	main.events.clear()
	main.congestion = 0
	main.travel_congestion = 0
	main.reroutes = 0

func _grid(center: Vector3, count: int, spacing: float = 0.55, columns: int = -1) -> Array:
	if count <= 0:
		return []
	var cols := columns
	if cols <= 0:
		cols = maxi(4, int(ceil(sqrt(float(count)) * 1.5)))
	var rows := int(ceil(float(count) / cols))
	var out: Array = []
	for i in count:
		var r := i / cols
		var c := i % cols
		var p := Vector3(
			center.x + (c - (cols - 1) * 0.5) * spacing,
			0.0,
			center.z + (r - (rows - 1) * 0.5) * spacing
		)
		out.append(p)
	return out

func _spawn_at(kind: String, faction: int, pos: Vector3, zone: String):
	var u = main.spawn(kind, faction, pos, zone)
	u.anchor = u.nav_pos
	return u

func _order(u, slot: Vector3, objective: String = "", freeze: bool = true) -> void:
	u.slot = main.terrain.nearest(slot)
	u.objective = objective
	if freeze:
		u.next_target = 1.0e9

func _hold(u, slot: Vector3, zone: String) -> void:
	u.anchor = main.terrain.nearest(slot)
	u.slot = u.anchor
	u.home = zone
	u.assigned = zone
	u.marching = false
	u.next_target = 1.0e9

func _setup_scenario() -> void:
	match scenario:
		"march":
			_setup_march()
		"multi":
			_setup_multi()
		"melee":
			_setup_melee()
		"gate":
			_setup_gate()
		"breach":
			_setup_breach()
		"reinforce":
			_setup_reinforce()
		"cave":
			_setup_cave()
		"dawn":
			_setup_dawn()
		"camera":
			_setup_march()
			dynamic_camera = true
		"idle":
			_setup_idle()
		_:
			push_error("unknown perf scenario: " + scenario)
			get_tree().quit(2)

func _setup_march() -> void:
	var n := target_units
	for p in _grid(Vector3(29, 0, 38), n, 0.55):
		var u = _spawn_at("ghost", 0, p, "coast")
		_order(u, Vector3(29, 0, 29.8), "", true)

func _setup_multi() -> void:
	var groups := [
		{"center": Vector3(29, 0, 40), "slot": Vector3(29, 0, 30)},
		{"center": Vector3(9, 0, 40), "slot": Vector3(9, 0, 25)},
		{"center": Vector3(45, 0, 40), "slot": Vector3(45, 0, 38)},
	]
	var base := target_units / 3
	var left := target_units
	for i in groups.size():
		var count := base if i < groups.size() - 1 else left
		left -= count
		for p in _grid(groups[i].center, count, 0.55):
			var u = _spawn_at("ghost", 0, p, "coast")
			_order(u, groups[i].slot, "", true)

func _setup_melee() -> void:
	var g := int(target_units * 0.5)
	var s := int(target_units * 0.4)
	var a := target_units - g - s
	for p in _grid(Vector3(30, 0, 20), g, 0.55):
		var u = _spawn_at("ghost", 0, p, "plaza")
		_order(u, Vector3(31, 0, 20), "", true)
	for p in _grid(Vector3(32, 0, 20), s, 0.55):
		_hold(_spawn_at("shield", 1, p, "plaza"), Vector3(31, 0, 20), "plaza")
	for p in _grid(Vector3(34, 0, 20), a, 0.55):
		_hold(_spawn_at("archer", 1, p, "plaza"), Vector3(32, 0, 20), "plaza")

func _setup_gate() -> void:
	main.terrain.change(main.params.map.gate_rect, true, 0.0, "perf_open_gate")
	main.terrain.gate_open = true
	var g := int(target_units * 0.6)
	var d := target_units - g
	var s := int(d * 0.8)
	var a := d - s
	for p in _grid(Vector3(29, 0, 31), g, 0.55):
		var u = _spawn_at("ghost", 0, p, "coast")
		_order(u, Vector3(29, 0, 27.5), "", true)
	for p in _grid(Vector3(29, 0, 27), s, 0.55):
		_hold(_spawn_at("shield", 1, p, "plaza"), Vector3(29, 0, 27.5), "plaza")
	for p in _grid(Vector3(31, 0, 26), a, 0.55):
		_hold(_spawn_at("archer", 1, p, "plaza"), Vector3(30, 0, 27), "plaza")

func _setup_breach() -> void:
	main.params.structures.gate_hp = 50.0
	main.gate_hp = 50.0
	for p in _grid(Vector3(29, 0, 31), target_units, 0.5):
		var u = _spawn_at("ghost", 0, p, "coast")
		_order(u, Vector3(29, 0, 29.0), "gate", true)

func _setup_reinforce() -> void:
	main.director.next_think = 0.0
	var g := int(target_units * 0.25)
	var d := target_units - g
	var ds := int(d * 0.8)
	var da := d - ds
	for p in _grid(Vector3(29, 0, 40), g, 0.55):
		var u = _spawn_at("ghost", 0, p, "coast")
		_order(u, Vector3(28, 0, 39), "", true)
	var zones := [
		{"id": "highland", "point": Vector3(9, 0, 24)},
		{"id": "plaza", "point": Vector3(31, 0, 20)},
		{"id": "keep", "point": Vector3(32, 0, 9)},
	]
	var si := 0
	var ai := 0
	for zi in zones.size():
		var count := ds / zones.size() if zi < zones.size() - 1 else ds - si
		si += count
		var acount := da / zones.size() if zi < zones.size() - 1 else da - ai
		ai += acount
		for p in _grid(zones[zi].point, count, 0.55):
			_hold(_spawn_at("shield", 1, p, zones[zi].id), zones[zi].point, zones[zi].id)
		for p in _grid(zones[zi].point + Vector3(0, 0, 1.5), acount, 0.55):
			_hold(_spawn_at("archer", 1, p, zones[zi].id), zones[zi].point + Vector3(0, 0, 1.5), zones[zi].id)

func _setup_idle() -> void:
	for p in _grid(Vector3(30, 0, 20), target_units, 1.0):
		var u = _spawn_at("ghost", 0, p, "plaza")
		_order(u, u.nav_pos, "", true)

func _setup_cave() -> void:
	for p in _grid(Vector3(45, 0, 40), target_units, 0.5):
		var u = _spawn_at("ghost", 0, p, "coast")
		u.route = "cave"
		u.stage = 0
		u.objective = "cave"
		u.next_target = 0.0

func _setup_dawn() -> void:
	main.params.simulation.night_seconds = 300.0
	var step := float(main.params.simulation.step)
	main.step_number = int(282.0 / step)
	main.time = main.step_number * step
	target_samples = mini(target_samples, 240)
	_setup_melee()

func _active_counts() -> Dictionary:
	var ghosts := 0
	var defenders := 0
	var on_field := 0
	var inside := 0
	for u in main.units:
		if not u.alive:
			continue
		if u.faction == 0:
			ghosts += 1
		else:
			defenders += 1
		if u.cave_until >= 0:
			inside += 1
		else:
			on_field += 1
	return {"ghost": ghosts, "defender": defenders, "on_field": on_field, "in_cave": inside}

func _process(_delta: float) -> void:
	if not running or done or main == null:
		return
	if warm_i < warmup:
		if view != null:
			view.refresh()
		warm_i += 1
		if warm_i == warmup:
			last_frame_us = Time.get_ticks_usec()
		return
	var now := Time.get_ticks_usec()
	var this_frame := now - last_frame_us
	last_frame_us = now

	if dynamic_camera and view != null:
		if (frame_us.size() + skip_left) % 75 == 0:
			var phase_i := ((frame_us.size() + skip_left) / 75) % 4
			view.zoom = [25.0, 85.0, 25.0, 85.0][phase_i]
			view.yaw = deg_to_rad([0.0, 90.0, 180.0, 270.0][phase_i])
			view.update_camera()
			camera_moves += 1

	if natural and main.finished:
		_finish()
		return
	var t0 := Time.get_ticks_usec()
	for n in steps_per_frame:
		main.simulate()
	var t1 := Time.get_ticks_usec()
	all_sim_us.append(t1 - t0)
	if view != null:
		view.refresh()
	var t2 := Time.get_ticks_usec()
	if not breach_seen and main.terrain.gate_broken:
		breach_seen = true
		breach_sample = frame_us.size()

	if skip_left > 0:
		skip_left -= 1
		return

	var counts := _active_counts()
	frame_us.append(this_frame)
	sim_us.append(t1 - t0)
	refresh_us.append(t2 - t1)
	residual_us.append(maxi(0, this_frame - (t1 - t0) - (t2 - t1)))
	active.append(int(counts.on_field))
	cave_inside.append(int(counts.in_cave))
	if view != null:
		draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if frame_us.size() >= target_samples:
		_finish()

func _pct(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var b := values.duplicate()
	b.sort()
	var idx := clampi(ceili(p * b.size()) - 1, 0, b.size() - 1)
	return float(b[idx])

func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / values.size()

func _ms(values: Array) -> Dictionary:
	return {
		"p50": snappedf(_pct(values, 0.50) / 1000.0, 0.001),
		"p95": snappedf(_pct(values, 0.95) / 1000.0, 0.001),
		"p99": snappedf(_pct(values, 0.99) / 1000.0, 0.001),
		"max": snappedf((float(values.max()) if not values.is_empty() else 0.0) / 1000.0, 0.001),
		"mean": snappedf(_mean(values) / 1000.0, 0.001),
	}

func _state_hash() -> String:
	var parts := PackedStringArray()
	for u in main.units:
		parts.append("%d:%d:%.5f:%.5f:%.5f:%s" % [u.id, u.faction, u.nav_pos.x, u.nav_pos.z, u.hp, str(u.alive)])
	parts.append(JSON.stringify(main.result()))
	return "\n".join(parts).sha256_text()

func _battle_hash() -> String:
	var rows: Array = []
	for u in main.units:
		rows.append([u.id, u.nav_pos, u.hp, u.alive, u.enemy.id if u.enemy != null else -1,
			u.brain.stamina, u.slot, u.route, u.stage, u.target_key, u.anim_name, u.anim_t,
			u.brain.adjacent.map(func(f): return f.id)])
	return var_to_str([main.sim_rng.state, rows]).sha256_text()

func _finish() -> void:
	done = true
	running = false
	var active_min := int(active.min()) if not active.is_empty() else 0
	var active_max := int(active.max()) if not active.is_empty() else 0
	var cave_max := int(cave_inside.max()) if not cave_inside.is_empty() else 0
	var out := {
		"schema": 1,
		"scenario": scenario,
		"mode": mode,
		"phase_mode": phase_mode,
		"units_target": 0 if natural else target_units,
		"natural": natural,
		"strategy": main.strategy,
		"ended_at": snappedf(main.ended_at, 0.01),
		"won": main.won,
		"victory_method": main.victory_method,
		"spawned": main.spawned,
		"casualties": main.casualties,
		"samples": frame_us.size(),
		"steps_per_frame": steps_per_frame,
		"step_seconds": float(main.params.simulation.step),
		"sample_sim_seconds": snappedf(frame_us.size() * steps_per_frame * float(main.params.simulation.step), 0.01),
		"active": {"min": active_min, "max": active_max, "mean": snappedf(_mean(active), 0.01)},
		"cave_inside_max": cave_max,
		"frame_ms": _ms(frame_us) if mode == "render" else {},
		"sim_ms": _ms(sim_us),
		"first_sim_ms": float(all_sim_us[0]) / 1000.0,
		"all_sim_ms": _ms(all_sim_us),
		"refresh_ms": _ms(refresh_us) if mode == "render" else {},
		"residual_ms": _ms(residual_us) if mode == "render" else {},
		"draw_calls": {
			"p50": int(_pct(draw_calls, 0.50)),
			"p95": int(_pct(draw_calls, 0.95)),
			"max": int(draw_calls.max()) if not draw_calls.is_empty() else 0,
		} if mode == "render" else {},
		"frames_over_16_7": _count_over(frame_us, 16700) if mode == "render" else 0,
		"frames_over_33_3": _count_over(frame_us, 33300) if mode == "render" else 0,
		"breach_sample": breach_sample,
		"breach_sim_seconds": snappedf(float(breach_sample) * steps_per_frame * float(main.params.simulation.step), 0.01) if breach_sample >= 0 else -1.0,
		"camera_moves": camera_moves,
		"cave_transits": main.cave_transits,
		"dispatches": main.director.dispatches,
		"flow_repairs": main.terrain.flow_repairs,
		"flow_relaxed_cells": main.terrain.repaired_cells,
		"topology_events": main.terrain.topology_events.size(),
		"combat_events": main.events,
		"state_hash": _state_hash(),
		"battle_hash": _battle_hash(),
		"result_hash": JSON.stringify(main.result()).sha256_text(),
		"params_sha256": JSON.stringify(main.params, "", true, true).sha256_text(),
		"environment": _environment(),
	}
	if phase_mode:
		out["phase"] = _phase_summary()
		out["map_stat"] = main.terrain.stat.duplicate()
		out["phase_steps"] = main.phase_steps
	var line := "PERF " + JSON.stringify(out)
	print(line)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_line(line.substr(5))
			f.close()
	get_tree().quit(0)

func _count_over(values: Array, threshold: int) -> int:
	var count := 0
	for v in values:
		if int(v) > threshold:
			count += 1
	return count

func _phase_summary() -> Dictionary:
	var out := {}
	for key in main.phase:
		var total := int(main.phase[key])
		out[key] = {
			"mean_ms": snappedf(float(total) / maxf(1, main.phase_steps) / 1000.0, 0.0001),
			"max_ms": snappedf(float(main.phase_max.get(key, 0)) / 1000.0, 0.0001),
		}
	return out

func _environment() -> Dictionary:
	var vi: Dictionary = Engine.get_version_info()
	var win := Vector2i.ZERO
	var vp := Vector2.ZERO
	var tex := Vector2i.ZERO
	if DisplayServer.get_name() != "headless":
		win = DisplayServer.window_get_size()
		vp = get_viewport().get_visible_rect().size
		tex = get_viewport().get_texture().get_size()
	var adapter := ""
	if RenderingServer.has_method("get_video_adapter_name"):
		adapter = str(RenderingServer.get_video_adapter_name())
	var driver := ""
	if RenderingServer.has_method("get_current_rendering_driver_name"):
		driver = str(RenderingServer.get_current_rendering_driver_name())
	var method := ""
	if RenderingServer.has_method("get_current_rendering_method"):
		method = str(RenderingServer.get_current_rendering_method())
	return {
		"godot": str(vi.get("string", "")),
		"os": OS.get_name() + " " + OS.get_version(),
		"cpu": OS.get_processor_name(),
		"cpu_count": OS.get_processor_count(),
		"adapter": adapter,
		"driver": driver,
		"rendering_method": method,
		"build": "debug" if OS.is_debug_build() else "release",
		"window": [win.x, win.y],
		"viewport": [int(vp.x), int(vp.y)],
		"texture": [tex.x, tex.y],
		"static_memory_mb": snappedf(float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0, 0.1),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
