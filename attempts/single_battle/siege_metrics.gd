extends RefCounted
## 路线探针仅作时间尺度测量，不消耗战斗 RNG、不修改战场。
const Map = preload("res://attempts/single_battle/siege_map.gd")

static func describe(world) -> Dictionary:
	var params: Dictionary = world.params
	var m = Map.new()
	m.setup(params)
	var area := 0
	var land_area := 0
	var low := Vector2i(m.width, m.depth)
	var high := Vector2i.ZERO
	for i in m.land.size():
		if m.land[i] != 0:
			land_area += 1
		if m.land[i] != 0 and m.blocked[i] == 0:
			area += 1
			low = low.min(Vector2i(i % m.width, i / m.width))
			high = high.max(Vector2i(i % m.width, i / m.width))
	var routes := {}
	for name in params.map.routes:
		if name == "cave" and not params.map.cave_enabled:
			routes[name] = {"enabled": false}
			continue
		var probe = Map.new()
		probe.setup(params)
		probe.change(params.map.gate_rect if name == "main" else params.map.weak_rect, true, 0, "probe")
		var points: Array = [probe.vec(params.strategies.deploy_points[name])]
		for p in params.map.routes[name]:
			points.append(probe.vec(p))
		var elapsed := 0.0
		var contact = null
		var length := 0.0
		for n in range(1, points.size()):
			if name == "cave" and n == 2:
				elapsed += float(params.map.cave_travel_seconds)
				continue
			var path := path_points(probe, points[n - 1], points[n])
			if path.is_empty():
				elapsed = -1.0
				break
			for j in range(1, path.size()):
				var segment: float = path[j - 1].distance_to(path[j])
				var samples := maxi(1, ceili(segment / 0.25))
				for sample in range(samples + 1):
					if contact != null:
						break
					var p: Vector3 = path[j - 1].lerp(path[j], float(sample) / samples)
					for guard in world.sides[1].units:
						var reach := float(params.units.archer.range) if guard.kind == "archer" else float(params.combat.chase_radius)
						if world.effective_defender(guard) and p.distance_to(guard.nav_pos) <= reach and probe.line_clear(p, guard.nav_pos):
							contact = snappedf(elapsed + segment * sample / samples / float(params.units.ghost.speed), 0.001)
							break
				elapsed += segment / float(params.units.ghost.speed)
				length += segment
		var wall_hp := float(params.structures.gate_hp if name == "main" else params.structures.weak_hp if name == "side" else 0)
		routes[name] = {"enabled": true, "movement_distance": snappedf(length, 0.001), "contact_seconds_no_combat": contact, "keep_seconds_no_combat": snappedf(elapsed, 0.001), "obstacle_seconds_one_ghost": snappedf(wall_hp / float(params.structures.damage_per_second), 0.001)}
	m.change(params.map.gate_rect, true, 0, "defender_estimate")
	var support: Array = []
	for source in params.map.zones:
		for target in params.map.zones:
			if source.id == target.id:
				continue
			var distance: float = m.distance(world.zone_point(source.id), world.zone_point(target.id), false)
			var times := {}
			for kind in ["shield", "archer", "cavalry"]:
				times[kind] = snappedf(distance / float(params.units[kind].speed), 0.001) if distance < float(params.map.flow_infinity) else null
			support.append({"from": source.id, "to": target.id, "movement_distance": snappedf(distance, 0.001) if distance < float(params.map.flow_infinity) else null, "seconds_by_kind": times})
	return {"grid_dimensions": [m.width, m.depth], "walkable_bounds_dimensions": [high.x - low.x + 1, high.y - low.y + 1], "land_area": land_area, "walkable_area_closed": area, "walkable_area_all_breached": area + m.rect_cells(params.map.gate_rect).size() + m.rect_cells(params.map.weak_rect).size(), "routes": routes, "defender_routes": support, "weak_wall": {"hp": params.structures.weak_hp, "damage_per_ghost_second": params.structures.damage_per_second, "minimum_attackers": params.structures.weak_min_attackers, "three_ghost_seconds": snappedf(float(params.structures.weak_hp) / (float(params.structures.damage_per_second) * 3), 0.001), "solo_seconds": snappedf(float(params.structures.weak_hp) / float(params.structures.damage_per_second), 0.001)}}

static func path_points(map, start: Vector3, goal: Vector3) -> Array:
	var f: Dictionary = map.field(goal, false)
	var i: int = map.index(map.tile(start))
	if not map.is_walkable_at(start) or f.dist[i] >= float(map.cfg.flow_infinity):
		return []
	var points: Array = [start]
	for n in map.land.size():
		if i == f.goal:
			points.append(goal)
			return points
		i = f.next[i]
		if i < 0:
			return []
		points.append(map.point(i))
	return []
