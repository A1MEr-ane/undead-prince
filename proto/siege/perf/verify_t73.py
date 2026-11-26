#!/usr/bin/env python3
"""优化机制检查，并将矩阵的确定性要求加强到逐字比较 SIEGE 行。"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('matrix', ROOT / 'proto/siege/run_matrix.py')
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)


def line(path):
    lines = [v for v in path.read_bytes().splitlines() if v.startswith(b'SIEGE ')]
    if len(lines) != 1:
        raise RuntimeError(f'缺少唯一 SIEGE 行: {path}')
    return lines[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--out', type=Path)
    parser.add_argument('--timeout', type=float, default=300)
    parser.add_argument('--start-seed', type=int, default=1)
    parser.add_argument('--seeds', '-n', type=int, default=20)
    parser.add_argument('--params', type=Path, default=matrix.DEFAULT_PARAMS)
    args = parser.parse_args()
    out = (args.out or ROOT / 'proto/siege/results/verify').resolve()
    output = matrix.execute(args.godot, ['--script', 'proto/siege/test_perf.gd'],
                            out / 'perf_features.log', args.timeout)
    if 'SIEGE_PERF_FEATURES PASS' not in output:
        raise RuntimeError('缺少优化机制通过标记')
    print('SIEGE_PERF_FEATURES PASS', flush=True)
    params = matrix.merged(json.loads(matrix.DEFAULT_PARAMS.read_text()),
                           json.loads(args.params.read_text()))
    count = 0
    for strategy in params['strategies']['names']:
        for seed in range(args.start_seed, args.start_seed + 2):
            base = out / f'{strategy}_{seed}.log'
            if line(base) != line(out / f'{strategy}_{seed}_repeat.log'):
                raise RuntimeError(f'逐字确定性不一致: {strategy}/{seed}')
            count += 1
    print(f'T73_BYTE_REPLAY PASS pairs={count}', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        print(f'T73_VERIFY FAIL: {error}', file=sys.stderr)
        sys.exit(1)
