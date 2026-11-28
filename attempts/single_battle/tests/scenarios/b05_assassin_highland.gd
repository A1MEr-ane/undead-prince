extends "res://attempts/single_battle/tests/behavior_scenario.gd"
## B05：刺客对高地弓兵。
## 通过条件：走崖壁捷径；先杀弓兵；不和盾兵纠缠。

var assassin
var archer
var shield
var archer_dead_at := -1.0
var shield_hp_at_kill := -1.0
var shield_damaged_before := false


func build() -> void:
	make_world({}, true)
	assassin = add("assassin", 0, vec(w.params.phase_b.cliff_entry), "coast")
	assassin.route = "cliff"
	assassin.stage = 0
	assassin.initial_route = "cliff"
	archer = add("archer", 1, cell(8, 23), "highland")
	shield = add("shield", 1, cell(11, 25), "highland")
	archer.anchor = archer.nav_pos
	archer.slot = archer.nav_pos
	shield.anchor = shield.nav_pos
	shield.slot = shield.nav_pos
	shield.hp = 10.0


func observe() -> void:
	if archer_dead_at < 0.0:
		if shield.hp < 9.99:
			shield_damaged_before = true
		if not archer.alive:
			archer_dead_at = w.time
			shield_hp_at_kill = shield.hp


func evaluate() -> void:
	check(w.phase_b.climb_transits >= 1, "刺客没有走崖壁捷径（climb_transits=%d）" % w.phase_b.climb_transits)
	check(archer_dead_at >= 0.0, "18 秒内没有杀掉高地弓兵")
	check(not shield_damaged_before, "刺客在杀弓兵前先打了盾兵（盾兵 HP %.1f）" % shield_hp_at_kill)
	var assassinations: Array = w.phase_b.assassinations.filter(func(e): return e.kind == "archer")
	check(not assassinations.is_empty(), "没有记录到刺客对弓兵的刺杀事件")
	if archer_dead_at >= 0.0:
		note("弓兵 %.2f 秒死亡；盾兵当时 HP %.1f；cliff_transits=%d" % [archer_dead_at, shield_hp_at_kill, w.phase_b.climb_transits])
	if assassin != null:
		note("刺客最终位置 (%.1f, %.1f)，objective=%s，detected=%s" % [assassin.nav_pos.x, assassin.nav_pos.z, assassin.objective, str(assassin.detected)])
