extends RefCounted
## 固定周期感知 → 预留兵员 → 延迟出发 → 实际行军；不补伤亡、不修墙。

const Map = preload("res://proto/siege/siege_map.gd")
var travel_map = Map.new()
var history: Array = []
var main
var next_think := 0.0
var cooldown := {}
var threats := {}
var decisions: Array = []
var dispatches := 0
var reinforcements_arrived := false

func setup(world) -> void:
	main = world
	travel_map.setup(main.params)
	travel_map.change(main.params.map.gate_rect, true, 0, "estimate_gate_access")
	for zone in main.params.map.zones:
		cooldown[zone.id] = 0.0
		threats[zone.id] = 0.0

func record(event: Dictionary) -> void:
	event.time = snappedf(main.time, 0.001)
	decisions.append(event)

func tick() -> void:
	if main.retreat_started:
		return
	var cfg: Dictionary = main.params.director
	for u in main.sides[1].units:
		if not u.alive or u.dispatch_at < 0 or main.time < u.dispatch_at:
			continue
		var from: String = u.assigned
		var retained := 0
		var minimum := 0
		for zone in main.params.map.zones:
			if zone.id == from:
				minimum = int(zone.min_garrison)
		for friend in main.sides[1].units:
			if friend.alive and friend.assigned == from and not friend.marching and main.terrain.zone_at(friend.nav_pos) == from:
				retained += 1
		if retained <= minimum:
			record({"event": "cancelled", "unit": u.id, "from": from, "to": u.dispatch_to, "reason": "garrison_min_after_losses"})
			u.dispatch_to = ""
			u.dispatch_at = -1
			continue
		u.mission_from = from
		u.departed_at = main.time
		u.expected_arrival = main.time + travel_seconds(u.nav_pos, main.zone_point(u.dispatch_to), u.speed)
		u.assigned = u.dispatch_to
		u.dispatch_to = ""
		u.dispatch_at = -1
		u.reserve = false
		u.marching = true
		u.anchor = main.zone_point(u.assigned)
		u.slot = u.anchor
		dispatches += 1
		record({"event": "depart", "unit": u.id, "kind": u.kind, "from": from, "to": u.assigned, "reason": "perceived_threat", "estimated_arrival_at": snappedf(u.expected_arrival, 0.001), "estimated_travel_seconds": snappedf(u.expected_arrival - main.time, 0.001)})
	var rein: Dictionary = main.params.reinforcements
	if rein.enabled and not reinforcements_arrived and main.time >= float(main.params.simulation.night_seconds) - float(rein.seconds_before_dawn):
		reinforcements_arrived = true
		var total := 0
		for group in rein.units:
			for n in int(group.count):
				var p: Vector3 = main.terrain.vec(rein.spawn) + main.formation_offset(total)
				var u = main.spawn(group.kind, 1, p, "keep")
				u.reserve = true
				total += 1
		record({"event": "kingdom_reinforcements", "count": total})
	if main.time < next_think:
		return
	next_think = main.time + float(cfg.think_seconds)
	var visible: Array = []
	for ghost in main.sides[0].units:
		if ghost.alive and ghost.cave_until < 0 and perceived(ghost):
			visible.append(ghost)
	for z in main.params.map.zones:
		var threat := 0.0
		var center: Vector3 = main.zone_point(z.id)
		for u in visible:
			var distance: float = Vector2(u.nav_pos.x - center.x, u.nav_pos.z - center.z).length()
			if main.terrain.zone_at(u.nav_pos) == z.id:
				threat += float(cfg.threat_per_ghost)
			threat += maxf(0, 1 - distance / float(cfg.threat_radius)) * float(cfg.proximity_weight)
		if main.zones[z.id].owner == "ghost" and threat > 0:
			threat += float(cfg.retake_bias)
		threats[z.id] = threat
		var stationed := 0
		var assigned := 0
		for guard in main.sides[1].units:
			if main.effective_defender(guard):
				if guard.assigned == z.id: assigned += 1
				if main.terrain.zone_at(guard.nav_pos) == z.id: stationed += 1
		history.append({"time": snappedf(main.time, 0.001), "zone": z.id, "threat": snappedf(threat, 0.01), "stationed": stationed, "assigned": assigned})
	var targets: Array = main.params.map.zones.duplicate()
	targets.sort_custom(func(a, b):
		if threats[a.id] == threats[b.id]:
			return a.id < b.id
		return threats[a.id] > threats[b.id])
	for z in targets:
		if threats[z.id] < float(cfg.threat_threshold) or main.time < cooldown[z.id]:
			continue
		var donors: Array = []
		var available := {}
		for source in main.params.map.zones:
			var count := 0
			for u in main.sides[1].units:
				if u.alive and u.assigned == source.id and u.dispatch_to.is_empty() and not u.marching and main.terrain.zone_at(u.nav_pos) == source.id:
					count += 1
			available[source.id] = maxi(0, count - int(source.min_garrison))
		for u in main.sides[1].units:
			if not u.alive or u.assigned == z.id or not u.dispatch_to.is_empty() or u.marching or main.time < u.mission_lock_until:
				continue
			if main.terrain.zone_at(u.nav_pos) != u.assigned:
				continue
			if u.enemy != null and u.enemy_dist < float(cfg.busy_enemy_radius):
				continue
			if available[u.assigned] <= 0:
				continue
			donors.append(u)
		donors.sort_custom(func(a, b):
			if a.reserve != b.reserve:
				return a.reserve
			var da: float = main.terrain.distance(a.nav_pos, main.zone_point(z.id), false)
			var db: float = main.terrain.distance(b.nav_pos, main.zone_point(z.id), false)
			return a.id < b.id if da == db else da < db)
		var selected: Array = []
		var members: Array = []
		for u in donors:
			if selected.size() >= int(cfg.support_batch):
				break
			if available[u.assigned] <= 0:
				continue
			if travel_seconds(u.nav_pos, main.zone_point(z.id), u.speed) < 0:
				continue
			available[u.assigned] -= 1
			u.mission_lock_until = main.time + float(cfg.dispatch_delay) + float(cfg.mission_lock_seconds)
			u.dispatch_to = z.id
			u.dispatch_at = main.time + float(cfg.dispatch_delay)
			selected.append(u.id)
			members.append({"unit": u.id, "kind": u.kind, "from": u.assigned, "estimated_arrival_at": snappedf(u.dispatch_at + travel_seconds(u.nav_pos, main.zone_point(z.id), u.speed), 0.001)})
		if not selected.is_empty():
			cooldown[z.id] = main.time + float(cfg.dispatch_cooldown)
			record({"event": "ordered", "to": z.id, "units": selected, "members": members, "reason": "retake_perceived_zone" if main.zones[z.id].owner == "ghost" else "perceived_threat", "threat": snappedf(threats[z.id], 0.01), "depart_at": snappedf(main.time + float(cfg.dispatch_delay), 0.001)})


func unit_order(u) -> void:
	if main.retreat_started:
		u.retreating = true
		u.dangerous = false
		u.dispatch_at = -1
		u.slot = main.terrain.vec(main.params.map.port)
		return
	if u.marching and Vector2(u.nav_pos.x - u.anchor.x, u.nav_pos.z - u.anchor.z).length() < float(main.params.director.arrival_radius):
		u.marching = false
		u.mission_lock_until = main.time + float(main.params.director.mission_lock_seconds)
		u.anchor = main.terrain.nearest(u.anchor + main.formation_offset(u.id % int(main.params.director.formation_columns)))
		record({"event": "arrive", "unit": u.id, "from": u.mission_from, "to": u.assigned, "reason": "mission_arrival", "estimated_arrival_at": snappedf(u.expected_arrival, 0.001), "actual_arrival_at": snappedf(main.time, 0.001), "actual_travel_seconds": snappedf(main.time - u.departed_at, 0.001), "arrival_error_seconds": snappedf(main.time - u.expected_arrival, 0.001), "locked_until": snappedf(u.mission_lock_until, 0.001)})
	u.slot = u.anchor
	if u.enemy != null and u.enemy_dist < float(main.params.combat.defender_leash):
		if Vector2(u.enemy.nav_pos.x - u.anchor.x, u.enemy.nav_pos.z - u.anchor.z).length() <= float(main.params.combat.defender_leash) and main.terrain.line_clear(u.nav_pos, u.enemy.nav_pos):
			u.slot = u.enemy.nav_pos

func perceived(ghost) -> bool:
	if main.params.director.global_perception:
		return true
	for guard in main.sides[1].units:
		if main.effective_defender(guard) and guard.cave_until < 0 and Vector2(ghost.nav_pos.x - guard.nav_pos.x, ghost.nav_pos.z - guard.nav_pos.z).length() <= float(main.params.director.perception_radius):
			return true
	return false

func travel_seconds(a: Vector3, b: Vector3, speed: float) -> float:
	var distance: float = travel_map.distance(a, b, false)
	return -1.0 if distance >= float(main.params.map.flow_infinity) else distance / speed
