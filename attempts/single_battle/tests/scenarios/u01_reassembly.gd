extends "res://attempts/single_battle/tests/behavior_scenario.gd"

var safe
var threatened
var first_rise := -1.0
var wait: float

func build() -> void:
	make_world()
	sentinel()
	wait = float(w.params.units.ghost.reassemble_seconds)
	safe = add("ghost", 0, cell(8, 43), "coast")
	threatened = add("ghost", 0, cell(41, 43), "coast")
	var guard = add("shield", 1, cell(42, 43), "coast")
	guard.speed = 0.0
	guard.hp = 30.0
	kill(safe)
	kill(threatened)
	check(safe.bones_until == wait and threatened.bones_until == wait, "首次倒下应各留下骨堆")

func kill(unit) -> void:
	unit.deal_damage({"damage": 99.0, "dir": Vector3.ZERO, "knockback": 0.0, "stun": 0.0})

func observe() -> void:
	if first_rise < 0 and safe.alive:
		first_rise = w.time
		check(safe.reassembled and not threatened.alive and threatened.bones_until < 0, "安全骨堆和有守军的骨堆应有不同结果")
		kill(safe)
		check(safe.bones_until < 0, "第二次倒下仍生成可重组骨堆")

func evaluate() -> void:
	check(is_equal_approx(first_rise, 4.0), "安全骨堆没有在第四秒原位重组")
	check(not safe.alive and not threatened.alive and w.events.get("reassembled", 0) == 1, "等待到第十秒时重组次数应为一")
	note("首次重组 %.2f 秒；重组事件 %d" % [first_rise, w.events.get("reassembled", 0)])
