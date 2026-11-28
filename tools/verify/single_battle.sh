#!/usr/bin/env bash
set -euo pipefail

TASK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
RUNNER=res://attempts/single_battle/tests/behavior_runner.gd

for arg in "$@"; do
	if [[ "$arg" == "--watch" ]]; then
		exec "$GODOT" --path "$TASK_ROOT" --rendering-method gl_compatibility --script "$RUNNER" -- "$@"
	fi
done
if [[ "$#" -gt 0 ]]; then
	exec "$GODOT" --headless --path "$TASK_ROOT" --script "$RUNNER" -- --strict "$@"
fi

python3 - "$TASK_ROOT" "$GODOT" "$RUNNER" <<'PY'
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

root, godot, runner = sys.argv[1:]
scene = 'res://attempts/single_battle/main.tscn'
prefix = b'SINGLE_BATTLE '


def run(log_dir, name, *args):
    command = [godot, '--headless', '--path', root, '--log-file', str(log_dir / (name + '.log')), *args]
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    except subprocess.TimeoutExpired as error:
        print((error.stdout or b'').decode(errors='replace'), file=sys.stderr)
        sys.exit(f'T86 FAIL: {name} timed out')
    lines = result.stdout.splitlines()
    errors = [line for line in lines if b'ERROR:' in line and b'Condition "ret != noErr"' not in line]
    if result.returncode != 0 or errors:
        print(result.stdout.decode(errors='replace'), file=sys.stderr)
        sys.exit(f'T86 FAIL: {name}, exit {result.returncode}')
    return lines


with tempfile.TemporaryDirectory(prefix='single-battle-') as directory:
    logs = Path(directory)
    behavior = run(logs, 'behavior', '--script', runner, '--', '--all', '--strict')
    for line in behavior:
        if line.startswith((b'PASS ', b'T86 SUMMARY:')):
            print(line.decode())
    if b'T86 SUMMARY: 17 passed, 0 failed, 17 total' not in behavior:
        sys.exit('T86 FAIL: behavior summary missing or incomplete')

    presentation = run(logs, 'presentation', '--script', 'res://attempts/single_battle/tests/presentation.gd')
    summary_sign = b'T86 PRESENTATION:'
    summary = [line for line in presentation if line.startswith(summary_sign)]
    if len(summary) != 1:
        sys.exit('T86 FAIL: presentation summary missing')
    print(summary[0].decode())

    replays = []
    for attempt in (1, 2):
        output = run(logs, f'replay-{attempt}', scene, '--', '--strategy=mixed', '--seed=7')
        records = [line for line in output if line.startswith(prefix)]
        if len(records) != 1:
            sys.exit(f'T86 FAIL: replay {attempt} emitted {len(records)} result records')
        replays.append(records[0])
    if replays[0] != replays[1]:
        sys.exit('T86 FAIL: same seed produced different SINGLE_BATTLE records')
    result = json.loads(replays[0][len(prefix):])
    kinds = ('ghost', 'assassin', 'giant', 'lich')
    if result['outcome'] not in ('WON', 'LOST') or not all(result['unit_results'][kind]['deployed'] for kind in kinds):
        sys.exit('T86 FAIL: mixed replay did not finish or did not deploy all four undead kinds')
    digest = hashlib.sha256(replays[0]).hexdigest()
    print(f"T86 DETERMINISM: seed 7, {result['outcome']} at {result['ended_at']}s, SHA-256 {digest}")
PY

exit 0
