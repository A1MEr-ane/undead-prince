#!/usr/bin/env python3
"""T73 同机串行探针；baseline 使用开工时冻结在忽略目录内的源文件。"""
import argparse
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('probe', ROOT / 'proto/siege/perf/run_perf.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--scenarios', default='march,multi,melee,gate,breach,reinforce,cave,dawn,idle,camera')
    parser.add_argument('--units', default='100,200,300,500')
    parser.add_argument('--samples', type=int, default=300)
    parser.add_argument('--modes', default='sim,render')
    parser.add_argument('--render-timeout', type=float, default=600)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.baseline:
        probe.SCENE = 'proto/siege/perf/results/t73/baseline_source/perf/perf_runner.tscn'
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    rows = []
    for scenario in args.scenarios.split(','):
        for units in map(int, args.units.split(',')):
            for mode in args.modes.split(','):
                if scenario == 'camera' and mode == 'sim':
                    continue
                row = probe.run_one('godot', scenario, units, mode,
                                    probe.samples_for(scenario, units, args.samples),
                                    timeout=(args.render_timeout if mode == 'render' else 600), out_dir=args.out)
                rows.append(row)
                if not row.get('ok'):
                    print(json.dumps(row), flush=True)
                    return 1
                if row['active']['min'] < units - 2 or row['sample_sim_seconds'] <= 0:
                    raise RuntimeError(f'压力场景提前结束: {row["tag"]}')
                print(f'{row["tag"]} samples={row["samples"]} '
                      f'sim={row["sim_ms"]["p50"]} frame={row["frame_ms"].get("p50")} '
                      f'first={row.get("first_sim_ms")}', flush=True)
                (args.out / 'summary.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
    print(f'T73_PERF PASS runs={len(rows)}', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
