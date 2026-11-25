#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$TASK_ROOT"
for strategy in main_gate highland feint waves idle; do
  "${GODOT:-godot}" --path . proto/siege/siege.tscn -- --capture --strategy="$strategy" --seed=1 "$@"
done
exit
