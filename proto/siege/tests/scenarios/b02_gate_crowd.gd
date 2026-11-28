extends "res://proto/siege/tests/behavior_scenario.gd"
## B02：10 名亡魂挤过城门。
## 通过条件：没有永久卡死；有另一条可达路线时，一部分单位改道。

var ghosts: Array = []
var last_pos := {}
var still_for := {}
var stuck := {}


func build() -> void:
	make_world()
	sentinel()
	# 城门打开、薄弱墙已破，主路和侧路都可达，才能观察“有其他路线时改道”。
	w.terrain.gate_open = true
	w.terrain.change(w.params.map.gate_rect, true, 0.0, "b02_open_gate")
	w.terrain.weak_broken = true
	w.terrain.change(w.params.map.weak_rect, true, 0.0, "b02_open_weak")
	var start: Vector3 = vec(w.params.strategies.deploy_points.main)
	for n in 10:
		var u = add("ghost", 0, start + w.formation_offset(n), "coast")
		u.route = "main"
		u.initial_route = "main"
		u.stage = 0
		u.hp = 20.0
		ghosts.append(u)
		last_pos[u.id] = u.nav_pos
		still_for[u.id] = 0.0
		stuck[u.id] = false


func observe() -> void:
	for u in ghosts:
		if not u.alive:
			continue
		var moved := flat(u.nav_pos, last_pos[u.id])
		var engaged: bool = u.enemy != null and u.enemy_dist <= float(w.params.combat.chase_radius)
		var intent: bool = u.order_dist > float(w.params.map.path_arrival_radius) and not engaged
		if moved > 0.03:
			still_for[u.id] = 0.0
		elif intent:
			still_for[u.id] += float(w.params.simulation.step)
			if still_for[u.id] > 5.0:
				stuck[u.id] = true
		last_pos[u.id] = u.nav_pos


func evaluate() -> void:
	var passed := 0
	var rerouted := 0
	for u in ghosts:
		if u.nav_pos.z < 28.0:
			passed += 1
		if u.route != "main":
			rerouted += 1
	var stuck_count := 0
	for id in stuck:
		if stuck[id]:
			stuck_count += 1
	check(stuck_count == 0, "%d 个单位在同一个路口连续 5 秒想走却走不动" % stuck_count)
	check(passed >= 5, "14 秒内只有 %d/10 个单位通过城门（z<28），队伍没有真正挤过去" % passed)
	check(rerouted > 0 or w.reroutes > 0, "侧路可达、队伍也出现拥堵/排队，但没有单位改道（main 仍为 %d/10，w.reroutes=%d，行军拥堵 %d）" % [10 - rerouted, w.reroutes, w.travel_congestion])
	note("通过城门 %d/10，改道 %d，路口拥堵计数 %d，行军拥堵计数 %d" % [passed, rerouted, w.congestion, w.travel_congestion])
	note("路线分布：main %d，side %d，cave %d" % [
		ghosts.filter(func(u): return u.route == "main").size(),
		ghosts.filter(func(u): return u.route == "side").size(),
		ghosts.filter(func(u): return u.route == "cave").size()])
