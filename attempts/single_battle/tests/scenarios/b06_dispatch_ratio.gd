extends "res://attempts/single_battle/tests/behavior_scenario.gd"
## B06：小股亡灵佯攻战区 A。
## 通过条件：派出的兵力和威胁成比例；战区 B 保留最低驻防。

var small := {}
var large := {}


func build() -> void:
	small = run_case(2)
	large = run_case(8)
	# run_headless 仍需要一个可释放的世界；实际断言已在上面的两次短运行里完成。
	w = large.world
	w.time = max_time


func run_case(count: int) -> Dictionary:
	make_world({"director": {"global_perception": true}}, false, true)
	var start: Vector3 = vec(w.params.strategies.deploy_points.main)
	for n in count:
		var u = add("ghost", 0, start + w.formation_offset(n), "coast")
		u.hp = 30.0
	var steps := int(ceil(2.5 / float(w.params.simulation.step)))
	for n in steps:
		w.simulate()
	var ordered := 0
	var ordered_ids: Array = []
	for decision in w.director.decisions:
		if decision.get("event", "") == "ordered":
			ordered += decision.units.size()
			ordered_ids.append_array(decision.units)
	var retained_ok := true
	var retained := {}
	for zone in w.params.map.zones:
		var count_here := 0
		for u in w.sides[1].units:
			if u.alive and u.assigned == zone.id and u.dispatch_at < 0 and not u.marching and w.terrain.zone_at(u.nav_pos) == zone.id:
				count_here += 1
		retained[zone.id] = count_here
		if count_here < int(zone.min_garrison):
			retained_ok = false
	var result := {
		"world": w,
		"ordered": ordered,
		"ids": ordered_ids,
		"threat": float(w.director.threats.get("coast", 0.0)),
		"retained": retained,
		"retained_ok": retained_ok,
		"defenders": w.sides[1].units.filter(func(u): return u.alive).size(),
	}
	w = null
	return result


func evaluate() -> void:
	check(not small.is_empty() and not large.is_empty(), "两组装载失败")
	if small.is_empty() or large.is_empty():
		return
	check(int(large.ordered) > int(small.ordered), "派兵数量没有随威胁增大：2 名亡魂派 %d 人（威胁 %.1f），8 名亡魂派 %d 人（威胁 %.1f）" % [
		int(small.ordered), float(small.threat), int(large.ordered), float(large.threat)])
	check(bool(small.retained_ok), "2 名亡魂组有战区低于最低驻防：%s" % JSON.stringify(small.retained))
	check(bool(large.retained_ok), "8 名亡魂组有战区低于最低驻防：%s" % JSON.stringify(large.retained))
	check(int(large.ordered) < int(large.defenders), "整个守军都被引走：派 %d / 守军 %d" % [int(large.ordered), int(large.defenders)])
	note("2 名亡魂：威胁 %.1f，派兵 %d；8 名亡魂：威胁 %.1f，派兵 %d" % [float(small.threat), int(small.ordered), float(large.threat), int(large.ordered)])
	note("最低驻防：2 名组 %s；8 名组 %s" % [JSON.stringify(small.retained), JSON.stringify(large.retained)])
	if small.has("world") and small.world != null:
		small.world._exit_tree()
		small.world.free()
		small.world = null
