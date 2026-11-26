#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 "$TASK_ROOT/proto/siege/camera/verify_replay.py" "$@"
python3 "$TASK_ROOT/proto/siege/run_matrix.py" --verify "$@"
exit
