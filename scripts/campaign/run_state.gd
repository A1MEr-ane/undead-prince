extends Node
## Run autoload 的独立战役接口；真实战斗接入 attack()/resolve_battle(won)。

const SaveState = preload("res://scripts/campaign/save_state.gd")
const CHART_PATH := "res://docs/canon/C/CAMPAIGN-DATA.json"
const REWARDS_PATH := "res://data/campaign/reward_map.json"
const STAGE := 1
const RUN_FIELDS := ["run_id", "capital_entry", "site_results", "evidence", "allegiance",
	"councillor_fates", "civilian_harm", "stores", "crown", "oath", "day",
	"settlement_committed", "aftermath_seen"]

var run_id := 1
var capital_entry := ""
var site_results: Dictionary = {}
var evidence: Array = []
var allegiance: Dictionary = {}
var councillor_fates: Dictionary = {}
var civilian_harm := 0
var stores: Dictionary = {}
var crown := ""
var oath := ""
var day := ""
var settlement_committed := false
var aftermath_seen := false

var save := SaveState.new()
var sites: Dictionary = {}
var edges: Array = []
var rewards: Dictionary = {}
var current_site := "bay"
var route: Array = ["bay"]
var phase := "map"
var capital_step := ""
var outcome := ""
var last_error: Error = OK
var _persistent := false
var _save_path := "user://save.json"
var _rng := RandomNumberGenerator.new()


func initialize(persistent: bool = true, seed_value: int = 1,
		path: String = "user://save.json") -> Error:
	_persistent = persistent
	_save_path = path
	_rng.seed = seed_value
	save = SaveState.new()
	var chart = JSON.parse_string(FileAccess.get_file_as_string(CHART_PATH))
	var reward_data = JSON.parse_string(FileAccess.get_file_as_string(REWARDS_PATH))
	if not chart is Dictionary or not reward_data is Dictionary:
		last_error = ERR_FILE_CORRUPT
		return last_error
	sites.clear()
	for site in chart.nodes:
		sites[site.id] = site
	edges = chart.edges
	rewards = reward_data
	last_error = save.read_from_disk(path) if persistent else OK
	_reset_current(1)
	return last_error


func current_data() -> Dictionary:
	var result: Dictionary = {}
	for field in RUN_FIELDS:
		result[field] = get(field)
	return result.duplicate(true)


func available_next() -> Array:
	var result: Array = []
	if phase != "map" or save.save_status != "ACTIVE" or last_error != OK:
		return result
	for edge in edges:
		if edge[0] == current_site and int(sites[edge[1]].stage) <= STAGE:
			if not route.has(edge[1]):
				result.append(edge[1])
	return result


func travel_to(site_id: String) -> bool:
	if not available_next().has(site_id):
		return false
	var known_route := current_site + ">" + site_id
	if not save.known_routes.has(known_route):
		save.known_routes.append(known_route)
	current_site = site_id
	route.append(site_id)
	phase = "site"
	if sites[site_id].type == "entry":
		capital_entry = site_id
	if site_id == "sunhold":
		phase = "capital"
		capital_step = "audience"
	_persist()
	return true


func attack() -> bool:
	if phase != "site" or sites[current_site].type == "lore":
		return false
	phase = "battle"
	return true


func investigate() -> bool:
	if phase != "site" or sites[current_site].type != "lore":
		return false
	_settle_site()
	return true


func resolve_battle(won: bool) -> bool:
	if phase == "capital" and capital_step == "council":
		if won:
			save.learn("K01") # 宫廷档案是所有航路的保底来源。
			evidence.append("sunhold:palace_papers")
			capital_step = "muster"
			_persist()
		else:
			_finish("E00")
		return true
	if phase != "battle":
		return false
	if won:
		_settle_site()
	else:
		site_results[current_site] = {"won": false}
		_finish("E00")
	return true


func advance_capital() -> bool:
	if phase != "capital":
		return false
	match capital_step:
		"audience":
			crown = "claim"
			capital_step = "council"
		"muster":
			oath = "keep"
			capital_step = "winter"
		"winter":
			capital_step = "day"
		"day":
			day = "continue"
			if crown != "claim" or oath != "keep":
				return false
			settlement_committed = true
			_finish("E01")
		_:
			return false
	return true


func return_to_bay() -> bool:
	if phase != "ending":
		return false
	save.ferryman_recognised = true
	_reset_current(run_id + 1)
	_persist()
	return true


func random_next() -> String:
	var next := available_next()
	return "" if next.is_empty() else str(next[_rng.randi_range(0, next.size() - 1)])


func roll_battle() -> bool:
	return _rng.randi_range(0, 9) != 0


func _settle_site() -> void:
	var site: Dictionary = sites[current_site]
	var reward: Dictionary = rewards[current_site]
	site_results[current_site] = {"won": true}
	if reward.grants_reward:
		if not stores.has("rewards"):
			stores["rewards"] = []
		stores.rewards.append({"site": current_site, "category": reward.category})
	if not str(site.effect).is_empty():
		stores[site.effect] = true
	for fact in site.facts:
		save.learn(str(fact))
	if site.has("evidence_fragment"):
		evidence.append(current_site + ":" + str(site.evidence_fragment))
		save.learn(str(site.evidence_fragment))
	phase = "map"
	_persist()


func _finish(ending: String) -> void:
	if not outcome.is_empty():
		return
	outcome = ending
	phase = "ending"
	aftermath_seen = true
	save.record_outcome(ending)
	_persist()


func _persist() -> void:
	if _persistent and last_error == OK:
		last_error = save.write_to_disk(_save_path)


func _reset_current(next_run_id: int) -> void:
	run_id = next_run_id
	capital_entry = ""
	site_results = {}
	evidence = []
	allegiance = {}
	councillor_fates = {}
	civilian_harm = 0
	stores = {}
	crown = ""
	oath = ""
	day = ""
	settlement_committed = false
	aftermath_seen = false
	current_site = "bay"
	route = ["bay"]
	phase = "map"
	capital_step = ""
	outcome = ""
