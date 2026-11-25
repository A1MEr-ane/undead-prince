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
	if main.retreat_started:
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
	if remaining <= 0:
		if strategy == "idle":
			return
		if strategy == "waves":
			if main.fire < float(eco.capacity) - 0.000001:
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
	if main.deploy(p):
		remaining -= 1
		serial += 1
