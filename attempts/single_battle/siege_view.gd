extends Node3D
## 固定机位与战术图从攻城原型移植。手玩输入排入模拟步。
const Observer = preload("res://attempts/single_battle/camera/observer.gd")
const Overview = preload("res://attempts/single_battle/camera/overview.gd")
const PaintedField = preload("res://attempts/single_battle/painted_field.gd")
const Sprites = preload("res://attempts/single_battle/battle_sprites.gd")
const INK := Color("#131c2a")
const GOLD := Color("#c6aa74")
const TEXT := Color("#ece5d5")
const FIRE := Color("#67dbb8")
const CARDS := [
	["ghost", "普通骷髅", "骨堆重组"],
	["assassin", "暗影刺客", "潜行背刺"],
	["giant", "缝合巨人", "破城横扫"],
	["lich", "巫妖", "冥火眩晕"],
]
enum Command { DEPLOY, RALLY, SPELL }

var main
var camera: Camera3D
var field: Node3D
var observer := Observer.new()
var sprites := Sprites.new()
var panel_style: StyleBoxFlat
var interface: Control
var overview: Control
var map_button: Button
var spell_button: Button
var rally_button: Button
var clock_label: Label
var zone_label: Label
var fire_label: Label
var fire_bar: ProgressBar
var hint: Label
var zone_buttons := {}
var unit_cards := {}
var end_panel: PanelContainer
var result_label: Label
var escape_button: Button
var preview: MeshInstance3D
var rally_ring: MeshInstance3D
var markers := {}
var actors := {}
var effect_nodes := {}
var command := Command.DEPLOY
var expanded := false
var watch := false
var shot_times: Array = []
var shot_index := 0
var shot_pending := false
var screenshot_dir := ""
var viewport_size: Vector2:
	get: return get_viewport().get_visible_rect().size

func setup(world) -> void:
	main = world
	watch = world.args.has("watch")
	observer.setup(main)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 260
	add_child(camera)
	camera.make_current()
	load_pose(observer.current)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#233546")
	add_child(environment)

	field = PaintedField.new()
	add_child(field)
	field.setup(main)
	sprites.setup()
	preview = ring(FIRE, 1.0)
	rally_ring = ring(GOLD, float(main.params.economy.rally_radius))
	for name in ["frenzy", "weakness"]:
		markers[name] = ring(effect_color(name), float(main.params.spell[name].radius))
	build_ui()
	if main.capture_mode:
		shot_times = main.params.view.shot_times
		screenshot_dir = str(main.args.get("out", ProjectSettings.globalize_path("res://shots/t86")))
		var error := DirAccess.make_dir_recursive_absolute(screenshot_dir)
		if error != OK:
			push_error("无法建立截图目录 " + screenshot_dir)
			get_tree().quit(3)
	refresh()

func load_pose(id: String) -> void:
	var config: Dictionary = observer.cfg.zones[id]
	var point := Vector3(float(config.focus[0]), float(config.focus[1]), float(config.focus[2]))
	var yaw := deg_to_rad(float(config.yaw))
	var pitch := deg_to_rad(float(config.pitch))
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.position = point + offset * float(config.distance)
	camera.look_at(point)
	camera.size = float(config.size)

func select_zone(id: String, source: String) -> void:
	if not observer.ids.has(id):
		return
	cancel_deploy()
	command = Command.DEPLOY
	observer.visit(id, source)
	load_pose(id)
	set_overview(false)

func set_overview(value: bool) -> void:
	expanded = value
	overview.visible = value
	if value:
		overview.queue_redraw()
	cancel_deploy()
	command = Command.DEPLOY
	map_button.text = "返回战区   Tab" if value else "战术地图   Tab"

func cancel_deploy() -> void:
	main.manual_deploy_held = false

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	interface = Control.new()
	interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(interface)
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.theme = make_theme()

	var header := dock(0.0, 0.0, 0.0, 0.0, 18, 16, 0, 0)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	header.add_child(top)
	zone_label = label_to(top, "", 21)
	clock_label = label_to(top, "", 15)
	map_button = button_to(top, "战术地图   Tab", func(): set_overview(not expanded))

	var alerts := dock(1.0, 0.0, 1.0, 0.0, -198, 16, -18, 0)
	var alert_column := VBoxContainer.new()
	alerts.add_child(alert_column)
	for id in observer.ids:
		var button := button_to(alert_column, str(observer.cfg.zones[id].label), select_zone.bind(id, "label"))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		zone_buttons[id] = button

	var footer := dock(0.5, 1.0, 0.5, 1.0, -344, -134, 344, -16)
	var command_stack := VBoxContainer.new()
	command_stack.add_theme_constant_override("separation", 7)
	footer.add_child(command_stack)
	var row := HBoxContainer.new()
	command_stack.add_child(row)
	fire_label = label_to(row, "", 15)
	fire_label.add_theme_color_override("font_color", FIRE)
	fire_bar = ProgressBar.new()
	fire_bar.max_value = float(main.params.economy.capacity)
	fire_bar.show_percentage = false
	fire_bar.custom_minimum_size = Vector2(0, 5)
	fire_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fire_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fire_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_bar.add_theme_stylebox_override("background", surface(Color("#2a3c49")))
	fire_bar.add_theme_stylebox_override("fill", surface(FIRE))
	row.add_child(fire_bar)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	command_stack.add_child(controls)
	for i in CARDS.size():
		var entry: Array = CARDS[i]
		var kind: String = entry[0]
		var button := button_to(controls, "%d  %s\n%s 冥火" % [i + 1, entry[1], cost_text(main.phase_b.cost(kind))], select_kind.bind(kind))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = entry[2]
		unit_cards[kind] = button
	rally_button = button_to(controls, "集结  F\n%s 冥火" % cost_text(float(main.params.economy.rally_cost)), select_command.bind(Command.RALLY))
	spell_button = button_to(controls, "", select_command.bind(Command.SPELL))
	hint = label_to(command_stack, "", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	overview = Overview.new()
	overview.view = self
	interface.add_child(overview)
	overview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overview.offset_left = 18
	overview.offset_top = 16
	overview.offset_right = -18
	overview.offset_bottom = -16
	overview.hide()
	var close := Button.new()
	close.text = "返回战区   Tab"
	close.focus_mode = Control.FOCUS_NONE
	overview.add_child(close)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -150
	close.offset_right = -14
	close.offset_top = 12
	close.offset_bottom = 48
	close.pressed.connect(set_overview.bind(false))

	end_panel = dock(0.5, 0.27, 0.5, 0.27, -175, 0, 175, 0)
	var conclusion := VBoxContainer.new()
	end_panel.add_child(conclusion)
	result_label = label_to(conclusion, "", 21)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_button = button_to(conclusion, "跳过守军撤离", func(): main.queue_input("skip_retreat"))
	button_to(conclusion, "再战   R", restart)
	end_panel.hide()
	if watch:
		footer.hide()

func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("#ffdf9b"))
	theme.set_color("font_disabled_color", "Button", Color("#7f8790"))
	theme.set_stylebox("normal", "Button", surface(Color("#1e2938"), Color("#43483f"), 8))
	theme.set_stylebox("hover", "Button", surface(Color("#303a44"), GOLD, 8))
	theme.set_stylebox("pressed", "Button", surface(Color("#42443b"), GOLD, 8))
	theme.set_stylebox("disabled", "Button", surface(Color("#1b2430"), Color("#323d48"), 8))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	panel_style = surface(Color(INK, 0.96), Color("#776748"), 12)
	return theme

static func surface(color: Color, border := Color.TRANSPARENT, margin := 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	if border.a > 0:
		style.border_width_top = 1
		style.border_width_bottom = 1
	style.set_content_margin_all(margin)
	return style

func dock(x: float, y: float, right: float, bottom: float, l: float, t: float, r: float, b: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	interface.add_child(panel)
	panel.anchor_left = x
	panel.anchor_top = y
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	panel.offset_left = l
	panel.offset_top = t
	panel.offset_right = r
	panel.offset_bottom = b
	return panel

static func label_to(parent: Control, value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

static func button_to(parent: Control, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

static func cost_text(value: float) -> String:
	return String.num(value, 2)

func restart() -> void:
	if watch:
		return
	var current_scene := get_tree().current_scene
	if current_scene != null:
		get_tree().reload_current_scene()

func select_kind(kind: String) -> void:
	cancel_deploy()
	if main.phase_b.available(kind):
		main.selected_kind = kind
		command = Command.DEPLOY

func select_command(value: Command) -> void:
	cancel_deploy()
	if not expanded and main.outcome == main.Outcome.ACTIVE:
		command = Command.DEPLOY if command == value else value

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cancel_deploy()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB: set_overview(not expanded)
			KEY_ESCAPE:
				if expanded:
					set_overview(false)
				command = Command.DEPLOY
				cancel_deploy()
			KEY_R: restart()
			KEY_F: select_command(Command.RALLY)
			KEY_G: select_command(Command.SPELL)
			KEY_SPACE:
				if not watch:
					main.queue_input("skip_retreat")
			KEY_1, KEY_2, KEY_3, KEY_4:
				select_kind(CARDS[event.physical_keycode - KEY_1][0])
			_:
				return
		get_viewport().set_input_as_handled()
	if watch or expanded or main.bot != null or main.outcome != main.Outcome.ACTIVE:
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		command = Command.DEPLOY
		cancel_deploy()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		var p := mouse_world(event.position)
		if not can_target(p):
			return
		match command:
			Command.RALLY, Command.SPELL:
				main.queue_input("rally" if command == Command.RALLY else "spell", p)
				command = Command.DEPLOY
			Command.DEPLOY:
				if main.can_deploy(p):
					main.manual_deploy_pos = p
					main.manual_deploy_held = true
					main.next_manual_deploy = main.time
		get_viewport().set_input_as_handled()

func mouse_world(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var normal := camera.project_ray_normal(screen)
	var map: Dictionary = main.params.map
	var heights: Array = [map.base_height, map.highland_height, map.keep_height]
	for section in map.get("height_rects", []):
		heights.append(section.height)
	heights.sort()
	heights.reverse()
	for value in heights:
		var p = Plane(Vector3.UP, float(value)).intersects_ray(origin, normal)
		if p != null and main.terrain.is_walkable_at(p) and is_equal_approx(main.terrain.height_at(p), float(value)):
			return p
	return Vector3.INF

func can_target(p: Vector3) -> bool:
	return p != Vector3.INF and main.terrain.zone_at(p) == observer.current

func refresh(alpha := 1.0) -> void:
	observer.poll()
	field.sync()
	refresh_units(alpha)
	refresh_effects()
	refresh_hud()
	if expanded:
		overview.queue_redraw()
	var can_play: bool = not expanded and not watch and main.bot == null and main.outcome == main.Outcome.ACTIVE
	var hover := get_viewport().gui_get_hovered_control()
	var p := mouse_world(get_viewport().get_mouse_position()) if can_play and hover == null else Vector3.INF
	var valid := can_target(p)
	if main.manual_deploy_held:
		if not valid or not main.can_deploy(p):
			cancel_deploy()
		else:
			main.manual_deploy_pos = p
	preview.visible = valid
	if valid:
		var radius := 0.53
		var color := FIRE if main.can_deploy(p) else Color("#886968")
		if command == Command.RALLY:
			radius = float(main.params.economy.rally_radius)
			color = GOLD
		elif command == Command.SPELL:
			radius = float(main.params.spell[main.params.spell.active].radius)
			color = effect_color(main.params.spell.active)
		preview.position = p + Vector3.UP * 0.07
		preview.scale = Vector3(radius, 1, radius)
		preview.material_override.albedo_color = color
	rally_ring.visible = main.rally_until > main.time and main.outcome == main.Outcome.ACTIVE
	rally_ring.position = ground(main.rally_pos) + Vector3.UP * 0.07
	for name in markers:
		var marker: MeshInstance3D = markers[name]
		marker.hide()
	for cast in main.spell_casts:
		if main.time < float(cast.until):
			var marker: MeshInstance3D = markers[cast.spell]
			marker.show()
			marker.position = ground(Vector3(cast.point[0], 0, cast.point[1])) + Vector3.UP * 0.09

func refresh_hud() -> void:
	var label: String = observer.cfg.zones[observer.current].label
	zone_label.text = label + "  ·  " + observer.zone_status(observer.current)
	var remaining := ceili(maxf(0, float(main.params.simulation.night_seconds) - main.time))
	clock_label.text = "距破晓  %02d:%02d" % [remaining / 60, remaining % 60]
	fire_label.text = "冥火  %d / %d" % [floori(main.fire), int(main.params.economy.capacity)]
	fire_bar.value = main.fire
	for id in zone_buttons:
		var button: Button = zone_buttons[id]
		var notice: Dictionary = observer.latest.get(id, {})
		button.text = str(observer.cfg.zones[id].label)
		if not notice.is_empty():
			button.text += "  ·  " + str(notice.message)
		button.set_pressed_no_signal(id == observer.current)
		button.modulate = GOLD if not notice.is_empty() else Color.WHITE
	for kind in unit_cards:
		var button: Button = unit_cards[kind]
		button.disabled = not main.phase_b.available(kind) or main.fire < main.phase_b.cost(kind)
		button.set_pressed_no_signal(command == Command.DEPLOY and kind == main.selected_kind)
		button.toggle_mode = true
	rally_button.toggle_mode = true
	rally_button.set_pressed_no_signal(command == Command.RALLY)
	rally_button.disabled = main.fire < float(main.params.economy.rally_cost)
	var name: String = main.params.spell.active
	var left: int = int(main.params.spell.charges) - main.spell_uses
	spell_button.toggle_mode = true
	spell_button.set_pressed_no_signal(command == Command.SPELL)
	spell_button.disabled = left <= 0 or main.fire < float(main.params.spell[name].cost)
	spell_button.text = "%s G  %d/%d\n%s 冥火" % ["狂化" if name == "frenzy" else "虚弱", left, int(main.params.spell.charges), cost_text(float(main.params.spell[name].cost))]
	match command:
		Command.RALLY: hint.text = "点击地面集结  ·  右键取消"
		Command.SPELL: hint.text = "点击地面施法  ·  右键取消"
		_: hint.text = "在青色登陆区长按左键连续部署"
	if not main.input_events.is_empty() and main.step_number - int(main.input_events.back().step) < 40 and not main.input_events.back().accepted:
		hint.text = "指令未执行  ·  检查冥火、目标位置或法术剩余次数"
	end_panel.visible = main.outcome != main.Outcome.ACTIVE and not expanded
	if main.won:
		result_label.text = "胜利\n%s" % ("主堡攻占 · 登船 %d" % main.escaped if main.retreat_started else "守军全歼")
	elif main.finished:
		result_label.text = "攻城失败\n破晓已至"
	escape_button.visible = main.presentation == main.Presentation.RETREAT

func refresh_units(alpha: float) -> void:
	for u in main.units:
		var bones: bool = not u.alive and u.bones_until > main.time
		var dead: bool = not u.alive and not u.escaped and u.anim_name == "death" and main.time < u.death_at + 0.45
		var visible_here: bool = (u.alive and u.cave_until < 0.0) or bones or dead
		if not visible_here:
			if actors.has(u.id):
				actors[u.id].root.queue_free()
				actors.erase(u.id)
			continue
		if not actors.has(u.id):
			var root := Node3D.new()
			add_child(root)
			var sprite := sprite_node(root)
			var stun := sprite_node(root)
			stun.texture = sprites.sample_tiles.stun
			stun.pixel_size = 0.005
			stun.position.y = 1.42
			stun.offset = Vector2(0, 0)
			actors[u.id] = {"root": root, "sprite": sprite, "stun": stun}
		var actor: Dictionary = actors[u.id]
		var sprite: Sprite3D = actor.sprite
		var action := "idle"
		var clock: float = main.time
		var looping := true
		if dead:
			action = "death"
			clock = main.time - u.death_at
			looping = false
		elif not bones:
			action = pose_for(u)
			looping = action in ["idle", "walk", "retreat", "stealth", "down", "charge"]
			clock = main.time + float(u.id) * 0.13 if looping else u.anim_t
			if action == "hurt":
				clock = float(main.params.combat.animation_lengths.hurt) - (u.hurt_until - main.time)
		var art := sprites.appearance("bones" if bones else u.kind, action, clock, looping)
		sprite.texture = art.texture
		sprite.pixel_size = float(main.params.view.sprite_heights[u.kind]) / float(art.height)
		sprite.offset = Vector2(sprite.texture.get_width() * 0.5 - art.foot.x, art.foot.y - sprite.texture.get_height() * 0.5)
		var facing: Vector3 = -u.facing if not art.faces_right else u.facing
		sprite.flip_h = camera.basis.x.dot(facing) < 0
		if sprite.flip_h:
			sprite.offset.x = -sprite.offset.x
		var hop := 0.0
		var tilt := 0.0
		if not bones and not sprites.atlases.has(u.kind):
			if action in ["walk", "charge", "retreat", "stealth"]:
				hop = absf(sin(u.walked * 3.9)) * float(main.params.combat.hop_height)
			elif action in ["attack", "backstab", "slam", "sweep", "cast", "hurt"]:
				tilt = sin(clampf(clock * 4.0, 0, PI)) * 0.19 * (-1 if sprite.flip_h else 1)
			elif action in ["fall", "down", "death", "launch"]:
				tilt = -1.05 * smoothstep(0.01, 0.24, clock)
		var root: Node3D = actor.root
		root.basis = camera.basis
		root.position = u.previous_pos.lerp(u.nav_pos, alpha) + Vector3.UP * hop
		sprite.rotation.z = tilt
		sprite.modulate = field.sprite_light
		if bones:
			sprite.modulate = Color("#afbaa8")
		elif u.kind == "assassin" and not main.phase_b.visible(u):
			sprite.modulate.a = 0.53
		if u.rallying:
			sprite.modulate = sprite.modulate.lerp(Color("#f1dab1", sprite.modulate.a), 0.35)
		if main.time < u.frenzy_until:
			sprite.modulate = sprite.modulate.lerp(effect_color("frenzy"), 0.35)
		elif main.time < u.weakness_until:
			sprite.modulate = sprite.modulate.lerp(effect_color("weakness"), 0.35)
		if dead:
			sprite.modulate.a *= 1.0 - clock / 0.45
		actor.stun.visible = u.targetable() and u.faction == 1 and u.stun_until > main.time and u.spell_stun_until > main.time
		actor.stun.position.y = float(main.params.view.sprite_heights[u.kind]) * 0.88

func pose_for(u) -> String:
	if u.falling_until >= 0: return "launch"
	if u.retreating: return "retreat"
	if main.time < u.rise_until:
		if main.time >= u.down_until: return u.anim_name if u.anim_name == "reassemble" else "rise"
		return u.anim_name
	if main.time < u.hurt_until: return "hurt"
	if u.charge_target != null: return "charge"
	if u.anim_name in ["attack", "shoot", "backstab", "slam", "sweep", "cast"] and u.anim_t < 0.48:
		return u.anim_name
	if u.walk_dir.length_squared() > 0.03:
		return "stealth" if u.kind == "assassin" and not main.phase_b.visible(u) else "walk"
	return "idle"

func refresh_effects() -> void:
	var active := {}
	for fx in main.effects:
		if main.time >= float(fx.end):
			continue
		var key: int = fx.id
		active[key] = true
		var age := clampf(inverse_lerp(float(fx.start), float(fx.end), main.time), 0, 1)
		var a: Vector3 = fx.from
		var b: Vector3 = fx.to
		var kind: String = fx.kind
		if not effect_nodes.has(key):
			var sprite := sprite_node(self)
			var tile := "clash"
			match kind:
				"fire_bolt", "fire_impact", "reassemble", "frenzy", "weakness": tile = "fire"
				"dust", "sweep": tile = "dust"
			sprite.texture = sprites.sample_tiles[tile]
			sprite.pixel_size = 0.009 if kind == "fire_impact" else 0.005
			effect_nodes[key] = sprite
		var sprite: Sprite3D = effect_nodes[key]
		sprite.basis = camera.basis
		sprite.position = ground(a).lerp(ground(b), age) + Vector3.UP * (0.65 + sin(age * PI) * 0.32)
		if kind == "clash":
			sprite.position = a
		sprite.modulate = effect_color(kind)
		sprite.modulate.a = 1.0 - smoothstep(0.25, 1.0, age) if kind != "fire_bolt" else 1.0
		sprite.scale = Vector3.ONE * (0.75 + age * 0.65)
	for key in effect_nodes.keys():
		if not active.has(key):
			effect_nodes[key].queue_free()
			effect_nodes.erase(key)

static func effect_color(kind: String) -> Color:
	match kind:
		"frenzy", "reassemble", "fire_bolt", "fire_impact": return Color("#71ecc6")
		"weakness": return Color("#c1ade0")
		"backstab", "clash", "arrow": return Color("#fae0a0")
		_: return Color.WHITE

func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, main.terrain.height_at(p), p.z)

static func sprite_node(parent: Node3D) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.double_sided = false
	parent.add_child(sprite)
	return sprite

func ring(color: Color, radius: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.outer_radius = radius
	mesh.inner_radius = maxf(0.01, radius - 0.075)
	mesh.rings = 64
	mesh.ring_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = PaintedField.solid(color)
	node.hide()
	add_child(node)
	return node

func next_shot_due() -> bool:
	return shot_index < shot_times.size() and main.time + 0.000001 >= float(shot_times[shot_index])

func capture_if_due() -> void:
	if shot_pending:
		return
	if shot_index >= shot_times.size():
		if main.finished:
			get_tree().quit()
		return
	if not next_shot_due():
		return
	shot_pending = true
	await RenderingServer.frame_post_draw
	var path := screenshot_dir.path_join("%s_seed%d_%03d.png" % [observer.current, main.seed_value, int(shot_times[shot_index])])
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		push_error("截图失败 " + path)
		get_tree().quit(3)
		return
	print("SHOT " + path)
	shot_index += 1
	shot_pending = false
