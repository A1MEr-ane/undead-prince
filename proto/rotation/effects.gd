extends Node3D

const TEAL := Color(0.18, 0.95, 0.72)
const GOLD := Color(1.0, 0.65, 0.23)
const ARROW_FROM := Vector3(-6.0, 1.0, -3.8)
const ARROW_TO := Vector3(-2.4, 0.04, -1.0)
const FIRE_FROM := Vector3(1.3, 0.9, -4.8)
const FIRE_TO := Vector3(4.5, 0.2, -1.0)
const FAN_ORIGIN := Vector3(-4, 0.08, 3.3)
const FAN_FORWARD := Vector3(1, 0, -0.35)
var ribbons := ImmediateMesh.new()
var ground_materials: Array[ShaderMaterial] = []
var bursts: Array[Sprite3D] = []
var spheres: Array[MeshInstance3D] = []
var last_time := 0.0
var impacts := 0
var axis_fallbacks := 0
var fan_tip := Vector3.ZERO

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = ribbons
	var mat := ShaderMaterial.new()
	mat.shader = load("res://flat.gdshader")
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.custom_aabb = AABB(Vector3(-14, -1, -14), Vector3(28, 12, 28))
	add_child(mesh)
	_ground(Vector3(3.8, 0.045, 3.6), 3.1, TEAL, 0)
	_ground(Vector3(3.8, 0.055, 3.6), 2.4, GOLD, 1)
	_ground(ARROW_TO, 1.0, GOLD, 0)
	_ground(FIRE_TO, 1.8, TEAL, 0)
	var texture := _burst_texture()
	for i in 3:
		var burst := Sprite3D.new()
		burst.texture = texture
		burst.hframes = 8
		burst.pixel_size = 0.028
		burst.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		burst.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		burst.no_depth_test = false
		burst.position = [FIRE_TO + Vector3.UP * 0.8, Vector3(6, 1.1, 1.5), Vector3(3.8, 1, 3.6)][i]
		add_child(burst)
		bursts.append(burst)
	for i in 2:
		var sphere := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.18
		ball.height = 0.36
		ball.radial_segments = 12
		ball.rings = 6
		sphere.mesh = ball
		var orb_material := StandardMaterial3D.new()
		orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		orb_material.albedo_color = TEAL.lightened(0.45)
		orb_material.emission_enabled = true
		orb_material.emission = TEAL
		orb_material.emission_energy_multiplier = 2.0
		sphere.material_override = orb_material
		add_child(sphere)
		spheres.append(sphere)
	_label("ARROW VOLLEYS  /  WORLD +X,+Z", Vector3(-5.2, 0.2, -5.2))
	_label("SOULFIRE  /  PARABOLA", Vector3(3, 0.2, -5.5))
	_label("FAN  /  WORLD +X,-Z", Vector3(-4, 0.2, 5.0))
	_label("SIGIL + BURN", Vector3(3.8, 0.2, 5.5))
	_label("AXIAL BEAM + CHAIN", Vector3(0, 0.2, 0.4))

func _label(value: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.font_size = 30
	label.pixel_size = 0.009
	label.modulate = Color("c4cec9")
	label.outline_modulate = Color("101820")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _ground(at: Vector3, diameter: float, color: Color, kind: int) -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * diameter
	mesh.mesh = plane
	mesh.position = at
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ground.gdshader")
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("kind", kind)
	mesh.material_override = mat
	add_child(mesh)
	ground_materials.append(mat)

static func ballistic(from: Vector3, to: Vector3, u: float, height: float) -> Vector3:
	return from.lerp(to, u) + Vector3.UP * (4.0 * height * u * (1.0 - u))

static func tangent(from: Vector3, to: Vector3, u: float, height: float) -> Vector3:
	return to - from + Vector3.UP * (4.0 * height * (1.0 - 2.0 * u))

static func axial_side(axis: Vector3, view: Vector3, camera_up: Vector3) -> Vector3:
	var side := axis.cross(view)
	if side.length_squared() < 0.0001:
		side = axis.cross(camera_up)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.RIGHT)
	return side.normalized()

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for v in [a, b, c, a, c, d]:
		ribbons.surface_set_color(color)
		ribbons.surface_add_vertex(v)

func _strip(a: Vector3, b: Vector3, width: float, color: Color, camera: Camera3D) -> void:
	var axis := (b - a).normalized()
	if axis.length_squared() < 0.001:
		return
	var side := axial_side(axis, camera.global_basis.z, camera.global_basis.y) * width * 0.5
	_quad(a - side, b - side, b + side, a + side, color)

func _particle(at: Vector3, size: float, color: Color, camera: Camera3D) -> void:
	var right := camera.global_basis.x * size
	var up := camera.global_basis.y * size
	_quad(at - right - up, at + right - up, at + right + up, at - right + up, Color("101b23"))
	_quad(at - right * 0.72 - up * 0.7, at + right * 0.72 - up * 0.7, at + up * 0.9, at - right * 0.6 + up * 0.3, color)

func update(time: float, camera: Camera3D, detect_impact: bool = true) -> bool:
	var hit := false
	ribbons.clear_surfaces()
	ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for mat in ground_materials:
		mat.set_shader_parameter("clock", time)
	# Four pooled volleys: flight lasts 1.4 s, embedded arrows last exactly 3 s.
	for volley in 4:
		var age := fposmod(time + volley * 0.77, 4.4)
		var old_age := fposmod(last_time + volley * 0.77, 4.4)
		if old_age < 1.4 and age >= 1.4 and detect_impact:
			hit = true
			impacts += 1
		for i in 6:
			var offset := Vector3((i % 3 - 1) * 0.32, 0, (i / 3) * 0.29)
			var from := ARROW_FROM + offset
			var to := ARROW_TO + offset
			var u := minf(age / 1.4, 1.0)
			var tip := ballistic(from, to, u, 2.5)
			var axis := tangent(from, to, u, 2.5).normalized()
			_strip(tip - axis * 0.65, tip, 0.07, Color("121a23"), camera)
			_strip(tip - axis * 0.59, tip - axis * 0.09, 0.028, Color("e3bc79"), camera)
			_strip(tip - axis * 0.14, tip, 0.10, Color("dbe7de"), camera)
			_strip(tip - axis * 0.65, tip - axis * 0.5, 0.14, Color("b96b4f"), camera)
			if age < 1.4:
				for j in 6:
					var a := maxf(0.0, u - j * 0.025)
					var b := maxf(0.0, u - (j + 1) * 0.025)
					_strip(ballistic(from, to, a, 2.5), ballistic(from, to, b, 2.5), 0.028 * (1.0 - j / 6.0), Color(0.95, 0.75, 0.4, 0.55), camera)
	for i in 2:
		var age := fposmod(time + i * 1.1, 2.2)
		var u := minf(age / 1.3, 1.0)
		var offset := Vector3(i * 0.5, 0, 0)
		var at := ballistic(FIRE_FROM + offset, FIRE_TO + offset, u, 2.1)
		spheres[i].position = at
		spheres[i].visible = age < 1.3
		if age < 1.3:
			_particle(at, 0.28, Color(0.12, 0.9, 0.65, 0.65), camera)
			for j in 10:
				var a := maxf(0.0, u - j * 0.027)
				var b := maxf(0.0, u - (j + 1) * 0.027)
				_strip(ballistic(FIRE_FROM + offset, FIRE_TO + offset, a, 2.1), ballistic(FIRE_FROM + offset, FIRE_TO + offset, b, 2.1), 0.23 * (1.0 - j / 10.0), Color(TEAL, 0.7), camera)
	# A filled world-space fan; particles move along the same fixed world rays.
	var forward := FAN_FORWARD.normalized()
	fan_tip = FAN_ORIGIN + forward * 3.6
	for i in 24:
		var a := forward.rotated(Vector3.UP, lerpf(-0.50, 0.50, i / 24.0))
		var b := forward.rotated(Vector3.UP, lerpf(-0.50, 0.50, (i + 1) / 24.0))
		_quad(FAN_ORIGIN, FAN_ORIGIN + a * 3.6, FAN_ORIGIN + b * 3.6, FAN_ORIGIN, Color(0.91, 0.28, 0.07, 0.65))
		var u := fposmod(time * 0.8 + i * 0.173, 1.0)
		var point := FAN_ORIGIN + a * (0.25 + u * 3.2) + Vector3.UP * (0.15 + sin(u * PI) * 0.45)
		_particle(point, 0.09 + u * 0.08, GOLD if i % 2 == 0 else Color("d94a25"), camera)
	_strip(FAN_ORIGIN + Vector3.UP * 0.03, fan_tip, 0.045, Color("ffe9ac"), camera)
	# Axial beam + a chain whose control points stay in world space.
	var beam_a := Vector3(-1.5, 1.0, 0.1)
	var beam_b := Vector3(2.0, 1.5, -0.7)
	_strip(beam_a, beam_b, 0.22, Color(TEAL, 0.3), camera)
	_strip(beam_a, beam_b, 0.065, TEAL.lightened(0.6), camera)
	var nodes := [beam_b, Vector3(3, 1.5, 0.5), Vector3(5.4, 1.0, 1.1), Vector3(6, 1.2, 2.3)]
	for i in 3:
		var a: Vector3 = nodes[i]
		var b: Vector3 = nodes[i + 1]
		var previous := a
		for j in range(1, 7):
			var u := j / 6.0
			var wobble := 0.0 if j == 6 else sin(j * 17.0 + floor(time * 12.0)) * 0.13
			var next := a.lerp(b, u) + Vector3(0, wobble, wobble)
			_strip(previous, next, 0.045, Color("fff1b5"), camera)
			previous = next
	for i in bursts.size():
		var phase := fposmod(time + i * 0.37, 0.8)
		bursts[i].frame = mini(7, int(phase * 10.0))
		bursts[i].modulate = TEAL if i != 2 else GOLD
	ribbons.surface_end()
	last_time = time
	return hit

func _burst_texture() -> ImageTexture:
	var img := Image.create(64 * 8, 64, false, Image.FORMAT_RGBA8)
	for frame in 8:
		var radius := 0.26 + frame * 0.06
		for y in 64:
			for x in 64:
				var p := (Vector2(x, y) - Vector2(31.5, 31.5)) / 32.0
				var angle := p.angle()
				var contour := radius * (1.0 + sin(angle * 7.0 + frame * 0.5) * 0.14 + sin(angle * 13.0) * 0.06)
				var r := p.length()
				if r > contour or r < maxf(0.0, frame - 3.0) * 0.11:
					continue
				var color := Color("101b26") if r > contour - 0.065 else (Color("efffd1") if r < contour * 0.58 else Color("78eabb"))
				img.set_pixel(frame * 64 + x, y, color)
	return ImageTexture.create_from_image(img)
