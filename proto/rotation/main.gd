extends Node3D

const Factory = preload("res://sprite_factory.gd")
const Soldier = preload("res://unit.gd")
const Effects = preload("res://effects.gd")
var args := {}
var camera := Camera3D.new()
var effects: Node3D
var units: Array[Node3D] = []
var hud := Label.new()
var yaw := 0.0
var target_yaw := 0.0
var zoom := 27.0
var target_zoom := 27.0
var angular_speed := 0.0
var orbit_seconds := 0.0
var orbit_age := 0.0
var world_time := 0.0
var stop_left := 0.0
var shake_left := 0.0
var dragging := false
var capturing := false
var moving := false
var modes: Array[String] = []
var phase := 0
var phase_age := 0.0
var warmup := 1.5
var sample_seconds := 4.0
var samples: Array[float] = []
var draws: Array[float] = []
var cpu: Array[float] = []
var results: Array[Dictionary] = []
var completed := false
var raw_min := 0.0
var raw_max := 0.0
var reversed := false
var frame_last_us := 0
var headless := false
var output := ""
var shot_manifest: Array[Dictionary] = []

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() == 2 else "true"
	headless = DisplayServer.get_name() == "headless"
	var count := int(args.get("units", "50"))
	if count not in [50, 200, 500]:
		push_error("units must be 50, 200 or 500")
		get_tree().quit(2)
		return
	orbit_seconds = float(args.get("orbit", "0"))
	sample_seconds = float(args.get("seconds", "4"))
	output = args.get("out", ProjectSettings.globalize_path("res://../../shots/t49"))
	var mode: String = args.get("mode", "both")
	if mode not in ["render", "move", "both"] or sample_seconds < 0.5 or (args.has("orbit") and orbit_seconds <= 0):
		push_error("invalid mode, seconds or orbit")
		get_tree().quit(2)
		return
	if args.has("bench") or args.has("orbit"):
		modes = ["render", "move"] if mode == "both" else [mode]
		moving = modes[0] == "move"
	_build_stage()
	_build_units(count)
	effects = Effects.new()
	add_child(effects)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.position = Vector2(20, 16)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Color("e5e3cf"))
	hud.add_theme_color_override("font_shadow_color", Color("101820"))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	_update_camera(0, true)
	_self_check()
	print("CONFIG " + JSON.stringify({"units": count, "resolution": get_viewport().get_visible_rect().size, "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(), "headless": headless, "warmup_s": warmup, "sample_s": sample_seconds, "vsync": "disabled", "godot": Engine.get_version_info().string}))
	if args.has("shots"):
		if headless:
			print("SHOTS_SKIPPED headless display; no rendered image available")
			if modes.is_empty():
				get_tree().quit()
		else:
			capturing = true
			_capture_sequence.call_deferred()
	frame_last_us = Time.get_ticks_usec()

func _build_stage() -> void:
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 150
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("17232c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	env.environment.glow_enabled = true
	add_child(env)
	var base := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 11.5
	mesh.bottom_radius = 11.8
	mesh.height = 0.45
	mesh.radial_segments = 64
	base.mesh = mesh
	base.position.y = -0.24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("34434a")
	base.material_override = mat
	add_child(base)
	for i in 4:
		var label := Label3D.new()
		label.text = ["+Z", "+X", "-Z", "-X"][i]
		label.position = Vector3(sin(i * PI / 2.0), 0.2, cos(i * PI / 2.0)) * Vector3(10.6, 1, 10.6)
		label.font_size = 64
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

func _build_units(count: int) -> void:
	var full: Dictionary = Factory.build(true)
	var bare: Dictionary = Factory.build(false)
	var palettes: Array = []
	for color in [Color("395465"), Color("8e3c38"), Color("376668"), Color("3e596b")]:
		palettes.append({1: Color("bebfaa"), 2: color, 3: Color("343543"), 4: Color("bbc5c5"), 5: Color("d7dbd2"), 6: Color("826955"), 7: color, 8: Color("d7b572"), 9: Color("9affd0"), 10: Color("4c3940")})
	var parts := ImageTexture.create_from_image(Factory.make_parts(palettes))
	var materials: Array[ShaderMaterial] = []
	for variant in 4:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://unit.gdshader")
		var data: Dictionary = full if variant < 2 else bare
		var tex := ImageTexture.create_from_image(data.image)
		mat.set_shader_parameter("atlas", tex)
		mat.set_shader_parameter("atlas_coverage", tex)
		mat.set_shader_parameter("atlas_grid", data.grid)
		mat.set_shader_parameter("parts", parts)
		mat.set_shader_parameter("quad_size", Soldier.QUAD)
		mat.set_shader_parameter("rim_color", Color("53eab9") if variant % 2 == 0 else Color("ffd17b"))
		materials.append(mat)
	for i in count:
		var use_mesh := i % 4 >= 2
		var at := Vector3.ZERO
		if i < 8:
			at = Vector3(-5.2 + (i % 4) * 3.4, 0, 7.0 + (i / 4) * 1.5)
		else:
			var row := (i - 8) / 64
			var angle := (i - 8) * TAU / 64.0
			var radius := 7.5 + row * 0.43
			at = Vector3(sin(angle) * radius, 0, cos(angle) * radius * 0.65 - 1.2)
		var soldier := Soldier.new()
		add_child(soldier)
		soldier.setup(i, at, materials[i % 4], bare if use_mesh else full, use_mesh)
		units.append(soldier)
	for x in 4:
		var label := Label3D.new()
		label.text = ["SPRITE / TEAL", "SPRITE / GOLD", "3D SHIELD / TEAL", "3D SHIELD / GOLD"][x]
		label.position = Vector3(-5.2 + x * 3.4, 0.3, 9.1)
		label.font_size = 32
		label.pixel_size = 0.009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

static func damp(value: float, target: float, rate: float, dt: float) -> float:
	return lerpf(value, target, 1.0 - exp(-rate * dt))

static func orbit_target(age: float, duration: float) -> float:
	var u := clampf(age / duration, 0, 1)
	return (u * 3.0 if u <= 2.0 / 3.0 else 2.0 - (u - 2.0 / 3.0) * 3.0) * TAU

func _update_camera(dt: float, instant: bool = false) -> void:
	var old := yaw
	yaw = target_yaw if instant else damp(yaw, target_yaw, 12.0, dt)
	angular_speed = (yaw - old) / dt if dt > 0 else 0.0
	zoom = target_zoom if instant else damp(zoom, target_zoom, 12.0, dt)
	camera.size = zoom
	var back := Vector3(sin(yaw) * cos(PI / 6), sin(PI / 6), cos(yaw) * cos(PI / 6))
	var focus := Vector3(0, 0.5, 0)
	if shake_left > 0:
		focus += Vector3(sin(world_time * 193), cos(world_time * 137), sin(world_time * 107)) * shake_left * 0.24
	camera.position = focus + back * 36.0
	camera.look_at(focus)
	raw_min = minf(raw_min, yaw)
	raw_max = maxf(raw_max, yaw)
	reversed = reversed or angular_speed < -0.01

func _advance(dt: float) -> void:
	var sim_dt := dt
	if stop_left > 0:
		stop_left = maxf(0, stop_left - dt)
		sim_dt = 0.0
	world_time += sim_dt
	shake_left = maxf(0, shake_left - dt)
	_update_camera(dt)
	for unit in units:
		unit.tick(dt, world_time, camera, angular_speed, moving)
	if effects.update(world_time, camera):
		stop_left = 0.055
		shake_left = 0.18

func _process(delta: float) -> void:
	if completed or capturing:
		return
	var now := Time.get_ticks_usec()
	var frame_ms := (now - frame_last_us) / 1000.0
	frame_last_us = now
	var begin := now
	var dt := delta
	if orbit_seconds > 0:
		orbit_age += dt
		target_yaw = orbit_target(orbit_age, orbit_seconds)
	_advance(dt)
	hud.text = "T49  |  %d UNITS  |  %s  |  YAW %.1f°\nRMB / MMB drag · Q/E 45° · Wheel zoom · M movement · Space impact\nTeal = fallen  /  Gold = kingdom  |  pitch locked 30°" % [units.size(), "MOVE" if moving else "RENDER", rad_to_deg(yaw)]
	if modes.is_empty():
		return
	if phase >= modes.size():
		if orbit_age >= orbit_seconds + 0.7:
			_finish_run()
		return
	phase_age += dt
	if phase_age >= warmup:
		samples.append(frame_ms)
		draws.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		cpu.append((Time.get_ticks_usec() - begin) / 1000.0)
	if phase_age >= warmup + sample_seconds:
		_finish_phase()

func _percentile(list: Array[float], percentile: float) -> float:
	var sorted := list.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(percentile * sorted.size()) - 1, 0, sorted.size() - 1)]

func _finish_phase() -> void:
	var row := {"mode": modes[phase], "units": units.size(), "samples": samples.size(), "mean_ms": _mean(samples), "p95_ms": _percentile(samples, 0.95), "p99_ms": _percentile(samples, 0.99), "logic_mean_ms": _mean(cpu), "draw_calls_mean": null if headless else _mean(draws), "draw_calls_p95": null if headless else _percentile(draws, 0.95), "headless": headless}
	results.append(row)
	print("PERF " + JSON.stringify(row))
	phase += 1
	if phase < modes.size():
		moving = modes[phase] == "move"
		phase_age = 0
		samples.clear()
		draws.clear()
		cpu.clear()
	else:
		if orbit_seconds > 0 and orbit_age < orbit_seconds + 0.7:
			return
		_finish_run()

func _finish_run() -> void:
	var orbit := {"requested_s": orbit_seconds, "elapsed_s": orbit_age, "target_turns": target_yaw / TAU, "max_yaw_deg": rad_to_deg(raw_max), "min_yaw_deg": rad_to_deg(raw_min), "reversed": reversed, "impacts": effects.impacts}
	print("ORBIT " + JSON.stringify(orbit))
	print("RESULT " + JSON.stringify({"ok": true, "metrics": results, "orbit": orbit, "headless": headless}))
	completed = true
	get_tree().quit()

func _mean(list: Array[float]) -> float:
	var total := 0.0
	for value in list:
		total += value
	return total / max(1, list.size())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = maxf(10, target_zoom - 1.0)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = minf(40, target_zoom + 1.0)
	if event is InputEventMouseMotion and dragging:
		target_yaw -= event.relative.x * 0.008
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			target_yaw -= PI / 4
		if event.keycode == KEY_E:
			target_yaw += PI / 4
		if event.keycode == KEY_M:
			moving = not moving
		if event.keycode == KEY_SPACE:
			stop_left = 0.055
			shake_left = 0.18
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _self_check() -> void:
	var a := damp(0, 10, 12, 1.0 / 30)
	var b := damp(damp(0, 10, 12, 1.0 / 60), 10, 12, 1.0 / 60)
	assert(absf(a - b) < 0.00001, "damping must be frame-rate independent")
	assert(damp(TAU - 0.01, TAU + 0.01, 12, 0.016) > TAU - 0.01)
	assert(is_equal_approx(orbit_target(2, 3), TAU * 2))
	assert(is_equal_approx(orbit_target(3, 3), TAU))
	assert(Effects.ballistic(Vector3.ZERO, Vector3.ONE, 1, 2).is_equal_approx(Vector3.ONE))
	assert(Effects.axial_side(Vector3.FORWARD, Vector3.FORWARD, Vector3.UP).is_normalized())
	assert(Effects.axial_side(Vector3.UP, Vector3.UP, Vector3.UP).is_normalized())
	print("CHECKS damping_30_60=ok cross_zero=ok two_turns_reverse=ok ballistic_endpoint=ok axial_parallel=ok")

func _save_shot(filename: String, kind: String, sample_time: float) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output.path_join(filename))
	if error != OK:
		push_error("screenshot write failed: " + filename)
		get_tree().quit(3)
		return
	shot_manifest.append({"file": filename, "kind": kind, "sample_s": sample_time, "world_s": world_time, "yaw_deg": rad_to_deg(yaw), "target_yaw_deg": rad_to_deg(target_yaw), "resolution": [image.get_width(), image.get_height()], "fan_origin": Effects.FAN_ORIGIN, "fan_tip": effects.fan_tip, "hitstop": stop_left > 0})
	print("SHOT " + filename)

func _capture_sequence() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for angle in range(0, 360, 45):
		target_yaw = deg_to_rad(angle)
		_update_camera(0, true)
		world_time = 1.17
		for unit in units:
			unit.tick(0.1, world_time, camera, 0, false)
		effects.update(world_time, camera, false)
		hud.text = "T49  |  STATIC %03d°  |  %d UNITS  |  ALL EFFECTS @ 1.17s\nFront: sprite shields (left) / world-facing 3D shields (right)\nWorld +X,+Z markers and station labels remain fixed" % [angle, units.size()]
		await _save_shot("azimuth_%03d.png" % angle, "static", 1.17)
	yaw = deg_to_rad(315)
	target_yaw = yaw
	world_time = 1.17
	shake_left = 0
	stop_left = 0
	moving = true
	for frame in 20:
		for substep in 6:
			target_yaw += 3.5 / 60.0
			_advance(1.0 / 60.0)
			await get_tree().process_frame
		hud.text = "T49  |  CONTINUOUS %02d / 20  |  t=%.1fs  |  YAW %.1f°\nFixed 60 Hz simulation; capture every 0.1 simulation seconds\nWorld-space effects + 80 ms flips + 55 ms impact stop + shake" % [frame + 1, (frame + 1) * 0.1, rad_to_deg(yaw)]
		await _save_shot("continuous_%02d.png" % frame, "continuous", (frame + 1) * 0.1)
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"count": shot_manifest.size(), "pitch_deg": 30, "cadence_s": 0.1, "fixed_step_hz": 60, "shots": shot_manifest}, "\t"))
	print("SHOTS_COMPLETE count=28 out=" + output)
	get_tree().quit()
