#!/usr/bin/env python3
"""T74: 机制边界、等预算三种策略各三种子、重复回放及新分析基线。"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('matrix', ROOT / 'proto/siege/run_matrix.py')
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)


def siege_line(path):
    lines = [s for s in path.read_bytes().splitlines() if s.startswith(b'SIEGE ')]
    if len(lines) != 1:
        raise RuntimeError(f'缺少唯一结果行: {path}')
    return lines[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--out', type=Path)
    parser.add_argument('--timeout', type=float, default=300)
    parser.add_argument('--params', type=Path, default=matrix.DEFAULT_PARAMS)
    parser.add_argument('--start-seed', type=int, default=1)
    parser.add_argument('--seeds', '-n', type=int, default=20)
    args = parser.parse_args()
    parent = (args.out or ROOT / 'proto/siege/results/verify').resolve()
    out = parent / 't74'
    out.mkdir(parents=True, exist_ok=True)
    (out / '.gdignore').touch()
    output = matrix.execute(args.godot, ['--script', 'proto/siege/test_phase_b.gd'], out / 'features.log', args.timeout)
    if 'T74_FEATURES PASS' not in output:
        raise RuntimeError('缺少机制通过标记')
    print('T74_FEATURES PASS', flush=True)
    config = ROOT / 'proto/siege/params/phase_b.json'
    params = matrix.merged(json.loads(matrix.DEFAULT_PARAMS.read_text()), json.loads(config.read_text()))
    rows = []
    for strategy in ['assassin_first', 'giant_breach', 'prep_control']:
        for seed in range(1, 4):
            row = matrix.one(args.godot, strategy, seed, config, params, out, args.timeout)
            if row['schema_version'] != 3 or row['metrics_version'] != 'T74-movement-intent-v1':
                raise RuntimeError('未启用新分析口径')
            if sum(s['fire'] for s in row['unit_results'].values()) != row['fire_spent']:
                raise RuntimeError('分兵种费用不守恒')
            budget = params['phase_b']['total_budget']
            spent = row['fire_spent']
            if spent > budget or (spent < budget and not row['won']):
                raise RuntimeError(f'准备策略预算异常: {strategy}/{seed} spent={spent} budget={budget}')
            if strategy == 'assassin_first' and not row['assassination_events']:
                raise RuntimeError(f'刺客策略未完成刺杀: seed={seed}')
            if strategy == 'giant_breach' and row['structure_work']['wall_west']['breached_at'] < 0:
                raise RuntimeError(f'巨人策略未破墙: seed={seed}')
            rows.append(row)
            print(f'T74_SMOKE {strategy} seed={seed} spent={row["fire_spent"]} won={row["won"]} assassinations={len(row["assassination_events"])} breach={row["structure_work"]["wall_west"]["breached_at"]}', flush=True)
        matrix.one(args.godot, strategy, 1, config, params, out, args.timeout, '_repeat')
        if siege_line(out / f'{strategy}_1.log') != siege_line(out / f'{strategy}_1_repeat.log'):
            raise RuntimeError(f'阶段 B 回放不一致: {strategy}')
    (out / 'phase_b_results.jsonl').write_text(''.join(json.dumps(r, ensure_ascii=False, sort_keys=True) + '\n' for r in rows))
    config = ROOT / 'proto/siege/params/analysis_v2.json'
    params = matrix.merged(json.loads(matrix.DEFAULT_PARAMS.read_text()), json.loads(config.read_text()))
    rows = []
    for strategy in params['strategies']['names']:
        row = matrix.one(args.godot, strategy, 1, config, params, out, args.timeout, '_analysis')
        rows.append(row)
    (out / 'analysis_baseline.jsonl').write_text(''.join(json.dumps(r, ensure_ascii=False, sort_keys=True) + '\n' for r in rows))
    print('T74_VERIFY PASS strategies=3 seeds=3 repeats=3 analysis_baseline=6', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        print(f'T74_VERIFY FAIL: {error}', file=sys.stderr)
        sys.exit(1)
