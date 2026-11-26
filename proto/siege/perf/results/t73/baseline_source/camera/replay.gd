extends SceneTree
## 在无渲染窗口的环境构造真实显示节点；固定步长模拟与显示 delta 独立推进。
const Scene = preload("res://proto/siege/perf/results/t73/baseline_source/camera/siege_camera.tscn")
const CameraView = preload("res://proto/siege/perf/results/t73/baseline_source/camera/camera_view.gd")

func _initialize() -> void:
	call_deferred("run")

func first_float_difference(a, b, path: String = "") -> String:
	if a is Dictionary and b is Dictionary:
		for key in a:
			var difference := first_float_difference(a[key], b[key], path + "." + str(key))
			if not difference.is_empty(): return difference
	elif a is Array and b is Array:
		for i in a.size():
			var difference := first_float_difference(a[i], b[i], path + "[%d]" % i)
			if not difference.is_empty(): return difference
	elif (a is float or a is int) and (b is float or b is int) and a != b:
		return "%s raw=%.17f parsed=%.17f" % [path, a, b]
	return ""

func run() -> void:
	var world = Scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	# 所有回放参数由同一个启动命令传入，禁止隐式拿 waves 与 feint 基线对比。
	var view = CameraView.new()
	world.add_child(view)
	view.setup(world)
	world.view = view
	view.set_process(false)
	var refreshes := 0
	var delta_pattern := [1.0 / 144, 1.0 / 20, 0.2, 1.0 / 60]
	var last_zone := -1
	while not world.finished:
		if world.step_number > ceili((float(world.params.simulation.night_seconds) + float(world.params.retreat.boat_depart_seconds) + float(world.params.retreat.boat_sail_seconds) + 1) / float(world.params.simulation.step)):
			printerr("CAMERA_REPLAY FAIL: 未在夜长及撤退时限内结束")
			world.free()
			quit(1)
			return
		var index := floori(world.time / 15) % 4
		if index != last_zone:
			last_zone = index
			view.transition_style = "slide" if index % 2 == 0 else "cut"
			view.select_zone(view.IDS[index], "test_replay")
		var delta: float = delta_pattern[world.step_number % delta_pattern.size()]
		view._process(delta)
		if view.mode == "continuous":
			view.yaw += delta * 0.3
			view.update_camera()
		# 同时覆盖全屏总览和定期插值刷新；只改显示状态。
		if world.step_number % 127 == 0:
			view.set_overview(not view.expanded)
		world.simulate()
		if world.step_number % 3 == 0 or world.finished:
			view.refresh(float(world.step_number % 7) / 6)
			refreshes += 1
	var result: Dictionary = world.result()
	var serialized := JSON.stringify(result)
	# 诊断旧检查：内存中的 double 与 JSON 往返后的数值不能用 Dictionary == 验收。
	var parsed: Dictionary = JSON.parse_string(serialized)
	var fields: Array = []
	for field in result:
		if result[field] != parsed[field]: fields.append(field)
	print("CAMERA_ROUNDTRIP " + JSON.stringify({"raw_dictionary_equal": result == parsed, "reserialized_equal": serialized == JSON.stringify(parsed), "raw_different_fields": fields, "first_float_difference": first_float_difference(result, parsed)}))
	print("CAMERA_REPLAY mode=%s seed=%d strategy=%s steps=%d refreshes=%d switches=%d" % [view.mode, world.seed_value, world.strategy, world.step_number, refreshes, world.camera_observer.switches.size()])
	print("SIEGE " + serialized)
	world.free()
	quit()
