extends RefCounted
## T60：批量模拟/汇总工具的自测入口。
## 实际断言在 tools/sim/test_summarize.py（Python unittest）；这里只负责把它接进
## `godot --headless --path . -s tests/run_tests.gd`，失败时返回非零。

const TEST_SCRIPT := "res://tools/sim/test_summarize.py"


func run_all() -> int:
	print("Sim 工具测试（T60：batch/summarize/异常判定）")
	if not FileAccess.file_exists(TEST_SCRIPT):
		print("[FAIL] 找不到 " + TEST_SCRIPT)
		print("=== Sim 工具结果：失败 ===")
		return 1
	var script_path := ProjectSettings.globalize_path(TEST_SCRIPT)
	var output: Array = []
	var code := OS.execute("python3", [script_path], output, true)
	for chunk in output:
		var text := String(chunk).rstrip("\n")
		if not text.is_empty():
			print(text)
	if code != 0:
		print("[FAIL] summarize 自测失败（python3 退出码 %d）" % code)
		print("=== Sim 工具结果：失败 ===")
		return 1
	print("=== Sim 工具结果：通过（Python 自测全部通过）===")
	return 0
