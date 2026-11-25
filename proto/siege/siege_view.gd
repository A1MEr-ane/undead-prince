extends Node3D
## 仅使用方块、圆柱和文字；该层不消耗模拟随机源。

var main
var camera: Camera3D
var environment: Environment
var tint: ColorRect
var hud: Label
var debug: Label
var banner: Label
var preview: MeshInstance3D
var rally_marker: MeshInstance3D
var unit_meshes := {}
var flags := {}
var gate: MeshInstance3D
var weak: MeshInstance3D
var boat: Node3D
var arrow_meshes: Array = []
var yaw: float
var zoom: float
var dragging := false
var deploying := false
var selected := false
var rally_mode := false
var next_deploy := 0.0
var debug_visible := false
var shot_times: Array = []
var shot_index := 0
var shot_pending := false
var screenshot_dir := ""
var capture_done := false
var ghost_mat: StandardMaterial3D
var shield_mat: StandardMaterial3D
var archer_mat: StandardMaterial3D
var cavalry_mat: StandardMaterial3D
var materials := {}

func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials[key] = mat
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	return node

func setup(world) -> void:
	main = world
	var cfg: Dictionary = main.params.view
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(int(cfg.window_size[0]), int(cfg.window_size[1])))
		get_window().title = "T67 · Siege / 灰盒夜袭攻城"
	yaw = deg_to_rad(float(cfg.camera_yaw))
	zoom = float(cfg.camera_size)
	debug_visible = cfg.debug_visible
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(cfg.night_color)
	var env := WorldEnvironment.new()
	env.environment = environment
	add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	update_camera()
	build_map()
	var layer := CanvasLayer.new()
	add_child(layer)
	tint = ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tint)
	hud = Label.new()
	hud.position = Vector2(22, 18)
	hud.add_theme_font_size_override("font_size", int(cfg.hud_font_size))
	layer.add_child(hud)
	debug = Label.new()
	debug.position = Vector2(22, 156)
	debug.add_theme_font_size_override("font_size", int(cfg.debug_font_size))
	layer.add_child(debug)
	banner = Label.new()
	banner.position = Vector2(660, 22)
	banner.add_theme_font_size_override("font_size", int(cfg.hud_font_size))
	layer.add_child(banner)
	preview = box(self, Vector3.ZERO, Vector3(1.2, 0.07, 1.2), Color(cfg.ghost_color))
	preview.visible = false
	rally_marker = box(self, Vector3.ZERO, Vector3(1.5, 0.08, 1.5), Color("f4eea0"))
	rally_marker.visible = false
	if main.capture_mode:
		shot_times = main.params.view.shot_times.duplicate()
		screenshot_dir = main.args.get("out", ProjectSettings.globalize_path("res://shots/t67"))
		DirAccess.make_dir_recursive_absolute(screenshot_dir)
	refresh()

func build_map() -> void:
	var map: Dictionary = main.params.map
	box(self, Vector3(float(map.width) / 2, -0.35, float(map.depth) / 2), Vector3(map.width + 15, 0.2, map.depth + 15), Color("1d3449"))
	for r in map.land_rects:
		var p := Vector3(r[0] + r[2] * 0.5, 0, r[1] + r[3] * 0.5)
		var h: float = main.terrain.height_at(p)
		box(self, Vector3(p.x, h * 0.5 - 0.15, p.z), Vector3(r[2], h + 0.3, r[3]), Color("5d6869"))
	for pair in [[map.highland_rect, "778183"], [map.keep_rect, "74797c"]]:
		var r: Array = pair[0]
		var p := Vector3(r[0] + r[2] * 0.5, 0, r[1] + r[3] * 0.5)
		var h: float = main.terrain.height_at(p)
		box(self, Vector3(p.x, h * 0.5, p.z), Vector3(r[2], h, r[3]), Color(pair[1]))
	var deploy: Array = map.deploy_rect
	box(self, Vector3(deploy[0] + deploy[2] * 0.5, float(map.base_height) + 0.012, deploy[1] + deploy[3] * 0.5), Vector3(deploy[2], 0.02, deploy[3]), Color("38695f"))
	for r in map.wall_rects:
		for cell in main.terrain.rect_cells(r):
			var p := Vector3(cell.x + 0.5, float(main.params.view.wall_height) * 0.5 + float(map.base_height), cell.y + 0.5)
			if main.terrain.in_rect(p, map.gate_rect) or main.terrain.in_rect(p, map.weak_rect):
				continue
			box(self, p, Vector3(0.96, main.params.view.wall_height, 0.96), Color("969b9e"))
	var gr: Array = map.gate_rect
	gate = box(self, Vector3(gr[0] + gr[2] * 0.5, float(main.params.view.wall_height) * 0.5, gr[1] + gr[3] * 0.5), Vector3(gr[2], main.params.view.wall_height, gr[3]), Color("bc9068"))
	var wr: Array = map.weak_rect
	weak = box(self, Vector3(wr[0] + wr[2] * 0.5, float(main.params.view.wall_height) * 0.5, wr[1] + wr[3] * 0.5), Vector3(wr[2], main.params.view.wall_height, wr[3]), Color("ba7972"))
	for zone in map.zones:
		var p: Vector3 = main.zone_point(zone.id)
		p.y = main.terrain.height_at(p)
		box(self, p + Vector3(0, 1.25, 0), Vector3(0.12, 2.5, 0.12), Color("d5d4c8"))
		flags[zone.id] = box(self, p + Vector3(0.5, 2.2, 0), Vector3(1, 0.6, 0.1), Color("ecad7d"))
		label3d(zone.label, p + Vector3(0, 4.2, 0), 38)
	label3d("MAIN ROAD", Vector3(30, 0.6, 34), 30)
	label3d("SIDE PATH", Vector3(7, 0.8, 32), 30)
	label3d("WEAK WALL", Vector3(14, 3, 25), 30)
	label3d("GATE", Vector3(29, 3, 28), 30)
	if map.cave_enabled:
		for pair in [[map.cave_a, "CAVE IN"], [map.cave_b, "CAVE OUT"]]:
			var p: Vector3 = main.terrain.vec(pair[0])
			p.y = main.terrain.height_at(p)
			box(self, p + Vector3(0, 0.4, 0), Vector3(1.7, 0.8, 1.7), Color("292b38"))
			label3d(pair[1], p + Vector3(0, 2, 0), 30)
	var port: Vector3 = main.terrain.vec(map.port)
	box(self, port + Vector3(1.8, 0.15, 0), Vector3(4.8, 0.3, 2), Color("ac977a"))
	label3d("PORT / EVACUATION", port + Vector3(0, 3, 0), 30)
	boat = Node3D.new()
	add_child(boat)
	boat.position = main.terrain.vec(map.boat)
	box(boat, Vector3.ZERO, Vector3(2, 0.6, 4.5), Color("a88c6f"))
	box(boat, Vector3(0, 1.8, 0), Vector3(0.14, 3, 0.14), Color("c7c0a9"))
	box(boat, Vector3(0.6, 2, 0), Vector3(1.2, 1.5, 0.08), Color("d1d3cb"))

func label3d(text: String, pos: Vector3, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.014
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

func update_camera() -> void:
	var cfg: Dictionary = main.params.view
	var focus := Vector3(cfg.camera_focus[0], cfg.camera_focus[1], cfg.camera_focus[2])
	var pitch := deg_to_rad(float(cfg.camera_pitch))
	camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(cfg.camera_distance)
	camera.look_at(focus, Vector3.UP)
	camera.size = zoom

func mouse_world() -> Vector3:
	var cursor := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(cursor)
	var ray := camera.project_ray_normal(cursor)
	var point = Plane(Vector3.UP, float(main.params.map.base_height)).intersects_ray(origin, ray)
	if point == null:
		return Vector3(-1, 0, -1)
	# 地面高度修正；高地与主堡也可准确点选。
	for n in 2:
		var hit = Plane(Vector3.UP, main.terrain.height_at(point)).intersects_ray(origin, ray)
		if hit != null:
			point = hit
	return point

func _unhandled_input(event: InputEvent) -> void:
	if main == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: selected = true; rally_mode = false
			KEY_F: rally_mode = true; deploying = false
			KEY_TAB: debug_visible = not debug_visible
			KEY_ESCAPE: rally_mode = false; deploying = false; selected = false
			KEY_R: get_tree().reload_current_scene()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and rally_mode:
				main.rally(mouse_world())
				rally_mode = false
			else:
				deploying = event.pressed and selected
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom /= float(main.params.view.zoom_factor)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom *= float(main.params.view.zoom_factor)
		zoom = clampf(zoom, float(main.params.view.zoom_limits[0]), float(main.params.view.zoom_limits[1]))
		update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * float(main.params.view.drag_speed)
		update_camera()

func _process(delta: float) -> void:
	if main == null:
		return
	var rotation := float(int(Input.is_physical_key_pressed(KEY_E)) - int(Input.is_physical_key_pressed(KEY_Q)))
	if rotation != 0:
		yaw += rotation * delta * float(main.params.view.rotation_speed)
		update_camera()
	if deploying and main.bot == null and main.time >= next_deploy:
		main.deploy(mouse_world())
		next_deploy = main.time + float(main.params.economy.deploy_interval)
	for effect in arrow_meshes.duplicate():
		effect.life -= delta
		if effect.life <= 0:
			effect.mesh.queue_free()
			arrow_meshes.erase(effect)

func refresh() -> void:
	var cfg: Dictionary = main.params.view
	var progress := clampf(main.time / float(main.params.simulation.night_seconds), 0, 1)
	var sky := Color(cfg.night_color).lerp(Color(cfg.dawn_color), pow(progress, 2))
	environment.background_color = sky
	tint.color = Color(sky, float(cfg.screen_tint_alpha))
	for u in main.units:
		if not u.alive or u.cave_until >= 0:
			if unit_meshes.has(u.id):
				unit_meshes[u.id].visible = false
			continue
		if not unit_meshes.has(u.id):
			var color := Color(cfg[u.kind + "_color"])
			var height := float(cfg.cavalry_height if u.kind == "cavalry" else cfg.unit_height)
			var size: float = u.radius * 2 * float(cfg.unit_radius_scale)
			var mesh := box(self, u.nav_pos, Vector3(size, height, size), color)
			if u.kind == "archer":
				box(mesh, Vector3(0.2, 0.15, 0), Vector3(0.12, height, 0.12), Color("342d22"))
			if u.kind == "cavalry":
				box(mesh, Vector3(0, -0.2, 0.2), Vector3(size * 0.8, height * 0.5, size * 1.8), color.darkened(0.2))
			unit_meshes[u.id] = mesh
		var mesh: MeshInstance3D = unit_meshes[u.id]
		mesh.visible = true
		var hop := absf(sin(u.walked * float(cfg.get("hop_frequency", main.params.combat.hop_frequency)) * PI)) * float(main.params.combat.hop_height)
		mesh.position = u.nav_pos + Vector3(0, float(cfg.unit_height) * 0.5 + hop, 0)
		mesh.rotation.y = atan2(u.facing.x, u.facing.z)
	gate.visible = not main.terrain.gate_open
	weak.visible = not main.terrain.weak_broken
	for id in flags:
		flags[id].material_override = material(Color(cfg.ghost_color) if main.zones[id].owner == "ghost" else Color(cfg.shield_color))
	var p := mouse_world()
	preview.visible = (selected or rally_mode) and main.bot == null and not main.finished
	preview.position = p + Vector3(0, 0.08, 0)
	preview.material_override = material(Color("f4eea0") if rally_mode else Color(cfg.ghost_color) if main.can_deploy(p) else Color("dc6f70"))
	rally_marker.visible = main.rally_until > main.time
	rally_marker.position = main.rally_pos + Vector3(0, 0.1, 0)
	var ghosts: int = main.sides[0].units.filter(func(u): return u.alive).size()
	var guards: int = main.sides[1].units.filter(func(u): return u.alive).size()
	hud.text = "T67 · GREYBOX NIGHT SIEGE    [%s / seed %d]\n冥火 %.0f / %.0f    亡魂 %d    守军 %d\n1 选择亡魂 · 左键长按部署 · F+左键集结 (%.0f 冥火)\nQ/E 或右键/中键拖动旋转 · 滚轮缩放 · Tab 调试 · R 重开\n绿色：部署区/亡魂    橙：盾兵    黄：弓兵    紫：骑兵" % [main.strategy, main.seed_value, main.fire, main.params.economy.capacity, ghosts, guards, main.params.economy.rally_cost]
	debug.visible = debug_visible
	if debug_visible:
		var text := "DEBUG · t=%.1f · gate=%.1f weak=%.1f · dispatch=%d\n" % [main.time, maxf(0, main.gate_hp), maxf(0, main.weak_hp), main.director.dispatches]
		for z in main.params.map.zones:
			var state: Dictionary = main.zones[z.id]
			text += "%s: threat %.1f · %s · capture %.1f / %.1f\n" % [z.id, main.director.threats[z.id], state.owner, state.progress, main.params.capture.seconds]
		var recent: Array = main.director.decisions.slice(maxi(0, main.director.decisions.size() - 5))
		for decision in recent:
			text += JSON.stringify(decision) + "\n"
		debug.text = text
	if main.won:
		banner.text = "胜利 · " + ("全歼守军" if main.victory_method == "annihilation" else "主堡攻占，守军撤退")
		if main.retreat_started:
			banner.text += "\n登船 %d · 截杀 %d" % [main.escaped, main.intercepted]
	elif main.finished:
		banner.text = "破晓 · 攻城失败"
	else:
		banner.text = ""
	if main.retreat_started and main.time >= main.boat_depart_at:
		boat.position.x = main.terrain.vec(main.params.map.boat).x + (main.time - main.boat_depart_at) * 0.8

func arrow(a: Vector3, b: Vector3) -> void:
	var mesh := box(self, (a + b) * 0.5 + Vector3.UP, Vector3(0.05, 0.05, a.distance_to(b)), Color("e8ddad"))
	mesh.look_at(b + Vector3.UP, Vector3.UP)
	arrow_meshes.append({"mesh": mesh, "life": 0.12})

func next_shot_due() -> bool:
	return shot_index < shot_times.size() and main.time >= float(shot_times[shot_index])

func capture_if_due() -> void:
	if shot_pending or capture_done:
		return
	if shot_index >= shot_times.size():
		if main.finished:
			capture_done = true
			get_tree().quit()
		return
	if not next_shot_due():
		return
	shot_pending = true
	await RenderingServer.frame_post_draw
	var path := screenshot_dir.path_join("%s_seed%d_%03d.png" % [main.strategy, main.seed_value, int(shot_times[shot_index])])
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Screenshot failed: " + path)
		get_tree().quit(3)
		return
	print("SHOT " + path)
	shot_index += 1
	shot_pending = false
