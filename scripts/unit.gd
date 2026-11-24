class_name Unit
extends Node3D
## 小兵 = Agent 本体 + 若干组件挂在状态树上（规格 docs/badnorth-behavior-spec.md）。
## - 逻辑位置 nav_pos 连续移动；身体 vis_pos 一步一步追（Body，规格 5.1）
## - 感知来自阵营势力场（Presence），命令来自小队站位
## - 受击：速度 += 击退/质量；冲击累积到随机阈值滑退或倒地（Stun，规格 8）
## - 水边被推出去、或受到抛射 → 击飞（Ragdoll，规格 9）
## 每帧由 main 统一调用 tick()，保证"采样 → 状态树 → 移动"的顺序。

const QUAD := 0.64
const WALK_LEN := 0.667
const CLIPS := {
	# 名字: [精灵动画, 时长, 循环]
	"idle": ["idle", 0.667, true],
	"attack": ["attack", 0.6, false],
	"clash": ["clash", 0.35, false],
	"parry": ["block", 0.65, false],
	"sit": ["down", 1.0, true],
	"rise": ["getup", 0.833, false],
	"death": ["dead", 0.583, false],
	"ragdoll": ["tumble", 0.517, true],
}

var main
var terrain: Terrain
var squad
var faction := 0
var brain: Swordsman
var beats: Beats
var removed := false
var corpse := false

var mesh: MeshInstance3D
var shadow: MeshInstance3D
var ring: MeshInstance3D
var anims: Dictionary
var fall_frames := PackedInt32Array()
# 精灵集：direct=true 时动画表里有与片段同名的动画（Blender 管线），直接按名字和 JSON 时长播放
var sprite_direct := false
var sprite_lens := {}
var sprite_loops := {}

# 数值
var max_hp := 1.0
var hp := 1.0
var max_speed := 2.0
var speed := 2.0
var size_scale := 1.0
var stun_mult := 1.0
var radius: float:
	get:
		return 0.12 * size_scale
var mass: float:
	get:
		return size_scale * size_scale * size_scale
var alive: bool:
	get:
		return alive_st != null and alive_st.active

# 运动
var nav_pos := Vector3.ZERO
var vis_pos := Vector3.ZERO
var walk_dir := Vector3.ZERO
var velocity := Vector3.ZERO
var movability := 1.0
var walked := 0.0
var facing := Vector3(1, 0, 0)
var _look := Vector3.ZERO
var _look_speed := 720.0
var _look_thr := 20.0
var flipped := false

# 感知与命令
var enemy = null
var enemy_dist := 1.0e6
var enemy_dir := Vector3.ZERO
var enemy_dangerous := false
var dangerous := true
var soft_int := 0.0
var hard_int := 0.0
var slot := Vector3.ZERO
var slot_look := Vector3(0, 0, -1)
var order_dir := Vector3.ZERO
var order_dist := 0.0

# 状态
var root: AgentState
var life: AgentState
var alive_st: AgentState
var dead: AgentState
var alive_grounded: AgentState
var exclusives: AgentState
var navigation: AgentState
var grounded: AgentState
var ragdoll_st: AgentState
var hopping: AgentState
var standing: AgentState
var stepping: AgentState
var sliding: AgentState
var move_animate: AgentState
var stun_fall: AgentState
var stun_slide: AgentState
var rise: AgentState

# 身体
var anchor := Vector3.ZERO
var step := 1.0
var step_time := 0.2
var step_from := Vector3.ZERO
var step_to := Vector3.ZERO
var parity := 0

# 动画
var anim_name := "idle"
var anim_t := 0.0
var anim_changed := false
var idle_offset := 0.0
var _frame := -1

# 眩晕 / 击飞
var acc_stun := 0.0
var stun_timer := 0.0
var fall_phase := 0
var rag_vel := Vector3.ZERO
var flash := 0.0
var stretch := 0.0


func setup(p_main, p_squad, p_faction: int, palette_row: int, pos: Vector3, stats: Dictionary) -> void:
	main = p_main
	terrain = p_main.terrain
	squad = p_squad
	faction = p_faction
	var sp: Dictionary = p_main.sprite_sets[stats.get("sprite", "proc")]
	anims = sp["anims"]
	sprite_direct = sp["direct"]
	sprite_lens = sp["lens"]
	sprite_loops = sp["loops"]
	max_hp = stats.get("hp", 1.0)
	hp = max_hp
	max_speed = stats.get("speed", 2.0)
	speed = max_speed
	stun_mult = stats.get("stun_mult", 1.0)
	nav_pos = Vector3(pos.x, terrain.height_at(pos), pos.z)
	vis_pos = nav_pos
	anchor = nav_pos
	step_from = nav_pos
	step_to = nav_pos
	position = vis_pos
	slot = nav_pos
	beats = Beats.new()
	idle_offset = randf()
	# 倒下：受击后仰 → 跪 → 坐 → 躺（借用已有帧）
	if not sprite_direct:
		var hit: Vector2i = anims["hit"]
		var getup: Vector2i = anims["getup"]
		var down: Vector2i = anims["down"]
		fall_frames = PackedInt32Array([hit.x, getup.x + mini(2, getup.y - 1), getup.x + mini(1, getup.y - 1), down.x])

	mesh = MeshInstance3D.new()
	mesh.mesh = p_main.unit_quad
	mesh.material_override = sp["material"]
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

	_build_states(stats)


# ---------- 状态树 ----------

func _build_states(stats: Dictionary) -> void:
	root = AgentState.new("Root", null, true, false)
	life = AgentState.new("Life", root, true, false)
	alive_st = AgentState.new("Alive", life, true, true)
	dead = AgentState.new("Dead", life, false, true)
	alive_grounded = AgentState.new("AliveGrounded", root, false, false)
	exclusives = AgentState.new("Exclusives", alive_grounded, false, false)
	navigation = AgentState.new("Navigation", root, true, false)
	grounded = AgentState.new("Grounded", navigation, true, true)
	ragdoll_st = AgentState.new("Ragdoll", navigation, false, true)
	hopping = AgentState.new("Hop", grounded, false, true)
	sliding = AgentState.new("Slide", grounded, false, true)
	standing = AgentState.new("Standing", hopping, false, true)
	stepping = AgentState.new("Stepping", hopping, false, true)
	move_animate = AgentState.new("MoveAnimate", root, true, false)
	stun_fall = AgentState.new("Stun", exclusives, false, true)
	rise = AgentState.new("Rise", exclusives, false, true)
	stun_slide = AgentState.new("StunSlide", sliding, false, true)
	brain = Swordsman.new()
	brain.setup(self, exclusives, stats)

	# 空槽回退链
	alive_grounded.on_empty.append(exclusives.set_true)
	exclusives.on_empty.append(brain.brain.set_true)
	grounded.on_empty.append(hopping.set_true)
	hopping.on_empty.append(stepping.set_true)
	alive_st.on_change.append(func(_v: bool): _refresh_alive_grounded())
	grounded.on_change.append(func(_v: bool): _refresh_alive_grounded())
	grounded.on_change.append(func(v: bool): shadow.visible = v)
	alive_grounded.on_deactivate.append(func():
		enemy = null
		enemy_dist = 1.0e6
		enemy_dir = Vector3.ZERO
		order_dir = Vector3.ZERO
		order_dist = 0.0)
	alive_grounded.on_update.append(func(): acc_stun = move_toward(acc_stun, 0.0, AgentState.dt / 4.0))

	# 身体
	standing.on_activate.append(func():
		if move_animate.active:
			play("idle", idle_offset)
		anchor = vis_pos)
	standing.on_update.append(_standing_update)
	stepping.on_activate.append(func():
		step = 1.0
		step_time = 0.4 / lerpf(max_speed, 2.0, 0.8))
	stepping.on_update.append(_stepping_update)
	sliding.on_update.append(_sliding_update)
	move_animate.on_activate.append(func():
		if standing.active:
			play("idle", idle_offset))

	# 眩晕
	stun_fall.on_change.append(func(v: bool):
		move_animate.set_active(not v)
		sliding.set_active(v))
	stun_fall.on_activate.append(func():
		fall_phase = 0
		play("fall")
		main.note("fall"))
	stun_fall.on_update.append(_fall_update)
	stun_fall.on_deactivate.append(func(): acc_stun = 0.0)
	stun_slide.on_activate.append(func(): main.note("slide"))
	stun_slide.on_update.append(func():
		if velocity.length_squared() < 0.04:
			sliding.set_false())

	# 击飞与爬起
	ragdoll_st.on_change.append(func(v: bool): move_animate.set_active(not v))
	ragdoll_st.on_update.append(_ragdoll_update)
	rise.on_change.append(func(v: bool):
		move_animate.set_active(not v)
		sliding.set_active(v))
	rise.on_activate.append(func(): play("rise"))
	rise.on_update.append(func():
		if anim_done():
			rise.set_false()
			brain.evaluate_new_state())

	# 死亡
	dead.on_activate.append(_start_die)
	dead.on_update.append(_dead_update)

	hopping.set_true()
	_refresh_alive_grounded()


func _refresh_alive_grounded() -> void:
	alive_grounded.set_active(alive_st.active and grounded.active)


# ---------- 每帧 ----------

func tick(dt: float) -> void:
	if removed:
		return
	if anim_changed:
		anim_changed = false
	else:
		anim_t += dt
	walk_dir = Vector3.ZERO
	movability = 1.0
	flash = maxf(0.0, flash - dt * 6.0)
	if alive_grounded.active:
		_sense()
	root.update()
	if removed:
		return
	if grounded.active:
		_move(dt)
	_look = Vector3.ZERO
	if alive:
		hp = move_toward(hp, max_hp, dt / 60.0)
	_apply_visuals()


func _sense() -> void:
	var r: Array = main.presence[1 - faction].sample(nav_pos)
	enemy_dist = r[0]
	enemy_dir = r[1]
	enemy = r[2]
	enemy_dangerous = enemy != null and enemy.dangerous
	var v := slot - nav_pos
	v.y = 0.0
	order_dist = v.length()
	if order_dist > 0.3 and not terrain.line_clear(nav_pos, slot):
		order_dir = terrain.flow_dir(nav_pos, terrain.tile_of(slot))
	else:
		order_dir = v.limit_length(1.0)


func _move(dt: float) -> void:
	var pos := nav_pos
	var wd := Vector3(walk_dir.x, 0.0, walk_dir.z)
	if wd.length_squared() > 1e-8 and hopping.active:
		var sp := speed * Swordsman._remap(wd.normalized().dot(facing), -1.0, 1.0, 0.7, 1.1) * movability
		pos = _try_move(pos, wd.limit_length(dt * sp))
	if velocity.length_squared() > 1e-8:
		velocity.y = 0.0
		pos = _move_velocity(pos, dt)
		if not grounded.active:
			return
	velocity *= pow(0.9, dt * 50.0)
	if velocity.length_squared() < 1e-6:
		velocity = Vector3.ZERO
	nav_pos = Vector3(pos.x, terrain.height_at(pos), pos.z)
	speed = max_speed
	_apply_look(dt)


func _try_move(pos: Vector3, d: Vector3) -> Vector3:
	for cand in [d, Vector3(d.x, 0, 0), Vector3(0, 0, d.z)]:
		var np: Vector3 = pos + cand
		if terrain.is_walkable_at(np) and terrain.can_step(pos, np):
			return np
	return pos


## 按速度移动：撞普通边界反弹减半；撞水边，朝外速度 ≥ 2 就被推下去，否则沿边滑
func _move_velocity(pos: Vector3, dt: float) -> Vector3:
	var np := pos + velocity * dt
	if terrain.is_walkable_at(np) and terrain.can_step(pos, np):
		return np
	for axis: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		var comp := velocity.dot(axis)
		var probe := pos + axis * comp * dt
		if terrain.is_walkable_at(probe) and terrain.can_step(pos, probe):
			continue
		if not terrain.is_land_at(probe):
			if absf(comp) >= 2.0:
				launch(velocity + Vector3.UP * 0.67)
				return pos
			velocity -= axis * comp
		else:
			velocity -= axis * comp * 1.5   # 反射并减半
	return _try_move(pos, velocity * dt)


func look(dir: Vector3, spd: float = 720.0, thr: float = 20.0) -> void:
	_look = Vector3(dir.x, 0.0, dir.z)
	_look_speed = spd
	_look_thr = thr


func set_dir(dir: Vector3) -> void:
	var f := Vector3(dir.x, 0.0, dir.z)
	if f.length_squared() > 1e-6:
		facing = f.normalized()


func _apply_look(dt: float) -> void:
	if _look.length_squared() < 1e-6:
		return
	var target := _look.normalized()
	var ang := facing.signed_angle_to(target, Vector3.UP)
	if absf(rad_to_deg(ang)) < _look_thr:
		return
	var stepv := deg_to_rad(_look_speed) * dt
	facing = facing.rotated(Vector3.UP, clampf(ang, -stepv, stepv)).normalized()


## 小队命令：走向站位；到了以后面朝站位朝向
func apply_order() -> void:
	walk_dir = order_dir
	look(order_dir if order_dist > 0.05 else slot_look)


func order_dist_to(p: Vector3) -> float:
	return Vector2(slot.x - p.x, slot.z - p.z).length()


func order_dir_at(p: Vector3) -> Vector3:
	return Vector3(slot.x - p.x, 0.0, slot.z - p.z).limit_length(1.0)


func intimidate(soft: float, hard: float) -> void:
	soft_int = maxf(soft_int, soft)
	hard_int = maxf(hard_int, hard)


func intimidated() -> bool:
	return soft_int + hard_int > 0.0


func friend_ratio() -> float:
	var a: float = main.presence[faction].amount_at(nav_pos)
	var b: float = main.presence[1 - faction].amount_at(nav_pos)
	return 0.5 if a + b < 1e-4 else a / (a + b)


# ---------- 身体：一步一跳 ----------

func _standing_update() -> void:
	var v := nav_pos - anchor
	v.y = 0.0
	var small := radius * 0.3
	if v.length_squared() > small * small:
		stepping.set_true()
		return
	vis_pos = Vector3(vis_pos.x, nav_pos.y, vis_pos.z)
	anchor = vis_pos


func _stepping_update() -> void:
	var dt := AgentState.dt
	step += dt / step_time
	if step >= 1.0:
		step -= 1.0
		step *= step_time
		step_from = vis_pos
		step_to = nav_pos
		var d := Vector2(step_to.x - step_from.x, step_to.z - step_from.z).length()
		if d < 0.01:
			vis_pos = nav_pos
			standing.set_true()
			return
		walked += d
		step_time = (d * 0.08 + 0.4) / lerpf(max_speed, 2.0, 0.8)
		step /= step_time
		parity = 1 - parity
		if d > 0.2:
			main.spawn_dust(vis_pos, 1, 0.4)
	if velocity.length_squared() > 0.0:
		var push := velocity * dt
		step_from += push
		step_to += push
	var t := clampf(step, 0.0, 1.0)
	var p := step_from.lerp(step_to, t)
	# 平地直线插值（起伏交给精灵帧，同 Bad North）；只有上台阶时才抬起
	var climb := step_to.y - step_from.y
	if climb > 0.01:
		p.y += sin(t * PI) * climb * 0.6
	vis_pos = p
	stretch = 0.01 * sin(t * PI)
	if move_animate.active:
		anim_name = "walk"
		anim_t = (t * 0.5 + 0.5 * parity) * WALK_LEN


func _sliding_update() -> void:
	vis_pos = nav_pos
	if alive and velocity.length_squared() < 0.0001 and not stun_fall.active and not rise.active and not brain.clash.active:
		sliding.set_false()
		return
	if move_animate.active and anim_name != "idle":
		play("idle", idle_offset)


# ---------- 受击 ----------

func deal_damage(atk: Dictionary) -> bool:
	brain.modify_attack(atk)
	var dir: Vector3 = atk.dir
	dir.y = 0.0
	dir = dir.normalized()
	var kb: float = atk.knockback / mass
	var add := dir * kb
	var along := (velocity + add).dot(dir)
	if along > kb:
		add -= dir * (along - kb)
	var launch_imp: float = atk.get("launch", 0.0) / (size_scale * size_scale)
	var killed := false
	if alive_st.active:
		if atk.damage > 0.0 or atk.knockback > 0.0:
			hp -= atk.damage
		if atk.damage > 0.0:
			flash = 1.0
			main.spawn_blood(nav_pos, dir)
			main.note("hit")
		if hp <= 0.0:
			killed = true
			dead.set_true()
			squad.report_dead(self)
		else:
			_post_attack(atk)
	else:
		add *= 0.5
	velocity += add
	if launch_imp >= 0.9:
		var v := velocity
		v.y = maxf(v.y, 0.0) + launch_imp
		launch(v)
	if atk.get("parried", false) or atk.get("shield_fx", false):
		flash = maxf(flash, 0.25)
	return killed


## 冲击累积（规格 8）：阈值每次都重新随机
func _post_attack(atk: Dictionary) -> void:
	if not alive_grounded.active:
		return
	acc_stun += atk.get("stun", 1.0) * stun_mult / mass
	if acc_stun > randf_range(1.0, 3.0) and not stun_fall.active:
		stun_fall.set_true()
		stun_timer = maxf(sqrt(acc_stun), 2.0) * randf_range(0.5, 1.0)
	elif acc_stun > randf_range(0.7, 1.2):
		stun_slide.set_true()


func _fall_update() -> void:
	movability = 0.1
	match fall_phase:
		0:
			if velocity.length_squared() > 4.0:
				play("fall")
			else:
				fall_phase = 1
		1:
			if anim_done():
				main.spawn_dust(vis_pos, 3, 0.6)
				play("sit")
				fall_phase = 2
		2:
			stun_timer -= AgentState.dt
			if stun_timer <= 0.0:
				play("rise")
				fall_phase = 3
		3:
			if anim_done():
				stun_fall.set_false()
				brain.evaluate_new_state()


# ---------- 击飞 ----------

func launch(v: Vector3) -> void:
	if ragdoll_st.active:
		return
	rag_vel = v
	ragdoll_st.set_true()
	play("ragdoll", randf())
	main.note("launch")
	main.shake(0.05)


func _ragdoll_update() -> void:
	var dt := AgentState.dt
	rag_vel.y -= 9.8 * dt
	var np := vis_pos + rag_vel * dt
	# 撞到更高的地块侧面：水平反弹
	if terrain.is_land_at(np) and terrain.height_at(np) > vis_pos.y + 0.05:
		rag_vel.x *= -0.3
		rag_vel.z *= -0.3
		np = vis_pos + Vector3(0, rag_vel.y * dt, 0)
	vis_pos = np
	if not terrain.is_land_at(vis_pos):
		if vis_pos.y < Terrain.WATER_Y - 0.2:
			main.spawn_splash(vis_pos)
			main.note("drown")
			if not dead.active:
				dead.set_true()
				squad.report_dead(self)
			_remove(false)
		return
	var ground := terrain.height_at(vis_pos)
	if vis_pos.y > ground:
		return
	vis_pos.y = ground
	var impact := -rag_vel.y
	if dead.active or impact > 12.0:
		main.spawn_blood_pool(vis_pos)
		if not dead.active:
			hp = 0.0
			dead.set_true()
			squad.report_dead(self)
		_remove(true)
		return
	main.spawn_dust(vis_pos, 3, 0.7)
	if ragdoll_st.since() > 0.2 and rag_vel.length() < 4.0 and terrain.is_walkable_at(vis_pos):
		# 落地附着：保留 20% 速度，爬起
		nav_pos = vis_pos
		velocity = Vector3(rag_vel.x, 0.0, rag_vel.z) * 0.2
		grounded.set_true()
		hopping.set_true()
		if alive:
			rise.set_true()
		return
	rag_vel.y = impact * 0.3
	rag_vel.x *= 0.6
	rag_vel.z *= 0.6
	play("ragdoll", randf())


# ---------- 死亡 ----------

func _start_die() -> void:
	ring.visible = false
	if grounded.active:
		play("death")
		move_animate.set_false()
		sliding.set_true()
	main.note("death")


func _dead_update() -> void:
	if removed:
		return
	if grounded.active and anim_done():
		main.spawn_blood_pool(nav_pos)
		_remove(true)
	elif dead.since() > 8.0:
		_remove(true)


## 移出模拟。keep_corpse 为真时留下最后一帧作为尸体。
func _remove(keep_corpse: bool) -> void:
	if removed:
		return
	removed = true
	main.on_unit_removed(self)
	if not keep_corpse:
		visible = false
		return
	corpse = true
	anim_name = "death"
	anim_t = 10.0
	shadow.visible = false
	mesh.set_instance_shader_parameter("spin", randf_range(-0.15, 0.15))
	_apply_visuals()


# ---------- 动画与显示 ----------

func play(clip: String, start_norm: float = 0.0) -> void:
	anim_name = clip
	anim_t = start_norm * _clip_len(clip)
	anim_changed = true


func _clip_len(clip: String) -> float:
	if sprite_direct and sprite_lens.has(clip):
		return sprite_lens[clip]
	if clip == "fall":
		return 0.35
	if clip == "walk":
		return WALK_LEN
	return CLIPS[clip][1]


func anim_norm() -> float:
	return anim_t / _clip_len(anim_name)


func anim_done() -> bool:
	return not anim_changed and anim_t >= _clip_len(anim_name)


func _current_frame() -> int:
	var clip_len := _clip_len(anim_name)
	var k := anim_t / clip_len
	if sprite_direct and anims.has(anim_name):
		var d: Vector2i = anims[anim_name]
		if sprite_loops.get(anim_name, false):
			k = fposmod(k, 1.0)
		return d.x + clampi(int(k * d.y), 0, d.y - 1)
	if anim_name == "fall":
		return fall_frames[mini(int(k * fall_frames.size()), fall_frames.size() - 1)]
	var sprite_anim := "walk" if anim_name == "walk" else String(CLIPS[anim_name][0])
	var loop: bool = anim_name == "walk" or CLIPS[anim_name][2]
	var a: Vector2i = anims[sprite_anim]
	if loop:
		k = fposmod(k, 1.0)
	return a.x + mini(int(k * a.y), a.y - 1)


func _apply_visuals() -> void:
	position = vis_pos
	var f := _current_frame()
	if f != _frame:
		_frame = f
		mesh.set_instance_shader_parameter("frame", float(f))
	var d: float = facing.dot(main.cam_right())
	if flipped and d > 0.1:
		flipped = false
	elif not flipped and d < -0.1:
		flipped = true
	mesh.set_instance_shader_parameter("flip", 1.0 if flipped else 0.0)
	mesh.set_instance_shader_parameter("flash", flash)
	mesh.set_instance_shader_parameter("stretch", stretch if stepping.active else 0.0)
	mesh.set_instance_shader_parameter("health", clampf(hp / max_hp, 0.0, 1.0))
	var g := terrain.height_at(vis_pos)
	mesh.set_instance_shader_parameter("grass", terrain.grass_at(vis_pos) if grounded.active else 0.0)
	shadow.global_position = Vector3(vis_pos.x, g + 0.015, vis_pos.z)
	var air: float = maxf(0.0, vis_pos.y - g)
	shadow.scale = Vector3.ONE * clampf(1.0 - air * 0.9, 0.4, 1.0) * size_scale


func set_selected(on: bool) -> void:
	ring.visible = on and alive


## 调试：当前激活的状态路径
func state_path() -> String:
	var ex := exclusives.path() if exclusives.active else life.path()
	return "%s [%s]" % [ex.trim_prefix("Exclusives/"), navigation.path().trim_prefix("Navigation/")]
