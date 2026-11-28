extends "res://proto/siege/tests/behavior_scenario.gd"
## B03：城门关闭、墙未破。
## 通过条件：没有单位穿墙；亡魂在门外等待/改去薄弱段，而不是直接出现在墙内。

var ghost
var gate_initial := 0.0
var wall_initial := 0.0
var penetration := false
var worst_z := 100.0


func build() -> void:
	make_world()
	sentinel()
	gate_initial = w.gate_hp
	wall_initial = w.weak_hp
	ghost = add("ghost", 0, cell(29, 35), "coast")
	ghost.hp = 30.0
	ghost.route = "main"
	ghost.initial_route = "main"
	ghost.stage = 0
	worst_z = ghost.nav_pos.z


func observe() -> void:
	for u in w.sides[0].units:
		if not u.alive:
			continue
		worst_z = minf(worst_z, u.nav_pos.z)
		# 墙在 z=28；城门/墙格关闭时，任何单位进入 z<28 都算穿墙。
		if u.nav_pos.z < 28.0 or w.terrain.in_rect(u.nav_pos, w.params.map.gate_rect) or w.terrain.in_rect(u.nav_pos, w.params.map.weak_rect):
			penetration = true


func evaluate() -> void:
	check(not penetration, "有单位穿过关闭的城门/未破的墙（最低 z=%.2f）" % worst_z)
	var attacked_gate: bool = w.gate_hp < gate_initial - 0.01
	var attacked_weak: bool = w.weak_hp < wall_initial - 0.01
	var waiting: bool = ghost != null and ghost.objective in ["gate", "weak"]
	check(attacked_gate or attacked_weak or waiting, "亡魂既没有攻击城门/薄弱段，也没有在门外等待（objective=%s）" % (ghost.objective if ghost != null else "?"))
	check(ghost != null and ghost.nav_pos.z >= 28.0, "亡魂最终位置越过了 z=28：%.2f" % (ghost.nav_pos.z if ghost != null else -1.0))
	note("门血 %.1f -> %.1f，薄弱墙 %.1f -> %.1f，最低 z=%.2f" % [gate_initial, w.gate_hp, wall_initial, w.weak_hp, worst_z])
