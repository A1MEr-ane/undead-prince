extends "res://attempts/single_battle/tests/behavior_scenario.gd"
## B12：拼刀和格挡，按 docs/badnorth-behavior-spec.md 第 7 节。
## 重点：拼刀进度差必须取绝对值；招架只在正面生效；无招架时正面伤害不减。

var valid := {}
var reverse := {}
var invalid := {}
var parried := {}
var shield_hit := {}


func build() -> void:
	valid = duel(0.06, 0.18, true, false)
	reverse = duel(0.18, 0.06, true, false)
	invalid = duel(0.06, 0.54, true, false)
	parried = duel(0.06, 0.18, false, true)
	shield_hit = duel(0.06, 0.18, false, false)
	# 断言已在上面五次短场景中完成；留一个空世界供 run_headless 收尾。
	make_world()
	w.time = max_time


func duel(attacker_time: float, defender_time: float, both_attacking: bool, parry: bool) -> Dictionary:
	make_world()
	var attacker = add("ghost", 0, cell(28, 35), "coast")
	var defender = add("shield", 1, cell(29, 35), "coast")
	attacker.hp = 10.0
	defender.hp = 10.0
	attacker.play("attack")
	if parry:
		defender.play("parry")
	else:
		defender.play("attack")
	if both_attacking:
		attacker.brain.attack.set_true()
		defender.brain.attack.set_true()
		attacker.brain.target = defender
		defender.brain.target = attacker
	attacker.anim_t = attacker_time
	defender.anim_t = defender_time
	defender.facing = (attacker.nav_pos - defender.nav_pos).normalized()
	if parry:
		defender.brain.parry.set_true()
	var direction: Vector3 = (defender.nav_pos - attacker.nav_pos).normalized()
	var diff_before: float = absf(attacker.anim_norm() - defender.anim_norm())
	var atk := {"damage": 1.0, "knockback": 0.0, "stun": 0.0, "dir": direction, "attacker": attacker.brain, "source": attacker}
	defender.brain.modify_attack(atk)
	var result := {
		"damage": float(atk.damage),
		"clash": bool(atk.get("clash", false)),
		"parried": bool(atk.get("parried", false)),
		"shield_fx": bool(atk.get("shield_fx", false)),
		"defender_clash": defender.brain.clash.active,
		"attacker_clash": attacker.brain.clash.active,
		"events": w.events.duplicate(),
		"attacker_hp": attacker.hp,
		"defender_hp": defender.hp,
		"diff": diff_before,
	}
	w._exit_tree()
	w.free()
	w = null
	return result


func check_clash(case: Dictionary, name: String, expected: bool) -> void:
	var actual: bool = bool(case.get("clash", false))
	check(actual == expected, "%s：拼刀判定为 %s，应为 %s（进度差 %.2f）" % [name, str(actual), str(expected), float(case.get("diff", -1.0))])
	if expected:
		check(float(case.damage) == 0.0, "%s：拼刀伤害没有归零（%.2f）" % [name, float(case.damage)])
		check(bool(case.defender_clash) and bool(case.attacker_clash), "%s：拼刀没有同时进入双方 Clash 状态" % name)


func evaluate() -> void:
	check_clash(valid, "有效拼刀（进度差 0.2）", true)
	check_clash(reverse, "反向有效拼刀（进度差 0.2）", true)
	check_clash(invalid, "无效拼刀（进度差 0.8）", false)
	check(bool(parried.parried), "正面招架没有把伤害归零")
	check(float(parried.damage) == 0.0, "招架判定后伤害仍为 %.2f" % float(parried.damage))
	check(float(shield_hit.damage) == 1.0, "没有招架时正面伤害被错误减免：%.2f" % float(shield_hit.damage))
	check(bool(shield_hit.shield_fx), "没有招架时没有记录盾牌特效")
	check(valid.events.get("clash", 0) >= 1, "有效拼刀没有产生 clash 事件")
	check(parried.events.get("parry", 0) >= 1, "招架没有产生 parry 事件")
	note("有效拼刀 %s；反向 %s；无效拼刀 %s（这是待修 bug）" % [JSON.stringify(valid), JSON.stringify(reverse), JSON.stringify(invalid)])
	note("招架 %s；无招架正面 %s" % [JSON.stringify(parried), JSON.stringify(shield_hit)])
