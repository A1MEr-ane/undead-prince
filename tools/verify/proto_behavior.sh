#!/usr/bin/env bash
# T80 行为场景 B01–B12。默认逐条打印 PASS/FAIL，退出码保持 0；
# 加 --strict 时只要有 FAIL 就返回 1。--watch 打开窗口回放单个场景。
set -uo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"

WATCH=0
for arg in "$@"; do
	if [[ "$arg" == "--watch" ]]; then
		WATCH=1
	fi
done

if [[ "$WATCH" -eq 1 ]]; then
	exec "$GODOT" --path "$TASK_ROOT" --script res://proto/siege/tests/behavior_runner.gd -- "$@"
else
	exec "$GODOT" --headless --path "$TASK_ROOT" --script res://proto/siege/tests/behavior_runner.gd -- "$@"
fi
