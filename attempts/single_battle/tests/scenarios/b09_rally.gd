extends "res://attempts/single_battle/tests/behavior_scenario.gd"
## B09：集结指令。
## 通过条件：范围内单位 2 秒内转向；到达后（指令结束）恢复自主。

var ghosts: Array = []
var rally_point := Vector3.ZERO
var responded := {}
var response_times := {}
var resumed := {}
var resumed_count := 0


func build() -> void:
	make_world()
	sentinel()
	for n in 3:
		var u = add("ghost", 0, cell(29, 40 + n * 0.3), "coast")
		u.hp = 20.0
		ghosts.append(u)
	rally_point = cell(29, 36)
	var ok: bool = w.rally(rally_point)
	check(ok, "集结指令没有被接受（冥火 %.1f）" % w.fire)
	note("集结点 (%.1f, %.1f)，范围 %.0f" % [rally_point.x, rally_point.z, float(w.params.economy.rally_radius)])


func observe() -> void:
	if w.rally_until > w.time:
		for id in w.rally_members:
			if responded.has(id):
				continue
			var u = w.units[id]
			var toward := flat(u.nav_pos, rally_point) <= 1.5
			var objective: bool = u.objective == "rally"
			if toward or objective:
				responded[id] = true
				response_times[id] = w.time
	elif w.time > w.rally_until:
		for u in ghosts:
			if u.alive and u.objective != "rally" and not resumed.has(u.id):
				resumed[u.id] = true
				resumed_count += 1


func evaluate() -> void:
	check(not w.rally_events.is_empty(), "没有记录集结事件")
	check(responded.size() >= 3, "只有 %d/3 个单位在 2 秒内转向集结点" % responded.size())
	for id in response_times:
		check(float(response_times[id]) <= 2.0, "单位 %d 响应集结用了 %.2f 秒，超过 2 秒" % [id, float(response_times[id])])
	check(resumed_count > 0, "集结结束后没有单位恢复自主目标")
	note("响应单位 %d/3；响应时刻 %s；结束后自主单位 %d" % [responded.size(), JSON.stringify(response_times), resumed_count])
	note("集结事件：%s" % JSON.stringify(w.rally_events))
