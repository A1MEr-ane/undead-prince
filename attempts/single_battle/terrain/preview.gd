extends Node3D

const Terrain := preload("res://attempts/single_battle/terrain/terrain.gd")
const FIRE := preload("res://attempts/single_battle/terrain/ghostfire.gdshader")
const CAPTURE_DIR := "res://shots/t85"
const VIEWS := ["coast", "highland", "plaza", "keep", "overview"]
const FIRES := [Vector2(24.15, 43.2), Vector2(12.57, 35.53), Vector2(12.54, 26.7),
	Vector2(22.30, 20.98), Vector2(34.91, 22.35), Vector2(30.2, 11.2), Vector2(45.75, 19.88)]

@onready var terrain := $GreyTide as Terrain
@onready var camera: Camera3D = $Camera3D
var _fire := ShaderMaterial.new()
var _time := 0.28
var _zone := "coast"
var _gate := 0
var _broken := false


func _ready() -> void:
	var capture := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--capture":
			capture = true
		elif argument.begins_with("--zone="):
			_zone = argument.get_slice("=", 1)
		elif argument.begins_with("--time="):
			var value := argument.get_slice("=", 1)
			if not value.is_valid_float() or not is_finite(value.to_float()):
				_fail("Expected --time=0..1.")
				return
			_time = clampf(value.to_float(), 0, 1)
	if not terrain.apply_camera(camera, _zone):
		_fail("Unknown camera '%s'." % _zone)
		return
	if capture and DisplayServer.get_name() == "headless":
		_fail("--capture requires a graphical Godot session.")
		return
	_add_display_fire()
	_light(_time)
	if capture:
		_capture()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key >= KEY_1 and key <= KEY_5:
		_zone = VIEWS[key - KEY_1]
		terrain.apply_camera(camera, _zone)
	elif key == KEY_N:
		_light(0.28)
	elif key == KEY_D:
		_light(1.0)
	elif key == KEY_G:
		_gate = (_gate + 1) % 3
		terrain.set_structure_state("gate", ["closed", "open", "broken"][_gate])
	elif key == KEY_B:
		_broken = not _broken
		var state := "breached" if _broken else "intact"
		for id: String in ["weak_wall", "wall_west", "wall_east", "wall_highland"]:
			terrain.set_structure_state(id, state)


func _add_display_fire() -> void:
	_fire.shader = FIRE
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.07, 2.07)
	for point in FIRES:
		var flame := MeshInstance3D.new()
		flame.mesh = mesh
		flame.material_override = _fire
		flame.position = Vector3(point.x, 0, point.y)
		flame.position.y = terrain.height_at(flame.position) + 0.79
		add_child(flame)


func _light(time: float) -> void:
	terrain.set_time(time)
	_fire.set_shader_parameter("daylight", smoothstep(0.42, 1.0, time))


func _capture() -> void:
	var directory := ProjectSettings.globalize_path(CAPTURE_DIR)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		_fail("Cannot create %s: %s." % [directory, error_string(error)])
		return
	terrain.set_process(false)
	for zone: String in Terrain.ZONES:
		terrain.apply_camera(camera, zone)
		for time: Array in [["night", 0.28], ["daybreak", 1.0]]:
			_light(time[1])
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var filename := "%s-%s.png" % [zone, time[0]]
			error = ERR_CANT_CREATE if image == null or image.is_empty() else image.save_png(directory.path_join(filename))
			if error != OK:
				_fail("Cannot save %s: %s." % [filename, error_string(error)])
				return
			print("CAPTURE %s %s" % [filename, image.get_size()])
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("T85: " + message)
	get_tree().quit(2)
