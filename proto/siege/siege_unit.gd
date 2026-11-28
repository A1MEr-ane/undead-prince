extends RefCounted
## 灰盒本体适配器：保留剑兵的备战/狩猎/冲锋/招架/拼刀，导航与渲染解耦。

const Brain = preload("res://proto/siege/siege_swordsman.gd")
const State = preload("res://scripts/agent_state.gd")

class ClockBeat:
	extends RefCounted
	var offset: float
	func hz(period: float) -> bool:
		return floorf((State.now + offset) / period) != floorf((State.now - State.dt + offset) / period)

var detected := false
var focus_archers := true
var next_melee := 0.0
var next_special := 0.0
var transit_kind := "cave"
var movement_since := -1.0
var movement_origin := Vector3.ZERO
var movement_reported := false
var main
var terrain
var squad: Dictionary
var id: int
var faction: int
var kind: String
var hp: float
var radius: float
var speed: float
var previous_pos := Vector3.ZERO
var spawn_time := 0.0
var initial_route := "main"
var victory_eligible := false
var target_key := ""
var behavior_changes: Array[float] = []
var enemy_lock_until := 0.0
var rally_received := -1
var rally_order := -1
var rallying := false
var rear_target := -1
var breach_passage := false
var breach_target := ""
var breach_approach := Vector3.ZERO
var breach_crossing := Vector3.ZERO
var route_approach := {}
var route_approach_kind := ""
var cave_queued_at := -1.0
var waiting_for_passage := false
var wants_to_move := false
var queued_behind := false
var impact := 0.0
var down_until := -1.0
var rise_until := -1.0
var mission_lock_until := 0.0
var mission_from := ""
var departed_at := -1.0
var expected_arrival := -1.0
var progress_at := 0.0
var progress_pos := Vector3.ZERO
var recovery_until := -1.0
var recovery_pos := Vector3.ZERO
var damage_in_progress := false
var alive := true
var escaped := false
var reserve := false
var retreating := false
var home: String
var assigned: String
var dispatch_to := ""
var dispatch_at := -1.0
var marching := false
var route := "main"
var stage := 0
var reroute_at := 0.0
var reroutes := 0
var objective := ""
var target_kind := ""
var target_pos := Vector3.ZERO
var nav_pos := Vector3.ZERO
var cell := Vector2i(-1, -1)
var slot := Vector3.ZERO
var anchor := Vector3.ZERO
var slot_look := Vector3.FORWARD
var facing := Vector3.FORWARD
var walk_dir := Vector3.ZERO
var velocity := Vector3.ZERO
var walked := 0.0
var order_dir := Vector3.ZERO
var order_dist := 0.0
var enemy = null
var enemy_dist := 1.0e6
var enemy_dir := Vector3.ZERO
var enemy_dangerous := false
var dangerous := true
var soft_int := 0.0
var hard_int := 0.0
var anim_name := "idle"
var anim_t := 0.0
var stun_until := 0.0
var next_arrow := 0.0
var next_sense := 0.0
var next_target := 0.0
var cave_until := -1.0
var cave_exit := Vector3.ZERO
var congestion_count := 0
var root
var alive_grounded
var dead
var hopping
var sliding
var move_animate
var brain
var beats := ClockBeat.new()

func setup(world, unit_id: int, type: String, side: int, pos: Vector3, zone: String) -> void:
	main = world
	terrain = world.terrain
	id = unit_id
	kind = type
	faction = side
	home = zone
	assigned = zone
	var stats: Dictionary = main.params.units[kind]
	hp = float(stats.hp)
	radius = float(stats.radius)
	speed = float(stats.speed)
	nav_pos = terrain.nearest(pos)
	nav_pos.y = terrain.height_at(nav_pos)
	cell = terrain.tile(nav_pos)
	previous_pos = nav_pos
	progress_pos = nav_pos
	spawn_time = main.time
	progress_at = main.time
	slot = nav_pos
	anchor = nav_pos
	beats.offset = main.sim_rng.randf() * float(main.params.combat.brain_seed_phase_range)
	next_target = main.time + main.sim_rng.randf() * float(main.params.targeting.think_seconds)
	next_sense = main.time + main.sim_rng.randf() * float(main.params.combat.sense_seconds)
	next_arrow = main.time + main.sim_rng.randf() * float(main.params.units.archer.cooldown)
	squad = main.sides[faction]
	root = State.new("Root", null, true, false)
	alive_grounded = State.new("Alive", root, true, true)
	dead = State.new("Dead", root, false, true)
	var exclusive = State.new("Exclusives", alive_grounded, true, false)
	hopping = State.new("Hop", root, true, false)
	sliding = State.new("Slide", root, false, false)
	move_animate = State.new("Animate", root, true, false)
	brain = Brain.new()
	var melee_stats := stats.duplicate()
	if kind == "archer":
		melee_stats.damage = stats.melee_damage
	brain.setup(self, exclusive, melee_stats)
	brain.idle.set_true()

func can_engage(victim) -> bool:
	if faction == 0:
		return main.retreat_started or kind != "assassin" or ((route != "cliff" or stage > 0) and (rear_target < 0 or rear_target == victim.id))
	if retreating:
		return false
	var leash := float(main.params.combat.defender_leash)
	if marching:
		return kind != "archer"
	return order_dist_to_anchor(victim.nav_pos) <= leash or (kind == "archer" and order_dist_to(victim.nav_pos) <= float(main.params.units.archer.range))

func order_dist_to_anchor(p: Vector3) -> float:
	return Vector2(p.x - anchor.x, p.z - anchor.z).length()

func change_behavior() -> bool:
	if behavior_changes.size() == 2:
		if main.time - behavior_changes[0] <= 10.0:
			return false
		behavior_changes.pop_front()
	behavior_changes.append(main.time)
	return true

func sense() -> void:
	if not alive or cave_until >= 0:
		return
	if not retreating and (main.time >= next_sense or (enemy != null and not enemy.alive)):
		# 半步余量使感知间隔保持为固定步数。
		var steps := int(main.params.combat.get("sense_steps", ceili(float(main.params.combat.sense_seconds) / float(main.params.simulation.step))))
		next_sense = main.time + (steps - 0.5) * float(main.params.simulation.step)
		var candidate = main.nearest_enemy(self)
		var current_valid := can_see_enemy(enemy)
		if enemy != null and not enemy.alive:
			enemy = null
		if candidate != null and candidate != enemy:
			var improves: bool = not current_valid or main.enemy_score(self, candidate) + float(main.params.targeting.enemy_switch_margin) < main.enemy_score(self, enemy)
			if enemy == null or (main.time >= enemy_lock_until and improves and change_behavior()):
				enemy = candidate
				enemy_lock_until = main.time + float(main.params.targeting.enemy_lock_seconds)
				main.note("enemy_switch")
		target_key = str(enemy.id) if enemy != null else ""
	enemy_dist = 1.0e6
	enemy_dir = Vector3.ZERO
	enemy_dangerous = false
	if can_see_enemy(enemy):
		var delta: Vector3 = enemy.nav_pos - nav_pos
		delta.y = 0
		enemy_dist = delta.length()
		enemy_dir = delta.normalized()
		enemy_dangerous = enemy.dangerous
		if not enemy.retreating and not retreating:
			enemy.brain.on_proximity(self)
	order_dist = distance_to(slot)
	var use_cave: bool = (rallying or (faction == 1 and main.phase_b.enabled)) and main.phase_b.can_cave(self)
	order_dir = terrain.direction(nav_pos, slot, use_cave)
	recover_navigation()
	soft_int = move_toward(soft_int, 0, State.dt * float(main.params.combat.threat_decay))
	hard_int = move_toward(hard_int, 0, State.dt * float(main.params.combat.threat_decay))

func can_see_enemy(victim) -> bool:
	return victim != null and victim.alive and victim.cave_until < 0 and not retreating and can_engage(victim) and (faction == 0 or main.phase_b.visible(victim)) and Vector2(victim.nav_pos.x - nav_pos.x, victim.nav_pos.z - nav_pos.z).length_squared() <= float(main.params.combat.sense_radius) ** 2 and terrain.line_clear(nav_pos, victim.nav_pos)

func tick(dt: float) -> void:
	if not alive:
		return
	if cave_until >= 0:
		if main.time >= cave_until and main.finish_transit(self):
			cave_until = -1
			cell = terrain.tile(nav_pos)
			if faction == 0 and route == "cave" and not rallying:
				stage = maxi(stage, 2)
			elif transit_kind == "cliff":
				stage = 1
		return
	anim_t += dt
	impact = move_toward(impact, 0, dt * 0.25)
	walk_dir = Vector3.ZERO
	if retreating:
		walk_dir = main.retreat_direction(self, order_dir).normalized()
		look(walk_dir)
	elif main.time < rise_until:
		update_knockdown()
	elif main.time < stun_until:
		pass
	elif rallying:
		apply_order()
	elif main.phase_b.enabled and kind in ["assassin", "giant"]:
		main.phase_b.special_tick(self)
	elif kind == "archer" and archer_uses_bow():
		brain.stamina = 1
		if enemy_dist <= float(main.params.units.archer.range):
			look(enemy_dir)
			if main.time >= next_arrow:
				next_arrow = main.time + float(main.params.units.archer.cooldown)
				main.fire_arrow(self, enemy)
		else:
			apply_order()
	else:
		tick_melee()
	if not alive:
		return
	if sliding.active and not brain.clash.active and main.time >= maxf(stun_until, rise_until):
		sliding.set_false()
	wants_to_move = walk_dir.length_squared() > 0.0025 or waiting_for_passage
	queued_behind = wants_to_move and not in_combat() and main.should_queue(self)
	if waiting_for_passage or queued_behind:
		walk_dir = Vector3.ZERO
	var separation: Vector3 = main.separation(self)
	var delta := walk_dir.limit_length(minf(1.0, 1.0 / maxf(speed * dt, 0.001))) * speed * dt
	if walk_dir == Vector3.ZERO and (waiting_for_passage or wants_to_move):
		separation = Vector3.ZERO
	var before := nav_pos
	nav_pos = move_safe(nav_pos, delta + separation * dt + velocity * dt)
	nav_pos.y = terrain.height_at(nav_pos)
	cell = terrain.tile(nav_pos)
	walked += Vector2(nav_pos.x - before.x, nav_pos.z - before.z).length()
	velocity = velocity.move_toward(Vector3.ZERO, dt * float(main.params.combat.velocity_decay))
	movement_congestion()

func archer_uses_bow() -> bool:
	if brain.attack.active:
		return false
	if enemy_dist > float(main.params.combat.chase_radius):
		return true
	return terrain.height_at(enemy.nav_pos) < terrain.height_at(nav_pos) and enemy_dist > radius + enemy.radius + brain.range_()

func tick_melee() -> void:
	root.update()
	if brain.attack.active or brain.parry.active or brain.clash.active:
		return
	var engage_distance := float(main.params.brain.idle_enemy_distance if faction == 0 else main.params.combat.chase_radius)
	if enemy_dist <= engage_distance and can_see_enemy(enemy):
		look(enemy_dir)
		var reach: float = radius + enemy.radius + brain.range_()
		if brain.stamina >= 0.0 and not brain.try_attack(enemy):
			walk_dir = enemy_dir
		elif enemy_dist <= reach:
			walk_dir = Vector3.ZERO
	elif order_dist > float(main.params.map.path_arrival_radius) and walk_dir.dot(order_dir) <= 0.01:
		apply_order()
	if faction == 1 and not marching and walk_dir.length_squared() > 0.0:
		var leash := float(main.params.combat.defender_leash)
		if order_dist_to_anchor(nav_pos + walk_dir * speed * State.dt) > leash:
			apply_order()

func in_combat() -> bool:
	return brain.attack.active or brain.parry.active or brain.clash.active or (enemy != null and enemy_dist <= radius + enemy.radius + brain.range_()) or main.phase_b.at_structure(self)

func movement_congestion() -> void:
	var cfg: Dictionary = main.params.targeting
	var intent: bool = waiting_for_passage or ((wants_to_move or walk_dir.length_squared() > 0.0025) and (order_dist > float(main.params.map.path_arrival_radius) or enemy_dist < float(main.params.combat.chase_radius)))
	if not intent or in_combat() or retreating or main.time < maxf(stun_until, rise_until) or cave_until >= 0:
		movement_since = -1
		movement_reported = false
		return
	if movement_since < 0 or Vector2(nav_pos.x - movement_origin.x, nav_pos.z - movement_origin.z).length() >= float(cfg.progress_epsilon):
		movement_origin = nav_pos
		movement_since = main.time
		movement_reported = false
	elif not movement_reported and main.time - movement_since >= float(cfg.congestion_seconds):
		movement_reported = true
		congestion_count += 1
		main.congestion += 1
		main.travel_congestion += 1

func recover_navigation() -> void:
	var cfg: Dictionary = main.params.targeting
	if order_dist <= float(main.params.map.path_arrival_radius) or in_combat() or waiting_for_passage or retreating or order_dir == Vector3.ZERO:
		progress_pos = nav_pos
		progress_at = main.time
		recovery_until = -1
		return
	if faction == 0 and queued_behind:
		return
	if main.time < recovery_until and distance_to(recovery_pos) > float(main.params.map.path_arrival_radius):
		order_dir = terrain.direction(nav_pos, recovery_pos)
		return
	if nav_pos.distance_to(progress_pos) >= float(cfg.progress_epsilon):
		progress_pos = nav_pos
		progress_at = main.time
		return
	if main.time - progress_at < float(cfg.stuck_seconds):
		return
	var field: Dictionary = terrain.field(slot, false)
	var here: int = terrain.index(terrain.tile(nav_pos))
	var best := INF
	var chosen := Vector3.ZERO
	for edge in terrain.neighbors(here, false):
		var p: Vector3 = terrain.point(edge[0])
		if edge[0] == field.next[here] or field.dist[edge[0]] >= float(main.params.map.flow_infinity) or field.dist[edge[0]] > field.dist[here] + 1:
			continue
		if main.nearby_count(p, 0.45, faction) > 0:
			continue
		var score: float = field.dist[edge[0]] + main.nearby_count(p, float(cfg.crowd_radius), faction) * float(cfg.congestion_weight)
		if score < best:
			best = score
			chosen = p
	if best < INF and change_behavior():
		recovery_pos = chosen
		recovery_until = main.time + float(cfg.stuck_seconds)
		order_dir = terrain.direction(nav_pos, chosen)
		main.recovery_events.append({"time": snappedf(main.time, 0.001), "unit": id, "from": [nav_pos.x, nav_pos.z], "to": [chosen.x, chosen.z]})
	progress_at = main.time

func update_knockdown() -> void:
	if main.time >= down_until:
		if anim_name != "rise":
			play("rise")
	elif anim_name == "fall" and anim_done():
		play("down")

func move_safe(pos: Vector3, delta: Vector3) -> Vector3:
	for d in [delta, Vector3(delta.x, 0, 0), Vector3(0, 0, delta.z)]:
		var q: Vector3 = pos + d
		if terrain.is_walkable_at(q) and terrain.line_clear(pos, q):
			return q
	return pos

func deal_damage(atk: Dictionary) -> void:
	if not alive or damage_in_progress:
		return
	damage_in_progress = true
	var before := hp
	var source = atk.get("source")
	if source != null:
		main.record_contact(self if faction == 0 else source, source if faction == 0 else self)
	if not retreating and not rallying and kind != "archer" and main.time >= rise_until and not atk.get("arrow", false):
		brain.modify_attack(atk)
	var damage: float = atk.damage
	if not retreating and kind == "shield" and atk.get("arrow", false) and (-atk.dir as Vector3).dot(facing) > 0.5:
		damage *= float(main.params.combat.arrow_shield_scale)
	main.phase_b.damage(self, source, damage)
	hp -= damage
	velocity += atk.dir * float(atk.knockback) * float(main.params.combat.knockback_scale)
	if damage > 0:
		stun_until = main.time + float(atk.stun)
		if hp > 0 and not retreating:
			impact += float(atk.stun) / float(main.params.units[kind].get("mass", 1.0))
			if main.time >= rise_until and impact > main.sim_rng.randf_range(1.0, 3.0):
				down_until = main.time + maxf(sqrt(impact), 2.0) * main.sim_rng.randf_range(0.5, 1.0)
				rise_until = down_until + float(main.params.combat.animation_lengths.rise)
				impact = 0
				brain.recover.set_true()
				sliding.set_true()
				play("fall")
				main.note("knockdown")
			elif impact > main.sim_rng.randf_range(0.7, 1.2):
				sliding.set_true()
		main.hooks.publish("hurt", {"unit": self, "source": atk.get("source"), "damage": damage, "step": main.step_number})
		var threshold := float(main.params.units[kind].hp) * float(main.params.events.near_death_fraction)
		if before > threshold and hp <= threshold:
			main.hooks.publish("near_death", {"unit": self, "source": atk.get("source"), "step": main.step_number})
	if hp <= 0:
		alive = false
		dead.set_true()
		main.on_death(self)
		main.phase_b.killed(self, source)
		main.hooks.publish("death", {"unit": self, "source": atk.get("source"), "step": main.step_number})
		if atk.get("source") != null:
			main.hooks.publish("kill", {"unit": atk.source, "victim": self, "step": main.step_number})
	damage_in_progress = false

func leave_ship() -> void:
	alive = false
	escaped = true
	alive_grounded.set_false()

func play(clip: String) -> void:
	anim_name = clip
	anim_t = 0

func anim_done() -> bool:
	return anim_t >= float(main.params.combat.animation_lengths.get(anim_name, main.params.combat.animation_lengths.idle))

func anim_norm() -> float:
	return anim_t / float(main.params.combat.animation_lengths.get(anim_name, main.params.combat.animation_lengths.idle))

func apply_order() -> void:
	walk_dir = order_dir if order_dist > float(main.params.map.path_arrival_radius) else Vector3.ZERO
	look(order_dir if walk_dir != Vector3.ZERO else slot_look)

func distance_to(p: Vector3) -> float:
	return Vector2(nav_pos.x - p.x, nav_pos.z - p.z).length()

func order_dist_to(p: Vector3) -> float:
	return Vector2(slot.x - p.x, slot.z - p.z).length()

func order_dir_at(p: Vector3) -> Vector3:
	return Vector3(slot.x - p.x, 0, slot.z - p.z).limit_length(1)

func look(dir: Vector3, _speed: float = 0, _threshold: float = 0) -> void:
	set_dir(dir)

func set_dir(dir: Vector3) -> void:
	if dir.length_squared() > 0.000001:
		facing = Vector3(dir.x, 0, dir.z).normalized()

func intimidate(soft: float, hard: float) -> void:
	soft_int = maxf(soft_int, soft)
	hard_int = maxf(hard_int, hard)

func intimidated() -> bool:
	return soft_int + hard_int > 0

func friend_ratio() -> float:
	var friends: int = main.nearby_count(nav_pos, 1.0, faction)
	var foes: int = main.nearby_count(nav_pos, 1.0, 1 - faction)
	return float(friends) / maxf(1, friends + foes)

func dispose() -> void:
	_clear_state(root)
	brain.target = null
	brain.parry_attacker = null
	brain.adjacent.clear()
	brain.u = null
	enemy = null
	squad = {}
	main = null

func _clear_state(state) -> void:
	for child in state.children:
		_clear_state(child)
	state.on_activate.clear()
	state.on_deactivate.clear()
	state.on_change.clear()
	state.on_empty.clear()
	state.on_update.clear()
	state.parent = null
	state.children.clear()
