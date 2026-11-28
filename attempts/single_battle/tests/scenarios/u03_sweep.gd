extends "res://attempts/single_battle/tests/behavior_scenario.gd"

var giant
var outside
var edge_a
var edge_b

func build() -> void:
	make_world({"units": {"giant": {"sweep_damage": 0.4}}})
	sentinel()
	var siege_giant = add("giant", 0, cell(26, 29), "coast")
	var skeleton = add("ghost", 0, cell(28, 29), "coast")
	siege_giant.objective = "wall_west"
	skeleton.objective = "gate"
	var wall_before: float = w.phase_b.walls.wall_west.hp
	var gate_before: float = w.gate_hp
	w.phase_b.attack_structures(0.1)
	var normal: float = gate_before - w.gate_hp
	var heavy: float = wall_before - w.phase_b.walls.wall_west.hp
	check(normal > 0 and is_equal_approx(heavy, normal * 5.0), "巨人每步攻城伤害应恰为骷髅的五倍")
	note("同期攻城伤害 %.2f / %.2f" % [heavy, normal])

	giant = add("giant", 0, Vector3(29.5, 0, 44.6), "coast")
	giant.speed = 0.0
	giant.hp = 100.0
	edge_a = guard(Vector3(29.05, 0, 45.29))
	edge_b = guard(Vector3(29.91, 0, 45.33))
	outside = guard(Vector3(29.50, 0, 43.38))

func guard(pos: Vector3):
	var unit = add("shield", 1, pos, "coast")
	unit.hp = 10.0
	unit.speed = 0.0
	return unit

func evaluate() -> void:
	check(w.events.get("swept_off_edge", 0) >= 1 and (not edge_a.alive or not edge_b.alive), "横扫没有把高血量的岸边守军击落")
	check(float(w.phase_b.stats("giant").sweeps) == 1.0, "三名敌人应触发一次横扫")
	check(outside.alive and is_equal_approx(outside.hp, 10.0), "扇形外的守军被横扫命中")
	note("横扫 %d 次；坠落 %d 人" % [w.phase_b.stats("giant").sweeps, w.events.get("swept_off_edge", 0)])
