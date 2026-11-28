extends "res://attempts/single_battle/tests/behavior_scenario.gd"
## B07：威胁在阈值附近波动。
## 通过条件：已派出的守军不因威胁小幅波动被取消/改派；同一单位不会来回调动。

var ghosts: Array = []
var defenders: Array = []
var ordered_ids: Array = []
var assign_history := {}
var moved_away := false
var moved_back := false


func build() -> void:
	make_world()
	var setup := [
		{"zone": "highland", "count": 5, "anchor": [9, 27], "kind": "shield"},
		{"zone": "plaza", "count": 6, "anchor": [30, 23], "kind": "shield"},
		{"zone": "keep", "count": 7, "anchor": [32, 11], "kind": "shield"},
	]
	for group in setup:
		for n in int(group.count):
			var u = add(group.kind, 1, vec(group.anchor) + w.formation_offset(n), group.zone)
			defenders.append(u)
			assign_history[u.id] = [u.assigned]
	for n in 2:
		var g = add("ghost", 0, cell(9, 24 + n), "highland")
		g.hp = 1000.0
		g.brain.damage = 0.0  # 只制造威胁，不杀守军，隔离调度行为。
		ghosts.append(g)


func observe() -> void:
	for u in defenders:
		if not u.alive:
			continue
		var history: Array = assign_history[u.id]
		if history[-1] != u.assigned:
			history.append(u.assigned)
	if not moved_away and w.time >= 2.2:
		moved_away = true
		for n in ghosts.size():
			var g = ghosts[n]
			g.nav_pos = cell(28, 40 + n)
			g.previous_pos = g.nav_pos
			g.cell = w.terrain.tile(g.nav_pos)
			g.enemy = null
		w.rebuild_spatial()
	if not moved_back and w.time >= 4.2:
		moved_back = true
		for n in ghosts.size():
			var g = ghosts[n]
			g.nav_pos = cell(9, 24 + n)
			g.previous_pos = g.nav_pos
			g.cell = w.terrain.tile(g.nav_pos)
			g.enemy = null
		w.rebuild_spatial()


func evaluate() -> void:
	for decision in w.director.decisions:
		if decision.get("event", "") == "ordered":
			ordered_ids.append_array(decision.units)
	check(not ordered_ids.is_empty(), "威胁出现后没有派兵")
	var cancelled: int = w.director.decisions.filter(func(d): return d.get("event", "") == "cancelled").size()
	check(cancelled == 0, "威胁回落后取消了 %d 个已下达的派兵任务" % cancelled)
	var reordered := 0
	for id in ordered_ids:
		var history: Array = assign_history.get(id, [])
		if history.size() > 2:
			reordered += 1
		if history.size() >= 3 and history[0] == history[-1]:
			reordered += 1
	check(reordered == 0, "%d 个已派出的单位在任务锁定窗口内来回改派" % reordered)
	check(moved_away and moved_back, "场景没有完成威胁搬离/搬回")
	var per_unit := {}
	for id in ordered_ids:
		per_unit[id] = per_unit.get(id, 0) + 1
	var duplicated: int = per_unit.values().filter(func(n): return n > 1).size()
	check(duplicated == 0, "%d 个单位被重复下达派兵命令" % duplicated)
	note("派兵 %d 人；取消 %d；改派 %d；单位调动历史 %s" % [ordered_ids.size(), cancelled, reordered, JSON.stringify(assign_history)])
