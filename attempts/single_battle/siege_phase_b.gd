extends RefCounted
## 四种亡灵的专属行为、冥火弹和攻城。
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
		for kind in ["ghost", "assassin", "giant", "lich"]:
			if available(kind): stats(kind)
		for phase in ["early", "middle", "late", "retreat"]:
			phase_peaks[phase] = {"ghost": 0, "defender": 0, "total": 0, "by_kind": {}}

func available(kind: String) -> bool:
	return kind == "ghost" or (enabled and kind in ["assassin", "giant", "lich"] and cfg.get(kind, true))

func cost(kind: String) -> float:
	return float(main.params.units[kind].cost)

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
	if not u.main.params.map.cave_enabled or u.kind == "cavalry":
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
	u.clear_since = -1.0
	detections.append({"time": snappedf(main.time, 0.001), "unit": u.id, "reason": reason})

func update_abilities() -> void:
	for i in range(main.effects.size() - 1, -1, -1):
		if main.effects[i].end <= main.time:
			main.effects.remove_at(i)
	resolve_bolts()
	for u in main.sides[0].units:
		if not u.alive and u.bones_until >= 0.0 and main.time >= u.bones_until:
			u.bones_until = -1.0
			if (main.outcome == main.Outcome.ACTIVE and main.terrain.is_walkable_at(u.nav_pos)
					and main.nearby(u.nav_pos, float(main.params.units.ghost.reassemble_clear_radius), 1).is_empty()):
				u.reassemble()
		elif enabled and u.kind == "assassin" and u.targetable() and u.detected and not main.retreat_started:
			if main.nearby(u.nav_pos, float(main.params.units.assassin.disengage_radius), 1).is_empty():
				if u.clear_since < 0.0:
					u.clear_since = main.time
				elif main.time >= u.clear_since + float(main.params.units.assassin.restealth_seconds) - 0.000001:
					u.detected = false
					u.clear_since = -1.0
					main.note("restealth")
			else:
				u.clear_since = -1.0

func resolve_bolts() -> void:
	var pending: Array = []
	var cfg: Dictionary = main.params.units.lich
	for bolt in main.bolts:
		if main.time < bolt.end - 0.000001:
			pending.append(bolt)
			continue
		if not main.terrain.line_clear(bolt.from, bolt.to):
			continue
		main.effect("fire_impact", bolt.to, bolt.to, 0.42)
		for guard in main.nearby(bolt.to, float(cfg.blast_radius), 1):
			if main.terrain.line_clear(bolt.to, guard.nav_pos):
				guard.deal_damage({"damage": float(cfg.damage), "knockback": 0.0, "stun": float(cfg.stun),
					"dir": flat_direction(bolt.to, guard.nav_pos), "source": bolt.source, "spell": true})
				main.note("lich_stun")
	main.bolts = pending

func visible(u) -> bool:
	return not enabled or u.kind != "assassin" or u.detected

func enemy_score(u, enemy) -> float:
	var distance: float = u.distance_to(enemy.nav_pos)
	if analysis and u.faction == 0 and u.focus_archers and distance <= float(main.params.brain.idle_enemy_distance) and enemy.kind in ["archer", "priest"]:
		distance -= float(main.params.targeting.values.archer) * float(main.params.targeting.value_weight)
	return distance

func can_climb(u) -> bool:
	if not enabled or u.kind != "assassin" or not cfg.get("cliff_enabled", true):
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
	if u.route == "cliff" and u.stage == 0 and cfg.get("cliff_enabled", true):
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
		elif rear.targetable() and main.terrain.is_walkable_at(rear.nav_pos):
			u.slot = rear.nav_pos
			u.objective = rear.kind
			return true
		else:
			# 目标在洞内时沿进攻路线推进，等待目标出洞。
			return false
	var best := float(main.params.map.flow_infinity)
	for enemy in main.sides[1].units:
		if not main.effective_defender(enemy) or not enemy.targetable() or enemy.kind not in ["archer", "priest"]:
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
	if u.breach_passage and u.breach_target.is_empty():
		u.slot = main.zone_point("keep")
		u.objective = "flag"
		return true
	if u.breach_target.is_empty():
		var hint: String = u.route.trim_prefix("breach:") if u.route.begins_with("breach:") else ""
		var best := INF
		for id in targets:
			var wall: Dictionary = targets[id]
			if wall.broken or (not hint.is_empty() and hint != id):
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
		u.breach_target = ""
		u.route = main.choose_route(u, false)
		if not main.params.map.routes.has(u.route):
			u.route = "main"
		u.stage = 0
		var next: Vector3 = main.zone_point("keep")
		if main.terrain.distance(u.nav_pos, next) < float(main.params.map.flow_infinity):
			u.objective = "flag"
			u.slot = next
			# 通向主堡后，继续沿同一个目标推进。
			u.breach_passage = true
			return true
		u.breach_passage = false
		return breach_order(u)
	return true

func special_tick(u) -> void:
	var config: Dictionary = main.params.units[u.kind]
	u.apply_order()
	if u.kind == "lich":
		lich_tick(u, config)
		return
	var breaching: bool = u.kind == "giant" and u.objective == u.breach_target and not u.breach_target.is_empty()
	if u.kind == "giant" and main.time >= u.next_special and sweep(u, config):
		return
	if not u.can_see_enemy(u.enemy):
		return
	var reach: float = float(config.melee_range) + u.radius + u.enemy.radius
	if u.enemy_dist <= reach:
		if not breaching:
			u.walk_dir = Vector3.ZERO
		u.look(u.enemy_dir)
		if main.time >= u.next_melee:
			u.next_melee = main.time + float(config.cooldown) / u.attack_scale()
			var backstab: bool = u.kind == "assassin" and not u.detected and u.enemy.kind == "archer"
			u.play("backstab" if backstab else "attack")
			reveal(u, "attack")
			if backstab:
				main.effect("backstab", u.enemy.nav_pos, u.enemy.nav_pos, 0.32)
				main.note("backstab")
			hit(u, u.enemy, u.enemy.hp if backstab else float(config.damage), float(config.knockback), float(config.stun), backstab)
	elif u.enemy_dist <= float(main.params.combat.chase_radius) and not breaching:
		u.walk_dir = u.enemy_dir

func sweep(u, cfg: Dictionary) -> bool:
	var victims: Array = []
	for enemy in main.nearby(u.nav_pos, float(cfg.sweep_radius), 1):
		if main.terrain.line_clear(u.nav_pos, enemy.nav_pos) and not enemy.retreating:
			victims.append(enemy)
	if victims.size() < int(cfg.sweep_min_enemies):
		return false
	var threshold := cos(deg_to_rad(float(cfg.sweep_angle) * 0.5))
	var direction: Vector3 = u.facing
	var best := -1
	var axes: Array[Vector3] = [direction]
	for i in victims.size():
		var a := flat_direction(u.nav_pos, victims[i].nav_pos)
		axes.append(a)
		for j in range(i + 1, victims.size()):
			var b := flat_direction(u.nav_pos, victims[j].nav_pos)
			var middle := (a + b).normalized()
			if middle != Vector3.ZERO:
				axes.append(middle)
	for axis in axes:
		var count := 0
		for enemy in victims:
			count += int(axis.dot(flat_direction(u.nav_pos, enemy.nav_pos)) >= threshold)
		if count > best:
			best = count
			direction = axis
	u.next_special = main.time + float(cfg.sweep_cooldown) / u.attack_scale()
	stats(u.kind).sweeps += 1
	u.look(direction)
	u.play("sweep")
	main.effect("sweep", u.nav_pos, u.nav_pos + direction, 0.32)
	for enemy in victims:
		if direction.dot(flat_direction(u.nav_pos, enemy.nav_pos)) >= threshold:
			hit(u, enemy, float(cfg.sweep_damage), float(cfg.sweep_knockback), float(cfg.sweep_stun), false, true)
	return true

func lich_tick(u, cfg: Dictionary) -> void:
	if u.can_see_enemy(u.enemy):
		u.look(u.enemy_dir)
		if u.enemy_dist < float(cfg.backoff_range):
			u.walk_dir = -u.enemy_dir
		elif u.enemy_dist <= float(cfg.range):
			u.walk_dir = Vector3.ZERO
		if u.enemy_dist <= float(cfg.range) and main.time >= u.next_special and not main.retreat_started:
			u.next_special = main.time + float(cfg.cooldown) / u.attack_scale()
			var flight: float = u.enemy_dist / float(cfg.bolt_speed)
			main.bolts.append({"source": u, "from": u.nav_pos, "to": u.enemy.nav_pos, "end": main.time + flight})
			main.effect("fire_bolt", u.nav_pos, u.enemy.nav_pos, flight)
			u.play("cast")
			main.note("lich_bolt")
		return
	var ahead: Vector3 = u.order_dir.normalized()
	if ahead == Vector3.ZERO or main.retreat_started:
		return
	var closest := INF
	var screen = null
	for friend in main.nearby(u.nav_pos, float(cfg.range), 0):
		if friend.kind not in ["ghost", "giant"] or not main.terrain.line_clear(u.nav_pos, friend.nav_pos):
			continue
		var offset: Vector3 = friend.nav_pos - u.nav_pos
		offset.y = 0
		if offset.dot(ahead) > 0 and offset.length_squared() < closest:
			closest = offset.length_squared()
			screen = friend
	if screen != null:
		var gap: float = (screen.nav_pos - u.nav_pos).dot(ahead)
		u.walk_dir = ahead * clampf(gap - float(cfg.screen_distance), 0.0, 1.0)

func hit(u, victim, damage: float, knockback: float, stun: float, backstab := false, sweep_hit := false) -> void:
	victim.deal_damage({"damage": damage, "knockback": knockback, "stun": stun,
		"dir": flat_direction(u.nav_pos, victim.nav_pos), "source": u, "backstab": backstab, "sweep": sweep_hit})

static func flat_direction(from: Vector3, to: Vector3) -> Vector3:
	var delta := to - from
	delta.y = 0
	return delta.normalized()

func damage(victim, source, amount: float) -> void:
	if analysis and source != null and source.faction == 0:
		stats(source.kind).damage += minf(maxf(0, victim.hp), amount)

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
			if not u.targetable() or u.kind == "lich" or u.objective != id or main.time < maxf(u.stun_until, u.rise_until):
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
			var dps := float(main.params.structures.damage_per_second)
			if u.kind == "giant":
				dps *= float(main.params.units.giant.structure_multiplier)
			dps *= u.attack_scale()
			if main.time >= u.next_structure_pose:
				u.next_structure_pose = main.time + (float(main.params.units.giant.cooldown) if u.kind == "giant" else 0.85) / u.attack_scale()
				if not u.brain.attack.active:
					u.play("slam" if u.kind == "giant" else "attack")
				main.effect("dust", u.nav_pos, u.nav_pos, 0.39)
				reveal(u, "structure")
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
			main.director.travel_map.change(wall.rect, true, main.time, id + "_breached")
			var center := Vector3(float(wall.rect[0]) + float(wall.rect[2]) * 0.5, 0, float(wall.rect[1]) + float(wall.rect[3]) * 0.5)
			main.effect("dust", center, center, 0.85)

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
	return {"metrics_version": "single-battle-v1", "phase_live_peaks": phase_peaks, "route_choice_distribution": route_choices, "unit_results": kind_stats, "assassination_events": assassinations, "detection_events": detections, "cliff_transits": climb_transits, "breakable_walls": walls}
