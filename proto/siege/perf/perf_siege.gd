extends "res://proto/siege/siege.gd"
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
	regenerate(dt)
	var t1 := Time.get_ticks_usec()
	_add_phase("regenerate", t1 - t0)
	if bot != null:
		bot.tick()
	var t2 := Time.get_ticks_usec()
	_add_phase("bot", t2 - t1)
	rebuild_spatial()
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
		u.tick(dt)
	var t7 := Time.get_ticks_usec()
	_add_phase("unit_tick_move_combat", t7 - t6)
	rebuild_spatial()
	var t8 := Time.get_ticks_usec()
	_add_phase("spatial_build_2", t8 - t7)
	attack_structures(dt)
	var t9 := Time.get_ticks_usec()
	_add_phase("structures", t9 - t8)
	update_captures(dt)
	var t10 := Time.get_ticks_usec()
	_add_phase("captures", t10 - t9)
	if not won and sides[1].units.filter(func(u): return u.alive).is_empty():
		win("annihilation")
		finish()
	if retreat_started:
		update_retreat()
	if time >= float(params.simulation.night_seconds) and not finished:
		finish()
	var t11 := Time.get_ticks_usec()
	_add_phase("end_checks", t11 - t10)
	phase_steps += 1
