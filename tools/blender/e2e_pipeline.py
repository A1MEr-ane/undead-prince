#!/usr/bin/env python3
"""T64 pipeline timing harness.

Runs the e2e sprite build, the isolated e2e validation, the fixed project
validation command, and (optionally) the Godot shader capture. Writes a
machine-readable timing report next to the e2e artifacts so T45 can compare
runs instead of relying on a hand-written estimate.

    python3 tools/blender/e2e_pipeline.py
    python3 tools/blender/e2e_pipeline.py --godot

Godot needs a desktop session for a real screenshot; --headless would produce
an empty capture. Without --godot the step is recorded as skipped.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / 'assets/sprites/e2e/undead_grunt.yml'
OUT = ROOT / 'assets/sprites/e2e'


def run_step(name, command, timeout=900):
    print(f'\n== {name}\n$ {" ".join(command)}', flush=True)
    started = time.monotonic()
    try:
        proc = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        seconds = round(time.monotonic() - started, 2)
        tail = [re.sub(r"/var/folders/[^\s']+", '<tmp>', line.replace(str(ROOT), '<repo>'))
                for line in (proc.stdout + proc.stderr).splitlines()[-8:]]
        print('\n'.join(tail), flush=True)
        record = dict(name=name, command=command, seconds=seconds, exit=proc.returncode,
                      output_tail=tail)
    except subprocess.TimeoutExpired as error:
        seconds = round(time.monotonic() - started, 2)
        print(f'TIMEOUT after {seconds}s', flush=True)
        record = dict(name=name, command=command, seconds=seconds, exit='timeout',
                      output_tail=(error.stdout or '')[-2000:])
    except OSError as error:
        seconds = round(time.monotonic() - started, 2)
        print(f'FAILED TO START: {error}', flush=True)
        record = dict(name=name, command=command, seconds=seconds, exit='spawn_error',
                      output_tail=str(error))
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', action='store_true', help='Also run the windowed Godot capture')
    parser.add_argument('--skip-build', action='store_true', help='Only run validation')
    args = parser.parse_args()

    blender = ['blender', '-b', '--factory-startup', '--python-exit-code', '1', '-P']
    steps = []
    if not args.skip_build:
        steps.append(run_step('build_e2e', blender + [
            'tools/blender/render_sprites.py', '--', '--spec', str(SPEC.relative_to(ROOT)),
            '--output', str(OUT.relative_to(ROOT)), '--supersample', '8']))
    steps.append(run_step('validate_e2e_only', blender + [
        'tools/blender/validate.py', '--', '--spec', str(SPEC.relative_to(ROOT)),
        '--output', str(OUT.relative_to(ROOT))]))
    steps.append(run_step('validate_fixed_suite',
                          blender + ['tools/blender/validate.py']))
    if args.godot:
        steps.append(run_step('godot_shader_capture',
                              ['godot', '--path', '.', '-s', 'assets/sprites/e2e/capture.gd']))
    else:
        steps.append(dict(name='godot_shader_capture', command=[], seconds=0, exit='skipped',
                          output_tail='Pass --godot in a desktop session to regenerate screenshots.'))

    failed = [step for step in steps if step['exit'] not in (0, 'skipped')]
    report = dict(task='T64', spec=str(SPEC.relative_to(ROOT)),
                  generated_at=time.strftime('%Y-%m-%dT%H:%M:%S%z'),
                  total_seconds=round(sum(step['seconds'] for step in steps), 2),
                  ok=not failed, steps=steps)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'pipeline_timing.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(f'\nPIPELINE {"PASS" if not failed else "FAIL"} total={report["total_seconds"]}s '
          f'-> {OUT / "pipeline_timing.json"}', flush=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
