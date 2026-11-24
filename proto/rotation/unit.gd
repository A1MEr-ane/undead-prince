extends Node3D

const QUAD := 1.65
const TURN_SECONDS := 0.08
var body: MeshInstance3D
var shield: Node3D
var anchor := Vector3.ZERO
var facing := Vector3.RIGHT
var index := 0
var flipped := false
var target_flip := false
var turn_age := TURN_SECONDS
var last_frame := -1
var data: Dictionary
var transitions := 0

func setup(i: int, origin: Vector3, material: ShaderMaterial, sprite_data: Dictionary, mesh_shield: bool) -> void:
	index = i
	anchor = origin
	position = origin
	data = sprite_data
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * QUAD
	quad.center_offset.y = QUAD * 0.5
	body = MeshInstance3D.new()
	body.mesh = quad
	body.material_override = material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	add_child(body)
	body.set_instance_shader_parameter("palette_row", 2.0 if i % 2 == 0 else 1.0)
	if mesh_shield:
		shield = Node3D.new()
		add_child(shield)
		for layer in 3:
			var disc := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = [0.16, 0.13, 0.035][layer]
			mesh.bottom_radius = mesh.top_radius
			mesh.height = 0.045
			mesh.radial_segments = 12
			disc.mesh = mesh
			disc.rotation.x = PI / 2.0
			disc.scale.z = 1.25
			disc.position.z = layer * 0.026
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = [Color("171e29"), Color("315b61") if i % 2 == 0 else Color("8e3f37"), Color("e2c486")][layer]
			disc.material_override = mat
			shield.add_child(disc)

func tick(dt: float, time: float, camera: Camera3D, angular_speed: float, move: bool) -> void:
	if move:
		var phase := time * 0.8 + index * 0.61
		var offset := Vector3(sin(phase) * 0.27, 0, cos(phase) * 0.22)
		var goal := anchor + offset
		position = position.lerp(goal, 1.0 - exp(-10.0 * dt))
		facing = Vector3(cos(phase), 0, -sin(phase)).normalized()
	var right := camera.global_basis.x
	var d := facing.dot(right)
	var hysteresis := lerpf(0.1, 0.3, clampf(absf(angular_speed) / 2.0, 0.0, 1.0))
	if turn_age >= TURN_SECONDS:
		if flipped and d > hysteresis:
			target_flip = false
			turn_age = 0.0
		elif not flipped and d < -hysteresis:
			target_flip = true
			turn_age = 0.0
	var old_age := turn_age
	turn_age = minf(turn_age + dt, TURN_SECONDS)
	if old_age < TURN_SECONDS * 0.5 and turn_age >= TURN_SECONDS * 0.5:
		flipped = target_flip
		transitions += 1
		body.set_instance_shader_parameter("flip", float(flipped))
	var squeeze := maxf(0.04, absf(cos(PI * turn_age / TURN_SECONDS)))
	body.set_instance_shader_parameter("squeeze", squeeze)
	var clip: Vector2i = data.anims["walk" if move else "idle"]
	var frame := clip.x + int(time * 12.0 + index * 0.31) % clip.y
	if last_frame != frame:
		body.set_instance_shader_parameter("frame", float(frame))
		last_frame = frame
	if shield != null:
		var a: Vector2 = data.anchors[frame]
		var x := (a.x / 64.0 - 0.5) * QUAD * (-1.0 if flipped else 1.0) * squeeze
		var y := (1.0 - a.y / 64.0) * QUAD * 1.1547
		var back := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
		shield.position = right * x + Vector3.UP * y + back * 0.11
		# World facing controls the shield normal; the body animation controls its grip.
		shield.rotation.y = atan2(facing.x, facing.z)
