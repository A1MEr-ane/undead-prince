extends "res://attempts/single_battle/tests/behavior_scenario.gd"

var lich
var horse
var guard
var first_bolt := -1.0
var second_bolt := -1.0
var impact_at := -1.0
var moved_back := false

func build() -> void:
	make_world()
	sentinel()
	lich = add("lich", 0, cell(29, 39), "coast")
	horse = add("cavalry", 1, Vector3(29.5, 0, 35.9), "coast")
	horse.anchor = cell(29, 38)
	horse.speed = 0.0
	horse.hp = 10.0
	guard = add("shield", 1, cell(30, 35), "coast")
	guard.speed = 0.0
	guard.hp = 10.0
	check(not w.phase_b.can_cave(horse), "骑兵不可进入山洞")

func observe() -> void:
	if first_bolt < 0.0 and w.events.get("lich_bolt", 0) > 0:
		first_bolt = w.time
	if second_bolt < 0.0 and w.events.get("lich_bolt", 0) > 1:
		second_bolt = w.time
	if impact_at < 0.0 and horse.spell_stun_until > 0:
		impact_at = w.time
		check(is_equal_approx(horse.stun_until - w.time, 1.0), "巫妖的弹应眩晕一秒")
		check(is_equal_approx(guard.spell_stun_until, horse.spell_stun_until), "相邻的盾兵未进入弹的眩晕范围")
		check(horse.charge_target == null and w.events.get("cavalry_charge_interrupted", 0) > 0, "冲锋未被眩晕打断")
	moved_back = moved_back or lich.nav_pos.z > 39.72

func evaluate() -> void:
	check(impact_at > first_bolt, "弹需要飞行后命中")
	check(moved_back, "敌人贴近时巫妖未后退")
	check(second_bolt - first_bolt >= 3.0 - 0.000001 and second_bolt - first_bolt <= 3.04, "两发弹之间应约三秒")
	note("第一发 %.2f 秒；首次命中 %.2f 秒；第二发 %.2f 秒" % [first_bolt, impact_at, second_bolt])
