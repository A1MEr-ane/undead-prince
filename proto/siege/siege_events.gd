extends RefCounted
## 同步钩子；同一调用链中同名事件只派发一次，并限制跨事件深度。
const NAMES := ["spawn", "hurt", "near_death", "kill", "death", "resource_changed"]
var listeners := {}
var active: Array = []
var max_depth := 8
var suppressed := 0
var counts := {}

func subscribe(event: String, callback: Callable) -> void:
	assert(NAMES.has(event), "Unknown siege hook: " + event)
	if not listeners.has(event):
		listeners[event] = []
	listeners[event].append(callback)

func publish(event: String, payload: Dictionary) -> void:
	if active.has(event) or active.size() >= max_depth:
		suppressed += 1
		return
	active.append(event)
	counts[event] = counts.get(event, 0) + 1
	for callback in listeners.get(event, []).duplicate():
		callback.call(payload)
	active.pop_back()

func clear() -> void:
	listeners.clear()
