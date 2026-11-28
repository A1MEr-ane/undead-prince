extends Node3D

const Coast := preload("res://attempts/single_battle/style_frame/coast.gd")
const Cast := preload("res://attempts/single_battle/style_frame/cast.gd")
const INK_SHADER := preload("res://attempts/single_battle/style_frame/ink.gdshader")
const SEA_SHADER := preload("res://attempts/single_battle/style_frame/sea.gdshader")
const FOCUS := Vector3(-0.15, 1.05, -0.54)
const YAW := -12.0
const PITCH := 30.0
const DISTANCE := 52.0
const SIZE := 18.6
const CAPTURE_DIR := "res://shots/t84"
const SHOTS := [
	["01-night", 0.0],
	["02-midnight", 0.27],
	["03-before-dawn", 0.70],
	["04-daybreak", 1.0],
]
const STILL := 2.27

var _ink := ShaderMaterial.new()
var _sea := ShaderMaterial.new()
var _cast := Cast.new()
var _clock := 0.0
var _capturing := false
var _panel: PanelContainer
var _time_label: Label


func _ready() -> void:
	var hour := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--time="):
			var value := arg.get_slice("=", 1)
			if not value.is_valid_float() or not is_finite(value.to_float()):
				push_error("T84: --time requires a finite number between 0 and 1.")
				get_tree().quit(2)
				return
			hour = clampf(value.to_float(), 0.0, 1.0)
		elif arg == "--capture":
			_capturing = true

	if _capturing and DisplayServer.get_name() == "headless":
		push_error("T84: --capture needs a graphical Godot session.")
		get_tree().quit(2)
		return

	var camera := _camera()
	_ink.shader = INK_SHADER
	_sea.shader = SEA_SHADER
	_build_sea()
	Coast.new().build(self, _ink)
	_cast.name = "Landing party and garrison"
	add_child(_cast)
	_cast.build(camera, _ink)
	_set_hour(hour)

	if _capturing:
		_capture()
	else:
		_build_controls(hour)
		_cast.pose(_clock)


func _process(delta: float) -> void:
	if _capturing or _panel == null:
		return
	_clock += delta
	_cast.pose(_clock)
	_sea.set_shader_parameter("clock", _clock)


func _unhandled_key_input(event: InputEvent) -> void:
	if _panel != null and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_H:
			_panel.visible = not _panel.visible


func _camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "Coast viewpoint"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = SIZE
	camera.far = 160.0
	add_child(camera)
	var yaw := deg_to_rad(YAW)
	var pitch := deg_to_rad(PITCH)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.position = FOCUS + offset * DISTANCE
	camera.look_at(FOCUS)
	camera.make_current()
	return camera


func _build_sea() -> void:
	var surface := PlaneMesh.new()
	surface.size = Vector2(140, 140)
	var sea := MeshInstance3D.new()
	sea.name = "Tidal water and horizon"
	sea.mesh = surface
	sea.material_override = _sea
	add_child(sea)
	_sea.set_shader_parameter("shore_field", Coast.shore_field())
	_sea.set_shader_parameter("shore_origin", Coast.SHORE_ORIGIN)
	_sea.set_shader_parameter("shore_size", Coast.SHORE_SIZE)
	_sea.set_shader_parameter("shore_reach", Coast.SHORE_REACH)


func _set_hour(hour: float) -> void:
	var dawn := smoothstep(0.30, 1.0, hour)
	var midnight := smoothstep(0.0, 0.27, hour) * (1.0 - dawn)
	var exposure := Vector3(0.74, 0.84, 0.98).lerp(Vector3(0.61, 0.74, 0.90), midnight)
	exposure = exposure.lerp(Vector3(1.17, 1.16, 1.11), dawn)
	var air := Vector3(0.027, 0.046, 0.066).lerp(Vector3(0.071, 0.074, 0.076), dawn)
	_ink.set_shader_parameter("exposure", exposure)
	_ink.set_shader_parameter("air", air)
	_sea.set_shader_parameter("dawn", dawn)
	_sea.set_shader_parameter("water", Color("#283e4b").lerp(Color("#203647"), midnight).lerp(Color("#526974"), dawn))
	_sea.set_shader_parameter("headland", Color("#465767").lerp(Color("#798b94"), dawn))
	_sea.set_shader_parameter("horizon", Color("#637081").lerp(Color("#f9f4e9"), dawn))
	_sea.set_shader_parameter("shallows", Color("#455958").lerp(Color("#78887b"), dawn))
	_sea.set_shader_parameter("froth", Color("#869f98").lerp(Color("#b7bfa9"), dawn))
	_cast.light(dawn)
	if _time_label != null:
		_time_label.text = "%s  ·  %.2f" % [_time_name(hour), hour]


func _build_controls(hour: float) -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var margin := MarginContainer.new()
	ui.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.offset_left = -252.0
	margin.offset_top = -80.0
	margin.offset_right = -22.0
	margin.offset_bottom = -21.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#121a25da")
	fill.border_color = Color("#6b7473bf")
	fill.set_border_width_all(1)
	fill.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override("panel", fill)
	margin.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	_time_label = Label.new()
	_time_label.add_theme_color_override("font_color", Color("#ddd8c8"))
	_time_label.add_theme_font_size_override("font_size", 14)
	_time_label.text = "%s  ·  %.2f" % [_time_name(hour), hour]
	column.add_child(_time_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = hour
	slider.custom_minimum_size.x = 200.0
	slider.tooltip_text = "夜晚 → 破晓  ·  H 隐藏控件"
	slider.value_changed.connect(_set_hour)
	column.add_child(slider)


func _capture() -> void:
	var directory := ProjectSettings.globalize_path(CAPTURE_DIR)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		push_error("T84: cannot create %s (%s)." % [directory, error_string(error)])
		get_tree().quit(1)
		return
	_sea.set_shader_parameter("clock", STILL)
	for shot in SHOTS:
		_set_hour(shot[1])
		_cast.pose(STILL)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := directory.path_join(shot[0] + ".png")
		var image := get_viewport().get_texture().get_image()
		error = ERR_CANT_CREATE if image == null or image.is_empty() else image.save_png(path)
		if error != OK:
			push_error("T84: cannot save %s (%s)." % [path, error_string(error)])
			get_tree().quit(1)
			return
		print("CAPTURE %s %s" % [shot[0], image.get_size()])
	get_tree().quit()


static func _time_name(hour: float) -> String:
	if hour < 0.16:
		return "夜晚"
	if hour < 0.49:
		return "午夜"
	if hour < 0.88:
		return "黎明前"
	return "破晓"
