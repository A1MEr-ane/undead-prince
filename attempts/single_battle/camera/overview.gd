extends Control
## 正交战术图。所有鼠标事件在 UI 层消费，点击只选择战区。
var view
var map_rect := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(on_input)

func map_point(p: Vector3) -> Vector2:
	return map_rect.position + Vector2(p.x / float(view.main.params.map.width), p.z / float(view.main.params.map.depth)) * map_rect.size

func rectangle(r: Array) -> Rect2:
	return Rect2(map_point(Vector3(r[0], 0, r[1])), Vector2(r[2] / float(view.main.params.map.width), r[3] / float(view.main.params.map.depth)) * map_rect.size)

func text_at(p: Vector2, value: String, color := Color("d8e4e3"), font_size := 15) -> void:
	draw_string(get_theme_default_font(), p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if view == null:
		return
	var world = view.main
	var observer = view.observer
	draw_style_box(view.panel_style, Rect2(Vector2.ZERO, size))
	var remaining := ceili(maxf(0, float(world.params.simulation.night_seconds) - world.time))
	text_at(Vector2(14, 25), "灰潮外岛 · 战术地图", Color("f0ede0"), 18)
	text_at(Vector2(14, 48), "冥火 %.0f / %.0f    破晓 %02d:%02d" % [world.fire, world.params.economy.capacity, remaining / 60, remaining % 60])
	var available := size - Vector2(24, 136)
	var scale_factor := minf(available.x / float(world.params.map.width), available.y / float(world.params.map.depth))
	map_rect = Rect2(Vector2((size.x - float(world.params.map.width) * scale_factor) * 0.5, 62), Vector2(world.params.map.width, world.params.map.depth) * scale_factor)
	draw_rect(map_rect, Color("#233d4a"))
	for r in world.params.map.land_rects:
		draw_rect(rectangle(r), Color("#526461"))
	for id in observer.ids:
		var zone: Dictionary = observer.cfg.zones[id]
		for z in world.params.map.zones:
			if z.id != id: continue
			for r in z.rects:
				draw_rect(rectangle(r), Color(0.35, 0.85, 0.7, 0.10) if id == observer.current else Color(0.75, 0.75, 0.7, 0.035))
		var p := map_point(world.zone_point(id))
		var c := Color("71f4c8") if world.zones[id].owner == "ghost" else Color("ecc39a")
		draw_circle(p, 5, c)
		if observer.latest.has(id):
			draw_arc(p, 10 + 2 * sin(Time.get_ticks_msec() * 0.008), 0, TAU, 24, Color("ffb87c"), 2)
		text_at(p + Vector2(9, -5), zone.label, c)
		text_at(p + Vector2(9, 13), "%s · 亡%d / 守%d" % [observer.zone_status(id), observer.counts[id][0], observer.counts[id][1]], Color("ffffff"), 14)
	for r in world.params.map.wall_rects:
		draw_rect(rectangle(r), Color("#878783"))
	for wall in world.phase_b.walls.values():
		draw_rect(rectangle(wall.rect), Color("#71ae96") if wall.broken else Color("#bb9581"))
	var gate_color := Color("78e1b6") if world.terrain.gate_open else Color("e8b57e")
	draw_rect(rectangle(world.params.map.gate_rect).grow(1), gate_color)
	draw_rect(rectangle(world.params.map.weak_rect).grow(1), Color("78e1b6") if world.terrain.weak_broken else Color("ed8f88"))
	if world.params.map.cave_enabled:
		for endpoint in [world.params.map.cave_a, world.params.map.cave_b]:
			draw_circle(map_point(world.terrain.vec(endpoint)), 4, Color("121829"))
	var marching := {}
	for u in world.sides[1].units:
		if not u.alive or not u.marching or u.retreating or u.falling_until >= 0.0: continue
		var key: String = u.mission_from + ":" + u.assigned
		if marching.has(key): continue
		marching[key] = true
		var a := map_point(u.nav_pos if u.cave_until < 0.0 else u.cave_exit)
		var b := map_point(world.zone_point(u.assigned))
		var dir := (b - a).normalized()
		draw_line(a, b, Color("ffcf75"), 2, true)
		draw_colored_polygon(PackedVector2Array([b, b - dir.rotated(0.5) * 10, b - dir.rotated(-0.5) * 10]), Color("ffcf75"))
	var corners := PackedVector2Array()
	for corner in [Vector2.ZERO, Vector2(view.viewport_size.x, 0), view.viewport_size, Vector2(0, view.viewport_size.y), Vector2.ZERO]:
		var hit = Plane(Vector3.UP, float(world.params.map.base_height)).intersects_ray(view.camera.project_ray_origin(corner), view.camera.project_ray_normal(corner))
		if hit != null:
			corners.append(map_point(Vector3(clampf(hit.x, 0, world.params.map.width), 0, clampf(hit.z, 0, world.params.map.depth))))
	if corners.size() > 1: draw_polyline(corners, Color(0.5, 1, 0.9, 0.6), 1, true)
	var y := size.y - 58
	text_at(Vector2(14, y), "门 %s %.0f  ·  薄墙 %s %.0f" % ["破" if world.terrain.gate_broken else "开" if world.terrain.gate_open else "闭", maxf(0, world.gate_hp), "破" if world.terrain.weak_broken else "完整", maxf(0, world.weak_hp)])
	text_at(Vector2(14, y + 22), "金色箭头 · %d 条增援路线" % marching.size())
	text_at(Vector2(14, y + 44), "点击战区切换视角", Color("8caaa9"), 14)

func on_input(event: InputEvent) -> void:
	view.cancel_deploy()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and map_rect.has_point(event.position):
		var uv: Vector2 = (event.position - map_rect.position) / map_rect.size
		var p := Vector3(uv.x * view.main.params.map.width, 0, uv.y * view.main.params.map.depth)
		var world = view.main
		if world.terrain.is_land_at(p):
			view.select_zone(world.terrain.zone_at(p), "overview")
	accept_event()
