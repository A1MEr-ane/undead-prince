class_name Unit
extends Node3D
## 单个小兵。决策按 8Hz 节拍（相位随机错开），执行按帧推进。
## 移动是一步一跳；走路帧绑定步伐进度，左右脚交替。
## 受击累积冲击值：超过随机阈值滑退，超过更高阈值击飞翻滚、倒地、爬起。

enum S { IDLE, MOVE, WINDUP, STRIKE, RECOVER, BLOCK, CLASH, STAGGER, TUMBLE, DOWN, GETUP, DEAD }

const QUAD := 0.8
const THINK_DT := 0.125
const MELEE_RANGE := 0.4

var main
var terrain: Terrain
var squad
var faction := 0
var alive := true
var has_shield := true

var mesh: MeshInstance3D
var shadow: MeshInstance3D
var ring: MeshInstance3D
var anims: Dictionary

var state: int = S.IDLE
var state_t := 0.0
var think_t := 0.0
var freeze := 0.0
var flash := 0.0
var anim_clock := 0.0
var _frame := -1

var hp := 3.0
var max_hp := 3.0
var power := 1.0
var stamina := 1.0
var impact := 0.0
var slide_th := 1.0
var knock_th := 2.0
var react_delay := 0.1
var target: Unit = null
var target_since := 0.0
var attack_cd := 0.0
var windup_dur := 0.3
var facing := Vector3(1, 0, 0)

var slot := Vector3.ZERO
var move_goal := Vector3.ZERO
var stepping := false
var step_from := Vector3.ZERO
var step_to := Vector3.ZERO
var step_t := 0.0
var step_dur := 0.26
var cur_step_dur := 0.26
var step_run := false
var step_parity := 0
var speed := 1.0
var anim_rate := 1.0
var idle_offset := 0.0

var slide_vel := Vector3.ZERO
var stagger_dur := 0.3
var fly_from := Vector3.ZERO
var fly_to := Vector3.ZERO
var fly_dur := 0.5
var fly_h := 0.4
var tumble_start := 0
var down_time := 1.0
var dying := false
var drowned := false


func setup(p_main, p_squad, p_faction: int, palette_row: int, pos: Vector3, stats: Dictionary) -> void:
	main = p_main
	terrain = p_main.terrain
	squad = p_squad
	faction = p_faction
	anims = p_main.anims
	max_hp = stats.get("hp", 3.0)
	hp = max_hp
	power = stats.get("power", 1.0)
	position = Vector3(pos.x, terrain.height_at(pos), pos.z)

	mesh = MeshInstance3D.new()
	mesh.mesh = p_main.unit_quad
	mesh.material_override = p_main.unit_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.custom_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 2.5, 2))
	add_child(mesh)
	mesh.set_instance_shader_parameter("palette_row", float(palette_row))

	shadow = MeshInstance3D.new()
	shadow.mesh = p_main.shadow_mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	ring = MeshInstance3D.new()
	ring.mesh = p_main.ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.004
	ring.visible = false
	shadow.add_child(ring)

	# 个体差异：步速、步频、动画速度、待机相位、决策相位、反应延迟
	speed = randf_range(0.9, 1.1)
	step_dur = randf_range(0.24, 0.29)
	anim_rate = randf_range(0.9, 1.12)
	idle_offset = randf() * 4.0
	think_t = randf() * THINK_DT
	react_delay = randf_range(0.05, 0.3)
	_roll_thresholds()
	slot = position
	move_goal = position


func _roll_thresholds() -> void:
	slide_th = randf_range(0.7, 1.3)
	knock_th = randf_range(1.7, 2.6)


# ---------- 帧更新 ----------

func _process(delta: float) -> void:
	if not alive:
		_process_dead(delta)
		return
	flash = max(0.0, flash - delta * 6.0)
	if freeze > 0.0:
		freeze -= delta
		_apply_visuals()
		return
	anim_clock += delta * anim_rate
	attack_cd -= delta
	impact = max(0.0, impact - delta * 0.6)
	stamina = min(1.0, stamina + delta * 0.1)
	think_t -= delta
	if think_t <= 0.0:
		think_t += THINK_DT
		_think()
	state_t += delta
	match state:
		S.IDLE, S.MOVE:
			_update_locomotion(delta)
		S.WINDUP:
			var k := state_t / windup_dur
			_set_anim("attack", mini(int(k * 3.0), 2))
			if k >= 1.0:
				_resolve_strike()
		S.STRIKE:
			_set_anim("attack", 3 if state_t < 0.06 else 4)
			if state_t > 0.14:
				_set_state(S.RECOVER)
		S.RECOVER:
			_set_anim("attack", 5)
			if state_t > 0.28:
				_set_state(S.IDLE)
				attack_cd = randf_range(0.45, 0.9)
		S.BLOCK:
			_set_anim("block", 0 if state_t < 0.12 else 1)
			_slide(delta)
			if state_t > 0.3:
				_set_state(S.IDLE)
		S.CLASH:
			_set_anim("clash", 0 if state_t < 0.18 else 1)
			_slide(delta)
			if state_t > 0.4:
				# 拼刀后体力还有剩才继续进攻
				if target != null and target.alive and stamina > 0.3 and _flat_dist(target) < MELEE_RANGE * 1.5:
					_start_windup()
				else:
					_set_state(S.IDLE)
					attack_cd = randf_range(0.3, 0.7)
		S.STAGGER:
			_set_anim("hit", 0 if state_t < 0.12 else 1)
			_slide(delta)
			if state_t > stagger_dur:
				_set_state(S.IDLE)
		S.TUMBLE:
			_update_tumble()
		S.DOWN:
			_set_anim("down", 0)
			if state_t > down_time:
				_set_state(S.GETUP)
		S.GETUP:
			_set_anim("getup", mini(int(state_t / 0.14), 3))
			if state_t > 0.56:
				_set_state(S.IDLE)
	_apply_visuals()


func _set_state(s: int) -> void:
	state = s
	state_t = 0.0
	if s != S.IDLE and s != S.MOVE and stepping:
		stepping = false
		position.y = terrain.height_at(position)


func _set_anim(anim_name: String, idx: int) -> void:
	var a: Vector2i = anims[anim_name]
	var f := a.x + clampi(idx, 0, a.y - 1)
	if f != _frame:
		_frame = f
		mesh.set_instance_shader_parameter("frame", float(f))


func _apply_visuals() -> void:
	var right: Vector3 = main.cam_right()
	mesh.set_instance_shader_parameter("flip", 1.0 if facing.dot(right) < 0.0 else 0.0)
	mesh.set_instance_shader_parameter("flash", flash)
	var g := terrain.height_at(position)
	mesh.set_instance_shader_parameter("grass", terrain.grass_at(position) if state != S.TUMBLE else 0.0)
	shadow.global_position = Vector3(position.x, g + 0.015, position.z)
	var air: float = max(0.0, position.y - g)
	shadow.scale = Vector3.ONE * clampf(1.0 - air * 0.9, 0.4, 1.0)


# ---------- 决策（8Hz） ----------

func _think() -> void:
	_share_stamina()
	if state != S.IDLE and state != S.MOVE:
		return
	var engage: float = squad.engage_radius(self)
	if target != null and (not target.alive or _flat_dist(target) > engage + 0.8 or not squad.can_chase(target)):
		target = null
	if target == null:
		target = _find_enemy(engage)
		if target != null:
			target_since = main.time
	if target != null:
		var d := _flat_dist(target)
		facing = _flat_dir(target.position)
		if d <= MELEE_RANGE:
			move_goal = position
			if not stepping:
				state = S.IDLE
				if attack_cd <= 0.0 and stamina > 0.08 and main.time - target_since > react_delay:
					_start_windup()
			return
		move_goal = target.position - facing * MELEE_RANGE * 0.75
		state = S.MOVE
		return
	if _flat_dist_pt(slot) > 0.1:
		move_goal = slot
		state = S.MOVE
	elif not stepping:
		state = S.IDLE
		facing = squad.facing_dir


func _find_enemy(r: float) -> Unit:
	var best: Unit = null
	var bd := r
	for u in main.units:
		if not u.alive or u.faction == faction:
			continue
		var d := _flat_dist(u)
		if d < bd and squad.can_chase(u):
			bd = d
			best = u
	return best


## 相邻队友之间体力互相拉向平均值。
func _share_stamina() -> void:
	var sum := 0.0
	var n := 0
	for u in squad.units:
		if u == self or not u.alive:
			continue
		if _flat_dist(u) < 0.9:
			sum += u.stamina
			n += 1
	if n > 0:
		stamina += (sum / n - stamina) * 0.2


# ---------- 移动 ----------

func _update_locomotion(delta: float) -> void:
	if stepping:
		step_t += delta / cur_step_dur
		var t: float = min(step_t, 1.0)
		var p := step_from.lerp(step_to, t)
		var climb: float = max(0.0, step_to.y - step_from.y)
		p.y = lerp(step_from.y, step_to.y, t) + sin(t * PI) * (0.03 + climb * 0.7)
		position = p
		_set_anim("walk", step_parity * 3 + mini(int(t * 3.0), 2))
		if step_t >= 1.0:
			stepping = false
			_on_footstep()
	if not stepping and state == S.MOVE:
		_begin_step()
	if not stepping:
		_set_anim("idle", int(anim_clock * 2.2 + idle_offset) % 4)


func _begin_step() -> void:
	var to := move_goal - position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.06:
		state = S.IDLE
		return
	var dir := to / dist
	if not terrain.line_clear(position, move_goal):
		dir = terrain.flow_dir(position, terrain.tile_of(move_goal))
		if dir == Vector3.ZERO:
			state = S.IDLE
			return
	step_run = dist > 1.6
	var length: float = min(dist, speed * (0.34 if step_run else 0.24))
	var end := position + dir * length + _separation()
	if not terrain.can_step(position, end):
		end = position + dir * length
		if not terrain.can_step(position, end):
			state = S.IDLE
			return
	step_from = position
	step_to = Vector3(end.x, terrain.height_at(end), end.z)
	step_t = 0.0
	cur_step_dur = step_dur * (0.85 if step_run else 1.0)
	stepping = true
	step_parity = 1 - step_parity
	facing = dir


func _separation() -> Vector3:
	var s := Vector3.ZERO
	for u in main.units:
		if u == self or not u.alive:
			continue
		var d: Vector3 = position - u.position
		d.y = 0.0
		var l := d.length()
		if l < 0.32 and l > 0.001:
			s += d / l * (0.32 - l)
	return s * 0.5


func _on_footstep() -> void:
	# 脚步声尚无素材；步子大（奔跑）时扬尘
	if step_run and randf() < 0.6:
		main.spawn_dust(position, 1, 0.5)


func _slide(delta: float) -> void:
	if slide_vel.length() < 0.01:
		return
	var np := position + slide_vel * delta
	if terrain.can_step(position, np) and terrain.is_walkable_at(np):
		position = Vector3(np.x, terrain.height_at(np), np.z)
	else:
		slide_vel = Vector3.ZERO
	slide_vel = slide_vel.move_toward(Vector3.ZERO, delta * 6.0)


# ---------- 战斗 ----------

func _start_windup() -> void:
	_set_state(S.WINDUP)
	windup_dur = 0.3 / anim_rate * (1.0 + (1.0 - stamina) * 0.6)
	stamina = max(0.0, stamina - 0.06)


func _resolve_strike() -> void:
	_set_state(S.STRIKE)
	if target == null or not target.alive:
		return
	if _flat_dist(target) > MELEE_RANGE * 1.6:
		return
	# 双方同时出手 → 拼刀
	if target.state == S.WINDUP and target.target == self:
		_clash_with(target)
		return
	var to_me: Vector3 = _flat_vec(target.position, position).normalized()
	var facing_me: bool = target.facing.dot(to_me) > 0.2
	var ready_states := [S.IDLE, S.MOVE, S.RECOVER, S.BLOCK]
	var can_block: bool = target.has_shield and facing_me and ready_states.has(target.state)
	if can_block and randf() < 0.2 + 0.5 * target.stamina:
		target.receive_block(self)
	else:
		target.receive_hit(self, 1.0)


func _clash_with(o: Unit) -> void:
	var dir := _flat_vec(o.position, position).normalized()
	for u: Unit in [self, o]:
		u._set_state(S.CLASH)
		u.stamina = max(0.0, u.stamina - 0.25)
		u.freeze = 0.06
	slide_vel = dir * 0.9
	o.slide_vel = -dir * 0.9
	main.spawn_spark((position + o.position) * 0.5 + Vector3(0, 0.35, 0))
	main.note("clash")


func receive_hit(attacker: Unit, dmg: float) -> void:
	var dir := _flat_vec(attacker.position, position)
	dir = dir.normalized() if dir.length() > 0.001 else attacker.facing
	hp -= dmg
	flash = 1.0
	freeze = 0.08
	attacker.freeze = 0.06
	mesh.set_instance_shader_parameter("health", clampf(hp / max_hp, 0.0, 1.0))
	main.spawn_blood(position, dir)
	main.note("hit")
	impact += randf_range(0.7, 1.3) * attacker.power
	facing = -dir
	if hp <= 0.0:
		dying = true
		if impact > knock_th * 0.8:
			_start_tumble(dir, 1.0)
		else:
			_die()
		return
	if impact > knock_th:
		_start_tumble(dir, 1.0)
		_roll_thresholds()
	elif impact > slide_th:
		main.note("slide")
		_start_stagger(dir, 1.6, 0.35)
	else:
		_start_stagger(dir, 0.6, 0.2)


func receive_block(attacker: Unit) -> void:
	var dir := _flat_vec(attacker.position, position).normalized()
	stamina = max(0.0, stamina - 0.15)
	impact += 0.35 * attacker.power
	flash = 0.3
	freeze = 0.04
	attacker.freeze = 0.04
	facing = -dir
	main.spawn_spark(position + Vector3(0, 0.3, 0) - dir * 0.12)
	main.note("block")
	_set_state(S.BLOCK)
	slide_vel = dir * (1.4 if impact > slide_th else 0.5)


func _start_stagger(dir: Vector3, strength: float, dur: float) -> void:
	_set_state(S.STAGGER)
	slide_vel = dir * strength
	stagger_dur = dur


func _start_tumble(dir: Vector3, strength: float) -> void:
	_set_state(S.TUMBLE)
	fly_from = position
	var dist := randf_range(0.7, 1.4) * strength
	var end := position
	for i in range(1, 9):
		var p := position + dir * dist * (i / 8.0)
		if terrain.is_land_at(p) and terrain.height_at(p) > fly_from.y + 0.05:
			break
		if terrain.is_land_at(p) and not terrain.is_walkable_at(p):
			break
		end = p
	fly_to = Vector3(end.x, terrain.height_at(end), end.z)
	if not terrain.is_land_at(end):
		fly_to.y = Terrain.WATER_Y - 0.1
	fly_dur = randf_range(0.4, 0.55)
	fly_h = randf_range(0.3, 0.5)
	tumble_start = randi() % 6   # 翻滚从随机帧开始
	main.note("tumble")
	facing = -dir
	main.shake(0.06)


func _update_tumble() -> void:
	var k: float = min(state_t / fly_dur, 1.0)
	var p := fly_from.lerp(fly_to, k)
	p.y = lerp(fly_from.y, fly_to.y, k) + sin(k * PI) * fly_h
	position = p
	_set_anim("tumble", (tumble_start + int(state_t * 14.0)) % 6)
	if k < 1.0:
		return
	if not terrain.is_land_at(position):
		_drown()
		return
	main.spawn_dust(position, 4, 0.8)
	if dying:
		_die()
		return
	down_time = randf_range(0.5, 1.4)   # 倒地时长随机
	_set_state(S.DOWN)


func _die() -> void:
	alive = false
	state = S.DEAD
	state_t = 0.0
	stepping = false
	ring.visible = false
	squad.on_unit_died(self)
	# 尸体加随机偏转
	mesh.set_instance_shader_parameter("spin", randf_range(-0.15, 0.15))
	main.spawn_blood_pool(position)


func _drown() -> void:
	alive = false
	drowned = true
	state = S.DEAD
	state_t = 0.0
	ring.visible = false
	shadow.visible = false
	squad.on_unit_died(self)
	main.spawn_splash(position)
	main.note("drown")


func _process_dead(delta: float) -> void:
	state_t += delta
	flash = max(0.0, flash - delta * 6.0)
	mesh.set_instance_shader_parameter("flash", flash)
	if drowned:
		position.y -= delta * 0.5
		if state_t > 1.2:
			visible = false
			set_process(false)
		return
	_set_anim("dead", 0 if state_t < 0.25 else 1)
	if state_t > 0.3:
		_apply_visuals()
		shadow.visible = false
		set_process(false)


# ---------- 工具 ----------

func _flat_vec(from: Vector3, to: Vector3) -> Vector3:
	return Vector3(to.x - from.x, 0.0, to.z - from.z)


func _flat_dir(p: Vector3) -> Vector3:
	var v := _flat_vec(position, p)
	return v.normalized() if v.length() > 0.001 else facing


func _flat_dist(u) -> float:
	return _flat_vec(position, u.position).length()


func _flat_dist_pt(p: Vector3) -> float:
	return _flat_vec(position, p).length()


func set_selected(on: bool) -> void:
	ring.visible = on and alive
