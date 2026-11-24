extends RefCounted
## canon 持久字段与 T29 记忆/技艺残响；本轮资产不进入 save.json。

const LEGACY_FIELDS := ["known_facts", "known_routes", "endings_seen", "last_outcome",
	"permanent_unlocks", "ferryman_recognised", "pact_release_known", "save_status"]
const FIELDS := LEGACY_FIELDS + ["enemy_memory", "echoes"]

var known_facts: Array = []
var known_routes: Array = []
var endings_seen: Array = []
var last_outcome := ""
var permanent_unlocks: Array = []
var ferryman_recognised := false
var pact_release_known := false
var save_status := "ACTIVE"
var enemy_memory: Dictionary = {}
var echoes := 0


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for field in FIELDS:
		result[field] = get(field)
	return result.duplicate(true)


func read_from_disk(path: String = "user://save.json") -> Error:
	if not FileAccess.file_exists(path):
		return OK
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return ERR_FILE_CORRUPT
	var data: Dictionary = parser.data
	var defaults := to_dict()
	for field in LEGACY_FIELDS:
		if not data.has(field) or typeof(data[field]) != typeof(defaults[field]):
			return ERR_FILE_CORRUPT
	for field in ["known_facts", "known_routes", "endings_seen", "permanent_unlocks"]:
		for value in data[field]:
			if not value is String:
				return ERR_FILE_CORRUPT
	if data.save_status not in ["ACTIVE", "COMPLETED"]:
		return ERR_FILE_CORRUPT
	# 新字段可缺省；旧八字段仍严格校验。全部校验通过后才更新内存。
	var memory = data.get("enemy_memory", {})
	var echo_count = data.get("echoes", 0)
	if not memory is Dictionary or not _is_count(echo_count):
		return ERR_FILE_CORRUPT
	for id in memory:
		if not id is String or not _is_count(memory[id]):
			return ERR_FILE_CORRUPT
	for field in LEGACY_FIELDS:
		set(field, data[field])
	enemy_memory = {}
	for id in memory:
		enemy_memory[id] = int(memory[id])
	echoes = int(echo_count)
	return OK


func _is_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floorf(float(value))


func write_to_disk(path: String = "user://save.json") -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),
		ProjectSettings.globalize_path(path))


func learn(fact: String) -> void:
	if not known_facts.has(fact):
		known_facts.append(fact)


func record_outcome(outcome: String) -> void:
	last_outcome = outcome
	if not endings_seen.has(outcome):
		endings_seen.append(outcome)
