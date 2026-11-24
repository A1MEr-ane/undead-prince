extends Control
## 使用 canon 坐标画有向图，按钮只负责选择；航行合法性由 Run 再检查。

signal selected_site(site_id: String)

const SHORT_NAMES := {
	"bay": "Bellgrave", "wreck": "Wrecker's Rest", "light": "Last Light",
	"oar": "Broken Oar", "pilot": "Pilot's Rest", "gate": "Iron Gate",
	"yard": "Blackwake", "kings": "Drowned Kings", "roads": "Crown Roads",
	"lantern": "Lantern Isle", "mill": "Miller's Cross", "harvest": "Harvest End",
	"granary": "Great Granary", "lock": "King's Lock", "abbey": "Pale Abbey",
	"merchant": "Merchant Gate", "lion": "Lion Gate", "provision": "Provision Gate",
	"sunhold": "SUNHOLD", "northrelief": "Northhaven", "watchskerry": "Watchman",
	"saltmarket": "Saltmarket", "foundry": "Ashen Foundry", "titheford": "Titheford",
	"reedcross": "Reedcross"
}
const ICONS := {"旧部增益": "益", "招募": "募", "魂火": "火", "缝补": "缝",
	"休整": "休", "遗物": "物", "航海": "航", "知识": "知"}
const OFFSETS := {"merchant": Vector2(-50, 40), "sunhold": Vector2(55, 15),
	"lion": Vector2(20, -25), "provision": Vector2(20, 95),
	"titheford": Vector2(25, 45), "reedcross": Vector2(45, 10)}

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
	for id in run.sites:
		var site: Dictionary = run.sites[id]
		if int(site.stage) > run.STAGE:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(84, 36)
		button.size = Vector2(84, 36)
		var icon := str(ICONS[run.rewards[id].category])
		button.text = str(SHORT_NAMES.get(id, site.en))
		if next.has(id):
			button.text += "  [" + icon + "]"
		if id == run.current_site:
			button.text = "> " + button.text
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = "%s · %s\n%s\n%s" % [site.en, site.zh,
			run.rewards[id].category, site.reward]
		var color := Color("75899a")
		if next.has(id):
			color = Color("a9e5cf")
		if run.route.has(id):
			color = Color("e9bd7c")
		if id == selected:
			color = Color("ffffff")
		button.add_theme_color_override("font_color", color)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("152736")
		style.border_color = color
		style.set_border_width_all(2 if id == selected or next.has(id) else 0)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override("normal", style)
		button.pressed.connect(func(): selected_site.emit(str(id)))
		add_child(button)
		_buttons[id] = button
	_layout_buttons()
	queue_redraw()


func _ready() -> void:
	resized.connect(func():
		_layout_buttons()
		queue_redraw())


func _point(id: String) -> Vector2:
	var site: Dictionary = run.sites[id]
	var point := Vector2(float(site.x), float(site.y))
	point += OFFSETS.get(id, Vector2.ZERO)
	return Vector2(20, 35) + point / Vector2(1672, 941) * (size - Vector2(40, 65))


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
		var color := Color("344b5e")
		var width := 1.0
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
