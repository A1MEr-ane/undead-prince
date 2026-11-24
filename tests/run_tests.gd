extends SceneTree
## 无头测试入口：godot --headless --path . -s tests/run_tests.gd
## 跑完 tests/test_agent_state.gd 的全部用例，有失败时退出码为 1。

const TestAgentState = preload("res://tests/test_agent_state.gd")


func _init() -> void:
	var suite = TestAgentState.new()
	var failed: int = suite.run_all()
	quit(1 if failed > 0 else 0)
