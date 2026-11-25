extends SceneTree
## T64 standalone shader capture. Loads the e2e atlas + part sheet with the
## existing in-game shader and writes two screenshots. No gameplay scene code
## is touched.
##
## Run: godot --path . -s assets/sprites/e2e/capture.gd
## Out: shots/t64/e2e_contact_sheet.png, shots/t64/e2e_game_angle.png

const PREFIX := "undead_e2e"
const DIR := "res://assets/sprites/e2e/"
const OUT_DIR := "res://shots/t64/"
const QUAD := 0.64
const WINDOW := Vector2i(1600, 700)

# Frames chosen from the 69-frame contract: idle 0-5, walk 6-13,
# attack 14-21, parry 22-29, death 54-60.
const FRAMES := [0, 3, 6, 8, 10, 13, 14, 16, 18, 20, 24, 26, 56, 59]
const FRAME_NAMES := ["idle0", "idle3", "walk6", "walk8", "walk10", "walk13",
	"atk14", "atk16", "atk18", "atk20", "par22", "par26", "die56", "die59"]

var _root: Node3D
var _camera: Camera3D
var _material: ShaderMaterial
var _quad: QuadMesh
var _meta: Dictionary
var _hud_label: Label


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("T64 capture needs a windowed display; headless has no rendered viewport")
		quit(2)
		return
	DisplayServer.window_set_size(WINDOW)
	get_root().size = WINDOW
	RenderingServer.set_default_clear_color(Color(0.075, 0.085, 0.105))
	_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + PREFIX + "_uv.json"))
	assert(not _meta.is_empty(), "Missing e2e JSON")
	if not _load_material():
		quit(1)
		return
	_root = Node3D.new()
	get_root().add_child(_root)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_root.add_child(_camera)
	_camera.current = true
	_quad = QuadMesh.new()
	_quad.size = Vector2(QUAD, QUAD)
	_quad.center_offset = Vector3(0, QUAD * 0.5, 0)
	var hud := CanvasLayer.new()
	get_root().add_child(hud)
	_hud_label = Label.new()
	_hud_label.position = Vector2(12, 8)
	_hud_label.add_theme_font_size_override("font_size", 18)
	_hud_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.92))
	hud.add_child(_hud_label)

	await _capture_sheet()
	await _capture_game_angle()
	print("T64 SHOTS OK")
	quit()


func _load_material() -> bool:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(DIR + PREFIX + "_uv.png"))
	var parts := Image.load_from_file(ProjectSettings.globalize_path(DIR + PREFIX + "_parts.png"))
	if atlas == null or parts == null:
		push_error("Could not load e2e atlas/parts")
		return false
	var atlas_tex := ImageTexture.create_from_image(atlas)
	var parts_tex := ImageTexture.create_from_image(parts)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/unit.gdshader")
	_material.set_shader_parameter("atlas", atlas_tex)
	_material.set_shader_parameter("atlas_coverage", atlas_tex)
	_material.set_shader_parameter("parts", parts_tex)
	var grid: Array = _meta["part_texture"]["grid"]
	_material.set_shader_parameter("look_grid", Vector2(grid[0], grid[1]))
	_material.set_shader_parameter("atlas_grid", Vector2(_meta["columns"], _meta["rows"]))
	_material.set_shader_parameter("quad_size", QUAD)
	_material.set_shader_parameter("v_up", true)
	_material.set_shader_parameter("light_mode", 1)
	_material.set_shader_parameter("blood_from_alpha", false)
	_material.set_shader_parameter("feet_height", 0.0)
	var stain := 0
	for part_name in ["skin", "helmet", "tunic", "cloth_trim", "sleeves", "trousers"]:
		var cell: Array = _meta["part_texture"]["regions"][part_name]["cell"]
		stain |= 1 << (int(cell[1]) * 4 + int(cell[0]))
	_material.set_shader_parameter("stain_mask", stain)
	var eye: Array = _meta["part_texture"]["regions"]["eye"]["cell"]
	_material.set_shader_parameter("eye_cell", int(eye[1]) * 4 + int(eye[0]))
	return true


func _unit(parent: Node3D, frame: int, pos: Vector3, flip: float = 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _quad
	mesh.material_override = _material
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.set_instance_shader_parameter("frame", float(frame))
	mesh.set_instance_shader_parameter("palette_row", 0.0)
	mesh.set_instance_shader_parameter("flip", flip)
	mesh.set_instance_shader_parameter("health", 1.0)
	mesh.set_instance_shader_parameter("flash", 0.0)
	mesh.set_instance_shader_parameter("grass", 0.0)
	mesh.set_instance_shader_parameter("stretch", 0.0)
	return mesh


func _wait_frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	var image := get_root().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var target := ProjectSettings.globalize_path(OUT_DIR + file_name)
	image.save_png(target)
	print("T64 SHOT ", target, " ", image.get_width(), "x", image.get_height())


func _capture_sheet() -> void:
	_clear_units()
	_hud_label.text = "T64  undead_e2e  /  unit.gdshader  /  64 px atlas  /  " + "  ".join(FRAME_NAMES)
	for i in FRAMES.size():
		var col := i % 7
		var row := i / 7
		_unit(_root, FRAMES[i], Vector3((3 - col) * 0.76, 1.02 - row * 0.86, 0))
	_camera.look_at_from_position(Vector3(0, 1.30, -8.0), Vector3(0, 1.02, 0.0), Vector3.UP)
	_camera.size = 2.32
	await _wait_frames()
	await _wait_frames()
	_save("e2e_contact_sheet.png")


func _capture_game_angle() -> void:
	_clear_units()
	_hud_label.text = "T64  e2e  /  game-angle preview: 30 deg pitch, orthographic, same shader"
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(5, 3)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.17, 0.21, 0.15)
	ground.material_override = gm
	ground.position = Vector3(0, -0.01, 0)
	_root.add_child(ground)
	_unit(_root, 0, Vector3(0.62, 0, 0))
	_unit(_root, 8, Vector3(0.0, 0, 0), 1.0)
	_unit(_root, 18, Vector3(-0.62, 0, 0))
	_camera.look_at_from_position(Vector3(0, 3.55, -5.2), Vector3(0, 0.55, 0.0), Vector3.UP)
	_camera.size = 1.55
	await _wait_frames()
	await _wait_frames()
	_save("e2e_game_angle.png")


func _clear_units() -> void:
	for child in _root.get_children():
		if child is MeshInstance3D:
			child.free()
