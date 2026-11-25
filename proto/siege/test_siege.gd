extends SceneTree
## 机制边界验收；短场景直接验证争夺、撤退、局部流场和合法输入。
const World = preload("res://proto/siege/siege.gd")
const Map = preload("res://proto/siege/siege_map.gd")
const Director = preload("res://proto/siege/siege_director.gd")
const View = preload("res://proto/siege/siege_view.gd")
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FEATURE FAIL: " + message)

func fresh():
	var w = World.new()
	# 不进场景树，避免启动窗口和自动策略；使用与正式场景相同的初始化数据。
	w.params = JSON.parse_string(FileAccess.get_file_as_string("res://proto/siege/siege_params.json"))
	w.sim_rng.seed = 11
	w.terrain.setup(w.params)
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

func test_navigation() -> void:
	var w = fresh()
	var m = w.terrain
	var target: Vector3 = w.zone_point("keep")
	var coast: Vector3 = w.terrain.vec(w.params.strategies.deploy_points.main)
	check(m.distance(coast, target, false) >= w.params.map.flow_infinity, "闭门且无破口时，大路不能穿墙")
	check(m.distance(coast, target, true) < w.params.map.flow_infinity, "山洞必须作为寻路图传送边连通内外城")
	for open in [true, false, true, false]:
		m.change(w.params.map.gate_rect, open, 1.0, "test")
		var incremental: Dictionary = m.field(target, false)
		var reference = Map.new()
		reference.setup(w.params)
		if open:
			reference.change(w.params.map.gate_rect, true, 1, "reference")
		var full: Dictionary = reference.field(target, false)
		check(incremental.dist == full.dist, "开/关门的局部修复必须与全图重算距离相等")
	m.change(w.params.map.weak_rect, true, 2, "test_weak")
	check(m.distance(coast, target, false) < w.params.map.flow_infinity, "破墙后应连通侧路")
	w.params.map.cave_enabled = false
	var closed = Map.new()
	closed.setup(w.params)
	check(closed.distance(coast, target, true) >= w.params.map.flow_infinity, "关闭山洞参数应删除传送边")
	dispose(w)

func test_capture_retreat() -> void:
	var w = fresh()
	var g = w.spawn("ghost", 0, w.zone_point("keep"), "coast")
	var d = w.spawn("shield", 1, w.zone_point("plaza"), "plaza")
	w.update_captures(float(w.params.capture.seconds) * 0.6)
	check(w.zones.keep.progress > 0 and not w.won, "空堡需要连续占据，不能立即胜利")
	d.nav_pos = w.zone_point("keep")
	w.update_captures(0.1)
	check(w.zones.keep.progress == 0, "反攻进入主堡必须清零亡魂占领计时")
	d.nav_pos = w.zone_point("plaza")
	w.update_captures(float(w.params.capture.seconds))
	check(w.won and w.victory_method == "keep_retreat" and w.retreat_started, "攻占主堡即判胜并启动撤退")
	var hp: float = g.hp
	d.enemy = g
	d.enemy_dist = 0.1
	d.nav_pos = g.nav_pos + Vector3(0.1, 0, 0)
	w.rebuild_spatial()
	w.director.unit_order(d)
	d.tick(1)
	check(g.hp == hp and d.retreating and not d.dangerous, "撤退守军不能反击")
	d.deal_damage({"damage": 10.0, "knockback": 0.0, "stun": 0.0, "dir": Vector3.RIGHT})
	check(w.intercepted == 1, "撤退中的死亡应记录截杀")
	var escaped = w.spawn("shield", 1, w.terrain.vec(w.params.map.port), "plaza")
	w.update_retreat()
	check(w.escaped == 1 and escaped.escaped, "港口登船应记录逃走且从战场移除")
	w.time = w.boat_depart_at
	w.update_retreat()
	check(w.finished and w.won, "船开走后结束且保留已判定的胜利")
	dispose(w)
	var r = fresh()
	var ghost = r.spawn("ghost", 0, r.zone_point("highland"), "coast")
	r.update_captures(float(r.params.capture.seconds))
	check(r.zones.highland.owner == "ghost", "其他战区也应能攻占")
	ghost.nav_pos = r.zone_point("coast")
	r.spawn("shield", 1, r.zone_point("highland"), "highland")
	r.update_captures(float(r.params.capture.defender_seconds))
	check(r.zones.highland.owner == "defender" and r.zones.highland.losses.size() == 1, "守军应能夺回据点并记录失守")
	dispose(r)

func test_economy_and_orders() -> void:
	var w = fresh()
	check(not w.deploy(w.zone_point("keep")), "默认禁止海岸外部署")
	var before: float = w.fire
	check(w.deploy(w.terrain.vec(w.params.strategies.deploy_points.main)), "海岸应允许部署")
	check(w.fire == before - float(w.params.economy.unit_cost), "部署必须扣费")
	check(w.rally(w.zone_point("highland")), "集结可以指向可通行高地")
	check(w.rally_events.size() == 1 and w.fire_spent == float(w.params.economy.unit_cost) + float(w.params.economy.rally_cost), "集结必须扣费并留记录")
	w.zones.highland.owner = "ghost"
	w.params.capture.expanded_deployment = true
	check(w.can_deploy(w.zone_point("highland")), "部署扩展开关应开放已占据战区")
	w.fire = w.params.economy.capacity
	w.regenerate(1)
	check(w.fire == float(w.params.economy.capacity) and w.fire_wasted > 0, "满额回复必须计入溢出")
	w.params.economy.kill_reward_enabled = false
	before = w.fire
	var enemy = w.spawn("shield", 1, w.zone_point("plaza"), "plaza")
	enemy.deal_damage({"damage": 10.0, "knockback": 0.0, "stun": 0.0, "dir": Vector3.RIGHT})
	check(w.fire == before, "默认击杀不回复冥火")
	dispose(w)

func test_director() -> void:
	var w = fresh()
	for group in w.params.garrisons:
		for n in int(group.count):
			var u = w.spawn(group.kind, 1, w.terrain.vec(group.anchor) + w.formation_offset(n), group.zone)
			u.reserve = group.get("reserve", false)
	for n in 10:
		w.spawn("ghost", 0, w.zone_point("coast") + w.formation_offset(n), "coast")
	w.rebuild_spatial()
	w.director.tick()
	var pending: Array = w.sides[1].units.filter(func(u): return u.dispatch_at >= 0)
	check(not pending.is_empty(), "受威胁时应有跨区支援决定")
	for u in pending:
		check(u.reserve and u.kind == "cavalry", "优先动用机动预备队")
		check(u.assigned == "keep" and u.dispatch_at == float(w.params.director.dispatch_delay), "派兵延迟期间不改变驻地")
	for zone in w.params.map.zones:
		var retained := 0
		for u in w.sides[1].units:
			if u.assigned == zone.id and u.dispatch_at < 0:
				retained += 1
		check(retained >= int(zone.min_garrison), "调度不得低于驻防下限: " + zone.id)
	var start: Vector3 = pending[0].nav_pos
	w.time = float(w.params.director.dispatch_delay)
	w.director.tick()
	check(w.director.dispatches > 0 and pending[0].nav_pos == start and pending[0].marching, "延迟结束只能开始行军，不可瞬移")
	w.params.reinforcements.enabled = true
	w.time = float(w.params.simulation.night_seconds) - float(w.params.reinforcements.seconds_before_dawn)
	w.director.tick()
	check(w.director.reinforcements_arrived, "最后一分钟应出现王国援军")
	dispose(w)

func test_end_conditions() -> void:
	var wipe = fresh()
	wipe.spawn("ghost", 0, wipe.zone_point("coast"), "coast")
	wipe.simulate()
	check(wipe.finished and wipe.victory_method == "annihilation", "全歼是独立胜利条件，无需先占主堡")
	dispose(wipe)
	var dawn = fresh()
	dawn.spawn("shield", 1, dawn.zone_point("keep"), "keep")
	dawn.params.simulation.night_seconds = dawn.params.simulation.step
	dawn.simulate()
	check(dawn.finished and not dawn.won and dawn.victory_method == "none", "破晓未全歼/占堡必须失败")
	dispose(dawn)

func test_dispatch_after_losses() -> void:
	var w = fresh()
	for n in 6:
		w.spawn("shield", 1, w.zone_point("keep") + w.formation_offset(n), "keep")
	for n in 10:
		w.spawn("ghost", 0, w.zone_point("coast") + w.formation_offset(n), "coast")
	w.rebuild_spatial()
	w.director.tick()
	var pending: Array = w.sides[1].units.filter(func(u): return u.dispatch_at >= 0)
	check(pending.size() == 1, "六名守军、五人驻防下限只允许预留一人")
	if not pending.is_empty():
		for u in w.sides[1].units:
			if u != pending[0]:
				u.deal_damage({"damage": 10.0, "knockback": 0.0, "stun": 0.0, "dir": Vector3.RIGHT})
				break
		w.time = float(w.params.director.dispatch_delay)
		w.director.tick()
		check(w.director.dispatches == 0 and pending[0].assigned == "keep", "延迟期间阵亡后，出发时必须重新检查驻防下限")
	dispose(w)

func test_view_startup() -> void:
	var w = fresh()
	for kind in ["ghost", "shield", "archer", "cavalry"]:
		w.spawn(kind, 0 if kind == "ghost" else 1, w.zone_point("coast") + w.formation_offset(w.units.size()), "coast")
	var visual = View.new()
	root.add_child(visual)
	visual.setup(w)
	visual.debug_visible = true
	visual.refresh()
	check(visual.unit_meshes.size() == 4 and visual.flags.size() == 4, "可视层启动应创建四类单位与四区旗点")
	check(visual.hud.text.contains("冥火") and visual.debug.text.contains("threat"), "HUD 与调试文字必须正常格式化")
	w.start_retreat()
	w.won = true
	w.time = w.boat_depart_at + 1
	visual.refresh()
	check(not visual.banner.text.is_empty(), "撤退胜利应显示结果")
	visual.main = null
	visual.free()
	dispose(w)

func test_congestion() -> void:
	var w = fresh()
	var gate_approach: Vector3 = w.terrain.vec(w.params.map.routes.main[0])
	for n in 16:
		w.spawn("ghost", 0, gate_approach, "coast")
	w.rebuild_spatial()
	w.time = float(w.params.targeting.reroute_after_seconds) + 1
	var first = w.units[0]
	w.ghost_order(first)
	check(first.route != "main" and w.reroutes == 1, "路口拥堵时必须能自主改走其他路线")
	dispose(w)
	var counter = fresh()
	var guard = counter.spawn("shield", 1, counter.zone_point("keep"), "keep")
	guard.cell = counter.terrain.tile(guard.nav_pos)
	counter.time = float(counter.params.targeting.congestion_seconds) + 1
	guard.tick(0)
	guard.tick(0)
	check(counter.congestion == 1, "同次同格停留超过阈值只能累计一次")
	check(counter.travel_congestion == 0, "站岗停留应能与行军堵塞区分")
	dispose(counter)

func run() -> void:
	test_navigation()
	test_capture_retreat()
	test_economy_and_orders()
	test_director()
	test_end_conditions()
	test_dispatch_after_losses()
	test_view_startup()
	test_congestion()
	if failures.is_empty():
		print("SIEGE_FEATURES PASS navigation/capture/retreat/economy/director/end_conditions/view_startup")
		quit(0)
	else:
		printerr("SIEGE_FEATURES FAIL " + str(failures))
		quit(1)
