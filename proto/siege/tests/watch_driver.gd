extends Node
## T80 窗口回放驱动；复用 proto/siege/siege_view.gd 的镜头、HUD 和遮挡表现。

const View = preload("res://proto/siege/siege_view.gd")

var scenario
var view
var accumulator := 0.0
var speed := 1.0
var printed := false
var frame_guard := 0


func start(s, argv: Dictionary) -> void:
	scenario = s
	speed = maxf(0.1, float(argv.get("speed", "1")))
	view = View.new()
	add_child(view)
	scenario.w.view = view
	view.setup(scenario.w)
	var win := get_window()
	if win != null:
		win.title = "T80 · %s · %s" % [scenario.label, scenario.title]
	print("T80 WATCH loaded %s" % scenario.label)


func _process(delta: float) -> void:
	if scenario == null or scenario.w == null:
		return
	var step := float(scenario.w.params.simulation.step)
	if not scenario.done:
		accumulator += minf(delta, 0.25) * speed
		var guard := 0
		while accumulator >= step and guard < 240 and not scenario.done:
			scenario.w.simulate()
			scenario.observe()
			accumulator -= step
			guard += 1
		scenario.maybe_finish()
	if view != null:
		view.refresh(clampf(accumulator / step, 0.0, 1.0))
	if scenario.done and not printed:
		printed = true
		scenario.print_result()
		print("T80 WATCH %s finished; 窗口保持打开，关闭退出。" % scenario.label)


func _exit_tree() -> void:
	if scenario != null:
		scenario.dispose()
		scenario = null
	view = null
