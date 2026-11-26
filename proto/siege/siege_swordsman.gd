extends RefCounted
const AgentState = preload("res://scripts/agent_state.gd")
## 从 scripts/swordsman.gd 复制的剑盾兵状态逻辑；仅将调参入口改到 JSON。
## 剑盾兵大脑（规格 7）。状态挂在 Unit 的 Brain 节点下，互斥：
## 待机 Idle、备战 Ready、冲锋 Pursuing、狩猎 Hunting、攻击 Attack、拼刀 Clash、恢复 Recover、招架 Parry。
## 兵与兵之间的协同只靠"最近 3 个邻居"：体力互相拉平、冲锋向邻居传播。

var cfg: Dictionary
var attack_hit_t: float
var parry_window: Vector2

var u   # Unit
var stamina := 1.0
var target = null
var adjacent: Array = []
var start_walked := 0.0
var damage := 1.0
var knockback := 1.0
var stun := 1.0
var attack_cost := 0.0
var parry_attacker = null
var _hit_done := false

var brain: AgentState
var idle: AgentState
var ready: AgentState
var pursuing: AgentState
var hunting: AgentState
var attack: AgentState
var clash: AgentState
var recover: AgentState
var parry: AgentState


func setup(unit, exclusives: AgentState, stats: Dictionary) -> void:
	u = unit
	cfg = u.main.params.brain
	attack_cost = cfg.attack_cost
	attack_hit_t = cfg.hit_time
	parry_window = Vector2(cfg.parry_window[0], cfg.parry_window[1])
	damage = stats.get("damage", 1.0)
	knockback = stats.get("knockback", 1.0)
	stun = stats.get("stun", 1.0)
	brain = AgentState.new("Brain", exclusives, false, true)
	idle = AgentState.new("Idle", brain, false, true)
	ready = AgentState.new("Ready", brain, false, true)
	pursuing = AgentState.new("Pursuing", brain, false, true)
	hunting = AgentState.new("Hunting", brain, false, true)
	attack = AgentState.new("Attack", brain, false, true)
	clash = AgentState.new("Clash", brain, false, true)
	recover = AgentState.new("Recover", brain, false, true)
	parry = AgentState.new("Parry", brain, false, true)

	brain.on_empty.append(idle.set_true)
	brain.on_change.append(func(v: bool): u.dangerous = v)
	brain.on_update.append(_update_stamina)
	brain.on_update.append(_update_adjacent)
	idle.on_update.append(_idle_update)
	ready.on_activate.append(func(): target = null)
	ready.on_update.append(_ready_update)
	hunting.on_activate.append(_start_counting)
	hunting.on_deactivate.append(func(): target = null)
	hunting.on_update.append(_hunting_update)
	pursuing.on_activate.append(_start_counting)
	pursuing.on_update.append(_pursuit_update)
	attack.on_update.append(_attack_update)
	attack.on_deactivate.append(func(): target = null)
	attack.on_change.append(func(v: bool): u.move_animate.set_active(not v))
	clash.on_activate.append(_clash_activate)
	clash.on_update.append(_clash_update)
	clash.on_change.append(func(v: bool): u.move_animate.set_active(not v))
	recover.on_update.append(func(): if u.hopping.active: ready.set_true())
	recover.on_deactivate.append(func(): stamina = 0.0)
	parry.on_update.append(_parry_update)
	parry.on_change.append(func(v: bool): u.move_animate.set_active(not v))
	u.dead.on_activate.append(func():
		for f in adjacent:
			if is_instance_valid(f) and f.brain != null:
				f.brain.stamina -= cfg.death_stamina_loss)


func range_() -> float:
	return u.radius * cfg.reach_radius_scale


## 眩晕、爬起结束后重新选状态
func evaluate_new_state() -> void:
	if not u.alive_grounded.active:
		return
	if u.sliding.active:
		recover.set_true()
		return
	if stamina > cfg.resume_stamina:
		for f in adjacent:
			if not _valid(f):
				continue
			if f.brain.pursuing.active:
				pursuing.set_true()
				return
			if f.brain.hunting.active:
				hunting.set_true()
				return
	ready.set_true()


# ---------- 被动：威慑、体力 ----------

## 别人靠近我时调用：在"贴身"到 1 米之间对对方施加软威慑 1→0
func on_proximity(other) -> void:
	if not u.alive_grounded.active:
		return
	var d: float = _flat(other.nav_pos - u.nav_pos).length()
	if d > cfg.proximity_radius:
		return
	var inner: float = u.radius + range_() + other.radius
	other.intimidate(_remap(d, inner, cfg.proximity_radius, 1.0, 0.0), 0.0)


func _update_stamina() -> void:
	for f in adjacent:
		if not _valid(f):
			continue
		var k: float = (stamina - f.brain.stamina) * cfg.stamina_share
		f.brain.stamina += k
		stamina -= k


## 8Hz：维护最近的 3 个队友（1 米内）
func _update_adjacent() -> void:
	if not u.beats.hz(cfg.adjacent_period):
		return
	var cands: Array = []
	var closest: Array = []
	var count := maxi(0, int(cfg.adjacent_count))
	for f in u.main.adjacent_units(u, sqrt(float(cfg.adjacent_radius_sq))):
		if f == u or not _valid(f):
			continue
		var d: float = (f.nav_pos - u.nav_pos).length_squared()
		if d < cfg.adjacent_radius_sq:
			var candidate := [d, f]
			cands.append(candidate)
			var slot := closest.size()
			for i in closest.size():
				if d < closest[i][0]:
					slot = i
					break
			if slot < count:
				closest.insert(slot, candidate)
				if closest.size() > count:
					closest.pop_back()
	# 只有等距会依赖 Godot 非稳定排序的细节；这些情况沿用原完整排序。
	var tied := false
	for i in range(1, closest.size()):
		if closest[i - 1][0] == closest[i][0]:
			tied = true
	if not closest.is_empty() and not tied:
		var boundary_count := 0
		for candidate in cands:
			if candidate[0] == closest[-1][0]:
				boundary_count += 1
				if boundary_count > 1:
					tied = true
					break
	if tied:
		cands.sort_custom(func(a, b): return a[0] < b[0])
		closest = cands.slice(0, count)
	adjacent.clear()
	for candidate in closest:
		adjacent.append(candidate[1])


# ---------- 各状态 ----------

func _idle_update() -> void:
	stamina = 1.0
	if u.beats.hz(cfg.adjacent_period) and u.enemy_dist < cfg.idle_enemy_distance:
		ready.set_true()
		return
	u.apply_order()


func _ready_update() -> void:
	stamina = move_toward(stamina, 1.0, AgentState.dt * cfg.recover_stamina_per_second)
	var od: Vector3 = u.order_dir * _remap(u.order_dist, cfg.order_slow_distance, 0.0, cfg.minimum_order_speed, 1.0)
	u.walk_dir = od * clampf(stamina, 0.0, 1.0)
	if u.hard_int > 0.0:
		u.walk_dir -= u.enemy_dir * u.hard_int * cfg.hard_intimidation_scale
	if u.soft_int > 0.0:
		var k: float = u.soft_int * lerpf(cfg.soft_intimidation_range[0], cfg.soft_intimidation_range[1], u.friend_ratio()) * lerpf(cfg.soft_intimidation_range[0], cfg.soft_intimidation_range[1], stamina)
		var back: Vector3 = -u.enemy_dir * k
		if u.order_dist < cfg.intimidation_order_distance:
			back = _clamp_to_dir(back, od, cfg.retreat_clamp)
		u.walk_dir += back
	else:
		u.walk_dir -= u.enemy_dir * _remap(u.enemy_dist, cfg.backoff_distance[0], cfg.backoff_distance[1], 1.0, 0.0)

	if u.beats.hz(cfg.think_period):
		var e = u.enemy
		if _valid(e) and (e.enemy == u or not e.enemy_dangerous) and stamina > 0.0:
			var face_off: bool = (u.order_dist_to(e.nav_pos) < cfg.faceoff_target_distance or u.intimidated()) and u.order_dist < cfg.faceoff_self_distance and e.order_dist < cfg.faceoff_enemy_distance
			var blocking: bool = (u.enemy_dist < cfg.blocking_distance or u.intimidated()) and u.enemy_dir.dot(u.order_dir) > 0.0 \
				and u.order_dist_to(e.nav_pos) < u.order_dist + cfg.blocking_margin
			if face_off or blocking:
				pursue()
				return
		if u.enemy_dist > cfg.idle_enemy_distance:
			idle.set_true()
			return
		if _should_hunt(e, cfg.hunt_distance):
			target = e
			hunting.set_true()
			return
	var look: Vector3 = u.order_dir
	if u.enemy_dir.dot(u.order_dir) > 0.0 or u.intimidated() or u.enemy_dist < cfg.look_enemy_distance:
		look = u.enemy_dir
	if look.length() < 0.01:
		look = u.slot_look
	u.look(look)


func _should_hunt(victim, hunt_dist: float) -> bool:
	if not _valid(victim) or victim.dangerous:
		return false
	if victim == u.enemy and u.enemy_dist < hunt_dist * cfg.hunt_distance_scale and u.enemy_dir.dot(u.order_dir) > 0.0:
		return true
	return u.order_dist_to(victim.nav_pos) < hunt_dist


func pursue() -> void:
	pursuing.set_true()
	_broadcast_pursuit(u.enemy_dir)
	u.main.note("pursue")


func _broadcast_pursuit(dir: Vector3) -> int:
	var count := 0
	for f in adjacent:
		if not _valid(f):
			continue
		var b = f.brain
		if not b.ready.active or b.stamina < 0.0:
			continue
		if dir.normalized().dot(f.enemy_dir.normalized()) < cfg.broadcast_dot_threshold:
			continue
		if f.order_dist > cfg.broadcast_order_distance and f.order_dir.dot(f.enemy_dir) < 0.0:
			continue
		b.pursuing.set_true()
		count += 1 + b._broadcast_pursuit(u.enemy_dir)
	return count


## 被冲锋：体力够就反冲锋，并带动邻居
func on_pursued(pursuer) -> void:
	if stamina < cfg.counter_min_stamina or not ready.active:
		return
	if not u.terrain.line_clear(u.nav_pos, pursuer.nav_pos):
		return
	if u.order_dir.dot(u.enemy_dir) < 0.0:
		return
	_broadcast_pursuit(u.enemy_dir)
	if ready.active and stamina > cfg.counter_start_stamina:
		pursuing.set_true()
		u.main.note("counter")


func _start_counting() -> void:
	start_walked = u.walked


func _pursuit_update() -> void:
	stamina -= AgentState.dt * cfg.pursuit_stamina_per_second
	if stamina < 0.0 or u.walked - start_walked > cfg.pursuit_max_distance:
		ready.set_true()
		return
	u.walk_dir = u.enemy_dir
	u.look(u.enemy_dir)
	var e = u.enemy
	if _valid(e):
		u.walk_dir += e.order_dir_at(u.nav_pos) * cfg.pursuit_follow_weight
		if u.enemy_dist < cfg.counter_contact_margin + u.radius + e.radius + range_():
			e.brain.on_pursued(u)
		if try_attack(e):
			return
	elif u.enemy_dist > cfg.pursuit_lost_distance + stamina:
		ready.set_true()


func _hunting_update() -> void:
	if target != null and not _valid(target):
		target = null
	if target != u.enemy:
		if _should_hunt(u.enemy, cfg.hunt_follow_distance):
			target = u.enemy
		elif not _should_hunt(target, cfg.hunt_follow_distance):
			ready.set_true()
			return
	elif not _should_hunt(target, cfg.hunt_follow_distance):
		ready.set_true()
		return
	if try_attack(target):
		return
	if u.terrain.line_clear(u.nav_pos, target.nav_pos):
		var v: Vector3 = _flat(target.nav_pos - u.nav_pos)
		u.walk_dir = v
		u.look(v)
	elif not u.enemy_dangerous:
		u.walk_dir = u.enemy_dir
		u.look(u.enemy_dir)
	else:
		ready.set_true()


## 出手：够得着就进入攻击，并通知对方的盾（可能招架）
func try_attack(t) -> bool:
	if not _valid(t) or not u.hopping.active or not u.alive_grounded.active:
		return false
	var reach: float = u.radius + t.radius + range_()
	if (t.nav_pos - u.nav_pos).length_squared() > reach * reach:
		return false
	attack.set_true()
	target = t
	_hit_done = false
	u.play("attack")
	if t.brain != null:
		t.brain.maybe_parry(self)
	return true


func _attack_update() -> void:
	if not _hit_done and u.anim_t >= attack_hit_t:
		_hit_done = true
		_do_hit()
		if not attack.active:
			return
	if u.anim_done():
		stamina -= attack_cost
		attack.set_false()
		if stamina > 0.0:
			try_attack(u.enemy)
		return
	if _valid(target):
		var v: Vector3 = _flat(target.nav_pos - u.nav_pos)
		var m := v.length()
		if m > 0.001:
			u.walk_dir = v / m * (m - u.radius - target.radius)
			u.set_dir(v)
	else:
		u.walk_dir = Vector3.ZERO


func _do_hit() -> void:
	if not _valid(target) or not attack.active:
		return
	var d: float = _flat(target.nav_pos - u.nav_pos).length() - (u.radius + target.radius + range_())
	if d >= 0.0:
		return
	var dir: Vector3 = _flat(target.nav_pos - u.nav_pos).normalized()
	var atk := {"damage": damage, "knockback": knockback, "stun": stun, "launch": 0.0,
		"dir": dir, "attacker": self, "source": u}
	u.main.shake(0.03 * damage)
	target.deal_damage(atk)


## 受击前修改攻击：拼刀、招架、盾挡
func modify_attack(atk: Dictionary) -> void:
	var a = atk.get("attacker")
	if a != null and a.get_script() == get_script() and attack.active and a.attack.active and target == a.u \
			and a.u.anim_norm() - u.anim_norm() < cfg.clash_phase_window:
		atk.damage = 0.0
		atk["clash"] = true
		clash.set_true()
		a.clash.set_true()
		var pos: Vector3 = (u.nav_pos + a.u.nav_pos) * 0.5 + Vector3(0, 0.25, 0)
		u.main.spawn_spark(pos)
		u.main.note("clash")
		a.u.deal_damage({"damage": 0.0, "knockback": knockback, "stun": cfg.clash_stun, "launch": 0.0,
			"dir": -atk.dir, "attacker": self, "clash": true})
		return
	if a != null and a.get_script() == get_script():
		var front: float = (-atk.dir as Vector3).dot(u.facing)
		if parry.active and _parry_window() and front > 0.0:
			atk.damage = 0.0
			atk["parried"] = true
			u.main.spawn_spark(u.nav_pos + Vector3(0, 0.25, 0) - atk.dir * 0.08)
			u.main.note("parry")
		elif front > cfg.shield_front_dot:
			atk["shield_fx"] = true


func maybe_parry(attacker) -> void:
	if ready.active or pursuing.active:
		u.play("parry")
		parry_attacker = attacker
		parry.set_true()


func _parry_window() -> bool:
	return u.anim_t >= parry_window.x and u.anim_t <= parry_window.y


func _parry_update() -> void:
	if u.anim_done():
		if parry_attacker != null and _valid(parry_attacker.u) and u.enemy == parry_attacker.u:
			parry.set_false()
			if not try_attack(u.enemy):
				ready.set_true()
		else:
			ready.set_true()
		parry_attacker = null
	elif parry_attacker != null and _valid(parry_attacker.u):
		u.look(parry_attacker.u.nav_pos - u.nav_pos, 900.0, 10.0)


func _clash_activate() -> void:
	u.play("clash")
	u.sliding.set_true()


func _clash_update() -> void:
	if u.anim_done():
		stamina -= cfg.clash_stamina_cost
		clash.set_false()
		if stamina > 0.0:
			try_attack(u.enemy)


# ---------- 工具 ----------

func _valid(x) -> bool:
	return x != null and is_instance_valid(x) and x.alive_grounded.active


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## 线性映射并夹在输出区间内
static func _remap(v: float, in0: float, in1: float, out0: float, out1: float) -> float:
	if in1 > in0:
		return lerpf(out0, out1, clampf(inverse_lerp(in0, in1, v), 0.0, 1.0))
	return lerpf(out1, out0, clampf(inverse_lerp(in1, in0, v), 0.0, 1.0))


static func _clamp_to_dir(v: Vector3, dir: Vector3, factor: float) -> Vector3:
	var k := v.dot(dir)
	if k < 0.0 and dir.length() > 0.0001:
		var nd := dir.normalized()
		v += nd * v.dot(-nd) * factor
	return v
