extends "res://attempts/single_battle/tests/behavior_scenario.gd"

var runner
var distant
var defender
var spent: float
var checked_weakness := false

func build() -> void:
	make_world()
	sentinel()
	runner = add("ghost", 0, cell(29, 41), "coast")
	distant = add("ghost", 0, cell(41, 41), "coast")
	defender = add("shield", 1, cell(31, 41), "coast")
	defender.speed = 0.0
	defender.hp = 100.0
	runner.hp = 100.0
	distant.hp = 100.0
	w.fire = float(w.params.economy.capacity)
	w.selected_kind = "lich"
	w.queue_input("deploy", cell(6, 43))
	w.selected_kind = "ghost"
	w.queue_input("spell", cell(29, 41))
	step_once()
	check(w.input_events[0].kind == "lich" and w.input_events[0].accepted, "队列须保留入队时所选兵种")
	check(w.spell_uses == 1 and w.fire_spent == w.params.units.lich.cost + w.params.spell.frenzy.cost, "狂化和部署应各扣费一次")
	check(runner.move_scale() > 1.0 and runner.attack_scale() > 1.0 and distant.move_scale() == 1.0, "狂化必须只提升范围内友军攻速与移速")
	check(defender.weakness_until < 0.0, "运行时只能使用配置中的法术")

	# 在独立的第二局运行虚弱，避免在同一局运行时切换法术。
	w._exit_tree()
	w.free()
	make_world({"spell": {"active": "weakness"}})
	sentinel()
	runner = add("ghost", 0, cell(40, 41), "coast")
	runner.hp = 100.0
	defender = add("shield", 1, cell(29, 41), "coast")
	defender.speed = 0.0
	defender.hp = 100.0
	var point: Vector3 = defender.nav_pos
	check(w.cast_spell(point) and w.cast_spell(point), "两次合法的虚弱应成功")
	spent = w.fire_spent
	check(not w.cast_spell(point) and w.fire_spent == spent, "第三次法术必须拒绝且不扣费")
	check(runner.move_scale() == 1.0 and defender.weakness_until > w.time, "虚弱只能作用于范围内守军")
	test_damage(true)

func step_once() -> void:
	w.simulate()

func test_damage(weakened: bool) -> void:
	var before: float = runner.hp
	runner.deal_damage({"damage": 2.0, "knockback": 0.0, "stun": 0.0, "dir": Vector3.ZERO, "source": defender})
	var scale := float(w.params.spell.weakness.damage_scale) if weakened else 1.0
	check(is_equal_approx(before - runner.hp, 2.0 * scale), "虚弱期间和过期后的守军伤害不符")

func observe() -> void:
	if not checked_weakness and w.time >= float(w.params.spell.weakness.seconds):
		checked_weakness = true
		test_damage(false)

func evaluate() -> void:
	check(checked_weakness, "虚弱过期后应恢复伤害")
