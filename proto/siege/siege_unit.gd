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
var target_lock_until := 0.0
var enemy_lock_until := 0.0
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
var cell := Vector2i(-1, -1)
var cell_since := 0.0
var congestion_reported := false
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

func sense() -> void:
	if not alive or cave_until >= 0:
		return
	if main.time >= next_sense:
		# 半步余量避免浮点边界令周期偶尔多等一步；首次随机相位沿用原参数。
		var steps := int(main.params.combat.get("sense_steps", ceili(float(main.params.combat.sense_seconds) / float(main.params.simulation.step))))
		next_sense = main.time + (steps - 0.5) * float(main.params.simulation.step)
		var candidate = main.nearest_enemy(self)
		var valid: bool = enemy != null and enemy.alive and enemy.cave_until < 0 and (faction == 0 or main.phase_b.visible(enemy)) and Vector2(enemy.nav_pos.x - nav_pos.x, enemy.nav_pos.z - nav_pos.z).length() <= float(main.params.combat.sense_radius) and terrain.line_clear(nav_pos, enemy.nav_pos)
		if not valid or (candidate != null and candidate != enemy and main.time >= enemy_lock_until and (main.phase_b.enemy_score(self, candidate) + float(main.params.targeting.enemy_switch_margin) < main.phase_b.enemy_score(self, enemy) if main.phase_b.analysis else nav_pos.distance_to(candidate.nav_pos) + float(main.params.targeting.enemy_switch_margin) < nav_pos.distance_to(enemy.nav_pos))):
			if candidate != enemy:
				main.note("enemy_switch")
			enemy = candidate
			enemy_lock_until = main.time + float(main.params.targeting.enemy_lock_seconds)
	if enemy != null and enemy.alive and enemy.cave_until < 0:
		var delta: Vector3 = enemy.nav_pos - nav_pos
		delta.y = 0
		enemy_dist = delta.length()
		enemy_dir = delta.normalized()
		enemy_dangerous = enemy.dangerous
	else:
		enemy = null
		enemy_dist = 1.0e6
		enemy_dir = Vector3.ZERO
		enemy_dangerous = false
	order_dist = Vector2(slot.x - nav_pos.x, slot.z - nav_pos.z).length()
	order_dir = terrain.direction(nav_pos, slot, faction == 1 and main.phase_b.enabled and main.phase_b.can_cave(self))
	recover_navigation()
	soft_int = move_toward(soft_int, 0, State.dt * float(main.params.combat.threat_decay))
	hard_int = move_toward(hard_int, 0, State.dt * float(main.params.combat.threat_decay))
	if enemy != null and not enemy.retreating:
		enemy.brain.on_proximity(self)

func tick(dt: float) -> void:
	if not alive:
		return
	if cave_until >= 0:
		if main.time >= cave_until:
			nav_pos = cave_exit
			previous_pos = nav_pos
			nav_pos.y = terrain.height_at(nav_pos)
			cave_until = -1
			stage = 1 if transit_kind == "cliff" else maxi(stage, 2)
		return
	anim_t += dt
	walk_dir = Vector3.ZERO
	if retreating:
		walk_dir = order_dir
		look(order_dir)
	elif main.time < stun_until:
		pass
	elif main.phase_b.enabled and kind in ["assassin", "giant"]:
		main.phase_b.special_tick(self)
	elif kind == "archer" and enemy != null and enemy_dist > float(main.params.combat.chase_radius):
		brain.stamina = 1
		if enemy_dist <= float(main.params.units.archer.range) and terrain.line_clear(nav_pos, enemy.nav_pos):
			look(enemy_dir)
			if main.time >= next_arrow:
				next_arrow = main.time + float(main.params.units.archer.cooldown)
				main.fire_arrow(self, enemy)
		else:
			apply_order()
	else:
		root.update()
		var within_leash: bool = faction == 0 or marching or enemy == null or Vector2(enemy.nav_pos.x - anchor.x, enemy.nav_pos.z - anchor.z).length() <= float(main.params.combat.defender_leash)
		if within_leash and enemy != null and kind != "archer" and enemy_dist <= float(main.params.combat.chase_radius) and not brain.attack.active and not brain.parry.active and not brain.clash.active:
			if terrain.line_clear(nav_pos, enemy.nav_pos):
				if not brain.try_attack(enemy):
					walk_dir = enemy_dir
					look(enemy_dir)
	if not alive:
		return
	if sliding.active and main.time >= stun_until:
		sliding.set_false()
	var separation: Vector3 = main.separation(self)
	var delta := walk_dir.limit_length(1.0) * speed * dt + separation * dt + velocity * dt
	var before := nav_pos
	nav_pos = move_safe(nav_pos, delta)
	nav_pos.y = terrain.height_at(nav_pos)
	walked += Vector2(nav_pos.x - before.x, nav_pos.z - before.z).length()
	velocity = velocity.move_toward(Vector3.ZERO, dt * float(main.params.combat.velocity_decay))
	var t: Vector2i = terrain.tile(nav_pos)
	if t != cell:
		cell = t
		cell_since = main.time
		congestion_reported = false
	elif not main.phase_b.analysis and main.time - cell_since > float(main.params.targeting.congestion_seconds) and not congestion_reported:
		# 指标按“同格停留 >3 秒”原定义统计，另记移动需求，便于排除站岗/近战。
		congestion_reported = true
		congestion_count += 1
		main.congestion += 1
		if order_dist > float(main.params.director.arrival_radius) and enemy == null and not retreating:
			main.travel_congestion += 1

	if main.phase_b.analysis: movement_congestion()

func movement_congestion() -> void:
	var cfg: Dictionary = main.params.targeting
	var engaging: bool = (enemy != null and enemy_dist <= float(main.params.combat.chase_radius)) or main.phase_b.at_structure(self)
	var intent: bool = walk_dir.length_squared() > 0.0025 and order_dist > float(main.params.map.path_arrival_radius)
	if not intent or engaging or retreating or main.time < stun_until or cave_until >= 0:
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
	if nav_pos.distance_to(progress_pos) >= float(cfg.progress_epsilon) or order_dist <= float(main.params.director.arrival_radius) or enemy != null:
		progress_pos = nav_pos
		progress_at = main.time
		return
	if main.time < recovery_until:
		order_dir = terrain.direction(nav_pos, recovery_pos)
		return
	if main.time - progress_at < float(cfg.stuck_seconds):
		return
	var f: Dictionary = terrain.field(slot, false)
	var here: int = terrain.index(terrain.tile(nav_pos))
	var best := INF
	var chosen := Vector3.ZERO
	for edge in terrain.neighbors(here, false):
		var p: Vector3 = terrain.point(edge[0])
		if f.dist[edge[0]] >= float(main.params.map.flow_infinity) or f.dist[edge[0]] > f.dist[here] + 1:
			continue
		var score: float = f.dist[edge[0]] + main.nearby_count(p, float(cfg.crowd_radius), faction) * float(cfg.congestion_weight)
		if score < best:
			best = score
			chosen = p
	if best < INF:
		recovery_pos = chosen
		recovery_until = main.time + float(cfg.stuck_seconds)
		order_dir = terrain.direction(nav_pos, chosen)
		main.recovery_events.append({"time": snappedf(main.time, 0.001), "unit": id, "from": [nav_pos.x, nav_pos.z], "to": [chosen.x, chosen.z]})
	progress_at = main.time

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
	if not retreating and kind != "archer" and not atk.get("arrow", false):
		brain.modify_attack(atk)
	var damage: float = atk.damage
	if not retreating and kind == "shield" and (-atk.dir as Vector3).dot(facing) > 0.5:
		damage *= float(main.params.combat.arrow_shield_scale if atk.get("arrow", false) else main.params.combat.shield_damage_scale)
	main.phase_b.damage(self, source, damage)
	hp -= damage
	velocity += atk.dir * float(atk.knockback) * float(main.params.combat.knockback_scale)
	if damage > 0:
		stun_until = main.time + float(atk.stun)
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
	walk_dir = order_dir
	look(order_dir if order_dist > float(main.params.map.path_arrival_radius) else slot_look)

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
