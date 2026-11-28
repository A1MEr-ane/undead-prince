extends RefCounted
## 行为场景使用本尝试版的实际战斗脚本与灰盒坐标。
## 每个场景继承本类，实现 build()/observe()/evaluate()，用 check() 记录失败原因。

const World = preload("res://attempts/single_battle/siege.gd")
const State = preload("res://scripts/agent_state.gd")
const BASE_PARAMS := "res://attempts/single_battle/siege_params.json"

var w
var args: Dictionary = {}
var label := "B00"
var title := "unnamed"
var max_time := 15.0
var failures: Array = []
var notes: Array = []
var checked := 0
var evaluated := false
var done := false
var watch := false


func configure(id: String, name: String, seconds: float, argv: Dictionary) -> void:
	label = id
	title = name
	max_time = seconds
	args = argv
	watch = args.has("watch")


func check(condition: bool, message: String) -> void:
	checked += 1
	if not condition:
		failures.append(message)


func note(message: String) -> void:
	notes.append(message)


func merge_dict(base: Dictionary, override: Dictionary) -> void:
	for key in override:
		if base.has(key) and base[key] is Dictionary and override[key] is Dictionary:
			merge_dict(base[key], override[key])
		else:
			base[key] = override[key]


## 建立独立模拟世界。默认清空正式驻军，避免场景之间互相干扰。
func make_world(overrides: Dictionary = {}, _use_phase_b: bool = false, keep_garrisons: bool = false) -> void:
	var params = JSON.parse_string(FileAccess.get_file_as_string(BASE_PARAMS))
	merge_dict(params, overrides)
	if not keep_garrisons:
		params.garrisons = []
	params.reinforcements.enabled = false
	w = World.new()
	w.params = params
	w.args = args
	w.headless = true
	w.strategy = "manual"
	w.seed_value = int(args.get("seed", "7"))
	w.sim_rng.seed = w.seed_value
	w.art_rng.seed = w.seed_value + 104729
	State.now = 0.0
	State.dt = float(params.simulation.step)
	w.terrain.setup(params)
	w.phase_b.setup(w)
	w.gate_hp = float(params.structures.gate_hp)
	w.weak_hp = float(params.structures.weak_hp)
	w.fire = float(params.economy.initial)
	for zone in params.map.zones:
		w.zones[zone.id] = {"owner": "defender", "progress": 0.0, "retake": 0.0, "captures": [], "losses": [], "contested_resets": []}
	w.director.setup(w)
	if keep_garrisons:
		for group in params.garrisons:
			for n in int(group.count):
				var guard = w.spawn(group.kind, 1, w.terrain.vec(group.anchor) + w.formation_offset(n), group.zone, group.get("victory_eligible", true))
				guard.reserve = group.get("reserve", false)


func add(kind: String, faction: int, pos: Vector3, zone: String, eligible: bool = true):
	return w.spawn(kind, faction, pos, zone, eligible)


## 一个不可移动、远离战场的有效守军，防止空守军触发“全歼”提前结束。
func sentinel():
	var u = add("shield", 1, cell(32, 9), "keep", true)
	u.speed = 0.0
	u.hp = 1000.0
	u.anchor = u.nav_pos
	u.slot = u.nav_pos
	return u


func cell(x: float, z: float) -> Vector3:
	return Vector3(x + 0.5, 0.0, z + 0.5)


func vec(a: Array) -> Vector3:
	return w.terrain.vec(a)


func zone_center(id: String) -> Vector3:
	return w.zone_point(id)


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func build() -> void:
	pass


func observe() -> void:
	pass


func evaluate() -> void:
	pass


func early_done() -> bool:
	return false


func maybe_finish() -> void:
	if evaluated:
		return
	if w == null:
		done = true
		return
	if w.finished or w.time >= max_time or early_done():
		evaluated = true
		done = true
		evaluate()


func run_headless() -> Array:
	build()
	if w == null:
		failures.append("场景未能建立模拟世界")
		return failures
	var steps := 0
	while not done and steps < 100000:
		w.simulate()
		observe()
		steps += 1
		maybe_finish()
	if not evaluated:
		evaluated = true
		evaluate()
	done = true
	return failures


func dispose() -> void:
	if w != null:
		w._exit_tree()
		w.free()
		w = null


func print_result() -> void:
	var status := "PASS" if failures.is_empty() else "FAIL"
	print("%s %s %s" % [status, label, title])
	for item in notes:
		print("  . " + item)
	for item in failures:
		print("  ! " + item)
	if failures.is_empty():
		print("  checks: %d" % checked)
	else:
		print("  checks: %d, failures: %d" % [checked, failures.size()])
