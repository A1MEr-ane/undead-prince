extends Control

const Chart = preload("res://scripts/campaign/chart.gd")
const ENDINGS := {
	"E00": {"title": "再沉灰海 · Lost at Sea",
		"body": "军旗落下，埃德蒙先听见桨声，才重新看见海岸。\n本轮讨伐在成功安排结算之前失败。已发生的交战与部分决定将随历史重置；亲历的知识仍留在王子记忆中。",
		"ferryman": "看来还没到家。"},
	"E01": {"title": "灰烬王冠 · The Crown of Ash",
		"body": "王冠复归，在证据允许范围内平反，亡灵卫队站在王座前。妹妹可能留在宫廷或退居别处，军团仍受命令束缚。\n王子发现胜利能够恢复身份，却不能让生前生活回来。",
		"ferryman": "那么，陛下。一切都如你所愿吗？"}
}

var _selected := "bay"
var _seed := 1
var _automatic := false
var _capture := false
var _chart
var _content: VBoxContainer
var _status: Label
var _memory: Label
var _countdown: Label
var _ending_seconds := -1.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto_run":
			_automatic = true
		elif arg == "--capture_t28":
			_capture = true
		elif arg.begins_with("--seed="):
			_seed = arg.trim_prefix("--seed=").to_int()
	Run.initialize(not (_automatic or _capture), _seed)
	_build_ui()
	_refresh()
	if _automatic:
		_auto_run.call_deferred()
	elif _capture:
		_capture_run.call_deferred()


func _process(delta: float) -> void:
	if Run.phase != "ending" or _automatic or _capture or Run.last_error != OK:
		return
	_ending_seconds -= delta
	if is_instance_valid(_countdown):
		_countdown.text = "%d 秒后，契约将召回王子。" % ceili(maxf(_ending_seconds, 0))
	if _ending_seconds <= 0:
		_return()


func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font_size = 17
	self.theme = theme
	var background := ColorRect.new()
	background.color = Color("0c1721")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	_label(page, "王冠海航海图   /   THE CROWNSEA", 27, Color("efc990"))
	_status = _label(page, "", 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	var map_column := VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(map_column)
	_label(map_column, "选择亮起的下一站 → 查看地点 → 前往并结算", 16, Color("a9e5cf"))
	_chart = Chart.new()
	_chart.custom_minimum_size = Vector2(600, 400)
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.selected_site.connect(_select)
	map_column.add_child(_chart)
	_label(map_column, "金色：已走航路    浅绿：可前往    箭头：航向", 14, Color("a6b9c7"))
	_label(map_column, "[益]旧部增益  [募]招募  [火]魂火  [缝]缝补\n[休]休整  [物]遗物  [航]航海  [知]知识", 14, Color("a6b9c7"))
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 370
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152736")
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.custom_minimum_size.x = 330
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_memory = _label(page, "", 15, Color("a9e5cf"))


func _label(parent: Node, value: String, font_size: int = 17,
		color: Color = Color("e1e8ec")) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	_content.add_child(button)


func _refresh() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_countdown = null
	if Run.last_error != OK:
		_label(_content, "无法读写战役存档", 24)
		_label(_content, "错误码：%s。请保留 user://save.json 交由 Lead 检查。" % Run.last_error)
		return
	_status.text = "第一阶段 · 复仇     本轮 %02d     当前位置：%s     已结算 %d 站" % [
		Run.run_id, Run.sites[Run.current_site].zh, Run.site_results.size()]
	_memory.text = "跨轮记忆：%s    |    结局记录：%s    |    本轮奖励：%d" % [
		"暂无" if Run.save.known_facts.is_empty() else " · ".join(Run.save.known_facts),
		"暂无" if Run.save.endings_seen.is_empty() else " / ".join(Run.save.endings_seen),
		Run.stores.get("rewards", []).size()]
	_chart.configure(Run, _selected)
	if Run.save.save_status == "COMPLETED":
		_label(_content, "这段故事已经结束", 24)
		_label(_content, "已完结存档不再发起出征。")
		return
	if Run.phase != "ending":
		_ending_seconds = -1
	match Run.phase:
		"ending":
			_show_ending()
		"capital":
			_show_capital()
		"battle":
			_label(_content, Run.sites[Run.current_site].zh, 25)
			_label(_content, "战斗桩", 21, Color("efc990"))
			_label(_content, "选择结果，或按种子判定。胜利后结算本站；败北进入 E00。")
			_battle_buttons()
		_:
			_show_location()


func _show_location() -> void:
	var site: Dictionary = Run.sites[_selected]
	var reward: Dictionary = Run.rewards[_selected]
	_label(_content, str(site.zh), 25, Color("efc990"))
	_label(_content, str(site.en), 15, Color("a6b9c7"))
	_label(_content, "遭遇", 18, Color("a9e5cf"))
	_label(_content, str(site.scene))
	_label(_content, "剧情", 18, Color("a9e5cf"))
	_label(_content, str(site.plot))
	_label(_content, "[%s] %s\n%s" % [Chart.ICONS[reward.category], reward.category, reward.reward], 16, Color("efc990"))
	if Run.phase == "site":
		if site.type == "lore":
			_button("调查并领取奖励", _investigate)
		else:
			_button("进攻", _attack)
		return
	if Run.available_next().has(_selected):
		_button("前往 %s →" % site.zh, _sail.bind(_selected))
	elif _selected == "bay" and Run.current_site == "bay":
		_label(_content, "基础军团已唤醒。选择断桅滩，开始本轮航行。")
		if not Run.save.last_outcome.is_empty():
			_label(_content, "渡魂人：\n“%s”" % ENDINGS[Run.save.last_outcome].ferryman,
				18, Color("efc990"))
	else:
		_label(_content, "本站已结算。" if _selected == Run.current_site else "此地不在当前出边上。", 15)
	_label(_content, "下一站", 19, Color("a9e5cf"))
	for id in Run.available_next():
		var next: Dictionary = Run.sites[id]
		var category: String = Run.rewards[id].category
		_button("[%s] %s  ›  %s" % [Chart.ICONS[category], next.zh, category], _select.bind(str(id)))


func _show_capital() -> void:
	_label(_content, "永昼王城 · SUNHOLD", 24, Color("efc990"))
	_label(_content, "入口：%s  /  第一阶段固定进程" % Run.sites[Run.capital_entry].zh, 15)
	match Run.capital_step:
		"audience":
			_label(_content, "1 / 5  王室会面 · 王权", 21)
			_label(_content, "妹妹确认他是自己的兄长，也要求他说明继位的法理与目的。王子仍坚持原定的王位主张，部分宫卫可能反抗。")
			_button("坚持王位主张 →", _advance_capital)
		"council":
			_label(_content, "2 / 5  摄政议会覆灭", 21)
			_label(_content, "沃尔特只愿为王子与近卫平反，仍将被征船员列作叛军。完成宫城对质，取得宫廷档案；未交战的议员不默认死亡。")
			_label(_content, "宫城战斗桩", 18, Color("a9e5cf"))
			_battle_buttons()
		"muster":
			_label(_content, "3 / 5  最后的集结 · 军誓", 21)
			_label(_content, "伯纳德召集旧部。有些亡魂希望继续战斗，另一些只想回家。第一阶段延续旧军誓，命令仍能束缚军团。")
			_button("保留军誓 →", _advance_capital)
		"winter":
			_label(_content, "4 / 5  冬政会议", 21)
			_label(_content, "埃德蒙主持会议，仍可命令亡魂运输与守港。" +
				("万谷仓的粮储已保全。" if Run.stores.has("reserve") else "本轮仍需另行筹集冬储。"))
			_button("继续 →", _advance_capital)
		"day":
			_label(_content, "5 / 5  永昼政策", 21)
			_label(_content, "王子尚未掌握秘印的运作与停机方式，沿用既有永昼政策。王权与军誓已经提交。")
			_button("延续永昼 · 见证结局", _advance_capital)


func _show_ending() -> void:
	var card: Dictionary = ENDINGS[Run.outcome]
	_label(_content, Run.outcome, 33, Color("efc990"))
	_label(_content, card.title, 23)
	_label(_content, card.body, 18)
	_label(_content, "渡魂人\n“%s”" % card.ferryman, 20, Color("a9e5cf"))
	_label(_content, "回溯将清空本轮军团收益、实物、证据、效忠与决定，保留知识、航路和结局记忆。", 15)
	if _ending_seconds < 0:
		_ending_seconds = 20
	_countdown = _label(_content, "20 秒后，契约将召回王子。", 15)
	_button("回溯到沉钟湾", _return)


func _battle_buttons() -> void:
	_button("胜利", _battle_result.bind(true))
	_button("败北", _battle_result.bind(false))
	_button("按种子判定", _random_battle)


func _select(id: String) -> void:
	if Run.phase != "map":
		return
	_selected = id
	_refresh()


func _sail(id: String) -> void:
	if Run.travel_to(id):
		_selected = id
	_refresh()


func _attack() -> void:
	Run.attack()
	_refresh()


func _investigate() -> void:
	Run.investigate()
	_refresh()


func _battle_result(won: bool) -> void:
	Run.resolve_battle(won)
	_refresh()


func _random_battle() -> void:
	_battle_result(Run.roll_battle())


func _advance_capital() -> void:
	Run.advance_capital()
	_refresh()


func _return() -> void:
	Run.return_to_bay()
	_selected = "bay"
	_refresh()


func _auto_run() -> void:
	if Run.last_error != OK:
		get_tree().quit(1)
		return
	for step in range(160):
		match Run.phase:
			"map":
				var next: String = Run.random_next()
				if next.is_empty():
					push_error("Campaign has no available directed route")
					get_tree().quit(1)
					return
				Run.travel_to(next)
			"site":
				if Run.sites[Run.current_site].type == "lore":
					Run.investigate()
				else:
					Run.attack()
			"battle":
				Run.resolve_battle(Run.roll_battle())
			"capital":
				if Run.capital_step == "council":
					Run.resolve_battle(Run.roll_battle())
				else:
					Run.advance_capital()
			"ending":
				var result := {"seed": _seed, "route": Run.route.duplicate(),
					"ending": Run.outcome, "knowledge": Run.save.known_facts.duplicate()}
				Run.return_to_bay()
				result["returned_to"] = Run.current_site
				result["run_cleared"] = Run.site_results.is_empty() and Run.stores.is_empty() and Run.crown.is_empty()
				print("CAMPAIGN " + JSON.stringify(result))
				get_tree().quit(0)
				return
	push_error("Campaign exceeded transition limit")
	get_tree().quit(1)


func _capture_run() -> void:
	_sail("wreck")
	_attack()
	_battle_result(true)
	await _shot("chart")
	_sail("light")
	await _shot("location")
	_attack()
	_battle_result(true)
	for id in ["kings", "roads", "merchant", "sunhold"]:
		_sail(id)
		if Run.phase == "site":
			if Run.sites[id].type == "lore":
				_investigate()
			else:
				_attack()
				_battle_result(true)
	while Run.phase == "capital":
		if Run.capital_step == "council":
			_battle_result(true)
		else:
			_advance_capital()
	await _shot("ending_e01")
	_return()
	await _shot("returned_bay")
	_sail("wreck")
	_attack()
	_battle_result(false)
	await _shot("ending_e00")
	get_tree().quit()


func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://shots/t28")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(name + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAMPAIGN_SHOT %s error=%s" % [path, error])
