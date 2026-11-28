extends "res://attempts/single_battle/tests/behavior_scenario.gd"
## B10：攻占主堡。
## 通过条件：剩余守军放弃阵地、走最短路去港口登船；路上不反击。

var defenders: Array = []
var start_distance := {}
var end_distance := {}
var countered := false
var capture_triggered := false


func build() -> void:
	make_world()
	var ghost = add("ghost", 0, zone_center("keep"), "keep")
	ghost.hp = 50.0
	defenders.append(add("shield", 1, cell(30, 20), "plaza"))
	defenders.append(add("shield", 1, cell(9, 24), "highland"))
	for u in defenders:
		u.anchor = u.nav_pos
		u.slot = u.nav_pos
		start_distance[u.id] = flat(u.nav_pos, vec(w.params.map.port))
	w.zones.keep.progress = float(w.params.capture.seconds) - 0.01


func observe() -> void:
	if w.retreat_started:
		capture_triggered = true
	for u in defenders:
		if not u.alive:
			continue
		if u.brain.attack.active or u.dangerous:
			countered = true
		end_distance[u.id] = flat(u.nav_pos, vec(w.params.map.port))


func evaluate() -> void:
	check(capture_triggered, "主堡没有触发攻占/撤退")
	check(w.victory_method == "keep_retreat", "胜利方式不是 keep_retreat：%s" % w.victory_method)
	check(w.retreat_started, "没有进入撤退阶段")
	check(w.terrain.gate_open, "撤退开始后城门没有保持打开，西侧守军无法走到港口")
	check(not countered, "撤退中的守军仍在反击（dangerous/attack 为真）")
	for u in defenders:
		if not u.alive:
			continue
		check(u.retreating, "守军 %d 没有进入撤退状态" % u.id)
		check(end_distance.get(u.id, 9999.0) < start_distance.get(u.id, 0.0) - 2.0, "守军 %d 没有向港口推进：距离 %.1f -> %.1f" % [
			u.id, start_distance[u.id], end_distance.get(u.id, 9999.0)])
	check(w.escaped + w.intercepted + w.stranded <= defenders.size(), "撤退统计超过剩余守军数")
	note("胜利方式 %s，撤退开始 %.1f 秒；距离变化 %s" % [w.victory_method, w.retreat_at, JSON.stringify([start_distance, end_distance])])
	note("登船 %d，截杀 %d，滞留 %d" % [w.escaped, w.intercepted, w.stranded])
