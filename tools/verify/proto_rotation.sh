#!/bin/bash
set -eu
cd "$(dirname "$0")/../.."
export T49_ROOT="$PWD"
python3 - "$@" <<'PY'
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import sys

root = Path(os.environ['T49_ROOT'])
project = root / 'proto/rotation'
evidence = project / 'evidence'
evidence.mkdir(exist_ok=True)
godot = os.environ.get('GODOT', 'godot')
# This stateless scene never writes user://; logs have explicit local paths.
# In the macOS sandbox, reuse the existing unnamed data directory read-only.
# Do not launch the editor, which would attempt to save shared editor settings.
if sys.platform == 'darwin' and (Path.home() / 'Library/Application Support/Godot/app_userdata/[unnamed project]').is_dir():
    (project / 'override.cfg').write_text('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="Godot/app_userdata/[unnamed project]"\n')
checks = []

def run(name, arguments, timeout=90):
    command = [godot, '--path', str(project), '--log-file', str(evidence / (name + '-engine.log')), *arguments]
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    log = result.stdout + result.stderr
    (evidence / (name + '.log')).write_text(log)
    errors = re.findall(r'^.*(?:SCRIPT ERROR|SHADER ERROR|Parse Error|ERROR:|Assertion failed).*$', log, re.M)
    # macOS certificate messages are environmental, not Godot script failures.
    errors = [x for x in errors if 'certificate' not in x.lower() and 'ret != noErr' not in x]
    if result.returncode or errors:
        raise RuntimeError(f'{name}: exit={result.returncode}\n' + '\n'.join(errors[:15]) + '\n' + log[-3000:])
    return log

try:
    for script in ['sprite_factory.gd', 'unit.gd', 'effects.gd', 'main.gd']:
        run('parse-' + script, ['--headless', '--check-only', '--script', 'res://' + script])
    log = run('headless', ['--headless', '--max-fps', '120', '--', '--orbit=6', '--units=200', '--seconds=2'])
    rows = [json.loads(x) for x in re.findall(r'^PERF (.*)$', log, re.M)]
    assert {r['mode'] for r in rows} == {'render', 'move'}, 'missing render/move metrics'
    for row in rows:
        assert row['units'] == 200 and row['samples'] >= 40
        assert all(math.isfinite(row[k]) and row[k] > 0 for k in ['mean_ms', 'p95_ms', 'p99_ms'])
        assert row['p99_ms'] >= row['p95_ms']
        print('PERF ' + json.dumps(row))
    orbit = json.loads(re.search(r'^ORBIT (.*)$', log, re.M)[1])
    assert orbit['max_yaw_deg'] > 650 and orbit['reversed'], 'two turns/reverse not observed'
    assert abs(orbit['target_turns'] - 1) < 0.01, 'orbit did not finish'
    assert orbit['impacts'] > 0, 'no projectile impacts'
    assert 'CHECKS damping_30_60=ok' in log and '"ok":true' in log
    checks.append({'check': 'headless_orbit_and_200_units', 'ok': True, 'orbit': orbit, 'metrics': rows})
    print('[PASS] headless two turns + reverse; frame metrics for render/move')
    shots = root / 'shots/t49'
    if '--screenshots' in sys.argv:
        run('screenshots', ['--', '--shots', '--units=50', '--out=' + str(shots)], timeout=120)
    manifest_path = shots / 'manifest.json'
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        expected = {f'azimuth_{a:03}.png' for a in range(0, 360, 45)} | {f'continuous_{f:02}.png' for f in range(20)}
        assert manifest['count'] == 28 and {r['file'] for r in manifest['shots']} == expected
        for name in expected:
            data = (shots / name).read_bytes()
            assert data[:8] == b'\x89PNG\r\n\x1a\n' and len(data) > 10000, f'invalid image {name}'
            assert struct.unpack('>II', data[16:24]) == (1280, 720)
        static = [s for s in manifest['shots'] if s['kind'] == 'static']
        assert all(abs(s['yaw_deg'] - a) < .001 for s, a in zip(static, range(0, 360, 45)))
        sequence = [s for s in manifest['shots'] if s['kind'] == 'continuous']
        assert all(abs((b['sample_s'] - a['sample_s']) - .1) < .00001 for a, b in zip(sequence, sequence[1:]))
        assert all(0 < b['yaw_deg'] - a['yaw_deg'] < 25 for a, b in zip(sequence, sequence[1:])), 'camera discontinuity'
        checks.append({'check': 'screenshots', 'ok': True, 'count': 28, 'path': str(shots)})
        print('[PASS] screenshots 8 azimuths + 20 continuous frames at 1280x720')
    else:
        checks.append({'check': 'screenshots', 'ok': True, 'skipped': True, 'reason': 'headless verification; run with --screenshots on a windowed display'})
        print('[SKIP] screenshots: headless run; use --screenshots for window capture')
    (evidence / 'verify.json').write_text(json.dumps({'ok': True, 'checks': checks}, indent=2))
except (AssertionError, RuntimeError, subprocess.TimeoutExpired) as error:
    (evidence / 'verify.json').write_text(json.dumps({'ok': False, 'error': str(error), 'checks': checks}, indent=2))
    print('[FAIL] ' + str(error), file=sys.stderr)
    sys.exit(1)
PY
exit
