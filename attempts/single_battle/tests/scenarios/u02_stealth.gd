extends "res://attempts/single_battle/tests/behavior_scenario.gd"

var assassin
var archer
var guard
var killed_at := -1.0
var hidden_at := -1.0

func build() -> void:
	make_world()
	sentinel()
	assassin = add("assassin", 0, cell(29, 41), "coast")
	archer = add("archer", 1, cell(29, 39), "coast")
	archer.hp = 100.0
	guard = add("shield", 1, cell(33, 41), "coast")
	guard.speed = 0.0
	guard.hp = 35.0
	w.rebuild_spatial()
	check(w.nearest_enemy(archer) == null and not w.director.perceived(assassin), "可见范围内的潜行刺客不能被守军锁定或纳入威胁")
	w.director.tick()
	check(is_zero_approx(w.director.threats.coast), "潜行刺客增加了战区威胁")

func observe() -> void:
	if killed_at < 0.0 and not archer.alive:
		killed_at = w.time
		check(assassin.detected and w.events.get("backstab", 0) == 1, "首击应背刺并暴露")
		# 保持脱战观察窗口，避免刺客沿主路与其他守军交手。
		assassin.speed = 0.0
		guard.nav_pos = cell(40, 42)
		guard.anchor = guard.nav_pos
	elif killed_at >= 0.0 and hidden_at < 0.0 and not assassin.detected:
		hidden_at = w.time
		check(not w.director.perceived(assassin), "重新潜行后守军仍能感知")

func early_done() -> bool:
	return hidden_at >= 0.0

func evaluate() -> void:
	check(killed_at > 0.0 and not archer.alive, "潜行首击没有秒杀 100 HP 弓兵")
	check(hidden_at - killed_at >= 3.0 and hidden_at - killed_at < 3.14, "未在脱战三秒后恢复潜行")
	note("背刺 %.2f 秒；重入潜行 %.2f 秒" % [killed_at, hidden_at])
