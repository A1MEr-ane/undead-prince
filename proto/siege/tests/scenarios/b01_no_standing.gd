extends "res://proto/siege/tests/behavior_scenario.gd"
## B01：1 名亡魂对 1 名盾兵，开阔地。
## 通过条件：3 秒内接战；接战前不会连续 2 秒不动。

var ghost
var shield
var first_contact := -1.0
var last_pos := Vector3.ZERO
var still_since := 0.0
var still_origin := Vector3.ZERO
var max_still := 0.0
var max_still_displacement := 0.0
var standing_violation := false


func build() -> void:
	make_world()
	ghost = add("ghost", 0, cell(28, 35), "coast")
	shield = add("shield", 1, cell(31, 35), "coast")
	# 固定兵力，避免一刀结束后无法观察“接战后不站着”的窗口；行为参数不变。
	ghost.hp = 10.0
	shield.hp = 10.0
	shield.anchor = shield.nav_pos
	shield.slot = shield.nav_pos
	ghost.route = "main"
	ghost.initial_route = "main"
	ghost.stage = 0
	last_pos = ghost.nav_pos
	still_origin = ghost.nav_pos
	still_since = 0.0


func observe() -> void:
	if ghost == null or not ghost.alive:
		return
	if first_contact < 0.0:
		var moved := flat(ghost.nav_pos, last_pos)
		if moved > 0.01:
			still_since = w.time
			still_origin = ghost.nav_pos
		else:
			var still_time: float = w.time - still_since
			if still_time > max_still:
				max_still = still_time
				max_still_displacement = flat(ghost.nav_pos, still_origin)
			if still_time > 2.0:
				standing_violation = true
		last_pos = ghost.nav_pos
		var attacking: bool = ghost.brain.attack.active or ghost.anim_name == "attack"
		var close: bool = ghost.enemy_dist <= 0.9
		if attacking or close or w.events.get("pursue", 0) > 0 or w.events.get("clash", 0) > 0:
			first_contact = w.time


func evaluate() -> void:
	if first_contact < 0.0:
		check(false, "8 秒内没有接战：亡魂与盾兵始终没有进入攻击/追击状态")
	else:
		check(first_contact <= 3.0, "接战时间 %.2f 秒，超过 3 秒" % first_contact)
		note("首次接战 %.2f 秒" % first_contact)
	check(not standing_violation, "接战前连续站立超过 2 秒（最长 %.2f 秒，窗口内只移动 %.2f 米）" % [max_still, max_still_displacement])
	if ghost != null:
		check(ghost.enemy != null or ghost.brain.attack.active, "接战对象为空，亡魂没有锁定盾兵")
		note("亡魂位置 (%.1f, %.1f)，盾兵位置 (%.1f, %.1f)" % [ghost.nav_pos.x, ghost.nav_pos.z, shield.nav_pos.x, shield.nav_pos.z])
