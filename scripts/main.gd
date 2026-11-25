extends Node3D
## 战斗原型主场景：搭环境、生成岛屿和两军、处理输入、镜头、特效和胜负。
## 命令行（-- 之后）：--auto 自动进攻；--shots=1,3,5 按真实秒数截图；--out=目录；
## --zoom=距离；--yaw=度；--focus=x,z；--dump_atlas 导出精灵图集预览。

const SLOW := 0.3
const BATTLE_DIR := "res://data/battles"
const FOG_COLOR := Color(0.75, 0.76, 0.78)
const CAM_PITCH := 30.0
# 模拟固定步长：战斗结果只取决于种子和步数，不受无头/有窗口的帧率影响。
const SIM_STEP := 1.0 / 60.0
const SIM_MAX_STEPS := 8   # 单帧最多补 8 步（约 0.13 秒），卡顿后不追帧到死循环
const PALETTE := [
	# 0 王国民兵
	{1: Color(0.94, 0.76, 0.6), 2: Color(0.22, 0.38, 0.74), 3: Color(0.38, 0.29, 0.21), 4: Color(0.72, 0.74, 0.78),
	 5: Color(0.9, 0.92, 0.96), 6: Color(0.46, 0.31, 0.19), 7: Color(0.88, 0.86, 0.78), 8: Color(0.22, 0.33, 0.64),
	 9: Color(0.1, 0.08, 0.08), 10: Color(0.3, 0.2, 0.12), 15: Color(0.09, 0.08, 0.08)},
	# 1 王国老兵
	{1: Color(0.92, 0.74, 0.58), 2: Color(0.74, 0.17, 0.15), 3: Color(0.3, 0.24, 0.2), 4: Color(0.78, 0.8, 0.84),
	 5: Color(0.92, 0.94, 0.98), 6: Color(0.4, 0.26, 0.15), 7: Color(0.8, 0.2, 0.16), 8: Color(0.88, 0.76, 0.4),
	 9: Color(0.1, 0.08, 0.08), 10: Color(0.25, 0.16, 0.1), 15: Color(0.09, 0.07, 0.07)},
	# 2 亡魂兵
	{1: Color(0.72, 0.8, 0.74), 2: Color(0.27, 0.21, 0.34), 3: Color(0.18, 0.16, 0.21), 4: Color(0.44, 0.4, 0.35),
	 5: Color(0.62, 0.88, 0.84), 6: Color(0.26, 0.21, 0.21), 7: Color(0.34, 0.31, 0.38), 8: Color(0.52, 0.47, 0.41),
	 9: Color(0.5, 1.0, 0.92), 10: Color(0.2, 0.16, 0.18), 15: Color(0.06, 0.05, 0.09)},
	# 3 亡魂精锐
	{1: Color(0.78, 0.84, 0.78), 2: Color(0.12, 0.34, 0.36), 3: Color(0.15, 0.18, 0.2), 4: Color(0.5, 0.48, 0.44),
	 5: Color(0.7, 0.95, 0.9), 6: Color(0.3, 0.25, 0.22), 7: Color(0.2, 0.42, 0.44), 8: Color(0.84, 0.82, 0.72),
	 9: Color(0.75, 1.0, 0.6), 10: Color(0.18, 0.14, 0.14), 15: Color(0.05, 0.06, 0.08)},
]

var terrain: Terrain
var camera: Camera3D
var units: Array = []
var presence: Array = []
var squads: Array = []
var player_squads: Array = []
var time := 0.0
var selected = null

# 模拟随机源：只由 --seed 决定，只给战斗逻辑用；视觉特效走 art_rng，互不干扰。
var sim_rng := RandomNumberGenerator.new()
var art_rng := RandomNumberGenerator.new()
var sim_accum := 0.0
var auto_ordered := false

var anims: Dictionary
var sprite_sets := {}   # 名字 → {material, anims, lens, loops, direct}
var unit_material: ShaderMaterial
var unit_quad: QuadMesh
var shadow_mesh: PlaneMesh
var ring_mesh: PlaneMesh
var soft_tex: ImageTexture
var blob_tex: ImageTexture
var puff_mesh: QuadMesh
var dust_mat: StandardMaterial3D
var splash_mat: StandardMaterial3D
var spark_mat: StandardMaterial3D
var blood_puff_mat: StandardMaterial3D
var blood_mat: StandardMaterial3D
var decals: Array = []
var marker: MeshInstance3D

var cam_yaw := 0.0
var cam_yaw_target := 0.0
var cam_pitch := deg_to_rad(CAM_PITCH)
var cam_dist := 15.0
var sel_zoom := 1.0
var sel_pull := Vector3.ZERO
var cam_focus := Vector3(12, 0.5, 12)
var shake_amt := 0.0

var label: Label
var banner: Label
var flag_pos := Vector3.ZERO
var flag_cloth: MeshInstance3D
var capture := 0.0
var capture_player_radius := 0.0
var capture_defender_radius := 0.0
var capture_time := 1.0
var capture_decay := 0.0
var game_over := false

var battle := {}

var args := {}
var shots: Array = []
var shot_idx := 0
var real_start := 0
var last_ticks := 0


func _ready() -> void:
	_parse_args()
	battle = _load_battle(String(args["battle"]))
	if battle.is_empty():
		push_error("无法读取战斗配置：" + String(args["battle"]))
		get_tree().quit(1)
		return
	var seed_value := int(args.get("seed", "7"))
	seed(seed_value)
	sim_rng.seed = seed_value
	art_rng.seed = seed_value + 104729
	_setup_env()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.generate(int(args.get("island", "3")))
	_setup_light()
	_setup_assets()
	_setup_camera()
	_spawn_armies()
	_setup_ui()
	if not args.has("no_prewarm"):
		_prewarm()
	real_start = Time.get_ticks_msec()
	last_ticks = real_start
	if args.has("click_test"):
		get_tree().create_timer(1.0).timeout.connect(_click_test)


## 用合成的鼠标事件走一遍"点选小兵 → 点地面下令"的输入路径。
func _click_test() -> void:
	var sq: Squad = player_squads[0]
	var u = sq.alive_units()[0]
	_send_click(camera.unproject_position(u.position + Vector3(0, 0.3, 0)))
	await get_tree().process_frame
	print("CLICK selected=", selected.title if selected else "none", " time_scale=", Engine.time_scale)
	var dest := terrain.nearest_walkable(flag_pos.lerp(sq.center(), 0.5))
	_send_click(camera.unproject_position(dest))
	await get_tree().process_frame
	print("CLICK order target=", sq.target_point.snappedf(0.1), " expected≈", dest.snappedf(0.1), " selected=", selected, " time_scale=", Engine.time_scale)


func _send_click(p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)


## 开场把每种特效材质各画一次，避免第一次命中时编译着色器卡顿。
func _prewarm() -> void:
	var p := camera.position + (cam_focus - camera.position).normalized() * 3.0
	for mat in [dust_mat, splash_mat, spark_mat, blood_puff_mat]:
		_puff(p, mat, 0.01, 0.1, Vector3.ZERO)
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.01, 0.01)
	m.mesh = pm
	m.material_override = blood_mat
	add_child(m)
	m.position = p
	get_tree().create_timer(0.2).timeout.connect(m.queue_free)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if not args.has("battle"):
		args["battle"] = "proto"
	if args.has("shots"):
		for s in String(args["shots"]).split(","):
			shots.append(float(s))


## 战斗配置只描述一场战斗（守军、站位、夺旗规则），不参与随机数。
func _load_battle(id: String) -> Dictionary:
	var path := BATTLE_DIR.path_join(id + ".json")
	if not FileAccess.file_exists(path):
		push_error("找不到战斗配置：" + path)
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("战斗配置不是 JSON 对象：" + path)
		return {}
	return data


# ---------- 环境 ----------

## 不用实时光和实时阴影：背景就是雾色，海面是一张雾平面。
func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sea := MeshInstance3D.new()
	var sm := PlaneMesh.new()
	sm.size = Vector2(240, 240)
	sea.mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fog_sea.gdshader")
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	mat.set_shader_parameter("cloud_noise", tex)
	mat.set_shader_parameter("fog_color", Vector3(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b))
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position = Vector3(12, Terrain.WATER_Y, 12)
	add_child(sea)


## 太阳在 X-Y 平面里：elev 是仰角（度），正值从 +X 侧照来。
func _setup_light() -> void:
	var elev := deg_to_rad(float(args.get("sun", "55")))
	var to_sun := Vector3(cos(elev), sin(elev), 0.0)
	terrain.set_light_param("sun_dir", -to_sun)
	terrain.set_light_param("fog_color", Vector3(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b))
	terrain.set_light_param("water_y", Terrain.WATER_Y)
	var c := Terrain.SIZE * 0.5
	terrain.set_light_param("fog_center", Vector2(c, c))
	# 雾的内外径：岛半径 × 0.5 + 1 到 × 1.2 + 2
	var r := Terrain.SIZE * 0.42
	terrain.set_light_param("fog_min", r * 0.5 + 1.0)
	terrain.set_light_param("fog_max", r * 1.2 + 2.0)


func _setup_assets() -> void:
	var res := SpriteFactory.build()
	var img: Image = res["image"]
	anims = res["anims"]
	var pal := _make_palette()
	if args.has("dump_atlas"):
		_dump_atlas(img, pal)
	unit_material = ShaderMaterial.new()
	unit_material.shader = load("res://shaders/unit.gdshader")
	unit_material.set_shader_parameter("atlas", ImageTexture.create_from_image(img))
	unit_material.set_shader_parameter("atlas_coverage", unit_material.get_shader_parameter("atlas"))
	unit_material.set_shader_parameter("parts", ImageTexture.create_from_image(pal))
	unit_material.set_shader_parameter("look_grid", Vector2(SpriteFactory.LOOK_GRID))
	unit_material.set_shader_parameter("atlas_grid", res["grid"])
	unit_material.set_shader_parameter("quad_size", Unit.QUAD)
	sprite_sets["proc"] = {"material": unit_material, "anims": anims, "lens": {}, "loops": {}, "direct": false}
	var shield := _load_blender_sprites("k2_shieldman")
	if not shield.is_empty():
		sprite_sets["shieldman"] = shield
	unit_quad = QuadMesh.new()
	unit_quad.size = Vector2(Unit.QUAD, Unit.QUAD)
	unit_quad.center_offset = Vector3(0, Unit.QUAD * 0.5, 0)

	soft_tex = ImageTexture.create_from_image(_circle_image(32, 0.0, 0.5, false))
	blob_tex = ImageTexture.create_from_image(_circle_image(32, 0.0, 0.45, true))
	var ring_tex := ImageTexture.create_from_image(_circle_image(64, 0.34, 0.46, false))

	shadow_mesh = PlaneMesh.new()
	shadow_mesh.size = Vector2(0.34, 0.23)
	var smat := _flat_mat(soft_tex, Color(0.05, 0.04, 0.08, 0.6))
	shadow_mesh.material = smat
	ring_mesh = PlaneMesh.new()
	ring_mesh.size = Vector2(0.55, 0.55)
	ring_mesh.material = _flat_mat(ring_tex, Color(0.55, 1.0, 0.9, 0.95))

	puff_mesh = QuadMesh.new()
	puff_mesh.size = Vector2(0.16, 0.16)
	dust_mat = _puff_mat(Color(0.86, 0.8, 0.68, 0.85), false)
	splash_mat = _puff_mat(Color(0.9, 0.96, 1.0, 0.9), false)
	spark_mat = _puff_mat(Color(1.0, 0.86, 0.45, 1.0), true)
	blood_puff_mat = _puff_mat(Color(0.55, 0.04, 0.04, 0.95), false)
	blood_mat = StandardMaterial3D.new()
	blood_mat.albedo_texture = blob_tex
	blood_mat.albedo_color = Color(0.45, 0.03, 0.03)
	blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	blood_mat.alpha_scissor_threshold = 0.5
	blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	marker = MeshInstance3D.new()
	var mm := PlaneMesh.new()
	mm.size = Vector2(1.3, 1.3)
	mm.material = _flat_mat(ring_tex, Color(0.55, 1.0, 0.9, 1.0))
	marker.mesh = mm
	marker.visible = false
	add_child(marker)


## 读取 Blender 管线产出的 UV 精灵（docs/sprite-pipeline.md）：图集 + 部位贴图 + JSON 动画表。
## 用 Image.load_from_file 直接读原始 PNG，绕过导入设置（数据图不能做 sRGB 或压缩）。
func _load_blender_sprites(id: String) -> Dictionary:
	var dir := "res://assets/sprites/"
	var json_path := ProjectSettings.globalize_path(dir + id + "_uv.json")
	if not FileAccess.file_exists(json_path):
		push_warning("缺少精灵：" + json_path)
		return {}
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(dir + String(meta["image"])))
	var parts := Image.load_from_file(ProjectSettings.globalize_path(dir + String(meta["part_texture"]["image"])))
	var atlas_tex := ImageTexture.create_from_image(atlas)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/unit.gdshader")
	mat.set_shader_parameter("atlas", atlas_tex)
	mat.set_shader_parameter("atlas_coverage", atlas_tex)
	mat.set_shader_parameter("parts", ImageTexture.create_from_image(parts))
	var grid: Array = meta["part_texture"]["grid"]
	mat.set_shader_parameter("look_grid", Vector2(grid[0], grid[1]))
	mat.set_shader_parameter("atlas_grid", Vector2(meta["columns"], meta["rows"]))
	mat.set_shader_parameter("quad_size", Unit.QUAD)
	mat.set_shader_parameter("v_up", true)
	mat.set_shader_parameter("light_mode", 1)
	mat.set_shader_parameter("blood_from_alpha", false)
	# 沾血分区：皮肤、头盔、外衣、衣边、袖子、裤子（按左下角起的 4×4 分区编号）
	var stain := 0
	for name in ["skin", "helmet", "tunic", "cloth_trim", "sleeves", "trousers"]:
		var c: Array = meta["part_texture"]["regions"][name]["cell"]
		stain |= 1 << (int(c[1]) * 4 + int(c[0]))
	mat.set_shader_parameter("stain_mask", stain)
	var eye: Array = meta["part_texture"]["regions"]["eye"]["cell"]
	mat.set_shader_parameter("eye_cell", int(eye[1]) * 4 + int(eye[0]))
	var a := {}
	var lens := {}
	var loops := {}
	for name in meta["animations"]:
		var an: Dictionary = meta["animations"][name]
		a[name] = Vector2i(int(an["start_frame"]), int(an["frame_count"]))
		lens[name] = float(an["duration"])
		loops[name] = bool(an["loop"])
	return {"material": mat, "anims": a, "lens": lens, "loops": loops, "direct": true}


func _make_palette() -> Image:
	# Keep the existing faction hues; each look now contains ten textured regions.
	return SpriteFactory.make_parts(PALETTE)


func _dump_atlas(img: Image, pal: Image) -> void:
	var out_dir: String = args.get("out", "res://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	img.save_png(out_dir.path_join("atlas_uv.png"))
	pal.save_png(out_dir.path_join("parts.png"))
	var names := ["kingdom_militia", "kingdom_veteran", "revenant", "revenant_elite"]
	var manifest := {"frame_size": [SpriteFactory.FW, SpriteFactory.FH],
		"supersampling": SpriteFactory.SS, "attack_hit_time": SpriteFactory.ATTACK_HIT_TIME,
		"looks": names, "animations": {}}
	for anim_name in anims:
		var span: Vector2i = anims[anim_name]
		manifest.animations[anim_name] = {"start": span.x, "frames": span.y,
			"duration": SpriteFactory.ANIM_DURATIONS[anim_name]}
	var file := FileAccess.open(out_dir.path_join("atlas_manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	# Tiny original bitmap lettering keeps the PNG contact sheets self-describing.
	var font := {
		"A": [2,5,7,5,5], "B": [6,5,6,5,6], "C": [3,4,4,4,3],
		"D": [6,5,5,5,6], "E": [7,4,6,4,7], "F": [7,4,6,4,4],
		"G": [3,4,5,5,3], "H": [5,5,7,5,5], "I": [7,2,2,2,7],
		"J": [1,1,1,5,2], "K": [5,5,6,5,5], "L": [4,4,4,4,7],
		"M": [5,7,7,5,5], "N": [5,7,7,7,5], "O": [2,5,5,5,2],
		"P": [6,5,6,4,4], "Q": [2,5,5,3,1], "R": [6,5,6,5,5],
		"S": [3,4,2,1,6], "T": [7,2,2,2,2], "U": [5,5,5,5,7],
		"V": [5,5,5,5,2], "W": [5,5,7,7,5], "X": [5,5,2,5,5],
		"Y": [5,5,2,2,2], "Z": [7,1,2,4,7], "_": [0,0,0,0,7],
	}
	var write_text := func(target: Image, title: String, origin: Vector2i):
		var cursor := origin
		for ch in title.to_upper():
			var glyph: Array = font.get(ch, [0,0,0,0,0])
			for gy in 5:
				for gx in 3:
					if (int(glyph[gy]) & (1 << (2 - gx))) != 0:
						target.fill_rect(Rect2i(cursor + Vector2i(gx, gy) * 2, Vector2i(2, 2)), Color(0.78, 0.82, 0.86))
			cursor.x += 8
	var bg := Color(0.24, 0.28, 0.29)
	for look in PALETTE.size():
		var prev := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		prev.fill(bg)
		var look_origin := Vector2i(look % SpriteFactory.LOOK_GRID.x, look / SpriteFactory.LOOK_GRID.x) * SpriteFactory.LOOK_PX
		for y in img.get_height():
			for x in img.get_width():
				var t := img.get_pixel(x, y)
				if t.a == 0.0:
					continue
				# Match the GPU's linear sampling at the encoded UV (no RG blur).
				var pos := Vector2(look_origin) + Vector2(t.r, t.g) * SpriteFactory.LOOK_PX - Vector2.ONE * 0.5
				var p0 := Vector2i(pos.floor())
				var f := pos - Vector2(p0)
				var top := pal.get_pixelv(p0).srgb_to_linear().lerp(pal.get_pixelv(p0 + Vector2i(1, 0)).srgb_to_linear(), f.x)
				var bot := pal.get_pixelv(p0 + Vector2i(0, 1)).srgb_to_linear().lerp(pal.get_pixelv(p0 + Vector2i(1, 1)).srgb_to_linear(), f.x)
				var color := top.lerp(bot, f.y)
				var light := SpriteFactory.light_decode(t.b)
				var slot := Vector2i(Vector2(t.r, t.g) * SpriteFactory.PART_GRID)
				if slot.y * SpriteFactory.PART_GRID + slot.x + 1 == SpriteFactory.EYE and look >= 2:
					light = 1.2
				color = Color(color.r * light, color.g * light, color.b * light, 1.0).linear_to_srgb()
				prev.set_pixel(x, y, bg.lerp(color, t.a))
		var enlarged := prev.duplicate()
		enlarged.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_BILINEAR)
		enlarged.save_png(out_dir.path_join("atlas_row%d_%s.png" % [look, names[look]]))
		# One named strip per animation, in original frame order, at 3x scale.
		var row_height := SpriteFactory.FH * 3 + 24
		var sheet := Image.create(SpriteFactory.COLS * SpriteFactory.FW * 3,
			row_height * anims.size() + 24, false, Image.FORMAT_RGBA8)
		sheet.fill(bg)
		write_text.call(sheet, names[look], Vector2i(8, 7))
		var row := 0
		for anim_name in anims:
			var span: Vector2i = anims[anim_name]
			var y0 := row * row_height + 24
			write_text.call(sheet, anim_name, Vector2i(8, y0 + 5))
			for frame_idx in span.y:
				var idx := span.x + frame_idx
				var source := Rect2i(Vector2i(idx % SpriteFactory.COLS, idx / SpriteFactory.COLS) * SpriteFactory.FW * 3,
					Vector2i(SpriteFactory.FW, SpriteFactory.FH) * 3)
				sheet.blit_rect(enlarged, source, Vector2i(frame_idx * SpriteFactory.FW * 3, y0 + 24))
			row += 1
		sheet.save_png(out_dir.path_join("animations_row%d.png" % look))
	print("UV_ATLAS: exported four looks, named animation strips, parts and manifest to ", out_dir)


func _circle_image(n: int, r_in: float, r_out: float, ragged: bool) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n - Vector2(0.5, 0.5)
			var d := p.length()
			var a := 0.0
			if ragged:
				var ang := atan2(p.y, p.x)
				var edge := r_out * (0.8 + 0.2 * sin(ang * 5.0 + 1.3) * sin(ang * 3.0))
				a = 1.0 if d < edge else 0.0
			elif r_in > 0.0:
				a = clampf(1.0 - abs(d - (r_in + r_out) * 0.5) / ((r_out - r_in) * 0.5), 0.0, 1.0)
				a = 1.0 if a > 0.3 else 0.0
			else:
				a = clampf(1.0 - d / r_out, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


func _flat_mat(tex: Texture2D, col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = col
	m.render_priority = 1
	return m


func _puff_mat(col: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = soft_tex
	m.albedo_color = col
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = 200.0
	add_child(camera)
	cam_dist = float(args.get("zoom", "15"))   # 正交镜头的竖向尺寸
	cam_yaw = deg_to_rad(float(args.get("yaw", "0")))
	cam_yaw_target = cam_yaw
	if args.has("focus"):
		var f := String(args["focus"]).split(",")
		cam_focus = Vector3(float(f[0]), 0.5, float(f[1]))
	_update_camera(0.0)


# ---------- 部队 ----------

func _spawn_armies() -> void:
	var peak := terrain.peak_tile()
	flag_pos = terrain.tile_center(peak)
	var beaches := terrain.beach_tiles()
	var half := Terrain.SIZE / 2
	var a := _best_beach(beaches, func(t: Vector2i): return t.x < half)
	var b := _best_beach(beaches, func(t: Vector2i): return t.x >= half)
	var pa := terrain.tile_center(a)
	var pb := terrain.tile_center(b)
	var mid := terrain.nearest_walkable(flag_pos.lerp((pa + pb) * 0.5, 0.5))
	var anchors := {"beach_left": pa, "beach_right": pb, "flag": flag_pos, "mid": mid}

	terrain.add_trees(int(battle["trees"]), [flag_pos, pa, pb, mid], 2.5)
	terrain.bake_light()
	_build_flag()

	presence = [Presence.new(), Presence.new()]
	presence[0].setup(terrain, 0)
	presence[1].setup(terrain, 1)

	var rule: Dictionary = battle["capture"]
	capture_player_radius = float(rule["player_radius"])
	capture_defender_radius = float(rule["defender_radius"])
	capture_time = float(rule["time"])
	capture_decay = float(rule["decay"])

	# 数值参照规格第 12 节：普通剑兵一刀死，战斗靠招架、拼刀、威慑和体力拉开
	var face_down := (pa + pb) * 0.5 - flag_pos
	face_down.y = 0.0
	for entry in battle["squads"]:
		var faction := int(entry["faction"])
		var look := int(entry["look"])
		var stats: Dictionary = entry["stats"].duplicate()
		if faction == 1:
			# 王国的精灵来源保持现状：有 Blender 盾兵用盾兵，否则用程序图。
			var kingdom_sprite := "shieldman" if sprite_sets.has("shieldman") else "proc"
			stats["sprite"] = kingdom_sprite
			if kingdom_sprite == "proc":
				look = 1
		var pos: Vector3 = anchors[String(entry["anchor"])]
		if entry.has("toward_beach"):
			pos += face_down.normalized() * float(entry["toward_beach"])
		if entry.has("offset"):
			var off: Array = entry["offset"]
			pos += Vector3(float(off[0]), float(off[1]), float(off[2]))
		var face := face_down if faction == 1 else -face_down
		var sq := _make_squad(String(entry["title"]), faction, look, int(entry["count"]), pos, bool(entry["is_player"]), stats, face)
		if bool(entry["is_player"]):
			player_squads.append(sq)


func _best_beach(list: Array[Vector2i], pred: Callable) -> Vector2i:
	var best := Vector2i(Terrain.SIZE / 2, Terrain.SIZE - 3)
	var score := -1e9
	for t in list:
		if not pred.call(t):
			continue
		var s := t.y * 3.0 - absf(t.x - Terrain.SIZE * 0.5) * 0.8
		if s > score:
			score = s
			best = t
	return best


func _make_squad(title: String, faction: int, palette_row: int, count: int, pos: Vector3, is_player: bool, stats: Dictionary, face: Vector3 = Vector3.ZERO) -> Squad:
	var sq := Squad.new()
	sq.main = self
	sq.terrain = terrain
	sq.faction = faction
	sq.is_player = is_player
	sq.title = title
	add_child(sq)
	for i in count:
		var off := Vector3((i % 3 - 1) * 0.26, 0, (i / 3) * 0.26) + Vector3(sim_rng.randf_range(-0.05, 0.05), 0, sim_rng.randf_range(-0.05, 0.05))
		var p := terrain.nearest_walkable(pos + off)
		var u := Unit.new()
		add_child(u)
		u.setup(self, sq, faction, palette_row, p, stats)
		if face != Vector3.ZERO:
			u.facing = Vector3(face.x, 0, face.z).normalized()
		sq.units.append(u)
		units.append(u)
	sq.order_move(pos, face)
	squads.append(sq)
	return sq


func _build_flag() -> void:
	var root := Node3D.new()
	root.position = flag_pos
	add_child(root)
	var stone := terrain.make_lit_material(Color(0.62, 0.6, 0.56), false, false)
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.12, 0.55)
	base.mesh = bm
	base.material_override = stone
	base.position.y = 0.06
	root.add_child(base)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.02
	pm.bottom_radius = 0.025
	pm.height = 1.3
	pole.mesh = pm
	var wood := terrain.make_lit_material(Color(0.4, 0.28, 0.18), false, false)
	pole.material_override = wood
	pole.position.y = 0.75
	root.add_child(pole)
	flag_cloth = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.5, 0.32, 0.02)
	flag_cloth.mesh = cm
	var cloth := terrain.make_lit_material(Color(0.22, 0.38, 0.74), false, false)
	flag_cloth.material_override = cloth
	flag_cloth.position = Vector3(0.26, 1.22, 0)
	root.add_child(flag_cloth)


func _auto_orders() -> void:
	for i in player_squads.size():
		var sq: Squad = player_squads[i]
		var side := Vector3(-0.6 if i == 0 else 0.6, 0, 0.3)
		sq.order_move(terrain.nearest_walkable(flag_pos + side))


# ---------- 输入 ----------

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_LEFT:
				_click(e.position)
			MOUSE_BUTTON_RIGHT:
				_select(null)
			MOUSE_BUTTON_WHEEL_UP:
				cam_dist = max(5.0, cam_dist - 1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam_dist = min(26.0, cam_dist + 1.0)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1:
				_select(player_squads[0])
			KEY_2:
				_select(player_squads[1])
			KEY_Q:
				cam_yaw_target += PI / 4.0
			KEY_E:
				cam_yaw_target -= PI / 4.0
			KEY_R:
				Engine.time_scale = 1.0
				get_tree().reload_current_scene()
			KEY_ESCAPE:
				_select(null)


func _click(screen: Vector2) -> void:
	# 先按屏幕距离点选己方小兵
	var best = null
	var bd := 26.0
	for sq in player_squads:
		for u in sq.alive_units():
			var p := camera.unproject_position(u.position + Vector3(0, 0.3, 0))
			var d := p.distance_to(screen)
			if d < bd:
				bd = d
				best = sq
	if best != null and best != selected:
		_select(best)
		return
	if selected == null:
		return
	var hit = terrain.raycast(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null or not terrain.is_walkable_at(hit):
		return
	selected.order_move(hit)
	_show_marker(hit)
	_select(null)


func _select(sq) -> void:
	if selected != null:
		selected.set_selected(false)
	selected = sq
	if sq != null:
		sq.set_selected(true)
	Engine.time_scale = SLOW if sq != null else 1.0


func _show_marker(p: Vector3) -> void:
	marker.position = Vector3(p.x, terrain.height_at(p) + 0.02, p.z)
	marker.visible = true
	marker.scale = Vector3.ONE * 1.4
	marker.transparency = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(marker, "scale", Vector3.ONE * 0.5, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(marker, "transparency", 1.0, 0.8)


# ---------- 每帧 ----------

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var rdt := (now - last_ticks) / 1000.0
	last_ticks = now
	if rdt > 0.1 and time > 0.5:
		print("HITCH %.2fs at t=%.2f stats=%s" % [rdt, time, stats])
	_advance_sim(delta)
	_update_camera(rdt)
	if flag_cloth:
		flag_cloth.rotation.y = sin(time * 3.0) * 0.25
	# 无头验证：游戏时间到 quit_at 秒（或分出胜负）时输出一行 RESULT JSON 并退出
	if args.has("quit_at") and (time >= float(args["quit_at"]) - 0.0001 or (game_over and args.has("quit_on_end"))):
		_print_result_and_quit()
	_update_ui()
	if not shots.is_empty() and (now - real_start) / 1000.0 >= shots[0]:
		shots.pop_front()
		_take_shot()


## 按固定步长推进模拟。渲染帧率、无头模式、窗口卡顿都只影响每帧补几步，
## 不改变战斗逻辑实际走过的步数；--auto 的下令也绑在模拟时间 0.8 秒而不是真实计时器。
func _advance_sim(frame_delta: float) -> void:
	sim_accum += frame_delta
	var steps := 0
	while sim_accum >= SIM_STEP and steps < SIM_MAX_STEPS:
		sim_accum -= SIM_STEP
		time += SIM_STEP
		if args.has("auto") and not auto_ordered and time >= 0.8:
			auto_ordered = true
			_auto_orders()
		_simulate(SIM_STEP)
		_check_goal(SIM_STEP)
		steps += 1
		if args.has("quit_on_end") and game_over:
			sim_accum = 0.0
			return
		if args.has("quit_at") and time >= float(args["quit_at"]) - 0.0001:
			sim_accum = 0.0
			return
	if steps >= SIM_MAX_STEPS:
		sim_accum = 0.0


## 每帧模拟顺序（规格 2.4）：势力场 → 清零威慑 → 互相通知靠近 → 逐个更新小兵 → 小队整队
func _simulate(delta: float) -> void:
	AgentState.now = time
	AgentState.dt = delta
	if delta <= 0.0:
		return
	for p in presence:
		p.update(units)
	for u in units:
		u.soft_int = 0.0
		u.hard_int = 0.0
	for u in units:
		if not u.alive_grounded.active:
			continue
		var e = u.enemy
		if e == null or not is_instance_valid(e) or e.removed or not e.alive_grounded.active:
			continue
		e.brain.on_proximity(u)
		if e.enemy != u:
			u.brain.on_proximity(e)
	for u in units.duplicate():
		u.tick(delta)
	for sq in squads:
		sq.tick()
	if args.has("trace") and floorf(time) != floorf(time - delta):
		var parts := []
		for sq in squads:
			var list: Array = sq.alive_units()
			if not list.is_empty():
				var u = list[0]
				parts.append("%s:%s st=%.2f e=%.1f o=%.1f" % [sq.title, u.state_path().trim_prefix("Root/"), u.brain.stamina, minf(u.enemy_dist, 99.0), u.order_dist])
		print("T%.0f " % time, " | ".join(parts))


func on_unit_removed(u) -> void:
	units.erase(u)


func _update_camera(rdt: float) -> void:
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_target, 1.0 - exp(-rdt * 8.0))
	# 选中部队（慢动作）时稍微拉近，并往部队方向偏一点
	var k := 1.0 - exp(-rdt * 6.0)
	sel_zoom = lerp(sel_zoom, 0.975 if selected != null else 1.0, k)
	var pull := Vector3.ZERO
	if selected != null:
		pull = (selected.center() - cam_focus) * 0.12
		pull.y = 0.0
	sel_pull = sel_pull.lerp(pull, k)
	var focus := cam_focus + sel_pull
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * 60.0
	camera.position = focus + off
	camera.look_at(focus, Vector3.UP)
	camera.size = cam_dist * sel_zoom
	camera.h_offset = art_rng.randf_range(-1.0, 1.0) * shake_amt
	camera.v_offset = art_rng.randf_range(-1.0, 1.0) * shake_amt
	shake_amt = move_toward(shake_amt, 0.0, rdt * 0.5)


func cam_right() -> Vector3:
	return camera.global_transform.basis.x


var stats := {}


func note(key: String) -> void:
	stats[key] = stats.get(key, 0) + 1


func shake(a: float) -> void:
	shake_amt = max(shake_amt, a)


func _check_goal(delta: float) -> void:
	if game_over:
		return
	var near_p := false
	var near_d := false
	var any_p := false
	for u in units:
		if not u.alive:
			continue
		var d := Vector2(u.position.x - flag_pos.x, u.position.z - flag_pos.z).length()
		if u.faction == 0:
			any_p = true
			if d < capture_player_radius:
				near_p = true
		elif d < capture_defender_radius:
			near_d = true
	if near_p and not near_d:
		capture += delta
	else:
		capture = maxf(0.0, capture - delta * capture_decay)
	if capture >= capture_time:
		game_over = true
		banner.text = "王旗已夺取"
		(flag_cloth.material_override as ShaderMaterial).set_shader_parameter("albedo_color", Vector3(0.3, 0.2, 0.36))
	elif not any_p:
		game_over = true
		banner.text = "亡魂散尽"


# ---------- 特效 ----------

func _puff(pos: Vector3, mat: Material, scale_to: float, life: float, drift: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = puff_mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.position = pos
	m.transparency = 0.15
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "position", pos + drift, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "scale", Vector3.ONE * scale_to, life).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "transparency", 1.0, life)
	tw.chain().tween_callback(m.queue_free)


func spawn_dust(pos: Vector3, n: int, strength: float) -> void:
	for i in n:
		var o := Vector3(art_rng.randf_range(-0.08, 0.08), 0.04, art_rng.randf_range(-0.08, 0.08))
		var drift := Vector3(art_rng.randf_range(-0.3, 0.3), art_rng.randf_range(0.08, 0.22), art_rng.randf_range(-0.3, 0.3)) * strength
		_puff(pos + o, dust_mat, art_rng.randf_range(1.5, 2.5) * (0.6 + strength * 0.5), art_rng.randf_range(0.45, 0.7), drift)


func spawn_splash(pos: Vector3) -> void:
	var p := Vector3(pos.x, Terrain.WATER_Y + 0.02, pos.z)
	for i in 8:
		var drift := Vector3(art_rng.randf_range(-0.35, 0.35), art_rng.randf_range(0.25, 0.6), art_rng.randf_range(-0.35, 0.35))
		_puff(p, splash_mat, art_rng.randf_range(1.2, 2.2), art_rng.randf_range(0.4, 0.7), drift)


func spawn_spark(pos: Vector3) -> void:
	for i in 4:
		var drift := Vector3(art_rng.randf_range(-0.25, 0.25), art_rng.randf_range(0.0, 0.25), art_rng.randf_range(-0.25, 0.25))
		_puff(pos, spark_mat, art_rng.randf_range(0.4, 0.8), 0.18, drift)


func spawn_blood(pos: Vector3, dir: Vector3) -> void:
	for i in 3:
		var drift := dir * art_rng.randf_range(0.15, 0.4) + Vector3(art_rng.randf_range(-0.1, 0.1), art_rng.randf_range(0.05, 0.2), art_rng.randf_range(-0.1, 0.1))
		_puff(pos + Vector3(0, 0.3, 0), blood_puff_mat, art_rng.randf_range(0.6, 1.0), 0.3, drift)
	for i in 2:
		var p := pos + dir * art_rng.randf_range(0.1, 0.45) + Vector3(art_rng.randf_range(-0.1, 0.1), 0, art_rng.randf_range(-0.1, 0.1))
		_decal(p, art_rng.randf_range(0.06, 0.14), 0.0)


func spawn_blood_pool(pos: Vector3) -> void:
	_decal(pos, art_rng.randf_range(0.28, 0.4), 2.5)


func _decal(p: Vector3, size: float, grow: float) -> void:
	if not terrain.is_land_at(p):
		return
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	m.mesh = pm
	m.material_override = blood_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.position = Vector3(p.x, terrain.height_at(p) + 0.006 + art_rng.randf() * 0.004, p.z)
	m.rotation.y = art_rng.randf() * TAU
	if grow > 0.0:
		m.scale = Vector3.ONE * 0.2
		create_tween().tween_property(m, "scale", Vector3.ONE, grow).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	decals.append(m)
	if decals.size() > 400:
		decals.pop_front().queue_free()


# ---------- UI ----------

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)
	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(540, 80)
	banner.size = Vector2(200, 40)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 34)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banner.add_theme_constant_override("outline_size", 8)
	layer.add_child(banner)


func _update_ui() -> void:
	var lines := []
	for sq in squads:
		lines.append("%s  %d/%d" % [sq.title, sq.alive_units().size(), sq.units.size()])
	lines.append("")
	if selected != null:
		lines.append("已选：%s（时间放慢）— 左键地面下令，右键取消" % selected.title)
	else:
		lines.append("1 / 2 或点击小兵选队 · Q/E 旋转 · 滚轮缩放 · R 重开")
	if capture > 0.0 and not game_over:
		lines.append("夺旗 %d%%" % int(capture / capture_time * 100.0))
	label.text = "\n".join(lines)


func _take_shot() -> void:
	var idx := shot_idx
	shot_idx += 1
	var last := shots.is_empty()
	await RenderingServer.frame_post_draw
	var out_dir: String = args.get("out", "res://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("shot_%d.png" % idx))
	if last:
		print("STATS ", stats, " fps=", Engine.get_frames_per_second(), " time=", snappedf(time, 0.1), " capture=", snappedf(capture, 0.1), " banner=", banner.text)
		get_tree().quit()


func _print_result_and_quit() -> void:
	var alive := {}
	for sq in squads:
		alive[sq.title] = sq.alive_units().size()
	var r := {
		"seed": int(args.get("seed", "7")),
		"island": int(args.get("island", "3")),
		"time": snappedf(time, 0.01),
		"banner": banner.text,
		"capture": snappedf(capture, 0.01),
		"alive": alive,
		"stats": stats,
	}
	print("RESULT ", JSON.stringify(r))
	set_process(false)
	get_tree().quit()
