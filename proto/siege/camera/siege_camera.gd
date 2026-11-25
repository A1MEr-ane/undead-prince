extends "res://proto/siege/siege.gd"
## 独立入口，仅替换展示层；模拟、输入队列和调度沿用原实现。
const CameraView = preload("res://proto/siege/camera/camera_view.gd")
const Observer = preload("res://proto/siege/camera/observer.gd")
var camera_observer

func _ready() -> void:
	super._ready()
	if params.is_empty():
		return
	camera_observer = Observer.new()
	camera_observer.setup(self)
	if not headless:
		remove_child(view)
		view.free()
		view = CameraView.new()
		add_child(view)
		view.setup(self)

func _process(delta: float) -> void:
	super._process(delta)
	if camera_observer == null:
		return
	camera_observer.poll()
	if result_printed and not camera_observer.saved:
		camera_observer.save(args.get("camera_out", "res://shots/t70/" + camera_observer.mode))

func _exit_tree() -> void:
	if camera_observer != null:
		camera_observer.world = null
	super._exit_tree()
