extends RefCounted
## 只保存 NARRATIVE-DESIGN §12 的持久字段；本轮资产不进入 save.json。

const FIELDS := ["known_facts", "known_routes", "endings_seen", "last_outcome",
	"permanent_unlocks", "ferryman_recognised", "pact_release_known", "save_status"]

var known_facts: Array = []
var known_routes: Array = []
var endings_seen: Array = []
var last_outcome := ""
var permanent_unlocks: Array = []
var ferryman_recognised := false
var pact_release_known := false
var save_status := "ACTIVE"


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
	for field in FIELDS:
		if not data.has(field) or typeof(data[field]) != typeof(defaults[field]):
			return ERR_FILE_CORRUPT
	for field in ["known_facts", "known_routes", "endings_seen", "permanent_unlocks"]:
		for value in data[field]:
			if not value is String:
				return ERR_FILE_CORRUPT
	if data.save_status not in ["ACTIVE", "COMPLETED"]:
		return ERR_FILE_CORRUPT
	for field in FIELDS:
		set(field, data[field])
	return OK


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
