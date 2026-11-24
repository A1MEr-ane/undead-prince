extends Control
## 显示坐标偏移来自 overrides；按钮选择与有向航行合法性分开处理。

signal selected_site(site_id: String)

const ICONS := {"旧部增益": "益", "招募": "募", "魂火": "火", "缝补": "缝",
	"休整": "休", "遗物": "物", "航海": "航", "知识": "知"}
const NODE_SIZE := Vector2(102, 34)

var run
var selected := "bay"
var _buttons: Dictionary = {}


func configure(state, selection: String) -> void:
	run = state
	selected = selection
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	var next: Array = run.available_next()
	var previews: Dictionary = run.reward_previews()
	for id in run.sites:
		var site: Dictionary = run.sites[id]
		if int(site.stage) > run.STAGE:
			continue
		var value: int = run.site_difficulty(id)
		var grade: Dictionary = run.difficulty.tier_data(value)
		var color := Color(str(grade.color))
		var button := Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.text = str(site.zh)
		if site.type == "boss":
			button.text = "◆ " + button.text
		if id == run.current_site:
			button.text = "› " + button.text
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = "%s · %d 档 %s\n%s\n%s" % [site.zh, value, grade.name,
			run.rewards[id].category, site.reward]
		if int(run.save.enemy_memory.get(id, 0)) > 0:
			button.tooltip_text += "\n已知守军布置"
		button.add_theme_color_override("font_color", Color("f2f6fa"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		var style := StyleBoxFlat.new()
		style.bg_color = color.darkened(0.72)
		style.border_color = color
		style.set_border_width_all(3 if next.has(id) else 1)
		style.set_corner_radius_all(5)
		if id == selected:
			style.shadow_color = Color("fff0ce")
			style.shadow_size = 3
		button.add_theme_stylebox_override("normal", style)
		var hover: StyleBoxFlat = style.duplicate()
		hover.bg_color = color.darkened(0.5)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.pressed.connect(func(): selected_site.emit(str(id)))
		add_child(button)
		_buttons[id] = button
		if previews.has(id):
			var badge := Label.new()
			badge.text = "[%s]%s" % [ICONS[run.rewards[id].category], "·" if previews[id] == 2 else ""]
			badge.add_theme_font_size_override("font_size", 13)
			badge.add_theme_color_override("font_color", Color("bcebe1") if previews[id] == 1 else Color("9cbcca"))
			badge.position = Vector2(NODE_SIZE.x - 18, -16)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(badge)
	_layout_buttons()
	queue_redraw()


func _ready() -> void:
	resized.connect(func():
		_layout_buttons()
		queue_redraw())


func _point(id: String) -> Vector2:
	var site: Dictionary = run.sites[id]
	var offset: Array = site.get("display_offset", [0, 0])
	var point := Vector2(float(site.x) + float(offset[0]), float(site.y) + float(offset[1]))
	return Vector2(45, 25) + point / Vector2(1672, 941) * (size - Vector2(90, 55))


func _layout_buttons() -> void:
	if run == null:
		return
	for id in _buttons:
		_buttons[id].position = _point(id) - _buttons[id].size * 0.5


func _draw() -> void:
	if run == null:
		return
	var next: Array = run.available_next()
	for edge in run.edges:
		if not _buttons.has(edge[0]) or not _buttons.has(edge[1]):
			continue
		var from := _point(str(edge[0]))
		var to := _point(str(edge[1]))
		var direction := (to - from).normalized()
		var known: bool = run.save.known_routes.has(str(edge[0]) + ">" + str(edge[1]))
		var color := Color("527b85") if known else Color("344b5e")
		var width := 1.5 if known else 1.0
		var route_index: int = run.route.find(edge[0])
		if route_index >= 0 and route_index + 1 < run.route.size():
			if run.route[route_index + 1] == edge[1]:
				color = Color("d3a365")
				width = 2.5
		if edge[0] == run.current_site and next.has(edge[1]):
			color = Color("a9e5cf")
			width = 3.0
		draw_line(from, to, color, width, true)
		var tip := from.lerp(to, 0.61)
		var side := direction.orthogonal() * 4
		draw_colored_polygon(PackedVector2Array([tip + direction * 6,
			tip - direction * 5 + side, tip - direction * 5 - side]), color)
