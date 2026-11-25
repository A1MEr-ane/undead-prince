extends RefCounted
## 战斗配置数据测试：data/battles/*.json 必须可读、字段齐全、类型正确。
## 由 tests/run_tests.gd 调用 run_all()；有失败时返回非零。

const BATTLE_DIR := "res://data/battles"
const ANCHORS := ["beach_left", "beach_right", "flag", "mid"]
const STAT_KEYS := ["hp", "damage", "knockback", "stun"]
const CAPTURE_KEYS := ["player_radius", "defender_radius", "time", "decay"]
const LOOK_ROWS := 4

var checks := 0
var failures := 0


func run_all() -> int:
	print("Battles 配置数据测试")
	var dir := DirAccess.open(BATTLE_DIR)
	_expect(dir != null, "data/battles 目录可打开")
	if dir == null:
		_summary()
		return failures
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	_expect(not files.is_empty(), "data/battles 至少有一个 JSON 配置")
	for f in files:
		_test_file(String(f))
	_summary()
	return failures


func _test_file(file_name: String) -> void:
	var path := BATTLE_DIR.path_join(file_name)
	var text := FileAccess.get_file_as_string(path)
	_expect(not text.is_empty(), file_name + "：文件可读取且非空")
	if text.is_empty():
		return
	var data = JSON.parse_string(text)
	_expect(typeof(data) == TYPE_DICTIONARY, file_name + "：顶层是 JSON 对象")
	if typeof(data) != TYPE_DICTIONARY:
		return
	_test_squads(file_name, data)
	_test_capture(file_name, data)
	_test_trees(file_name, data)


func _test_squads(file_name: String, data: Dictionary) -> void:
	_expect(typeof(data.get("squads")) == TYPE_ARRAY, file_name + "：squads 是数组")
	if typeof(data.get("squads")) != TYPE_ARRAY:
		return
	var squads: Array = data["squads"]
	_expect(not squads.is_empty(), file_name + "：squads 非空")
	var has_player := false
	for i in squads.size():
		var entry = squads[i]
		var tag := "%s：squads[%d]" % [file_name, i]
		_expect(typeof(entry) == TYPE_DICTIONARY, tag + " 是对象")
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_expect(typeof(entry.get("title")) == TYPE_STRING and not String(entry.get("title", "")).is_empty(), tag + ".title 是非空字符串")
		_expect(_is_int(entry.get("faction")) and int(entry.get("faction", -1)) in [0, 1], tag + ".faction 是 0 或 1")
		_expect(_is_int(entry.get("look")) and int(entry.get("look", -1)) >= 0 and int(entry.get("look", LOOK_ROWS)) < LOOK_ROWS, tag + ".look 是合法调色板行")
		_expect(_is_int(entry.get("count")) and int(entry.get("count", 0)) > 0, tag + ".count 是大于 0 的整数")
		_expect(ANCHORS.has(entry.get("anchor")), tag + ".anchor 合法")
		_expect(typeof(entry.get("is_player")) == TYPE_BOOL, tag + ".is_player 是布尔值")
		if entry.get("is_player") == true:
			has_player = true
		if entry.has("offset"):
			var offset = entry["offset"]
			_expect(typeof(offset) == TYPE_ARRAY and offset.size() == 3, tag + ".offset 是三元素数组")
			if typeof(offset) == TYPE_ARRAY and offset.size() == 3:
				for j in offset.size():
					_expect(_is_number(offset[j]), tag + ".offset[%d] 是数字" % j)
		if entry.has("toward_beach"):
			_expect(_is_number(entry["toward_beach"]), tag + ".toward_beach 是数字")
		_test_stats(tag, entry.get("stats"))
	_expect(has_player, file_name + "：至少有一支 is_player=true 的部队")


func _test_stats(tag: String, stats) -> void:
	_expect(typeof(stats) == TYPE_DICTIONARY, tag + ".stats 是对象")
	if typeof(stats) != TYPE_DICTIONARY:
		return
	for key in STAT_KEYS:
		_expect(_is_number(stats.get(key)), tag + ".stats." + key + " 是数字")
	if stats.has("sprite"):
		_expect(typeof(stats["sprite"]) == TYPE_STRING, tag + ".stats.sprite 是字符串")


func _test_capture(file_name: String, data: Dictionary) -> void:
	_expect(typeof(data.get("capture")) == TYPE_DICTIONARY, file_name + "：capture 是对象")
	if typeof(data.get("capture")) != TYPE_DICTIONARY:
		return
	var capture: Dictionary = data["capture"]
	for key in CAPTURE_KEYS:
		_expect(_is_number(capture.get(key)), file_name + "：capture." + key + " 是数字")
	for key in CAPTURE_KEYS:
		if _is_number(capture.get(key)):
			_expect(float(capture[key]) > 0.0, file_name + "：capture." + key + " 大于 0")
	if _is_number(capture.get("player_radius")) and _is_number(capture.get("defender_radius")):
		_expect(float(capture["player_radius"]) <= float(capture["defender_radius"]), file_name + "：夺旗半径不大于守旗半径")


func _test_trees(file_name: String, data: Dictionary) -> void:
	_expect(_is_int(data.get("trees")) and int(data.get("trees", 0)) > 0, file_name + "：trees 是大于 0 的整数")


func _is_number(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _is_int(v) -> bool:
	return _is_number(v) and float(v) == floorf(float(v))


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("[FAIL] " + message)


func _summary() -> void:
	print("")
	print("=== Battles 结果：%d 个断言，%d 个失败 ===" % [checks, failures])
