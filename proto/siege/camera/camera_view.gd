extends "res://proto/siege/siege_view.gd"
const Overview = preload("res://proto/siege/camera/overview.gd")
const IDS := ["coast", "highland", "plaza", "keep"]
var observer
var cfg: Dictionary
var mode := "zones"
var transition_style := "slide"
var active_zone := "coast"
var pan := Vector2.ZERO
var focus := Vector3.ZERO
var pitch := 0.0
var distance := 75.0
var moving := false
var move_elapsed := 0.0
var start_transform := Transform3D.IDENTITY
var target_transform := Transform3D.IDENTITY
var start_size := 0.0
var target_size := 0.0
var overview
var panel_style: StyleBoxFlat
var zone_buttons: Array = []
var notice_buttons: Array = []
var mode_label: Label
var viewport_size := Vector2(1440, 900)
var expanded := false
var patrol_index := -1
var recorded_frames := 0
var recording := false
var frame_fps := 10.0
var next_frame_time := 0.0
var frame_manifest: FileAccess
var side_texture: ImageTexture
var sidesprites := {}

func setup(world) -> void:
	observer = world.camera_observer
	cfg = observer.cfg
	mode = observer.mode
	transition_style = world.args.get("camera_transition", cfg.transition)
	active_zone = observer.current
	recording = world.args.has("camera_record")
	frame_fps = clampf(float(world.args.get("camera_fps", "10")), 1, 60)
	selected = true
	load_pose(active_zone)
	if mode == "continuous":
		focus = vector3(world.params.view.camera_focus)
		pitch = deg_to_rad(float(world.params.view.camera_pitch))
		distance = float(world.params.view.camera_distance)
		yaw = deg_to_rad(float(world.params.view.camera_yaw))
		zoom = float(world.params.view.camera_size)
	super.setup(world)
	get_window().title = "T70 · 战区固定镜头 / 连续 360°"
	# super.setup 初始化原镜头字段后，重新套用战区机位。
	if mode == "zones": load_pose(active_zone)
	update_camera()
	build_ui()
	build_side_texture()
	if recording:
		screenshot_dir = world.args.get("out", ProjectSettings.globalize_path("res://shots/t70/" + mode))
		DirAccess.make_dir_recursive_absolute(screenshot_dir)
		FileAccess.open(screenshot_dir.path_join(".gdignore"), FileAccess.WRITE).close()
		frame_manifest = FileAccess.open(screenshot_dir.path_join("frames.jsonl"), FileAccess.WRITE)
	if main.args.has("camera_still"):
		shot_times = [0.1]
	refresh()

func vector3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func load_pose(id: String) -> void:
	var pose: Dictionary = cfg.zones[id]
	focus = vector3(pose.focus)
	yaw = deg_to_rad(float(pose.yaw))
	pitch = deg_to_rad(float(pose.pitch))
	distance = float(pose.distance)
	zoom = float(pose.size)
	pan = Vector2.ZERO

func update_camera() -> void:
	if camera == null: return
	var center := focus + Vector3(pan.x, 0, pan.y)
	camera.position = center + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(center, Vector3.UP)
	camera.size = zoom

func cancel_deploy() -> void:
	deploying = false
	if main != null: main.manual_deploy_held = false

func select_zone(id: String, source := "keyboard") -> void:
	if not IDS.has(id): return
	cancel_deploy()
	dragging = false
	rally_mode = false
	if mode == "zones" and id == active_zone and not moving:
		observer.visit(id, source)
		return
	var old := camera.transform
	var old_size := camera.size
	active_zone = id
	if mode == "zones":
		load_pose(id)
	else:
		focus = main.zone_point(id)
		pan = Vector2.ZERO
	update_camera()
	target_transform = camera.transform
	target_size = camera.size
	moving = transition_style == "slide"
	move_elapsed = 0
	start_transform = old
	start_size = old_size
	if moving:
		camera.transform = old
		camera.size = old_size
	else:
		observer.visit(id, source)
	# 切换来源留在视图内，抵达时才确认提醒。
	set_meta("switch_source", source)

func set_overview(value: bool) -> void:
	expanded = value
	overview.expanded = value
	cancel_deploy()
	dragging = false
	layout_ui()

func build_ui() -> void:
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.065, 0.09, 0.97)
	panel_style.border_color = Color("45615f")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	var layer = hud.get_parent()
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 17)
	layer.add_child(mode_label)
	for i in IDS.size():
		var id: String = IDS[i]
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(func(): select_zone(id, "edge"))
		layer.add_child(button)
		zone_buttons.append(button)
	for i in 3:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(func():
			if button.has_meta("zone"): select_zone(button.get_meta("zone"), "alert"))
		layer.add_child(button)
		notice_buttons.append(button)
	overview = Overview.new()
	overview.view = self
	layer.add_child(overview)
	debug.position = Vector2(20, 350)
	layout_ui()

func layout_ui() -> void:
	viewport_size = get_viewport().get_visible_rect().size
	if overview == null: return
	overview.position = Vector2(12, 12) if expanded else Vector2(viewport_size.x - 362, 12)
	overview.size = viewport_size - Vector2(24, 24) if expanded else Vector2(350, 385)
	for i in zone_buttons.size():
		zone_buttons[i].position = Vector2(12 + i * (viewport_size.x - 24) / 4, viewport_size.y - 61)
		zone_buttons[i].size = Vector2((viewport_size.x - 36) / 4, 49)
		zone_buttons[i].visible = not expanded
	for i in notice_buttons.size():
		notice_buttons[i].position = Vector2(22, 220 + i * 36)
		notice_buttons[i].size = Vector2(minf(600, viewport_size.x - 400), 32)
	mode_label.position = Vector2(22, viewport_size.y - 91)
	banner.position = Vector2(22, 164)
	skip_button.position = Vector2(22, 190)

func pointer_over_ui() -> bool:
	var p := get_viewport().get_mouse_position()
	if overview != null and overview.get_global_rect().has_point(p): return true
	for button in zone_buttons + notice_buttons + [skip_button]:
		if button.visible and button.get_global_rect().has_point(p): return true
	return false

func can_view_deploy(p: Vector3) -> bool:
	if moving or expanded or pointer_over_ui() or dragging or main.finished: return false
	if mode == "zones" and main.terrain.zone_at(p) != active_zone: return false
	if camera.is_position_behind(p) or not Rect2(Vector2.ZERO, viewport_size).has_point(camera.unproject_position(p)): return false
	return main.can_deploy(p)

func _input(event: InputEvent) -> void:
	# 即使松开事件被 UI 消费，也必须结束长按和拖动。
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: cancel_deploy()
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]: dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if main == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			select_zone(IDS[event.keycode - KEY_1])
			return
		match event.keycode:
			KEY_TAB: set_overview(not expanded)
			KEY_F3: debug_visible = not debug_visible
			KEY_F: rally_mode = true; cancel_deploy()
			KEY_C:
				transition_style = "cut" if transition_style == "slide" else "slide"
			KEY_ESCAPE:
				rally_mode = false
				cancel_deploy()
				set_overview(false)
			KEY_SPACE: main.queue_input("skip_retreat")
			KEY_R: get_tree().reload_current_scene()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not moving and not expanded and not pointer_over_ui():
				if rally_mode:
					main.queue_input("rally", mouse_world())
					rally_mode = false
				else:
					deploying = can_view_deploy(mouse_world())
		if moving or expanded: return
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			dragging = event.pressed
			cancel_deploy()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom *= 1 / float(main.params.view.zoom_factor) if event.button_index == MOUSE_BUTTON_WHEEL_UP else float(main.params.view.zoom_factor)
			var limits: Array = cfg.zones[active_zone].zoom_limits if mode == "zones" else main.params.view.zoom_limits
			zoom = clampf(zoom, limits[0], limits[1])
			update_camera()
	if event is InputEventMouseMotion and dragging and not moving and not expanded:
		if mode == "continuous":
			yaw -= event.relative.x * float(main.params.view.drag_speed)
		else:
			var right := Vector2(camera.basis.x.x, camera.basis.x.z).normalized()
			var down := Vector2(camera.basis.y.x, camera.basis.y.z).normalized()
			pan -= (right * event.relative.x + down * event.relative.y) * zoom / viewport_size.y
			clamp_pan()
		update_camera()

func clamp_pan() -> void:
	var limit: Array = cfg.zones[active_zone].pan_limit
	pan = pan.clamp(-Vector2(limit[0], limit[1]), Vector2(limit[0], limit[1]))

func _process(delta: float) -> void:
	if main == null: return
	if not main.finished and main.time > 1:
		observer.frame_msec.append(delta * 1000)
	if moving:
		move_elapsed += delta
		var t := clampf(move_elapsed / float(cfg.transition_seconds), 0, 1)
		camera.transform = start_transform.interpolate_with(target_transform, smoothstep(0, 1, t))
		camera.size = lerpf(start_size, target_size, t)
		if t >= 1:
			moving = false
			observer.visit(active_zone, get_meta("switch_source", "keyboard"))
	elif not expanded:
		if mode == "continuous":
			var rotation := float(int(Input.is_physical_key_pressed(KEY_E)) - int(Input.is_physical_key_pressed(KEY_Q)))
			if main.args.has("camera_patrol"): rotation = 0.18
			if rotation != 0:
				yaw += rotation * delta * float(main.params.view.rotation_speed)
				update_camera()
		else:
			var direction := Vector2(float(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))), float(int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))))
			if direction != Vector2.ZERO:
				pan += direction.normalized() * delta * float(cfg.pan_speed)
				clamp_pan()
				update_camera()
	if main.args.has("camera_patrol") and mode == "zones":
		var index := floori(main.time / 15.0) % 4
		if index != patrol_index:
			patrol_index = index
			select_zone(IDS[index], "scripted_patrol_15s")
	main.manual_deploy_held = deploying and main.bot == null and can_view_deploy(mouse_world())
	main.manual_deploy_pos = mouse_world()
	for effect in arrow_meshes.duplicate():
		effect.life -= delta
		if effect.life <= 0:
			effect.mesh.queue_free()
			arrow_meshes.erase(effect)

func build_side_texture() -> void:
	# 不引入正式美术：单张有鼻尖/武器的灰盒侧影，仅用来观察左右翻转。
	var image := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for r in [Rect2i(7, 2, 10, 9), Rect2i(16, 6, 4, 3), Rect2i(5, 12, 12, 12), Rect2i(6, 24, 4, 8), Rect2i(13, 24, 4, 8), Rect2i(18, 12, 2, 15), Rect2i(16, 15, 7, 2)]:
		image.fill_rect(r, Color.WHITE)
	image.fill_rect(Rect2i(14, 5, 2, 2), Color("243e40"))
	side_texture = ImageTexture.create_from_image(image)

func refresh(alpha: float = 1.0) -> void:
	var started := Time.get_ticks_usec()
	super.refresh(alpha)
	if overview == null: return
	observer.poll()
	if viewport_size != get_viewport().get_visible_rect().size: layout_ui()
	for u in main.units:
		if not unit_meshes.has(u.id): continue
		var mesh: MeshInstance3D = unit_meshes[u.id]
		if not sidesprites.has(u.id):
			var sprite := Sprite3D.new()
			sprite.texture = side_texture
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.shaded = false
			sprite.pixel_size = float(main.params.view.cavalry_height if u.kind == "cavalry" else main.params.view.unit_height) / 32.0
			sprite.offset = Vector2(0, 16)
			add_child(sprite)
			sidesprites[u.id] = sprite
		var sprite: Sprite3D = sidesprites[u.id]
		sprite.visible = mesh.visible
		sprite.position = mesh.position - Vector3(0, float(main.params.view.unit_height) * 0.5, 0)
		sprite.modulate = mesh.material_override.albedo_color
		var horizontal: float = u.facing.dot(camera.global_basis.x)
		if absf(horizontal) > 0.08: sprite.flip_h = horizontal < 0
		mesh.visible = false
	preview.visible = preview.visible and not moving and not expanded and not pointer_over_ui()
	if preview.visible and not rally_mode:
		preview.material_override = material(Color(main.params.view.ghost_color) if can_view_deploy(mouse_world()) else Color("dc6f70"))
	var remaining := ceili(maxf(0, float(main.params.simulation.night_seconds) - main.time))
	hud.text = "T70 · %s  [%s / seed %d]    破晓 %02d:%02d\n冥火 %.0f / %.0f   亡魂 %d / 守军 %d\n1–4 战区 · 左键长按部署 · F+左键集结\n%s · 滚轮缩放\nTab 总览 · C 推移/直切 · F3 调试 · R 重开" % ["战区固定镜头" if mode == "zones" else "连续 360°", main.strategy, main.seed_value, remaining / 60, remaining % 60, main.fire, main.params.economy.capacity, main.spawned[0] - main.casualties[0], main.spawned[1] - main.casualties[1] - main.escaped, "WASD / 右键拖动小范围平移（朝向固定）" if mode == "zones" else "Q/E / 右键拖动连续旋转"]
	mode_label.text = "%s · %s · 切换 %d 次%s" % [cfg.zones[active_zone].label, "0.2 秒推移" if transition_style == "slide" else "直接切换", observer.switches.size(), " · 切换中，禁止部署" if moving else ""]
	for i in IDS.size():
		var id: String = IDS[i]
		var alert: bool = observer.latest.has(id)
		var hint := ""
		if alert: hint = " · " + observer.latest[id].message
		zone_buttons[i].text = "%d %s  亡%d / 守%d%s" % [i + 1, cfg.zones[id].label, observer.counts[id][0], observer.counts[id][1], hint]
		zone_buttons[i].modulate = Color("ffb879") if alert and sin(Time.get_ticks_msec() * 0.008) > 0 else Color("88f3cb") if id == active_zone else Color.WHITE
	var pending: Array = observer.latest.values()
	pending.sort_custom(func(a, b): return a.time > b.time)
	for i in notice_buttons.size():
		var button: Button = notice_buttons[i]
		button.visible = i < pending.size() and not expanded
		if button.visible:
			var a: Dictionary = pending[i]
			button.text = "[%s · %03ds] %s  → 查看" % [cfg.zones[a.zone].label, int(a.time), a.message]
			button.set_meta("zone", a.zone)
	overview.queue_redraw()
	if not main.finished: observer.view_usec.append(Time.get_ticks_usec() - started)

func next_shot_due() -> bool:
	if recording: return main.time + 0.000001 >= next_frame_time
	return super.next_shot_due()

func capture_if_due() -> void:
	if not recording:
		if main.args.has("camera_still") and shot_index >= shot_times.size():
			get_tree().quit()
		else:
			super.capture_if_due()
		return
	if shot_pending or capture_done or not next_shot_due(): return
	shot_pending = true
	await RenderingServer.frame_post_draw
	var path := screenshot_dir.path_join("frame_%05d.png" % recorded_frames)
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("T70 screenshot failed: " + path)
		get_tree().quit(3)
		return
	frame_manifest.store_line(JSON.stringify({"frame": recorded_frames, "time": main.time, "step": main.step_number, "zone": active_zone, "file": path.get_file()}))
	frame_manifest.flush()
	recorded_frames += 1
	next_frame_time = recorded_frames / frame_fps
	shot_pending = false
	if main.result_printed:
		capture_done = true
		get_tree().quit()
