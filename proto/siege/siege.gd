extends Node3D
## T67 独立灰盒场景；所有模拟只在固定步长内更新。

const Map = preload("res://proto/siege/siege_map.gd")
const Soldier = preload("res://proto/siege/siege_unit.gd")
const Director = preload("res://proto/siege/siege_director.gd")
const Bot = preload("res://proto/siege/siege_bot.gd")
const View = preload("res://proto/siege/siege_view.gd")
const State = preload("res://scripts/agent_state.gd")
const DEFAULT_PARAMS := "res://proto/siege/siege_params.json"

var params: Dictionary
var args := {}
var terrain := Map.new()
var director := Director.new()
var bot = null
var view = null
var sim_rng := RandomNumberGenerator.new()
var art_rng := RandomNumberGenerator.new()
var units: Array = []
var sides: Array = [{"units": []}, {"units": []}]
var spatial := {}
var zones := {}
var seed_value := 7
var strategy := "manual"
var time := 0.0
var step_number := 0
var accumulator := 0.0
var fire := 0.0
var fire_wasted := 0.0
var fire_generated := 0.0
var fire_spent := 0.0
var waves: Array = []
var rally_events: Array = []
var last_deploy := -1000.0
var rally_pos := Vector3.ZERO
var rally_until := -1.0
var gate_hp: float
var weak_hp: float
var gate_close_at := 0.0
var retreat_started := false
var retreat_at := -1.0
var boat_depart_at := -1.0
var escaped := 0
var intercepted := 0
var stranded := 0
var casualties := [0, 0]
var spawned := [0, 0]
var archer_deaths: Array = []
var congestion := 0
var travel_congestion := 0
var reroutes := 0
var cave_transits := 0
var events := {}
var won := false
var victory_method := "none"
var victory_time := -1.0
var finished := false
var ended_at := -1.0
var result_printed := false
var final_result := {}
var headless := false
var capture_mode := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	headless = DisplayServer.get_name() == "headless"
	capture_mode = args.has("capture")
	if headless and capture_mode:
		fail("--capture 需要窗口渲染，headless 没有可截图视口")
		return
	var source := FileAccess.get_file_as_string(DEFAULT_PARAMS)
	var loaded = JSON.parse_string(source)
	if not loaded is Dictionary:
		fail("默认参数无法读取")
		return
	params = loaded
	if args.has("params"):
		var override = JSON.parse_string(FileAccess.get_file_as_string(args.params))
		if not override is Dictionary:
			fail("--params 必须指向有效 JSON 对象")
			return
		merge_params(params, override)
	if not validate_params():
		return
	seed_value = int(args.get("seed", "7"))
	strategy = args.get("strategy", "waves" if headless else "manual")
	if strategy != "manual" and not params.strategies.names.has(strategy):
		fail("未知策略: " + strategy)
		return
	sim_rng.seed = seed_value
	art_rng.seed = seed_value + 104729
	State.now = 0
	State.dt = float(params.simulation.step)
	terrain.setup(params)
	gate_hp = float(params.structures.gate_hp)
	weak_hp = float(params.structures.weak_hp)
	fire = float(params.economy.initial)
	for z in params.map.zones:
		zones[z.id] = {"owner": "defender", "progress": 0.0, "retake": 0.0, "captures": [], "losses": [], "contested_resets": []}
	for group in params.garrisons:
		for n in int(group.count):
			var u = spawn(group.kind, 1, terrain.vec(group.anchor) + formation_offset(n), group.zone)
			u.reserve = group.get("reserve", false)
	director.setup(self)
	if strategy != "manual":
		bot = Bot.new()
		bot.setup(self, strategy)
	if not headless:
		view = View.new()
		add_child(view)
		view.setup(self)

func merge_params(base: Dictionary, override: Dictionary) -> void:
	for key in override:
		if base.has(key) and base[key] is Dictionary and override[key] is Dictionary:
			merge_params(base[key], override[key])
		else:
			base[key] = override[key]

func validate_params() -> bool:
	if float(params.simulation.step) <= 0 or float(params.simulation.night_seconds) <= 0 or float(params.economy.unit_cost) <= 0 or float(params.economy.capacity) < float(params.economy.unit_cost):
		fail("时间、费用必须为正，冥火上限必须足够部署一个单位")
		return false
	if float(params.economy.initial) < 0 or float(params.economy.initial) > float(params.economy.capacity):
		fail("initial 必须位于 [0, capacity]")
		return false
	if params.economy.regen_curve.size() < 2 or float(params.capture.seconds) <= 0:
		fail("回复曲线至少两个点；攻占秒数必须为正")
		return false
	var previous := -1.0
	for knot in params.economy.regen_curve:
		if float(knot[0]) <= previous or float(knot[1]) < 0:
			fail("回复曲线时间必须递增，速率不能为负")
			return false
		previous = float(knot[0])
	return true

func fail(message: String) -> void:
	push_error("SIEGE CONFIG: " + message)
	get_tree().quit(2)

func _process(delta: float) -> void:
	if params.is_empty() or result_printed and headless:
		return
	var count := 0
	if headless:
		count = int(params.simulation.headless_steps_per_frame)
	else:
		var speed := float(args.get("speed", params.view.capture_speed if capture_mode else params.view.simulation_speed))
		accumulator += minf(delta, float(params.simulation.max_frame_delta)) * speed
		count = mini(int(params.simulation.max_frame_steps), floori(accumulator / float(params.simulation.step)))
		accumulator -= count * float(params.simulation.step)
	for n in count:
		if finished and not capture_mode:
			break
		simulate()
		if capture_mode and view != null and view.next_shot_due():
			break
	if view != null:
		view.refresh()
	if finished and not result_printed:
		final_result = result()
		print("SIEGE " + JSON.stringify(final_result))
		result_printed = true
		if headless or (bot != null and not capture_mode):
			get_tree().quit()
	if capture_mode and view != null:
		view.capture_if_due()

func simulate() -> void:
	step_number += 1
	time = step_number * float(params.simulation.step)
	State.now = time
	State.dt = float(params.simulation.step)
	if finished:
		return
	var dt := float(params.simulation.step)
	regenerate(dt)
	if bot != null:
		bot.tick()
	rebuild_spatial()
	director.tick()
	update_gate()
	for u in units:
		if not u.alive:
			continue
		if u.faction == 0:
			ghost_order(u)
		else:
			director.unit_order(u)
			stage_defender_at_gate(u)
		u.sense()
	for u in units:
		u.tick(dt)
	rebuild_spatial()
	attack_structures(dt)
	update_captures(dt)
	if not won and sides[1].units.filter(func(u): return u.alive).is_empty():
		win("annihilation")
		finish()
	if retreat_started:
		update_retreat()
	if time >= float(params.simulation.night_seconds) and not finished:
		finish()

func regenerate(dt: float) -> void:
	var progress := time / float(params.simulation.night_seconds)
	var curve: Array = params.economy.regen_curve
	var rate := float(curve[-1][1])
	for n in range(1, curve.size()):
		if progress <= float(curve[n][0]):
			rate = lerpf(float(curve[n - 1][1]), float(curve[n][1]), clampf(inverse_lerp(float(curve[n - 1][0]), float(curve[n][0]), progress), 0, 1))
			break
	var amount := rate * dt
	fire_generated += amount
	fire_wasted += maxf(0, fire + amount - float(params.economy.capacity))
	fire = minf(float(params.economy.capacity), fire + amount)

func spawn(kind: String, faction: int, pos: Vector3, zone: String):
	var u = Soldier.new()
	u.setup(self, units.size(), kind, faction, pos, zone)
	units.append(u)
	sides[faction].units.append(u)
	spawned[faction] += 1
	return u

func formation_offset(n: int) -> Vector3:
	var columns := int(params.director.formation_columns)
	var spacing := float(params.director.garrison_spacing)
	return Vector3((n % columns - (columns - 1) * 0.5) * spacing, 0, (n / columns) * spacing)

func zone_point(id: String) -> Vector3:
	for z in params.map.zones:
		if z.id == id:
			return terrain.vec(z.center)
	return Vector3.ZERO

func can_deploy(pos: Vector3) -> bool:
	if finished or retreat_started or not terrain.is_walkable_at(pos):
		return false
	if terrain.in_rect(pos, params.map.deploy_rect):
		return true
	if params.capture.expanded_deployment:
		return zones[terrain.zone_at(pos)].owner == "ghost"
	return false

func deploy(pos: Vector3) -> bool:
	var cost := float(params.economy.unit_cost)
	if not can_deploy(pos) or fire < cost:
		return false
	fire -= cost
	fire_spent += cost
	var u = spawn("ghost", 0, pos, "coast")
	u.route = choose_route(u, false)
	if waves.is_empty() or time - last_deploy > float(params.economy.wave_gap_seconds):
		waves.append({"start": snappedf(time, 0.001), "end": 0.0, "count": 0, "fire": 0.0, "routes": {"main": 0, "side": 0, "cave": 0}})
	waves[-1].count += 1
	waves[-1].fire += cost
	waves[-1].routes[u.route] += 1
	waves[-1].end = snappedf(time, 0.001)
	last_deploy = time
	return true

func rally(pos: Vector3) -> bool:
	var cost := float(params.economy.rally_cost)
	if finished or retreat_started or fire < cost or not terrain.is_walkable_at(pos):
		return false
	fire -= cost
	fire_spent += cost
	rally_pos = pos
	rally_until = time + float(params.economy.rally_seconds)
	rally_events.append({"time": snappedf(time, 0.001), "point": [snappedf(pos.x, 0.01), snappedf(pos.z, 0.01)], "cost": cost})
	return true

func choose_route(u, congestion_change: bool) -> String:
	var scores := {}
	var cfg: Dictionary = params.targeting
	for route in params.map.routes:
		if route == "cave" and not params.map.cave_enabled:
			continue
		var first: Vector3 = terrain.vec(params.map.routes[route][0])
		var distance: float = terrain.distance(u.nav_pos, first, false)
		var crowd := 0
		for f in sides[0].units:
			if f.alive and f != u and f.route == route and f.stage < 2 and Vector2(f.nav_pos.x - first.x, f.nav_pos.z - first.z).length() <= float(cfg.crowd_radius):
				crowd += 1
		var value := float(cfg.values.gate if route == "main" else cfg.values.archer if route == "side" else cfg.values.keep)
		var commitment := float(cfg.route_commitment) if route == u.route and not congestion_change else 0.0
		# 同一登陆点的主路/侧路入口可以区分；高地尚存弓手时，侧路偏好更高。
		scores[route] = value * float(cfg.value_weight) - distance * float(cfg.distance_weight) - crowd * float(cfg.congestion_weight) + commitment
	var best := "main"
	var highest := -INF
	for route in scores:
		if scores[route] > highest:
			highest = scores[route]
			best = route
	return best

func ghost_order(u) -> void:
	if u.cave_until >= 0:
		return
	if retreat_started:
		var target = nearest_enemy(u, float(params.retreat.pursuit_radius))
		u.slot = target.nav_pos if target != null else terrain.vec(params.map.port)
		return
	var cfg: Dictionary = params.targeting
	if time < u.next_target and u.objective != "cave":
		return
	if time >= u.next_target:
		u.next_target = time + float(cfg.think_seconds)
		if u.stage < 2 and time >= u.reroute_at and time - u.cell_since >= float(cfg.reroute_after_seconds) and nearby(u.nav_pos, float(cfg.crowd_radius), 0).size() > int(cfg.route_crowd_threshold):
			var alternative := choose_route(u, true)
			if alternative != u.route:
				u.route = alternative
				u.stage = 0
				u.reroutes += 1
				reroutes += 1
				u.reroute_at = time + float(cfg.reroute_cooldown_seconds)
	var route: Array = params.map.routes[u.route]
	var waypoint: Vector3 = terrain.vec(route[mini(u.stage, route.size() - 1)])
	if Vector2(waypoint.x - u.nav_pos.x, waypoint.z - u.nav_pos.z).length() < float(cfg.route_waypoint_radius) and u.stage < route.size() - 1:
		u.stage += 1
		waypoint = terrain.vec(route[u.stage])
	if u.route == "cave" and u.stage <= 1:
		u.slot = terrain.vec(params.map.cave_a)
		u.objective = "cave"
		var travelers := 0
		for f in units:
			if f.cave_until >= 0:
				travelers += 1
		if Vector2(u.slot.x - u.nav_pos.x, u.slot.z - u.nav_pos.z).length() <= float(params.map.cave_entry_radius) and travelers < int(params.map.cave_capacity):
			u.cave_until = time + float(params.map.cave_travel_seconds)
			u.cave_exit = terrain.vec(params.map.cave_b)
			cave_transits += 1
		return
	var candidates: Array = [{"pos": terrain.nearest(waypoint), "value": float(cfg.values.zone), "kind": "flag"}]
	if u.route == "main" and u.stage <= 2 and not terrain.gate_broken and not terrain.gate_open:
		candidates = [{"pos": terrain.vec(params.map.routes.main[1]), "value": float(cfg.values.gate), "kind": "gate"}]
	elif u.route == "side" and u.stage <= 3:
		if zones.highland.owner != "ghost" and u.stage <= 2:
			candidates = [{"pos": zone_point("highland"), "value": float(cfg.values.zone), "kind": "flag"}]
		else:
			if u.stage < 2:
				u.stage = 2
			if not terrain.weak_broken:
				candidates = [{"pos": Vector3(float(params.map.weak_rect[0]) - 0.5, 0, float(params.map.weak_rect[1]) + float(params.map.weak_rect[3]) * 0.5), "value": float(cfg.values.weak), "kind": "weak"}]
			else:
				u.stage = maxi(u.stage, 3)
				candidates = [{"pos": zone_point("plaza"), "value": float(cfg.values.zone), "kind": "flag"}]
	for e in nearby(u.nav_pos, float(params.combat.chase_radius), 1):
		if terrain.line_clear(u.nav_pos, e.nav_pos):
			candidates.append({"pos": e.nav_pos, "value": float(cfg.values.archer if e.kind == "archer" else cfg.values.zone), "kind": e.kind})
	if rally_until > time and Vector2(u.nav_pos.x - rally_pos.x, u.nav_pos.z - rally_pos.z).length() <= float(params.economy.rally_radius):
		candidates.append({"pos": rally_pos, "value": float(cfg.rally_weight), "kind": "rally"})
	var best := -INF
	for c in candidates:
		var dist: float = terrain.distance(u.nav_pos, c.pos, false)
		var crowded := nearby(c.pos, float(cfg.crowd_radius), 0).size()
		var score := float(c.value) * float(cfg.value_weight) - dist * float(cfg.distance_weight) - crowded * float(cfg.congestion_weight)
		if score > best:
			best = score
			u.slot = c.pos
			u.objective = c.kind
	if u.stage >= route.size() - 1:
		u.slot = zone_point("keep") if u.objective == "flag" else u.slot

func rebuild_spatial() -> void:
	spatial.clear()
	var size := float(params.combat.spatial_cell_size)
	for u in units:
		if not u.alive or u.cave_until >= 0:
			continue
		var key := Vector3i(floori(u.nav_pos.x / size), u.faction, floori(u.nav_pos.z / size))
		if not spatial.has(key):
			spatial[key] = []
		spatial[key].append(u)

func nearby(p: Vector3, radius: float, faction: int) -> Array:
	var out: Array = []
	var size := float(params.combat.spatial_cell_size)
	for z in range(floori((p.z - radius) / size), floori((p.z + radius) / size) + 1):
		for x in range(floori((p.x - radius) / size), floori((p.x + radius) / size) + 1):
			for u in spatial.get(Vector3i(x, faction, z), []):
				if u.alive and u.cave_until < 0 and Vector2(u.nav_pos.x - p.x, u.nav_pos.z - p.z).length_squared() <= radius * radius:
					out.append(u)
	return out

func nearest_enemy(u, radius: float = -1):
	var best = null
	var distance := float(params.combat.sense_radius) if radius < 0 else radius
	for e in nearby(u.nav_pos, distance, 1 - u.faction):
		var d: float = Vector2(e.nav_pos.x - u.nav_pos.x, e.nav_pos.z - u.nav_pos.z).length()
		if d < distance and terrain.line_clear(u.nav_pos, e.nav_pos):
			distance = d
			best = e
	return best

func separation(u) -> Vector3:
	var v := Vector3.ZERO
	for faction in 2:
		for other in nearby(u.nav_pos, float(params.combat.separation_radius), faction):
			if other == u:
				continue
			var delta: Vector3 = u.nav_pos - other.nav_pos
			delta.y = 0
			var d := delta.length()
			var desired: float = u.radius + other.radius + float(params.combat.contact_slack)
			if d < desired:
				v += (delta.normalized() if d > 0.000001 else Vector3.RIGHT * (1 if u.id > other.id else -1)) * (desired - d) * float(params.combat.separation_strength)
	return v.limit_length(float(params.combat.max_separation_speed))

func attack_structures(dt: float) -> void:
	for u in sides[0].units:
		if not u.alive or u.cave_until >= 0 or time < u.stun_until or u.enemy_dist < float(params.combat.chase_radius):
			continue
		if u.objective == "gate" and not terrain.gate_broken:
			var gate: Array = params.map.gate_rect
			if u.nav_pos.x >= gate[0] - float(params.structures.attack_range) and u.nav_pos.x <= gate[0] + gate[2] + float(params.structures.attack_range) and absf(u.nav_pos.z - float(gate[1]) - 0.5) < float(params.structures.attack_range):
				gate_hp -= float(params.structures.damage_per_second) * dt
		elif u.objective == "weak" and not terrain.weak_broken:
			var weak: Array = params.map.weak_rect
			if absf(u.nav_pos.x - float(weak[0]) - 0.5) < float(params.structures.attack_range) and u.nav_pos.z >= weak[1] - float(params.structures.attack_range) and u.nav_pos.z <= weak[1] + weak[3] + float(params.structures.attack_range):
				weak_hp -= float(params.structures.damage_per_second) * dt
	if gate_hp <= 0 and not terrain.gate_broken:
		terrain.gate_broken = true
		terrain.gate_open = true
		terrain.change(params.map.gate_rect, true, time, "gate_breached")
	if weak_hp <= 0 and not terrain.weak_broken:
		terrain.weak_broken = true
		terrain.change(params.map.weak_rect, true, time, "weak_wall_breached")

func stage_defender_at_gate(u) -> void:
	if terrain.gate_open or terrain.gate_broken or terrain.weak_broken or retreat_started:
		return
	var outside: bool = u.nav_pos.z > float(params.map.gate_rect[1])
	var target_outside: bool = u.slot.z > float(params.map.gate_rect[1])
	if outside != target_outside:
		u.slot = Vector3(float(params.map.gate_rect[0]) + float(params.map.gate_rect[2]) * 0.5, 0, float(params.map.gate_rect[1]) + (1.5 if outside else -0.5))

func update_gate() -> void:
	if terrain.gate_broken or not params.structures.gate_auto_open:
		return
	var center := Vector3(float(params.map.gate_rect[0]) + float(params.map.gate_rect[2]) * 0.5, 0, float(params.map.gate_rect[1]) + 0.5)
	var want := false
	for u in nearby(center, float(params.director.gate_trigger_radius), 1):
		if u.marching:
			want = true
	var safe := nearby(center, float(params.structures.gate_safe_radius), 0).is_empty()
	if want and safe:
		gate_close_at = time + float(params.structures.gate_open_seconds)
		if not terrain.gate_open:
			terrain.gate_open = true
			terrain.change(params.map.gate_rect, true, time, "defender_opened_gate")
	if terrain.gate_open and time >= gate_close_at:
		var in_gate := false
		for u in units:
			if u.alive and terrain.in_rect(u.nav_pos, params.map.gate_rect):
				in_gate = true
		if not in_gate:
			terrain.gate_open = false
			terrain.change(params.map.gate_rect, false, time, "defender_closed_gate")

func update_captures(dt: float) -> void:
	if retreat_started:
		return
	for z in params.map.zones:
		var ghosts := 0
		var guards := 0
		for u in units:
			if u.alive and u.cave_until < 0 and terrain.zone_at(u.nav_pos) == z.id:
				if u.faction == 0: ghosts += 1
				else: guards += 1
		var state: Dictionary = zones[z.id]
		if state.owner == "defender":
			if ghosts > 0 and guards == 0:
				state.progress += dt
				if state.progress + 0.000001 >= float(params.capture.seconds):
					state.owner = "ghost"
					state.progress = 0.0
					state.captures.append(snappedf(time, 0.001))
					if z.id == "keep":
						win("keep_retreat")
						start_retreat()
			else:
				if state.progress > 0 and guards > 0:
					state.contested_resets.append(snappedf(time, 0.001))
				state.progress = 0.0
		else:
			if guards > 0 and ghosts == 0:
				state.retake += dt
				if state.retake + 0.000001 >= float(params.capture.defender_seconds):
					state.owner = "defender"
					state.retake = 0.0
					state.losses.append(snappedf(time, 0.001))
			else:
				state.retake = 0.0

func win(method: String) -> void:
	if won:
		return
	won = true
	victory_method = method
	victory_time = time

func start_retreat() -> void:
	retreat_started = true
	retreat_at = time
	boat_depart_at = time + float(params.retreat.boat_depart_seconds)
	# 剩余守军解除战斗；打开现有城门，保证所有驻地都能跑到港口。
	if not terrain.gate_open:
		terrain.gate_open = true
		terrain.change(params.map.gate_rect, true, time, "retreat_gate_open")
	for u in sides[1].units:
		if u.alive:
			u.retreating = true
			u.dangerous = false
			u.dispatch_to = ""
			u.dispatch_at = -1

func update_retreat() -> void:
	var port: Vector3 = terrain.vec(params.map.port)
	for u in sides[1].units:
		if u.alive and Vector2(u.nav_pos.x - port.x, u.nav_pos.z - port.z).length() <= float(params.retreat.boarding_radius):
			u.leave_ship()
			escaped += 1
	if time >= boat_depart_at:
		finish()

func on_death(u) -> void:
	casualties[u.faction] += 1
	if u.faction == 1:
		if u.kind == "archer":
			archer_deaths.append(snappedf(time, 0.001))
		if retreat_started:
			intercepted += 1
		if params.economy.kill_reward_enabled:
			var reward := float(params.economy.kill_reward)
			fire_generated += reward
			fire_wasted += maxf(0, fire + reward - float(params.economy.capacity))
			fire = minf(float(params.economy.capacity), fire + reward)

func fire_arrow(archer, target) -> void:
	if retreat_started or not target.alive:
		return
	if sim_rng.randf() <= float(params.units.archer.accuracy):
		var delta: Vector3 = target.nav_pos - archer.nav_pos
		var cfg: Dictionary = params.units.archer
		target.deal_damage({"damage": float(cfg.damage), "knockback": float(cfg.knockback), "stun": float(cfg.stun), "dir": Vector3(delta.x, 0, delta.z).normalized(), "arrow": true})
	if view != null:
		view.arrow(archer.nav_pos, target.nav_pos)

func finish() -> void:
	finished = true
	ended_at = time
	if retreat_started:
		stranded = sides[1].units.filter(func(u): return u.alive).size()

func result() -> Dictionary:
	var captures := {}
	var losses := {}
	var resets := {}
	for id in zones:
		captures[id] = zones[id].captures
		losses[id] = zones[id].losses
		resets[id] = zones[id].contested_resets
	var early := archer_deaths.filter(func(t): return t <= float(params.strategies.early_archer_seconds)).size()
	var configs := JSON.stringify(params, "", true, true)
	return {"schema_version": 1, "seed": seed_value, "strategy": strategy, "params_sha256": configs.sha256_text(),
		"won": won, "victory_method": victory_method, "victory_time": snappedf(victory_time, 0.001), "ended_at": snappedf(ended_at, 0.001),
		"zone_captures": captures, "zone_losses": losses, "capture_resets": resets,
		"retreat": {"started_at": snappedf(retreat_at, 0.001), "boat_depart_at": snappedf(boat_depart_at, 0.001), "escaped": escaped, "intercepted": intercepted, "stranded": stranded},
		"casualties": {"ghost": casualties[0], "defender": casualties[1]}, "spawned": {"ghost": spawned[0], "defender": spawned[1]},
		"waves": waves, "rallies": rally_events, "fire_wasted": snappedf(fire_wasted, 0.001), "fire_generated": snappedf(fire_generated, 0.001), "fire_spent": snappedf(fire_spent, 0.001), "fire_remaining": snappedf(fire, 0.001),
		"defender_dispatches": director.dispatches, "dispatch_decisions": director.decisions, "kingdom_reinforcements_arrived": director.reinforcements_arrived,
		"congestion_events": congestion, "travel_congestion_events": travel_congestion, "congestion_per_deployed": snappedf(float(congestion) / maxf(1, spawned[0] + spawned[1]), 0.0001),
		"reroutes": reroutes, "cave_transits": cave_transits, "archer_kill_times": archer_deaths, "early_archer_kills": early,
		"topology_events": terrain.topology_events, "flow_repairs": terrain.flow_repairs, "flow_relaxed_cells": terrain.repaired_cells, "combat_events": events,
		"simulation_steps": ceili(ended_at / float(params.simulation.step))}

func note(event: String) -> void:
	events[event] = events.get(event, 0) + 1

func shake(_amount: float) -> void:
	pass

func spawn_spark(_pos: Vector3) -> void:
	pass

func _exit_tree() -> void:
	for u in units:
		u.dispose()
	for side in sides:
		side.units.clear()
	spatial.clear()
	units.clear()
	director.main = null
	if bot != null:
		bot.main = null
