extends SceneTree
const World = preload("res://proto/siege/siege.gd")
const Map = preload("res://proto/siege/siege_map.gd")
const View = preload("res://proto/siege/siege_view.gd")
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("T74 FAIL: " + message)

func fresh(phase_b: bool = true):
	var w = World.new()
	w.params = JSON.parse_string(FileAccess.get_file_as_string(w.DEFAULT_PARAMS))
	w.merge_params(w.params, JSON.parse_string(FileAccess.get_file_as_string("res://proto/siege/params/phase_b.json" if phase_b else "res://proto/siege/params/analysis_v2.json")))
	w.sim_rng.seed = 7
	w.terrain.setup(w.params)
	w.phase_b.setup(w)
	w.gate_hp = w.params.structures.gate_hp
	w.weak_hp = w.params.structures.weak_hp
	w.fire = w.params.economy.initial
	for z in w.params.map.zones:
		w.zones[z.id] = {"owner": "defender", "progress": 0.0, "retake": 0.0, "captures": [], "losses": [], "contested_resets": []}
	w.director.setup(w)
	return w

func dispose(w) -> void:
	w._exit_tree()
	w.free()

func test_gates() -> void:
	var w = fresh(false)
	check(not w.phase_b.enabled and not w.phase_b.available("assassin"), "analysis 模式不能开放新兵种")
	check(not w.deploy(w.terrain.vec(w.params.strategies.deploy_points.main), "giant"), "关闭时不能部署巨人")
	dispose(w)
	w = fresh()
	var p: Vector3 = w.terrain.vec(w.params.strategies.deploy_points.main)
	var before: float = w.fire
	check(w.deploy(p, "assassin", "cliff"), "开启后可从合法海岸部署刺客")
	check(w.fire == before - w.params.units.assassin.cost, "刺客独立费用")
	check(not w.deploy(w.zone_point("keep"), "giant"), "新兵种不绕过部署权限")
	w.params.phase_b.giant = false
	check(not w.deploy(p, "giant"), "兵种子开关有效")
	dispose(w)

func test_targeting() -> void:
	var w = fresh(false)
	var u = w.spawn("ghost", 0, w.terrain.vec([29, 23]), "coast")
	var shield = w.spawn("shield", 1, u.nav_pos + Vector3(0.6, 0, 0), "plaza")
	var archer = w.spawn("archer", 1, u.nav_pos + Vector3(2.3, 0, 0), "plaza")
	w.rebuild_spatial()
	u.focus_archers = false
	check(w.nearest_enemy(u) == shield, "关闭偏好时优先最近敌人")
	u.focus_archers = true
	check(w.nearest_enemy(u) == archer, "开启偏好时实际索敌优先弓兵")
	u.nav_pos = w.terrain.vec(w.params.strategies.deploy_points.main)
	var route: String = w.choose_route(u, false)
	w.params.targeting.values.archer = 100
	check(w.choose_route(u, false) == route, "弓兵价值不能再改变路线选择")
	dispose(w)

func test_assassin() -> void:
	var w = fresh()
	var a = w.spawn("assassin", 0, w.terrain.vec(w.params.phase_b.cliff_entry), "coast")
	a.route = "cliff"
	var guard = w.spawn("shield", 1, a.nav_pos + Vector3(2, 0, 0), "coast")
	w.rebuild_spatial()
	check(not w.director.perceived(a) and w.nearest_enemy(guard) == null, "未发现刺客不计入调度或索敌")
	w.params.director.global_perception = true
	check(not w.director.perceived(a), "全图感知仍不能看穿未发现刺客")
	w.phase_b.special_order(a)
	check(a.cave_until > 0 and a.transit_kind == "cliff", "刺客能使用指定崖壁")
	w.time = a.cave_until
	a.tick(w.params.simulation.step)
	check(w.terrain.tile(a.nav_pos) == Vector2i(12, 21), "崖壁转移到指定出口")
	var ordinary = w.spawn("ghost", 0, w.terrain.vec(w.params.phase_b.cliff_entry), "coast")
	check(not w.valid_route(ordinary, "cliff"), "普通亡魂不能选崖壁")
	guard.nav_pos = a.nav_pos + Vector3(0.5, 0, 0)
	w.rebuild_spatial()
	w.phase_b.update_detection()
	check(a.detected and w.director.perceived(a), "近距无遮挡发现后正常计入威胁")
	var archer = w.spawn("archer", 1, a.nav_pos + Vector3(0.7, 0, 0), "highland")
	w.phase_b.hit(a, archer, 4)
	check(not archer.alive and w.phase_b.assassinations.size() == 1, "刺客近战能秒杀弓兵并记录时间")
	dispose(w)

func test_walls_and_sweep() -> void:
	var w = fresh()
	var giant = w.spawn("giant", 0, w.terrain.vec([26, 29]), "coast")
	giant.objective = "wall_west"
	var target: Vector3 = w.zone_point("keep")
	w.terrain.field(target, false)
	w.phase_b.attack_structures(5)
	check(w.phase_b.walls.wall_west.broken and w.terrain.is_walkable_at(w.terrain.vec([26, 28])), "巨人破墙应开放通行")
	check(w.structure_work.wall_west.breached_at == w.time, "破墙时间有记录")
	var reference = Map.new()
	reference.setup(w.params)
	reference.change([26, 28, 1, 1], true, 0, "test")
	check(w.terrain.field(target, false).dist == reference.field(target, false).dist, "额外破口沿用 T73 修复并等于全重算")
	check(not w.terrain.is_walkable_at(w.terrain.vec([25, 28])), "未指定墙段仍不可破")
	giant.nav_pos = w.zone_point("plaza")
	for n in 3:
		w.spawn("shield", 1, giant.nav_pos + Vector3(0.5, 0, (n - 1) * 0.4), "plaza")
	w.rebuild_spatial()
	w.phase_b.special_tick(giant)
	check(w.phase_b.stats("giant").sweeps == 1, "巨人被三兵包围时横扫")
	dispose(w)

func test_caves() -> void:
	var w = fresh()
	var a = w.spawn("assassin", 0, w.terrain.vec(w.params.map.cave_a), "coast")
	var g = w.spawn("ghost", 0, a.nav_pos, "coast")
	var d = w.spawn("shield", 1, a.nav_pos, "coast")
	for permission in ["all", "undead", "assassin"]:
		w.params.phase_b.cave_permission = permission
		check(w.phase_b.can_cave(a), "三种权限下刺客均可进洞")
		check(w.phase_b.can_cave(g) == (permission != "assassin"), "亡魂山洞权限")
		check(w.phase_b.can_cave(d) == (permission == "all"), "守军山洞权限")
	w.params.phase_b.cave_permission = "all"
	d.slot = w.terrain.vec(w.params.map.cave_b)
	check(w.try_cave(d) and d.cave_until > 0, "所有人权限下守军实际能够进洞")
	w.params.phase_b.cave_permission = "assassin"
	g.route = "cave"
	w.ghost_order(g)
	check(g.cave_until < 0 and g.route != "cave", "禁止进洞者不会卡在洞口")
	dispose(w)

func test_metrics_and_ui() -> void:
	var w = fresh()
	var g = w.spawn("ghost", 0, w.terrain.vec([29, 34]), "coast")
	g.order_dist = 5
	g.order_dir = Vector3.FORWARD
	g.walk_dir = Vector3.FORWARD
	for n in 100:
		w.time = n / 30.0
		g.movement_congestion()
	check(w.congestion == 1, "有移动意图持续无进展只计一次")
	g.enemy = w.spawn("shield", 1, g.nav_pos + Vector3(0.3, 0, 0), "coast")
	g.enemy_dist = 0.3
	for n in 100:
		w.time += 1.0 / 30
		g.movement_congestion()
	check(w.congestion == 1, "近战交战不计拥堵")
	g.enemy = null
	g.walk_dir = Vector3.ZERO
	for n in 100:
		w.time += 1.0 / 30
		g.movement_congestion()
	check(w.congestion == 1, "站岗不计拥堵")
	g.nav_pos = w.terrain.vec([26, 29])
	g.objective = "wall_west"
	g.walk_dir = Vector3.FORWARD
	for n in 100:
		w.time += 1.0 / 30
		g.movement_congestion()
	check(w.congestion == 1, "正在攻击结构不计拥堵")
	w.phase_b.sample_peaks()
	check(w.phase_b.phase_peaks.early.ghost == 1 and w.phase_b.phase_peaks.early.defender == 1, "阶段峰值统计活兵")
	var view = View.new()
	root.add_child(view)
	view.setup(w)
	check(view.unit_cards.size() == 3, "底部有三张带费用卡片")
	view.select_kind("giant")
	check(w.selected_kind == "giant", "卡片改变下一次部署兵种")
	view.free()
	dispose(w)

func run() -> void:
	test_gates()
	test_targeting()
	test_assassin()
	test_walls_and_sweep()
	test_caves()
	test_metrics_and_ui()
	if failures.is_empty():
		print("T74_FEATURES PASS")
	quit(0 if failures.is_empty() else 1)
