extends SceneTree
const Scene = preload("res://proto/siege/perf/results/t73/baseline_source/camera/siege_camera.tscn")
const CameraView = preload("res://proto/siege/perf/results/t73/baseline_source/camera/camera_view.gd")
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		printerr("CAMERA FAIL: " + description)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func run() -> void:
	var world = Scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	var view = CameraView.new()
	world.add_child(view)
	view.setup(world)
	view.set_process(false)
	var observer = world.camera_observer
	var coast: Vector3 = world.terrain.vec(world.params.strategies.deploy_points.main)
	check(view.can_view_deploy(coast), "初始海岸机位可在可见部署区投兵")
	var yaw: float = view.yaw
	view._unhandled_input(key(KEY_Q))
	view._unhandled_input(key(KEY_E))
	check(view.yaw == yaw, "固定模式 Q/E 不改变朝向")
	view._unhandled_input(key(KEY_2))
	check(view.active_zone == "highland" and view.moving, "数字键 2 选择高地并推移")
	check(not view.can_view_deploy(coast), "推移过程禁止部署")
	view._process(0.2)
	check(not view.moving and observer.current == "highland", "0.2 秒后抵达并确认当前战区")
	check(not view.can_view_deploy(coast), "高地机位不能在海岸部署")
	view.transition_style = "cut"
	view.select_zone("coast", "test")
	check(not view.moving and view.can_view_deploy(coast), "直切立即恢复海岸可部署状态")
	view.deploying = true
	world.manual_deploy_held = true
	view.set_overview(true)
	check(not view.deploying and not world.manual_deploy_held and not view.can_view_deploy(coast), "总览展开立即取消长按并禁止部署")
	view.set_overview(false)
	view.deploying = true
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	view._input(release)
	check(not view.deploying, "UI 消费事件前也能收到全局松开")
	view.select_zone("keep", "test")
	observer.on_hurt({"unit": world.units[0]})
	check(observer.latest.has("coast"), "离屏受伤触发战区提示")
	world.terrain.topology_events.append({"time": 1.0, "reason": "weak_wall_breached"})
	world.director.decisions.append({"event": "depart", "time": 2.0, "from": "keep", "to": "plaza"})
	world.zones.coast.captures.append(3.0)
	world.zones.coast.losses.append(4.0)
	observer.poll()
	check(observer.latest.has("plaza") and not observer.latest.has("keep"), "增援目的区闪烁，当前来源区无需离屏提醒")
	var kinds: Array = observer.alerts.map(func(a): return a.kind)
	for kind in ["attack", "reinforcement", "breach", "capture", "loss"]:
		check(kinds.has(kind), "提醒覆盖 " + kind)
	check(observer.latest.coast.kind == "loss", "重要状态不会被低优先级攻击提示覆盖")
	observer.on_hurt({"unit": world.units[0]})
	check(observer.latest.coast.kind == "loss", "受伤冷却及优先级保留失守提示")
	view.select_zone("coast", "test")
	check(not observer.latest.has("coast"), "跳转确认该战区所有待看提醒")
	world.director.decisions.append({"event": "depart", "time": 5.0, "from": "keep", "to": "plaza"})
	observer.poll()
	check(observer.latest.has("keep") and observer.latest.has("plaza"), "离屏增援来源和目的标签同时闪烁")
	view.select_zone("keep", "test")
	check(not observer.latest.has("keep") and observer.latest.has("plaza"), "查看来源不清除目的区的待看提醒")
	var count: int = observer.alerts.size()
	observer.poll()
	check(observer.alerts.size() == count, "只读历史游标不重复派发提醒")
	for id in view.IDS:
		view.select_zone(id, "test")
		var pose: Dictionary = view.cfg.zones[id]
		check(is_equal_approx(view.camera.size, float(pose.size)), "机位缩放 " + id)
		check(is_equal_approx(view.yaw, deg_to_rad(float(pose.yaw))), "机位朝向 " + id)
	view.mode = "continuous"
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20, 0)
	view.dragging = true
	yaw = view.yaw
	view._unhandled_input(motion)
	check(view.yaw != yaw, "连续对照仍支持拖动旋转")
	view.refresh()
	for u in world.units:
		if not view.sidesprites.has(u.id): continue
		var sprite: Sprite3D = view.sidesprites[u.id]
		check(is_equal_approx(sprite.position.y, u.nav_pos.y), "静止侧影脚底锚定单位地面高度")
		check(sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "侧影始终朝向镜头")
	view.free()
	world.free()
	print("CAMERA_FEATURES %s checks=deployment,transition,overview,alerts,poses,flip,grounding" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
