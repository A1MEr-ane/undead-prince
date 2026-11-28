extends "res://attempts/single_battle/tests/behavior_scenario.gd"
## B02：10 名亡魂挤过城门。
## 通过条件：没有永久卡死；有另一条可达路线时，一部分单位改道。

var ghosts: Array = []
var last_pos := {}
var still_for := {}
var held_queue := {}
var blocker
var release_at := 11.0


func build() -> void:
	make_world({"structures": {"gate_auto_open": false}})
	sentinel()
	# 城门打开、薄弱墙已破，主路和侧路都可达，才能观察“有其他路线时改道”。
	w.terrain.gate_open = true
	w.terrain.change(w.params.map.gate_rect, true, 0.0, "b02_open_gate")
	w.terrain.weak_broken = true
	w.terrain.change(w.params.map.weak_rect, true, 0.0, "b02_open_weak")
	# 留一格通道，在入口安排一个暂时待命的己方单位，制造真实排队。
	w.terrain.change([26, 30, 3, 1], false, 0.0, "b02_narrow_west")
	w.terrain.change([30, 30, 3, 1], false, 0.0, "b02_narrow_east")
	blocker = add("ghost", 0, cell(29, 30), "coast")
	blocker.speed = 0.0
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



func observe() -> void:
	if w.time < release_at:
		blocker.nav_pos = cell(29, 30)
		blocker.nav_pos.y = w.terrain.height_at(blocker.nav_pos)
	elif blocker.alive:
		blocker.alive = false
	if w.step_number % 30 == 0 and w.time < release_at:
		for u in ghosts:
			if u.movement_since >= 0.0 and w.time - u.movement_since >= 3.0:
				note("t %.0f id %d stage %d pos %s blocked %.2f queue %s alternate %s dir %s" % [w.time, u.id, u.stage, u.nav_pos, w.time - u.movement_since, u.queued_behind, w.choose_route(u, true), u.order_dir])
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
				held_queue[u.id] = true
		last_pos[u.id] = u.nav_pos


func evaluate() -> void:
	var passed := 0
	var rerouted := 0
	for u in ghosts:
		if u.nav_pos.z < 28.0:
			passed += 1
		if u.route != "main":
			rerouted += 1
	check(not held_queue.is_empty() or w.travel_congestion > 0, "夹具没有建立持续拥堵")
	check(ghosts.all(func(u): return still_for[u.id] < 5.0), "堵点解除后，仍有单位连续 5 秒想走却走不动")
	check(passed >= 5, "只有 %d/10 个单位通过城门（z<28）" % passed)
	check(rerouted > 0, "侧路可达且入口持续拥堵时，没有单位改道")
	note("通过城门 %d/10，改道 %d，路口拥堵计数 %d，行军拥堵计数 %d" % [passed, rerouted, w.congestion, w.travel_congestion])
	note("路线分布：main %d，side %d，cave %d" % [
		ghosts.filter(func(u): return u.route == "main").size(),
		ghosts.filter(func(u): return u.route == "side").size(),
		ghosts.filter(func(u): return u.route == "cave").size()])
