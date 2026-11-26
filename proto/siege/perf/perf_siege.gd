extends "res://proto/siege/perf/perf_world.gd"
## 测量用场景子类：simulate() 与父类逐行同序，只在外层加计时。
## 目的：在不修改 proto/siege/*.gd 的前提下，给出模拟内部各阶段的耗时。
## 行为一致性由 perf_runner 的 state_hash 与父类对照验证。

const PerfMap = preload("res://proto/siege/perf/perf_map.gd")
const PerfState = preload("res://scripts/agent_state.gd")

var phase := {}
var phase_max := {}
var phase_steps := 0

func _ready() -> void:
	terrain = PerfMap.new()
	super._ready()

func _add_phase(name: String, usec: int) -> void:
	phase[name] = int(phase.get(name, 0)) + usec
	phase_max[name] = maxi(int(phase_max.get(name, 0)), usec)

func simulate() -> void:
	step_number += 1
	time = step_number * float(params.simulation.step)
	PerfState.now = time
	PerfState.dt = float(params.simulation.step)
	if finished:
		return
	var dt := float(params.simulation.step)
	var t0 := Time.get_ticks_usec()
	if outcome == Outcome.ACTIVE:
		regenerate(dt)
		if manual_deploy_held and time >= next_manual_deploy:
			queue_input("deploy", manual_deploy_pos)
			next_manual_deploy = time + float(params.economy.deploy_interval)
		apply_inputs()
	elif presentation == Presentation.RETREAT:
		apply_inputs()
	var t1 := Time.get_ticks_usec()
	_add_phase("regenerate", t1 - t0)
	if outcome == Outcome.ACTIVE and bot != null:
		bot.tick()
	if finished:
		return
	var t2 := Time.get_ticks_usec()
	_add_phase("bot", t2 - t1)
	rebuild_spatial()
	refresh_rally_members()
	var t3 := Time.get_ticks_usec()
	_add_phase("spatial_build_1", t3 - t2)
	director.tick()
	var t4 := Time.get_ticks_usec()
	_add_phase("director", t4 - t3)
	update_gate()
	var t5 := Time.get_ticks_usec()
	_add_phase("gate", t5 - t4)
	var orders_us := 0
	var sense_us := 0
	for u in units:
		if not u.alive:
			continue
		var a := Time.get_ticks_usec()
		if u.faction == 0:
			ghost_order(u)
		else:
			director.unit_order(u)
			stage_defender_at_gate(u)
		var b := Time.get_ticks_usec()
		u.sense()
		var c := Time.get_ticks_usec()
		orders_us += b - a
		sense_us += c - b
	var t6 := Time.get_ticks_usec()
	_add_phase("orders_sense", t6 - t5)
	_add_phase("orders", orders_us)
	_add_phase("sense_nearby", sense_us)
	for u in units:
		u.previous_pos = u.nav_pos
		u.tick(dt)
		fine_spatial.moved(u)
		observe_route(u)
	var t7 := Time.get_ticks_usec()
	_add_phase("unit_tick_move_combat", t7 - t6)
	rebuild_spatial()
	var t8 := Time.get_ticks_usec()
	_add_phase("spatial_build_2", t8 - t7)
	if outcome == Outcome.ACTIVE:
		attack_structures(dt)
	var t9 := Time.get_ticks_usec()
	_add_phase("structures", t9 - t8)
	if outcome == Outcome.ACTIVE:
		update_captures(dt)
	var t10 := Time.get_ticks_usec()
	_add_phase("captures", t10 - t9)
	if outcome == Outcome.ACTIVE:
		resolve_outcome()
	if presentation == Presentation.RETREAT:
		update_retreat()
	var t11 := Time.get_ticks_usec()
	_add_phase("end_checks", t11 - t10)
	phase_steps += 1

func separation(u) -> Vector3:
	var t := Time.get_ticks_usec()
	var out := super.separation(u)
	_add_phase("separation", Time.get_ticks_usec() - t)
	return out

func adjacent_units(u, radius: float) -> Array:
	var t := Time.get_ticks_usec()
	var out := super.adjacent_units(u, radius)
	_add_phase("adjacent_query", Time.get_ticks_usec() - t)
	return out
