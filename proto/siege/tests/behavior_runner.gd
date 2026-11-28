extends SceneTree
## T80 行为场景入口。
## 无头：godot --headless --path . --script res://proto/siege/tests/behavior_runner.gd -- --scenario=B01
## 回放：godot --path . --script res://proto/siege/tests/behavior_runner.gd -- --scenario=B01 --watch

const B01 = preload("res://proto/siege/tests/scenarios/b01_no_standing.gd")
const B02 = preload("res://proto/siege/tests/scenarios/b02_gate_crowd.gd")
const B03 = preload("res://proto/siege/tests/scenarios/b03_closed_wall.gd")
const B04 = preload("res://proto/siege/tests/scenarios/b04_giant_breach.gd")
const B05 = preload("res://proto/siege/tests/scenarios/b05_assassin_highland.gd")
const B06 = preload("res://proto/siege/tests/scenarios/b06_dispatch_ratio.gd")
const B07 = preload("res://proto/siege/tests/scenarios/b07_mission_lock.gd")
const B08 = preload("res://proto/siege/tests/scenarios/b08_archer_melee.gd")
const B09 = preload("res://proto/siege/tests/scenarios/b09_rally.gd")
const B10 = preload("res://proto/siege/tests/scenarios/b10_retreat_route.gd")
const B11 = preload("res://proto/siege/tests/scenarios/b11_cave_permission.gd")
const B12 = preload("res://proto/siege/tests/scenarios/b12_clash_parry.gd")

const WATCH_DRIVER = preload("res://proto/siege/tests/watch_driver.gd")

const TABLE := {
	"B01": {"script": B01, "title": "1 亡魂 vs 1 盾兵：3 秒内接战，无站立超时", "seconds": 8.0},
	"B02": {"script": B02, "title": "10 亡魂挤过城门：不永久卡死，有其他路时改道", "seconds": 14.0},
	"B03": {"script": B03, "title": "城门关闭、墙未破：不穿墙，等待或改道", "seconds": 12.0},
	"B04": {"script": B04, "title": "巨人破可破墙：走到墙下、持续攻击、破口后通行", "seconds": 18.0},
	"B05": {"script": B05, "title": "刺客对高地弓兵：走崖壁、先杀弓兵、不纠缠盾兵", "seconds": 18.0},
	"B06": {"script": B06, "title": "小股佯攻：派兵与威胁成比例，其他战区保留最低驻防", "seconds": 4.0},
	"B07": {"script": B07, "title": "威胁阈值附近波动：任务锁定，不来回调动", "seconds": 20.0},
	"B08": {"script": B08, "title": "弓兵被近身：后撤或换近战，不站着被砍", "seconds": 6.0},
	"B09": {"script": B09, "title": "集结指令：2 秒内转向，到达后恢复自主", "seconds": 24.0},
	"B10": {"script": B10, "title": "攻占主堡：剩余守军走最短路去港口，不反击", "seconds": 12.0},
	"B11": {"script": B11, "title": "山洞权限：只有有权限的单位能走，容量满时排队", "seconds": 10.0},
	"B12": {"script": B12, "title": "拼刀和格挡：按规格第 7 节触发，进度差取绝对值", "seconds": 1.0},
}

var args := {}
var selected: Array = []
var strict := false


func _initialize() -> void:
	call_deferred("run")


func parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	strict = args.has("strict")
	if args.has("scenario"):
		for id in str(args.scenario).split(",", false):
			selected.append(id.strip_edges().to_upper())
	elif args.has("all"):
		selected = TABLE.keys()
	else:
		selected = TABLE.keys()


func run() -> void:
	parse_args()
	if args.has("list"):
		for id in TABLE:
			print("%s  %s" % [id, TABLE[id].title])
		quit(0)
		return
	if selected.is_empty():
		printerr("没有选中场景。用 --scenario=B01 或 --all。")
		quit(2)
		return
	for id in selected:
		if not TABLE.has(id):
			printerr("未知场景: " + id)
			quit(2)
			return
	if args.has("watch"):
		if selected.size() != 1:
			printerr("--watch 一次只能回放一个场景，请用 --scenario=Bxx。")
			quit(2)
			return
		start_watch(selected[0])
		return
	run_headless()


func run_headless() -> void:
	print("T80 behavior scenarios · %d selected · headless" % selected.size())
	var failed := 0
	for id in selected:
		var info: Dictionary = TABLE[id]
		var scenario = info.script.new()
		scenario.configure(id, info.title, float(info.seconds), args)
		scenario.run_headless()
		scenario.print_result()
		if not scenario.failures.is_empty():
			failed += 1
		scenario.dispose()
	print("T80 SUMMARY: %d passed, %d failed, %d total" % [selected.size() - failed, failed, selected.size()])
	if strict and failed > 0:
		quit(1)
	else:
		quit(0)


func start_watch(id: String) -> void:
	var info: Dictionary = TABLE[id]
	var scenario = info.script.new()
	scenario.configure(id, info.title, float(info.seconds), args)
	scenario.build()
	if scenario.w == null:
		printerr("场景未能建立模拟世界")
		quit(2)
		return
	var driver = WATCH_DRIVER.new()
	root.add_child(driver)
	driver.start(scenario, args)
	print("T80 WATCH %s · %s" % [id, info.title])
	print("窗口回放中；关闭窗口退出。可用 --speed=2 加速。")
