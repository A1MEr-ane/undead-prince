extends RefCounted
## 可选实验层；关闭时不接入模拟、参数或 SIEGE 字段。
var main
var cfg := {}
var enabled := false
var analysis := false
var walls := {}
var kind_stats := {}
var assassinations: Array = []
var detections: Array = []
var route_choices := {}
var phase_peaks := {}
var climb_transits := 0

func setup(world) -> void:
	main = world
	cfg = main.params.get("phase_b", {})
	enabled = cfg.get("enabled", false)
	analysis = enabled or main.params.get("analysis", {}).get("enabled", false)
	if enabled and cfg.get("walls", true):
		for wall in cfg.breakable_walls:
			walls[wall.id] = {"rect": wall.rect, "hp": float(wall.hp), "max_hp": float(wall.hp), "broken": false}
			main.structure_work[wall.id] = {"started_at": -1.0, "breached_at": -1.0, "active_seconds": 0.0, "attacker_seconds": 0.0}
	if analysis:
		for kind in ["ghost", "assassin", "giant"]:
			if available(kind): stats(kind)
		for phase in ["early", "middle", "late", "retreat"]:
			phase_peaks[phase] = {"ghost": 0, "defender": 0, "total": 0, "by_kind": {}}

func available(kind: String) -> bool:
	return kind == "ghost" or (enabled and kind in ["assassin", "giant"] and cfg.get(kind, true))

func cost(kind: String) -> float:
	return float(main.params.economy.unit_cost if kind == "ghost" else main.params.units[kind].cost)

func stats(kind: String) -> Dictionary:
	if not kind_stats.has(kind):
		kind_stats[kind] = {"deployed": 0, "fire": 0.0, "kills": 0, "archer_kills": 0, "damage": 0.0, "structure_damage": 0.0, "deaths": 0, "sweeps": 0}
	return kind_stats[kind]

func deployed(u, spent: float) -> void:
	var record := stats(u.kind)
	record.deployed += 1
	record.fire += spent
	choice(u, "deploy")

func choice(u, reason: String) -> void:
	if not route_choices.has(u.route):
		route_choices[u.route] = {"deployed": 0, "rerouted_in": 0, "by_kind": {}}
	var record: Dictionary = route_choices[u.route]
	if reason == "deploy":
		record.deployed += 1
		record.by_kind[u.kind] = record.by_kind.get(u.kind, 0) + 1
	else:
		record.rerouted_in += 1

func can_cave(u) -> bool:
	if not u.main.params.map.cave_enabled:
		return false
	if not enabled:
		return true
	match cfg.get("cave_permission", "all"):
		"undead": return u.faction == 0
		"assassin": return u.faction == 0 and u.kind == "assassin"
	return true

func start_transit(u, exit: Vector3, seconds: float, kind: String) -> void:
	u.cave_until = main.time + seconds
	u.cave_exit = exit
	u.transit_kind = kind
	u.enemy = null
	if kind == "cliff": climb_transits += 1
	else: main.cave_transits += 1

func reveal(u, reason: String) -> void:
	if u.kind != "assassin" or u.detected:
		return
	u.detected = true
	detections.append({"time": snappedf(main.time, 0.001), "unit": u.id, "reason": reason})

func update_detection() -> void:
	if not enabled:
		return
	for u in main.sides[0].units:
		if not u.alive or u.kind != "assassin" or u.detected or u.cave_until >= 0:
			continue
		for guard in main.nearby(u.nav_pos, float(cfg.detection_radius), 1):
			if main.effective_defender(guard) and main.terrain.line_clear(u.nav_pos, guard.nav_pos):
				reveal(u, "guard_line_of_sight")
				break

func visible(u) -> bool:
	return not enabled or u.kind != "assassin" or u.detected

func enemy_score(u, enemy) -> float:
	var distance: float = u.distance_to(enemy.nav_pos)
	if analysis and u.faction == 0 and u.focus_archers and distance <= float(main.params.brain.idle_enemy_distance) and enemy.kind in ["archer", "priest"]:
		distance -= float(main.params.targeting.values.archer) * float(main.params.targeting.value_weight)
	return distance

func can_climb(u) -> bool:
	if not enabled or u.kind != "assassin":
		return false
	var entry: Vector3 = main.terrain.vec(cfg.cliff_entry)
	var exit: Vector3 = main.terrain.vec(cfg.cliff_exit)
	if not main.terrain.is_walkable_at(entry) or not main.terrain.is_walkable_at(exit):
		return false
	var to_entry: float = main.terrain.distance(u.nav_pos, entry)
	if to_entry >= float(main.params.map.flow_infinity):
		return false
	return to_entry + float(cfg.cliff_seconds) * u.speed < main.terrain.distance(u.nav_pos, exit)

func special_order(u) -> bool:
	if not enabled or u.retreating or main.retreat_started:
		return false
	if u.kind == "assassin":
		return assassin_order(u)
	if u.kind == "giant" or u.route.begins_with("breach:"):
		return breach_order(u)
	return false

func assassin_order(u) -> bool:
	if u.route == "cliff" and u.stage == 0:
		u.slot = main.terrain.vec(cfg.cliff_entry)
		u.objective = "cliff"
		if u.distance_to(u.slot) <= float(main.params.map.cave_entry_radius):
			start_transit(u, main.terrain.vec(cfg.cliff_exit), float(cfg.cliff_seconds), "cliff")
		return true
	if u.route == "cliff":
		u.route = "side"
		u.stage = 1
	if u.rear_target >= 0:
		var rear = main.units[u.rear_target]
		if not rear.alive:
			u.rear_target = -1
		elif rear.cave_until < 0 and main.terrain.is_walkable_at(rear.nav_pos):
			u.slot = rear.nav_pos
			u.objective = rear.kind
			return true
		else:
			# 目标在洞内时沿进攻路线推进，等待目标出洞。
			return false
	var best := float(main.params.map.flow_infinity)
	for enemy in main.sides[1].units:
		if not main.effective_defender(enemy) or enemy.cave_until >= 0 or enemy.kind not in ["archer", "priest"]:
			continue
		var distance: float = main.terrain.distance(u.nav_pos, enemy.nav_pos)
		if distance < best:
			best = distance
			u.rear_target = enemy.id
	if u.rear_target < 0:
		return false
	u.slot = main.units[u.rear_target].nav_pos
	u.objective = main.units[u.rear_target].kind
	return true

func breach_order(u) -> bool:
	var targets := {"gate": {"rect": main.params.map.gate_rect, "broken": main.terrain.gate_broken or main.terrain.gate_open},
		"weak": {"rect": main.params.map.weak_rect, "broken": main.terrain.weak_broken}}
	targets.merge(walls)
	if u.breach_target.is_empty():
		var hint: String = u.route.trim_prefix("breach:") if u.kind != "giant" else ""
		var best := INF
		for id in targets:
			var wall: Dictionary = targets[id]
			if (hint.is_empty() and wall.broken) or (not hint.is_empty() and hint != id):
				continue
			var approach: Dictionary = main.approach_structure(u, wall.rect)
			if not approach.is_empty() and approach.distance < best:
				best = approach.distance
				u.breach_target = id
				u.breach_approach = approach.pos
				u.breach_crossing = approach.through
	if u.breach_target.is_empty():
		return false
	var wall: Dictionary = targets[u.breach_target]
	if not wall.broken:
		u.objective = u.breach_target
		u.slot = u.breach_approach
	elif not u.breach_passage and main.terrain.is_walkable_at(u.breach_crossing):
		u.objective = "flag"
		u.slot = u.breach_crossing
		u.breach_passage = u.distance_to(u.slot) < float(main.params.targeting.route_waypoint_radius) * 0.5
	else:
		u.objective = "flag"
		u.slot = main.zone_point("keep")
	return true

func special_tick(u) -> void:
	var config: Dictionary = main.params.units[u.kind]
	u.apply_order()
	var breaching: bool = u.kind == "giant" and u.objective == u.breach_target and not u.breach_target.is_empty()
	if u.kind == "giant":
		var victims: Array = []
		for enemy in main.nearby(u.nav_pos, float(config.sweep_radius), 1):
			if main.terrain.line_clear(u.nav_pos, enemy.nav_pos) and not enemy.retreating:
				victims.append(enemy)
		if victims.size() >= int(config.sweep_min_enemies) and main.time >= u.next_special:
			u.next_special = main.time + float(config.sweep_cooldown)
			stats(u.kind).sweeps += 1
			u.play("attack")
			for enemy in victims:
				hit(u, enemy, float(config.sweep_damage))
	if not u.can_see_enemy(u.enemy):
		return
	var reach: float = float(config.melee_range) + u.radius + u.enemy.radius
	if u.enemy_dist <= reach and main.terrain.line_clear(u.nav_pos, u.enemy.nav_pos):
		if not breaching:
			u.walk_dir = Vector3.ZERO
		u.look(u.enemy_dir)
		if main.time >= u.next_melee:
			u.next_melee = main.time + float(config.cooldown)
			u.play("attack")
			reveal(u, "attack")
			hit(u, u.enemy, float(config.damage))
	elif u.enemy_dist <= float(main.params.combat.chase_radius) and not breaching:
		u.walk_dir = u.enemy_dir

func hit(u, victim, damage: float) -> void:
	var delta: Vector3 = victim.nav_pos - u.nav_pos
	victim.deal_damage({"damage": damage, "knockback": float(main.params.units[u.kind].knockback), "stun": float(main.params.units[u.kind].stun), "dir": Vector3(delta.x, 0, delta.z).normalized(), "source": u})

func damage(victim, source, amount: float) -> void:
	if not analysis:
		return
	if source != null and source.faction == 0:
		stats(source.kind).damage += minf(maxf(0, victim.hp), amount)
	if enabled and amount > 0:
		reveal(victim, "hurt")

func killed(victim, source) -> void:
	if not analysis:
		return
	if victim.faction == 0:
		stats(victim.kind).deaths += 1
	if source != null and source.faction == 0:
		var record := stats(source.kind)
		record.kills += 1
		if victim.kind == "archer": record.archer_kills += 1
		if source.kind == "assassin" and victim.kind in ["archer", "priest"]:
			assassinations.append({"time": snappedf(main.time, 0.001), "unit": source.id, "victim": victim.id, "kind": victim.kind})

func at_structure(u) -> bool:
	var world = u.main
	var rect: Array = []
	if u.objective == "gate" and not world.terrain.gate_open: rect = world.params.map.gate_rect
	elif u.objective == "weak" and not world.terrain.weak_broken: rect = world.params.map.weak_rect
	elif walls.has(u.objective) and not walls[u.objective].broken: rect = walls[u.objective].rect
	if rect.is_empty(): return false
	var p := Vector2(clampf(u.nav_pos.x, rect[0], rect[0] + rect[2]), clampf(u.nav_pos.z, rect[1], rect[1] + rect[3]))
	return Vector2(u.nav_pos.x, u.nav_pos.z).distance_to(p) <= float(world.params.structures.attack_range) and world.terrain.line_clear(u.nav_pos, Vector3(p.x, 0, p.y).move_toward(u.nav_pos, 0.001))

func attack_structures(dt: float) -> void:
	var targets := {"gate": {"rect": main.params.map.gate_rect, "hp": main.gate_hp, "broken": main.terrain.gate_open}, "weak": {"rect": main.params.map.weak_rect, "hp": main.weak_hp, "broken": main.terrain.weak_broken}}
	targets.merge(walls)
	for id in targets:
		var wall: Dictionary = targets[id]
		if wall.broken:
			continue
		var attackers: Array = []
		for u in main.sides[0].units:
			if not u.alive or u.cave_until >= 0 or u.objective != id or main.time < maxf(u.stun_until, u.rise_until):
				continue
			if u.kind != "giant" and u.enemy_dist < float(main.params.combat.chase_radius):
				continue
			if at_structure(u):
				attackers.append(u)
		if attackers.size() < (int(main.params.structures.weak_min_attackers) if id == "weak" else 1):
			continue
		var work: Dictionary = main.structure_work[id]
		if work.started_at < 0: work.started_at = maxf(0, main.time - dt)
		work.active_seconds += dt
		work.attacker_seconds += attackers.size() * dt
		for u in attackers:
			var dps := float(main.params.units.giant.structure_dps) if u.kind == "giant" else float(main.params.structures.damage_per_second)
			var amount := minf(maxf(0, wall.hp), dps * dt)
			wall.hp -= amount
			stats(u.kind).structure_damage += amount
		if id == "gate": main.gate_hp = wall.hp
		elif id == "weak": main.weak_hp = wall.hp
		if wall.hp <= 0.000001:
			wall.broken = true
			work.breached_at = main.time
			if id == "gate":
				main.terrain.gate_broken = true
				main.terrain.gate_open = true
			elif id == "weak": main.terrain.weak_broken = true
			main.terrain.change(wall.rect, true, main.time, id + "_breached")

func sample_peaks() -> void:
	if not analysis:
		return
	var progress: float = main.time / float(main.params.simulation.night_seconds)
	var phase := "retreat" if main.retreat_started else "early" if progress < 0.4 else "middle" if progress < 0.8 else "late"
	var record: Dictionary = phase_peaks[phase]
	var counts := {"ghost": 0, "defender": 0}
	var kinds := {}
	for u in main.units:
		if u.alive:
			counts["ghost" if u.faction == 0 else "defender"] += 1
			kinds[u.kind] = kinds.get(u.kind, 0) + 1
	for side in counts: record[side] = maxi(record[side], counts[side])
	record.total = maxi(record.total, counts.ghost + counts.defender)
	for kind in kinds: record.by_kind[kind] = maxi(record.by_kind.get(kind, 0), kinds[kind])

func result() -> Dictionary:
	return {"metrics_version": "T74-movement-intent-v1", "phase_live_peaks": phase_peaks, "route_choice_distribution": route_choices, "unit_results": kind_stats, "assassination_events": assassinations, "detection_events": detections, "cliff_transits": climb_transits, "breakable_walls": walls}
