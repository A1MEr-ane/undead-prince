extends "res://proto/siege/tests/behavior_scenario.gd"
## B11：山洞权限。
## 通过条件：只有有权限的单位能走山洞；容量满时后来者排队，不穿模。

var cave_in := Vector3.ZERO
var cave_out := Vector3.ZERO


func build() -> void:
	make_world({}, true)
	cave_in = vec(w.params.map.cave_a)
	cave_out = vec(w.params.map.cave_b)
	var ghost = add("ghost", 0, cave_in, "coast")
	var assassin = add("assassin", 0, cave_in, "coast")
	var shield = add("shield", 1, cave_in, "coast")
	for permission in ["all", "undead", "assassin"]:
		w.params.phase_b.cave_permission = permission
		check(w.phase_b.can_cave(ghost) == (permission != "assassin"), "权限 %s 下普通亡魂的 can_cave 错误" % permission)
		check(w.phase_b.can_cave(assassin), "权限 %s 下刺客不能走山洞" % permission)
		check(w.phase_b.can_cave(shield) == (permission == "all"), "权限 %s 下盾兵的 can_cave 错误" % permission)
	# 权限为 assassin 时，普通亡魂实际也不能开始转移。
	w.params.phase_b.cave_permission = "assassin"
	var denied = add("ghost", 0, cave_in, "coast")
	denied.slot = cave_out
	var allowed = add("assassin", 0, cave_in, "coast")
	allowed.slot = cave_out
	check(not w.try_cave(denied), "权限 assassin 下普通亡魂仍能开始山洞转移")
	check(w.try_cave(allowed), "权限 assassin 下刺客不能开始山洞转移")
	# 容量 2：已有 1 人，再放 3 人，只能再进 1 人，其余排队。
	w.params.phase_b.cave_permission = "undead"
	var starters: Array = []
	for n in 3:
		var u = add("ghost", 0, cave_in, "coast")
		u.slot = cave_out
		starters.append(w.try_cave(u))
	var started: int = starters.filter(func(ok): return ok).size()
	check(started == 1, "山洞容量 2、已有 1 人时又放进 %d 人（应为 1）" % started)
	var active: int = w.units.filter(func(u): return u.alive and u.cave_until >= 0).size()
	check(active <= int(w.params.map.cave_capacity), "同时在山洞里的单位 %d 超过容量 %d" % [active, int(w.params.map.cave_capacity)])
	note("权限矩阵已检查；山洞容量 %d；同时在洞内 %d；本轮允许进入 %d/3" % [int(w.params.map.cave_capacity), active, started])
