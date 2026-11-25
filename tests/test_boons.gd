extends RefCounted
## 增益数据校验（T50）。
## 数据源：docs/boons.md。文档明确写明渡魂人的增益不占槽位、没有专精，
## 因此五槽/专精检查只覆盖伯纳德、玛蒂尔达、奥斯温、皮普四人；渡魂人单独校验文档形态。

const FILES := {
	"bernard": "res://data/boons/bernard.json",
	"matilda": "res://data/boons/matilda.json",
	"oswin": "res://data/boons/oswin.json",
	"pip": "res://data/boons/pip.json",
	"ferryman": "res://data/boons/ferryman.json",
	"duo": "res://data/boons/duo.json",
}
const STANDARD_CREWS := ["bernard", "matilda", "oswin", "pip"]
const ALL_CREWS := ["bernard", "matilda", "oswin", "pip", "ferryman"]
const FIVE_SLOTS := ["blade", "formation", "march", "soulfire", "raise"]
const SLOTS := ["blade", "formation", "march", "soulfire", "raise", "passive", "mastery", "duo"]
const REQUIRES := ["existing", "squad_skill", "prince_soulfire", "corpse", "raise", "morale", "burning"]
const ID_PATTERN := "^[a-z][a-z0-9_]*$"

var checks := 0
var failures := 0
var data := {}
var status_ids := {}
var boon_ids := {}
var _id_regex: RegEx


func _init() -> void:
	_id_regex = RegEx.new()
	if _id_regex.compile(ID_PATTERN) != OK:
		push_error("增益 id 正则编译失败")


func run_all() -> int:
	print("Boons 数据校验测试（T50，源 docs/boons.md）")
	_load_files()
	_validate_statuses()
	_validate_boons()
	_validate_standard_coverage()
	_validate_ferryman_exception()
	_validate_duo()
	print("数据：%d 个文件，%d 条增益，%d 个状态" % [data.size(), boon_ids.size(), status_ids.size()])
	print("=== Boons 结果：%d 个断言，%d 个失败 ===" % [checks, failures])
	return failures


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("[FAIL] " + message)


func _load_files() -> void:
	for crew in FILES:
		var path: String = FILES[crew]
		_expect(FileAccess.file_exists(path), "数据文件存在：" + path)
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		_expect(not text.strip_edges().is_empty(), "数据文件非空：" + path)
		if text.strip_edges().is_empty():
			continue
		var parsed = JSON.parse_string(text)
		_expect(parsed is Dictionary, "JSON 可解析：" + path)
		if parsed is Dictionary:
			data[crew] = parsed


func _validate_statuses() -> void:
	for crew in ALL_CREWS:
		if not data.has(crew) or not (data[crew] is Dictionary):
			continue
		var doc: Dictionary = data[crew]
		_expect(str(doc.get("crew", "")) == crew, "文件 crew 字段：" + crew)
		var status = doc.get("status", null)
		_expect(status is Dictionary, "有状态定义：" + crew)
		if not (status is Dictionary):
			continue
		var status_id := str(status.get("status_id", ""))
		_expect(_valid_id(status_id), "状态 id 合法：" + crew + " -> " + status_id)
		if not status_id.is_empty():
			_expect(not status_ids.has(status_id), "状态 id 全局唯一：" + status_id)
			status_ids[status_id] = crew
		_expect(not str(status.get("name_zh", "")).is_empty(), "状态有 name_zh：" + crew)
		_expect(not str(status.get("effect_zh", "")).is_empty(), "状态有 effect_zh：" + crew)
		_validate_params(status.get("params", {}), "status:" + crew)

	if data.has("duo") and data["duo"] is Dictionary:
		_expect(data["duo"].get("status", null) == null, "duo 文件没有单一状态")


func _validate_boons() -> void:
	for crew in FILES:
		if not data.has(crew) or not (data[crew] is Dictionary):
			continue
		var doc: Dictionary = data[crew]
		var boons = doc.get("boons", null)
		_expect(boons is Array and not boons.is_empty(), "boons 是非空数组：" + crew)
		if not (boons is Array):
			continue
		for boon in boons:
			_expect(boon is Dictionary, "增益是对象：" + crew)
			if boon is Dictionary:
				_validate_boon(crew, boon)


func _validate_boon(file_crew: String, boon: Dictionary) -> void:
	var boon_id := str(boon.get("id", ""))
	_expect(_valid_id(boon_id), "增益 id 合法：" + boon_id)
	if not boon_id.is_empty():
		_expect(not boon_ids.has(boon_id), "增益 id 全局唯一：" + boon_id)
		boon_ids[boon_id] = file_crew
	_expect(str(boon.get("crew", "")) == file_crew, "增益 crew 与文件一致：" + boon_id)

	var slot := str(boon.get("slot", ""))
	_expect(SLOTS.has(slot), "slot 合法：" + boon_id + " -> " + slot)
	if file_crew == "duo":
		_expect(slot == "duo", "双人增益 slot=duo：" + boon_id)
	else:
		_expect(slot != "duo", "单人增益不使用 duo 槽：" + boon_id)

	_expect(not str(boon.get("name_zh", "")).is_empty(), "增益有 name_zh：" + boon_id)
	_expect(not str(boon.get("effect_zh", "")).is_empty(), "增益有 effect_zh：" + boon_id)

	var status = boon.get("status", null)
	if status != null:
		_expect(status is String and status_ids.has(str(status)), "status 引用已定义状态：" + boon_id + " -> " + str(status))

	var requires = boon.get("requires", null)
	_expect(requires is Array, "requires 是数组：" + boon_id)
	if requires is Array:
		_expect(not requires.is_empty(), "requires 非空：" + boon_id)
		var seen := {}
		for req in requires:
			var req_id := str(req)
			_expect(req is String and REQUIRES.has(req_id), "requires 取值合法：" + boon_id + " -> " + req_id)
			_expect(not seen.has(req_id), "requires 不重复：" + boon_id + " -> " + req_id)
			seen[req_id] = true

	_validate_params(boon.get("params", {}), "boon:" + boon_id)


func _validate_params(params, context: String) -> void:
	_expect(params is Dictionary, "params 是对象：" + context)
	if not (params is Dictionary):
		return
	for key in params:
		_expect(key is String and not str(key).is_empty(), "params 键合法：" + context)
		var value = params[key]
		_expect(value is int or value is float, "params 值为数字：" + context + "." + str(key))


func _validate_standard_coverage() -> void:
	for crew in STANDARD_CREWS:
		if not data.has(crew) or not (data[crew] is Dictionary):
			continue
		var boons = data[crew].get("boons", [])
		if not (boons is Array):
			continue
		var slot_counts := {}
		var mastery_count := 0
		var passive_count := 0
		for boon in boons:
			if not (boon is Dictionary):
				continue
			var slot := str(boon.get("slot", ""))
			slot_counts[slot] = int(slot_counts.get(slot, 0)) + 1
			if slot == "mastery":
				mastery_count += 1
			if slot == "passive":
				passive_count += 1
		for slot in FIVE_SLOTS:
			_expect(int(slot_counts.get(slot, 0)) >= 1, "%s 至少 1 个 %s 槽增益" % [crew, slot])
		_expect(mastery_count >= 1, "%s 有专精" % crew)
		_expect(passive_count >= 3, "%s 至少 3 个被动（roguelike §4.2）" % crew)


func _validate_ferryman_exception() -> void:
	print("注：渡魂人按 docs/boons.md 不占槽位、没有专精，按文档特例校验")
	if not data.has("ferryman") or not (data["ferryman"] is Dictionary):
		return
	var boons = data["ferryman"].get("boons", [])
	if not (boons is Array):
		return
	_expect(boons.size() == 5, "渡魂人按文档有 5 条规则增益")
	for boon in boons:
		if not (boon is Dictionary):
			continue
		_expect(str(boon.get("slot", "")) == "passive", "渡魂人不占槽位（记 passive）：" + str(boon.get("id", "")))
	for slot in FIVE_SLOTS:
		_expect(not _has_slot(boons, slot), "渡魂人按文档没有 %s 槽" % slot)
	_expect(not _has_slot(boons, "mastery"), "渡魂人按文档没有专精")


func _validate_duo() -> void:
	if not data.has("duo") or not (data["duo"] is Dictionary):
		return
	var boons = data["duo"].get("boons", [])
	if not (boons is Array):
		return
	_expect(boons.size() == 10, "双人增益按文档有 10 条")
	for boon in boons:
		if not (boon is Dictionary):
			continue
		var boon_id := str(boon.get("id", ""))
		_expect(str(boon.get("slot", "")) == "duo", "双人增益 slot=duo：" + boon_id)
		var crews = boon.get("crews", null)
		_expect(crews is Array and crews.size() == 2, "双人增益 crews 有两人：" + boon_id)
		if crews is Array and crews.size() == 2:
			var first := str(crews[0])
			var second := str(crews[1])
			_expect(first != second, "双人增益引用两位不同旧部：" + boon_id)
			_expect(ALL_CREWS.has(first), "双人增益 crew 存在：" + boon_id + " -> " + first)
			_expect(ALL_CREWS.has(second), "双人增益 crew 存在：" + boon_id + " -> " + second)
		_expect(not str(boon.get("condition_zh", "")).is_empty(), "双人增益有 condition_zh：" + boon_id)


func _has_slot(boons: Array, slot: String) -> bool:
	for boon in boons:
		if boon is Dictionary and str(boon.get("slot", "")) == slot:
			return true
	return false


func _valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	return _id_regex.search(value) != null
