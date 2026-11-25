extends RefCounted
## T51：战役图、奖励映射与覆盖表的一致性检查。
## 难度不在这里重写，直接使用 scripts/campaign/difficulty.gd（经 RunState 正式加载并 configure）。

const RunState = preload("res://scripts/campaign/run_state.gd")
const CHART_PATH := "res://docs/canon/C/CAMPAIGN-DATA.json"
const REWARDS_PATH := "res://data/campaign/reward_map.json"
const OVERRIDES_PATH := "res://data/campaign/overrides.json"
const DIFFICULTY_PATH := "res://data/campaign/difficulty.json"

var checks := 0
var failures := 0


func run_all() -> int:
	print("Campaign 数据一致性检查")
	var chart := _load_json(CHART_PATH)
	var rewards := _load_json(REWARDS_PATH)
	var overrides := _load_json(OVERRIDES_PATH)
	var rules := _load_json(DIFFICULTY_PATH)
	if chart.is_empty() or rewards.is_empty() or overrides.is_empty() or rules.is_empty():
		print("=== Campaign 数据结果：%d 个断言，%d 个失败 ===" % [checks, failures])
		return failures
	var site_ids := _site_ids(chart)
	_test_rewards(site_ids, rewards)
	_test_overrides(site_ids, overrides)
	_test_edges(site_ids, chart)
	_test_reachability(site_ids, chart)
	_test_difficulty(site_ids)
	print("=== Campaign 数据结果：%d 个断言，%d 个失败 ===" % [checks, failures])
	return failures


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("[FAIL] " + message)


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_expect(false, "可读取数据文件：" + path)
		return {}
	var value = JSON.parse_string(text)
	_expect(value is Dictionary, "JSON 顶层是对象：" + path)
	return value if value is Dictionary else {}


func _site_ids(chart: Dictionary) -> Array:
	var ids: Array = []
	var nodes = chart.get("nodes", [])
	_expect(nodes is Array and not nodes.is_empty(), "canon 含地点列表")
	if not nodes is Array:
		return ids
	for node in nodes:
		if not node is Dictionary or not node.has("id"):
			_expect(false, "每个地点条目都有 id")
			continue
		var id := str(node.id)
		_expect(not ids.has(id), "地点 id 不重复：" + id)
		ids.append(id)
	return ids


func _test_rewards(site_ids: Array, rewards: Dictionary) -> void:
	for id in site_ids:
		_expect(rewards.has(id), "reward_map 覆盖地点：" + str(id))
	for id in rewards:
		_expect(site_ids.has(str(id)), "reward_map 不引用不存在的地点：" + str(id))


func _test_overrides(site_ids: Array, overrides: Dictionary) -> void:
	var sites = overrides.get("sites", {})
	_expect(sites is Dictionary, "overrides 含 sites 对象")
	if not sites is Dictionary:
		return
	for id in sites:
		_expect(site_ids.has(str(id)), "overrides 只引用 canon 地点：" + str(id))


func _test_edges(site_ids: Array, chart: Dictionary) -> void:
	var edges = chart.get("edges", [])
	_expect(edges is Array and not edges.is_empty(), "canon 含边列表")
	if not edges is Array:
		return
	for edge in edges:
		if not edge is Array or edge.size() != 2:
			_expect(false, "每条边是 [起点, 终点]：" + str(edge))
			continue
		var from := str(edge[0])
		var to := str(edge[1])
		_expect(site_ids.has(from), "边起点存在：%s→%s" % [from, to])
		_expect(site_ids.has(to), "边终点存在：%s→%s" % [from, to])


func _test_reachability(site_ids: Array, chart: Dictionary) -> void:
	var edges: Array = chart.get("edges", [])
	var forward := _reachable("bay", edges, false)
	var backward := _reachable("sunhold", edges, true)
	_expect(forward.size() == site_ids.size(), "从沉钟湾可达全部地点")
	_expect(backward.size() == site_ids.size(), "全部地点都能到王都入口")
	for id in site_ids:
		_expect(forward.has(id), "从沉钟湾可达：" + str(id))
		_expect(backward.has(id), "可到王都入口：" + str(id))


func _reachable(start: String, edges: Array, reverse: bool) -> Dictionary:
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var current := str(queue.pop_front())
		for edge in edges:
			if not edge is Array or edge.size() != 2:
				continue
			var from := str(edge[0])
			var to := str(edge[1])
			var source := to if reverse else from
			var target := from if reverse else to
			if source == current and not seen.has(target):
				seen[target] = true
				queue.append(target)
	return seen


func _test_difficulty(site_ids: Array) -> void:
	# 走游戏同一条加载路径：读 canon、叠加 overrides，再 configure 难度脚本。
	var state = RunState.new()
	_expect(state.initialize(false, 7) == OK, "RunState 可按正式加载路径初始化")
	if state.last_error != OK:
		state.free()
		return
	_expect(state.sites.size() == site_ids.size(), "正式加载保留全部地点")
	for id in site_ids:
		var site_id := str(id)
		_expect(state.sites.has(site_id), "正式加载含地点：" + site_id)
		if not state.sites.has(site_id):
			continue
		_expect(state.difficulty.depth.has(site_id), "可算出离据点的最短步数：" + site_id)
		_expect(state.difficulty.remaining.has(site_id), "可算出到王都入口的最短步数：" + site_id)
		var detail: Dictionary = state.difficulty.describe(site_id)
		var value := int(detail.get("tier", -1))
		_expect(value >= 1 and value <= 5, "难度落在 1–5 档：%s=%d" % [site_id, value])
		_expect(int(state.difficulty.tier(site_id)) == value, "tier() 与 describe().tier 一致：" + site_id)
		_expect(state.site_difficulty(site_id) >= 1 and state.site_difficulty(site_id) <= 5, "按敌情记忆计算的难度仍为 1–5 档：" + site_id)
		_expect(state.difficulty.tier_data(value).has("name"), "难度档有对应颜色档位：" + site_id)
	state.free()
