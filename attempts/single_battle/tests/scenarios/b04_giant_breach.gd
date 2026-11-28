extends "res://attempts/single_battle/tests/behavior_scenario.gd"
## B04：巨人走向最近的可破墙段，持续攻击到破口，破口后继续向战区推进。
## 使用 phase_b 的 wall_west（26,28）作为可破墙。

var giant
var breach_time := -1.0
var damage_started := false
var crossed := false


func build() -> void:
	make_world({}, true)
	sentinel()
	giant = add("giant", 0, cell(26, 34), "coast")
	giant.route = "breach:wall_west"
	giant.stage = 0
	giant.objective = ""
	giant.hp = 200.0
	note("巨人出生点 (%.1f, %.1f)，目标墙 (26,28)" % [giant.nav_pos.x, giant.nav_pos.z])


func observe() -> void:
	if giant == null or not giant.alive:
		return
	if not damage_started and w.structure_work.wall_west.started_at >= 0.0:
		damage_started = true
	if w.phase_b.walls.wall_west.broken and breach_time < 0.0:
		breach_time = w.time
	if breach_time >= 0.0 and giant.nav_pos.z < 28.0:
		crossed = true


func evaluate() -> void:
	var wall: Dictionary = w.phase_b.walls.wall_west
	check(damage_started, "巨人没有走到墙下开始攻击（structure_work.started_at=%.1f）" % w.structure_work.wall_west.started_at)
	check(wall.broken, "18 秒内墙没有破（HP %.1f/%.1f）" % [wall.hp, wall.max_hp])
	check(breach_time >= 0.0, "破口时间没有记录")
	check(w.terrain.is_walkable_at(vec([26, 28])), "破口后墙格仍不可通行")
	check(w.terrain.distance(giant.nav_pos, zone_center("keep"), false) < float(w.params.map.flow_infinity), "破口后到主堡的流场没有重算为可达")
	check(crossed, "破口后巨人没有穿过墙格继续向战区推进（z=%.2f）" % giant.nav_pos.z)
	check(w.structure_work.wall_west.active_seconds > 0.0 and w.structure_work.wall_west.attacker_seconds > 0.0, "攻击耗时/攻击者秒数没有累计")
	note("破口时刻 %.2f 秒；攻击持续 %.2f 秒；巨人最终 z=%.2f，objective=%s" % [breach_time, w.structure_work.wall_west.active_seconds, giant.nav_pos.z, giant.objective])
