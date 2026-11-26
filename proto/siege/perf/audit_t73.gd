extends SceneTree
## 与开工快照逐步对照；快照由本轮记录保存，不作为运行依赖入库。
var baseline_path := "res://proto/siege/perf/results/t73/baseline_source/siege.gd"
const Current = preload("res://proto/siege/siege.gd")
var old
var current

func _initialize() -> void:
	call_deferred("run")

func state(w) -> String:
	var rows: Array = []
	for u in w.units:
		rows.append([u.id, u.nav_pos, u.hp, u.alive, u.enemy.id if u.enemy != null else -1,
			u.brain.stamina, u.slot, u.route, u.stage, u.target_key, u.anim_name, u.anim_t,
			u.brain.brain.active, u.brain.attack.active, u.brain.parry.active, u.brain.hunting.active,
			u.brain.adjacent.map(func(f): return f.id)])
	return var_to_str([w.sim_rng.state, rows])

func run() -> void:
	var baseline = load(baseline_path)
	if baseline == null:
		printerr("T73_AUDIT FAIL: 先按 README 冻结基线源码")
		quit(2)
		return
	old = baseline.new()
	current = Current.new()
	root.add_child(old)
	root.add_child(current)
	old.set_process(false)
	current.set_process(false)
	while not old.finished and not current.finished:
		old.simulate()
		current.simulate()
		var a := state(old)
		var b := state(current)
		if a != b:
			var f := FileAccess.open("res://proto/siege/perf/results/t73/audit-difference.txt", FileAccess.WRITE)
			f.store_string("STEP %d\nBASELINE\n%s\nCURRENT\n%s" % [old.step_number, a, b])
			printerr("T73_AUDIT FAIL step=%d strategy=%s seed=%d" % [old.step_number, old.strategy, old.seed_value])
			old.free()
			current.free()
			quit(1)
			return
	print("T73_AUDIT PASS strategy=%s seed=%d steps=%d exact_unit_state_and_rng=true finished_equal=%s" % [old.strategy, old.seed_value, old.step_number, old.finished == current.finished])
	old.free()
	current.free()
	quit(0)
