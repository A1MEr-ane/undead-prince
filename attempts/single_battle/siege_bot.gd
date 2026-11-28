extends RefCounted
## 机器人只能通过部署及付费集结操作；没有战斗数值加成。
var main
var strategy: String
var remaining := 0
var next_deploy := 0.0
var released := false
var serial := 0
var wave_index := 0
var idle_end := 0.0

func setup(world, name: String) -> void:
	main = world
	strategy = name

func tick() -> void:
	if main.outcome != main.Outcome.ACTIVE:
		return
	if strategy == "mixed":
		tick_mixed()
		return
	if main.phase_b.enabled and strategy in ["assassin_first", "giant_breach", "prep_control"]:
		tick_preparation()
		return
	var cfg: Dictionary = main.params.strategies
	var eco: Dictionary = main.params.economy
	if strategy == "idle" and not released:
		if main.time < float(main.params.simulation.night_seconds) - float(cfg.idle_seconds_before_dawn):
			return
		released = true
		idle_end = main.time + float(cfg.idle_release_seconds)
		remaining = floori(main.fire / float(eco.unit_cost))
		wave_index += 1
	if strategy == "idle" and main.time > idle_end:
		remaining = 0
		return
	if strategy == "late_batches" and main.time < float(cfg.late_start_seconds):
		return
	if remaining <= 0:
		if strategy == "idle":
			return
		if strategy in ["waves", "late_batches"]:
			var threshold := float(eco.capacity) * (float(cfg.late_capacity_fraction) if strategy == "late_batches" else 1.0)
			if main.fire < threshold - 0.000001:
				return
			remaining = floori(main.fire / float(eco.unit_cost))
		else:
			if main.fire < float(cfg.continuous_batch) * float(eco.unit_cost):
				return
			remaining = int(cfg.continuous_batch)
		wave_index += 1
	if main.time < next_deploy:
		return
	next_deploy = main.time + float(eco.deploy_interval)
	var route := "main"
	match strategy:
		"highland": route = "side"
		"feint":
			route = "main" if serial % int(cfg.feint_divisor) < int(cfg.feint_main_count) else ("cave" if main.params.map.cave_enabled else "side")
		"waves": route = cfg.wave_routes[(wave_index - 1) % cfg.wave_routes.size()]
	if route == "cave" and not main.params.map.cave_enabled:
		route = "side"
	var p: Vector3 = main.terrain.vec(cfg.deploy_points[route])
	p.x += main.sim_rng.randf_range(-float(cfg.lane_spread), float(cfg.lane_spread))
	p.z += main.sim_rng.randf_range(-float(cfg.lane_spread), float(cfg.lane_spread))
	var success: bool
	if main.phase_b.analysis:
		var hint: String = cfg.get("route_by_strategy", {}).get(strategy, route)
		var focus: bool = cfg.get("archer_focus_by_strategy", {}).get(strategy, true)
		success = main.deploy(p, "ghost", hint, focus)
	else:
		success = main.deploy(p)
	if success:
		remaining -= 1
		serial += 1

func tick_preparation() -> void:
	var cfg: Dictionary = main.phase_b.cfg
	var eco: Dictionary = main.params.economy
	var prep_kind := "assassin" if strategy == "assassin_first" else "giant"
	var prep_count := int(cfg.prep_assassins if strategy == "assassin_first" else cfg.prep_giants) if strategy != "prep_control" else 0
	if main.time < next_deploy or main.fire_spent >= float(cfg.total_budget) - 0.000001:
		return
	var kind := "ghost"
	var route := "main"
	var p: Vector3 = main.terrain.vec(main.params.strategies.deploy_points.main)
	if serial < prep_count and main.time < float(cfg.prep_deadline):
		kind = prep_kind
		route = "cliff" if kind == "assassin" else "breach:" + str(cfg.breach_target)
		p.x = float(cfg.cliff_entry[0]) + 0.5 if kind == "assassin" else float(main.phase_b.walls[cfg.breach_target].rect[0]) + 0.5
	else:
		if main.time < float(cfg.main_start):
			return
		if remaining <= 0:
			var budget: float = minf(float(cfg.main_wave_fire), float(cfg.total_budget) - main.fire_spent)
			if main.fire + 0.000001 < budget:
				return
			remaining = floori(budget / float(eco.unit_cost))
		if strategy == "giant_breach":
			route = "breach:" + str(cfg.breach_target)
			p.x = float(main.phase_b.walls[cfg.breach_target].rect[0]) + 0.5
	var cost: float = main.phase_b.cost(kind)
	if main.fire_spent + cost > float(cfg.total_budget) + 0.000001:
		return
	# 对照组和准备组使用同一主力开始时间、每波预算、间隔及总预算。
	p.x += main.sim_rng.randf_range(-0.3, 0.3)
	p.z += main.sim_rng.randf_range(-0.3, 0.3)
	if main.deploy(p, kind, route, kind == "assassin"):
		serial += 1
		if kind == "ghost": remaining -= 1
		next_deploy = main.time + (float(eco.wave_gap_seconds) + float(main.params.simulation.step) if kind == "ghost" and remaining == 0 else float(eco.deploy_interval))

func tick_mixed() -> void:
	if main.time < next_deploy:
		return
	if main.spell_uses < int(main.params.spell.charges):
		var target_faction := 0 if main.params.spell.active == "frenzy" else 1
		for u in main.sides[target_faction].units:
			if u.targetable() and u.enemy_dist < 4.0 and main.cast_spell(u.nav_pos):
				break
	var roster := ["giant", "ghost", "assassin", "ghost", "lich", "ghost", "ghost", "ghost"]
	var kind: String = roster[serial % roster.size()]
	var route := "side" if kind == "assassin" else "main"
	var pos: Vector3 = main.terrain.vec(main.params.strategies.deploy_points[route])
	var spread := float(main.params.strategies.lane_spread)
	pos.x += main.sim_rng.randf_range(-spread, spread)
	pos.z += main.sim_rng.randf_range(-0.5, 0.5)
	next_deploy = main.time + float(main.params.economy.deploy_interval)
	if main.deploy(pos, kind, route):
		serial += 1
