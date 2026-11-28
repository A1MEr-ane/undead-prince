extends SceneTree
## 机制边界验收；短场景直接验证争夺、撤退、局部流场和合法输入。
const World = preload("res://proto/siege/siege.gd")
const Map = preload("res://proto/siege/siege_map.gd")
const Director = preload("res://proto/siege/siege_director.gd")
const Bot = preload("res://proto/siege/siege_bot.gd")
const Hooks = preload("res://proto/siege/siege_events.gd")
const Metrics = preload("res://proto/siege/siege_metrics.gd")
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
	w.time = w.boat_depart_at + float(w.params.retreat.boat_sail_seconds)
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
	check(not w.params.reinforcements.enabled and not w.params.director.global_perception, "基线默认关闭新增援军和全图感知")
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
	w.params.director.global_perception = true
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
	check(visual.hud.text.contains("冥火") and visual.hud.text.contains("05:00") and visual.debug.text.contains("threat"), "HUD 与调试文字必须正常格式化")
	w.win("keep_retreat")
	w.start_retreat()
	w.time = w.boat_depart_at + 1
	visual.refresh()
	check(not visual.banner.text.is_empty(), "撤退胜利应显示结果")
	visual.main = null
	visual.free()
	dispose(w)

func test_congestion() -> void:
	var w = fresh()
	w.params.map.cave_enabled = false
	w.params.combat.separation_strength = 0.0
	w.params.map.gate_rect = [29, 28, 1, 1]
	w.terrain.change(w.params.map.gate_rect, true, 0, "test_narrow_gate")
	w.terrain.gate_open = true
	w.terrain.gate_broken = true
	w.terrain.weak_broken = true
	w.terrain.change(w.params.map.weak_rect, true, 0, "test_side_open")
	var lead = w.spawn("ghost", 0, Vector3(29.5, 0, 28.5), "coast")
	lead.stage = 2
	lead.speed = 0.0
	for n in 9:
		var unit = w.spawn("ghost", 0, Vector3(29.5, 0, 28.93 + n * 0.47), "coast")
		unit.stage = 2
	var guard = w.spawn("shield", 1, w.zone_point("keep"), "keep")
	guard.hp = 1000.0
	for step in 238:
		w.simulate()
	check(w.reroutes > 0 and w.travel_congestion > 0, "窄门实际堵塞后，一部分亡魂应改走可达的侧路")
	check(guard.congestion_count == 0, "驻防等待不算拥堵")
	lead.speed = 2.0
	for step in 240:
		w.simulate()
	check(w.sides[0].units.any(func(unit): return unit.nav_pos.z < 28.0), "障碍离开后原路线的队伍继续通行")
	dispose(w)

func test_locked_outcomes() -> void:
	var w = fresh()
	w.params.simulation.night_seconds = w.params.simulation.step
	w.spawn("ghost", 0, w.zone_point("keep"), "coast")
	w.spawn("shield", 1, w.zone_point("coast"), "coast")
	w.zones.keep.progress = float(w.params.capture.seconds) - float(w.params.simulation.step)
	w.simulate()
	check(w.outcome == World.Outcome.WON and w.retreat_started and not w.finished, "同一步攻占和破晓：胜利优先，撤退独立继续")
	w.win("annihilation")
	check(w.victory_method == "keep_retreat", "已锁定胜法不得被后续条件覆盖")
	w.simulate()
	check(w.outcome == World.Outcome.WON and not w.finished, "破晓之后不得改判或截断撤退")
	w.queue_input("skip_retreat")
	w.simulate()
	check(w.finished and w.retreat_skipped and w.won, "撤退可通过同一模拟输入接口跳过")
	dispose(w)
	var wipe = fresh()
	wipe.params.simulation.night_seconds = wipe.params.simulation.step
	wipe.simulate()
	check(wipe.outcome == World.Outcome.WON and wipe.finished, "同一步全歼和破晓：全歼优先")
	dispose(wipe)
	var lost = fresh()
	lost.spawn("shield", 1, lost.zone_point("keep"), "keep")
	lost.params.simulation.night_seconds = lost.params.simulation.step
	lost.simulate()
	lost.win("annihilation")
	check(lost.outcome == World.Outcome.LOST and not lost.won, "LOST 为终态，不接受事后胜利")
	dispose(lost)

func test_effective_defenders() -> void:
	var w = fresh()
	w.params.map.land_rects.append([1, 1, 1, 1])
	w.terrain = Map.new()
	w.terrain.setup(w.params)
	var stranded = w.spawn("shield", 1, Vector3(1.5, 0, 1.5), "coast")
	var remnant = w.spawn("shield", 1, w.zone_point("keep"), "keep", false)
	var escaped = w.spawn("shield", 1, w.zone_point("keep"), "keep")
	escaped.leave_ship()
	var retreating = w.spawn("shield", 1, w.zone_point("keep"), "keep")
	retreating.retreating = true
	var valid = w.spawn("shield", 1, w.zone_point("plaza"), "plaza")
	check(not w.effective_defender(stranded) and not w.effective_defender(remnant), "不可达单位与未登记残影不得参与胜负")
	w.resolve_outcome()
	check(w.outcome == World.Outcome.ACTIVE, "闭门内的有效守军仍须阻止全歼，不能误排除可破墙区域")
	valid.alive = false
	w.resolve_outcome()
	check(w.won and w.victory_method == "annihilation", "已撤离、撤退、不可达与残影不能阻塞全歼")
	dispose(w)

func test_weak_wall() -> void:
	for count in [1, 3, 5]:
		var w = fresh()
		for n in count:
			var u = w.spawn("ghost", 0, Vector3(13.5, 0, 24.5), "coast")
			u.objective = "weak"
		var dt := float(w.params.simulation.step)
		var expected := ceili(float(w.params.structures.weak_hp) / (count * float(w.params.structures.damage_per_second) * dt) - 0.000001)
		for n in expected - 1:
			w.time = (n + 1) * dt
			w.attack_structures(dt)
		check(not w.terrain.weak_broken, "薄弱墙不能早于参数定义的耗时破开")
		w.time = expected * dt
		w.attack_structures(dt)
		check(w.terrain.weak_broken, "唯一亡魂兵种应按人数与攻城参数打开薄弱墙")
		check(is_equal_approx(w.structure_work.weak.breached_at - w.structure_work.weak.started_at, expected * dt), "破墙实耗时必须使用固定模拟时间")
		check(not w.terrain.walkable(Vector2i(14, 21)), "普通墙不能随薄弱段一起破坏")
		dispose(w)

func test_perception_and_mission_lock() -> void:
	var w = fresh()
	var guard = w.spawn("cavalry", 1, w.zone_point("keep"), "keep")
	var ghost = w.spawn("ghost", 0, w.zone_point("coast"), "coast")
	w.rebuild_spatial()
	w.director.tick()
	check(w.director.threats.coast == 0 and w.director.decisions.is_empty(), "默认感知外亡魂不产生威胁")
	w.fire = 0
	w.director.next_think = 0
	w.director.tick()
	check(w.director.threats.coast == 0, "威胁不依赖玩家剩余冥火")
	w.params.director.global_perception = true
	w.director.next_think = 0
	w.director.tick()
	check(w.director.threats.coast > 0, "全图感知实验开关应独立生效")
	check(w.director.history.size() == 12, "每次感知评估保留四战区驻防与威胁历史")
	w.params.director.global_perception = false
	ghost.nav_pos = guard.nav_pos + Vector3(1, 0, 0)
	check(w.director.perceived(ghost), "感知半径内应发现亡魂")
	dispose(w)
	var m = fresh()
	for z in m.params.map.zones:
		z.min_garrison = 0
	var unit = m.spawn("cavalry", 1, m.zone_point("plaza"), "plaza")
	unit.marching = true
	unit.mission_from = "keep"
	unit.departed_at = 0
	unit.expected_arrival = 1
	m.time = 2
	m.director.unit_order(unit)
	check(not unit.marching and unit.mission_lock_until > m.time, "抵达后须继续锁定任务")
	m.params.director.global_perception = true
	for n in 10:
		m.spawn("ghost", 0, m.zone_point("coast"), "coast")
	m.rebuild_spatial()
	m.director.tick()
	check(unit.dispatch_to.is_empty(), "抵达锁定期内不得被小幅威胁调走")
	var arrival: Dictionary = m.director.decisions[0]
	check(arrival.has("actual_travel_seconds") and arrival.has("estimated_arrival_at") and arrival.from == "keep", "到达日志保留来源、预计与实际行军时间")
	m.time = unit.mission_lock_until + 1
	m.director.tick()
	check(unit.dispatch_to == "coast", "锁定到期后可再次支援")
	dispose(m)

func test_target_lock_and_recovery() -> void:
	var w = fresh()
	var unit = w.spawn("ghost", 0, w.zone_point("coast"), "coast")
	var a = w.spawn("shield", 1, unit.nav_pos + Vector3(2, 0, 0), "coast")
	var b = w.spawn("shield", 1, unit.nav_pos + Vector3(2.1, 0, 0), "coast")
	w.rebuild_spatial()
	unit.next_sense = 0
	unit.sense()
	check(unit.enemy == a, "首次选择最近可见敌人")
	b.nav_pos = unit.nav_pos + Vector3(1.9, 0, 0)
	w.rebuild_spatial()
	w.time = 0.2
	unit.next_sense = 0
	unit.sense()
	check(unit.enemy == a, "锁定期间小幅距离波动不得换目标")
	w.time = 3
	unit.next_sense = 0
	unit.sense()
	check(unit.enemy == a, "解锁后仍须满足切换滞后")
	b.nav_pos = unit.nav_pos + Vector3(0.5, 0, 0)
	w.rebuild_spatial()
	unit.next_sense = 0
	unit.sense()
	check(unit.enemy == b, "明显更优目标可在解锁后接管")
	b.alive = false
	unit.next_sense = 0
	unit.sense()
	check(unit.enemy == a, "原目标死亡应立即释放锁定")
	dispose(w)
	var r = fresh()
	var stuck = r.spawn("ghost", 0, Vector3(29.5, 0, 36.5), "coast")
	stuck.slot = Vector3(29.5, 0, 32.5)
	r.time = 3
	r.rebuild_spatial()
	stuck.sense()
	check(r.recovery_events.size() == 1 and stuck.order_dir.length() > 0, "无敌人且无进展时生成局部绕障路径")
	for n in 90:
		r.time += float(r.params.simulation.step)
		stuck.sense()
		stuck.tick(float(r.params.simulation.step))
	check(stuck.nav_pos.distance_to(Vector3(29.5, 0.3, 36.5)) > 0.5, "绕障后应恢复实际前进")
	dispose(r)

func test_hooks_and_fixed_input() -> void:
	var w = fresh()
	var received: Array = []
	for event in Hooks.NAMES:
		w.hooks.subscribe(event, func(payload): received.append(payload))
	var killer = w.spawn("ghost", 0, w.zone_point("coast"), "coast")
	var victim = w.spawn("shield", 1, w.zone_point("plaza"), "plaza")
	victim.deal_damage({"damage": 10.0, "knockback": 0.0, "stun": 0.0, "dir": Vector3.RIGHT, "source": killer})
	w.regenerate(1)
	for event in Hooks.NAMES:
		check(w.hooks.counts.get(event, 0) > 0, "事件接口可实际收到: " + event)
	w.hooks.subscribe("kill", func(_payload): w.spawn("shield", 1, w.zone_point("plaza"), "plaza"))
	w.hooks.subscribe("spawn", func(payload): payload.unit.deal_damage({"damage": 10.0, "knockback": 0.0, "stun": 0.0, "dir": Vector3.RIGHT, "source": killer}))
	w.hooks.publish("kill", {"unit": killer, "victim": victim})
	check(w.hooks.suppressed == 1 and w.units.size() == 3, "击杀→生成→击杀递归链必须被截断")
	var count: int = w.units.size()
	w.queue_input("deploy", w.terrain.vec(w.params.strategies.deploy_points.main))
	check(w.units.size() == count, "输入不能在渲染帧中直接生成单位")
	w.spawn("shield", 1, w.zone_point("keep"), "keep")
	w.hooks.clear()
	w.simulate()
	check(w.input_events.size() == 1 and w.input_events[0].step == 1, "输入在固定逻辑步执行并记录步号")
	dispose(w)

func test_late_batches() -> void:
	var w = fresh()
	var bot = Bot.new()
	bot.setup(w, "late_batches")
	w.fire = w.params.economy.capacity
	w.time = 59.9
	bot.tick()
	check(w.spawned[0] == 0, "晚开始策略第一分钟不部署")
	w.time = 60
	bot.tick()
	check(w.spawned[0] == 1 and bot.remaining == 19, "第二分钟开始，将当前资源按部署间隔分批投入")
	bot.remaining = 0
	w.time = 90
	w.fire = 59.9
	bot.tick()
	check(w.spawned[0] == 1, "资源不足60%时等待下一批")
	w.fire = 60
	bot.tick()
	check(w.spawned[0] == 2 and bot.remaining == 11, "冥火达到60%后启动下一批")
	bot.main = null
	dispose(w)

func test_objective_hysteresis_and_rally() -> void:
	var w = fresh()
	var unit = w.spawn("ghost", 0, Vector3(29.5, 0, 40.5), "coast")
	var archer = w.spawn("archer", 1, unit.nav_pos + Vector3(2, 0, 0), "coast")
	w.rebuild_spatial()
	w.ghost_order(unit)
	var waypoint: Vector3 = unit.slot
	unit.next_sense = 0
	unit.sense()
	check(unit.enemy == archer and unit.slot == waypoint, "索敌与行军点独立")
	var outside = w.spawn("ghost", 0, Vector3(49.5, 0, 43.5), "coast")
	check(w.rally(unit.nav_pos + Vector3(0, 0, -2)), "可下达局部集结命令")
	w.ghost_order(unit)
	check(unit.rallying and unit.slot == w.rally_pos and not w.rally_members.has(outside.id), "半径内单位立即转向集结点")
	outside.nav_pos = unit.nav_pos
	w.refresh_rally_members()
	check(w.rally_members.has(outside.id), "持续集结沿用动态作用范围")
	unit.nav_pos = w.rally_pos
	w.ghost_order(unit)
	check(not unit.rallying and unit.route == "main", "到达后恢复原路线")
	w.refresh_rally_members()
	check(not w.rally_members.has(unit.id), "已到达者不再重复响应同一条集结指令")
	w.time = w.rally_until + 0.1
	w.ghost_order(outside)
	check(not outside.rallying, "集结到期应恢复自主目标")
	dispose(w)

func test_presentation_isolation_and_scale() -> void:
	var w = fresh()
	w.params.simulation.night_seconds = 2
	w.map_metrics = Metrics.describe(w)
	w.spawn("shield", 1, w.zone_point("keep"), "keep")
	w.queue_input("deploy", w.terrain.vec(w.params.strategies.deploy_points.main))
	w.simulate()
	var before := JSON.stringify(w.result())
	var rng_state: int = w.sim_rng.state
	var position: Vector3 = w.units[-1].nav_pos
	var visual = View.new()
	root.add_child(visual)
	visual.setup(w)
	visual.refresh(0.1)
	visual.refresh(0.9)
	check(w.units[-1].nav_pos == position and w.sim_rng.state == rng_state and JSON.stringify(w.result()) == before, "视觉插值不能修改模拟、RNG 或 SIEGE 数据")
	check(w.map_metrics.walkable_area_closed == 1275 and w.map_metrics.walkable_bounds_dimensions == [48, 42], "地图实际面积与线性包围盒必须由网格计算")
	check(w.map_metrics.defender_routes.size() == 12 and w.map_metrics.routes.size() == 3, "每条进攻/有向增援路线都有时间尺度记录")
	var headless = fresh()
	headless.params.simulation.night_seconds = 2
	headless.map_metrics = Metrics.describe(headless)
	headless.spawn("shield", 1, headless.zone_point("keep"), "keep")
	headless.queue_input("deploy", headless.terrain.vec(headless.params.strategies.deploy_points.main))
	headless.simulate()
	for n in 60:
		w.simulate()
		visual.refresh(0.5)
		headless.simulate()
	check(JSON.stringify(w.result()) == JSON.stringify(headless.result()), "同输入同种子：带可视层与无头执行同一模拟，完整结果相同")
	visual.main = null
	visual.free()
	dispose(w)
	dispose(headless)

func run() -> void:
	test_objective_hysteresis_and_rally()
	test_presentation_isolation_and_scale()
	test_locked_outcomes()
	test_effective_defenders()
	test_weak_wall()
	test_perception_and_mission_lock()
	test_target_lock_and_recovery()
	test_hooks_and_fixed_input()
	test_late_batches()
	test_navigation()
	test_capture_retreat()
	test_economy_and_orders()
	test_director()
	test_end_conditions()
	test_dispatch_after_losses()
	test_view_startup()
	test_congestion()
	if failures.is_empty():
		print("SIEGE_FEATURES PASS T69 outcome_priority/eligible_defenders/weak_wall/perception/mission_lock/target_lock/recovery/hooks/fixed_input/late_batches + T67 regression")
		quit(0)
	else:
		printerr("SIEGE_FEATURES FAIL " + str(failures))
		quit(1)
