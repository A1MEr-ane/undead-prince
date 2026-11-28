extends SceneTree
## Screenshot the T84 Sprite3D artwork and the existing UV shader at a 30° camera angle.

const WINDOW := Vector2i(1440, 468)
const BACKGROUND := Color("#30424b")
const PIXELS_PER_WORLD_UNIT := 100.0
var _scene: Node3D
var _camera: Camera3D
var _canvas: CanvasLayer
var _meta: Dictionary
var _ink: Image
var _material := ShaderMaterial.new()
var _cell_world: float
var _cell_px: int
var _pitch := PI / 6.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Pass an asset stem (directory/id) and an output PNG path after --.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Unit capture requires a graphics session.")
		quit(2)
		return
	var stem := args[0]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(stem + "_uv.json"))
	if parsed is not Dictionary:
		push_error("Unable to read " + stem + "_uv.json")
		quit(2)
		return
	_meta = parsed
	_ink = Image.load_from_file(stem + "_ink.png")
	var source := Image.load_from_file(stem + "_uv.png")
	var parts := Image.load_from_file(stem + "_parts.png")
	if _ink == null or source == null or parts == null:
		push_error("Missing unit image(s) for " + stem)
		quit(2)
		return

	DisplayServer.window_set_size(WINDOW)
	root.size = WINDOW
	RenderingServer.set_default_clear_color(BACKGROUND)
	_scene = Node3D.new()
	_camera = Camera3D.new()
	_canvas = CanvasLayer.new()
	root.add_child(_scene)
	root.add_child(_canvas)
	_scene.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = float(WINDOW.y) / PIXELS_PER_WORLD_UNIT
	_camera.position = Vector3(0.0, sin(_pitch), cos(_pitch)) * 10.0
	_camera.rotation.x = -_pitch
	_camera.current = true
	_cell_px = int(_meta.frame_size[0])
	var sizing: Dictionary = _meta.get("presentation", {})
	var target_height := 48.0
	if sizing.is_empty():
		var bounds: Array = _meta.frames[0].alpha_bbox
		_cell_world = target_height * _cell_px / (float(bounds[3]) - float(bounds[1])) / PIXELS_PER_WORLD_UNIT
	else:
		_cell_world = _cell_px * float(sizing.review_pixels_per_model_unit) / float(sizing.pixels_per_model_unit) / PIXELS_PER_WORLD_UNIT
		target_height = 72.0 * float(sizing.standing_height_ratio)
	var atlas := ImageTexture.create_from_image(source)
	_material.shader = load("res://shaders/unit.gdshader")
	_material.set_shader_parameter("atlas", atlas)
	_material.set_shader_parameter("atlas_coverage", atlas)
	_material.set_shader_parameter("parts", ImageTexture.create_from_image(parts))
	_material.set_shader_parameter("atlas_grid", Vector2(float(_meta.columns), float(_meta.rows)))
	_material.set_shader_parameter("v_up", true)
	_material.set_shader_parameter("light_mode", 1)
	_material.set_shader_parameter("quad_size", _cell_world)
	_material.set_shader_parameter("blood_from_alpha", false)

	var names: Array[String] = ["idle", "walk", "attack"]
	for name: String in ["sneak", "backstab", "bone_pile", "reassemble", "hit_heavy", "death_pierce", "death_crush"]:
		if _meta.animations.has(name):
			names.append(name)
	names.append("flip")
	var rows := mini(names.size(), 9)
	_caption(stem.get_file().capitalize() + " / 30° / ~%d px" % roundi(target_height), Vector2(28, 16))
	_caption("Ink artwork / Sprite3D", Vector2(28, 45))
	_caption("UV atlas / unit.gdshader", Vector2(28, 221))
	for i in rows:
		var name := names[i]
		var flip := name == "flip"
		var anim: Dictionary = _meta.animations["idle" if flip else name]
		var index := int(anim.start_frame)
		if name not in ["idle", "flip"]:
			index += int(anim.frame_count) / 2
			for value: int in anim.event_frames.values():
				if value > int(anim.start_frame) and value < int(anim.start_frame + anim.frame_count - 1):
					index = value
					break
		var x := (i + 0.5) * WINDOW.x / rows
		_draw_ink(index, flip, Vector2(x, 195))
		_draw_uv(index, flip, Vector2(x, 371))
		_caption(name.capitalize(), Vector2(x - 39, 201))
		_caption(name.capitalize(), Vector2(x - 39, 401))

	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var sx := float(shot.get_width()) / WINDOW.x
	var sy := float(shot.get_height()) / WINDOW.y
	var middle := int(WINDOW.x / (2.0 * rows) * sx)
	for center_y in [172, 348]:
		var changed := 0
		var background := shot.get_pixel(0, int(center_y * sy))
		for y in range(int((center_y - 16) * sy), int((center_y + 16) * sy)):
			for x in range(middle - int(20 * sx), middle + int(20 * sx)):
				if not shot.get_pixel(x, y).is_equal_approx(background):
					changed += 1
		if changed < 40:
			push_error("Empty unit capture row at y=%s" % center_y)
			quit(1)
			return
	var error := shot.save_png(args[1])
	if error != OK:
		push_error("Could not save unit capture: %s" % error_string(error))
	else:
		print("UNIT CAPTURE ", args[1], " ", shot.get_size())
	quit(0 if error == OK else 1)


func _on_ground(screen: Vector2) -> Vector3:
	# The camera looks along -Z in the horizontal plane. Project the ground
	# position to the requested screen coordinate through the pitched camera.
	return Vector3((screen.x - WINDOW.x * 0.5) / PIXELS_PER_WORLD_UNIT, 0.0,
		(screen.y - WINDOW.y * 0.5) / (PIXELS_PER_WORLD_UNIT * sin(_pitch)))


func _anchor_offset() -> float:
	return (float(_meta.coordinates.standing_foot_anchor_pixels[1]) / _cell_px - 0.5) * _cell_world


func _draw_ink(index: int, flip: bool, screen: Vector2) -> void:
	var frame: Array = _meta.frames[index].rect
	var sprite := Sprite3D.new()
	sprite.texture = ImageTexture.create_from_image(_ink.get_region(Rect2i(frame[0], frame[1], frame[2], frame[3])))
	sprite.pixel_size = _cell_world / _cell_px
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.flip_h = flip
	sprite.basis = _camera.basis
	sprite.position = _on_ground(screen) + _camera.basis.y * _anchor_offset()
	_scene.add_child(sprite)


func _draw_uv(index: int, flip: bool, screen: Vector2) -> void:
	var instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * _cell_world
	quad.center_offset.y = _anchor_offset()
	instance.mesh = quad
	instance.material_override = _material
	instance.position = _on_ground(screen)
	_scene.add_child(instance)
	instance.set_instance_shader_parameter("frame", float(index))
	instance.set_instance_shader_parameter("flip", float(flip))


func _caption(value: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = value
	label.position = pos
	_canvas.add_child(label)
