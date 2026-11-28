extends "res://attempts/single_battle/tests/behavior_scenario.gd"
## B08：弓兵被近身。
## 通过条件：后撤或换近战，不能站着被砍。

var archer
var ghost
var start_pos := Vector3.ZERO
var max_displacement := 0.0
var responded := false
var response_at := -1.0
var last_pos := Vector3.ZERO
var still_since := 0.0
var max_still := 0.0
var standing_violation := false


func build() -> void:
	make_world()
	archer = add("archer", 1, cell(9, 24), "highland")
	ghost = add("ghost", 0, cell(9, 25), "highland")
	archer.hp = 10.0  # 让弓兵活到能展示近战反应，避免一刀结束后看不见行为。
	ghost.hp = 5.0
	archer.anchor = archer.nav_pos
	archer.slot = archer.nav_pos
	start_pos = archer.nav_pos
	last_pos = archer.nav_pos
	still_since = 0.0


func observe() -> void:
	if archer == null or not archer.alive:
		return
	max_displacement = maxf(max_displacement, flat(archer.nav_pos, start_pos))
	if not responded:
		var attacking: bool = archer.brain.attack.active or archer.anim_name == "attack"
		var moved := flat(archer.nav_pos, last_pos)
		if attacking or max_displacement > 0.5:
			responded = true
			response_at = w.time
		else:
			if moved > 0.02:
				still_since = w.time
			else:
				max_still = maxf(max_still, w.time - still_since)
				if w.time - still_since > 2.0:
					standing_violation = true
		last_pos = archer.nav_pos


func evaluate() -> void:
	check(responded, "弓兵被近身 2 秒后仍没有后撤或换近战（位移 %.2f）" % max_displacement)
	check(not standing_violation, "弓兵在近身前连续站立超过 2 秒（最长 %.2f 秒）" % max_still)
	check(ghost == null or not ghost.alive or ghost.hp < 5.0, "弓兵没有对贴身敌人造成任何伤害")
	if responded:
		note("弓兵 %.2f 秒响应；最大位移 %.2f 米；HP %.1f" % [response_at, max_displacement, archer.hp])
	else:
		note("弓兵最大位移 %.2f 米；HP %.1f" % [max_displacement, archer.hp])
