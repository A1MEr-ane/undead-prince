#!/usr/bin/env python3
"""从 git 版本重建 T73 只读基线；仅写 perf/results 内的忽略目录。"""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
DEFAULT_REF = 'a058daa4737fab9cfc2cd12775bf487c1e8b498f'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ref', default=DEFAULT_REF)
    args = parser.parse_args()
    dest = ROOT / 'proto/siege/perf/results/t73/baseline_source'
    if dest.exists():
        raise SystemExit(f'基线目录已存在；先归档旧结果再重建: {dest}')
    prefix = 'res://proto/siege/perf/results/t73/baseline_source/'
    files = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', args.ref,
                                     '--', 'proto/siege'], cwd=ROOT, text=True).splitlines()
    for name in files:
        p = Path(name)
        if p.parent != Path('proto/siege') or p.suffix not in ('.gd', '.tscn', '.json'):
            continue
        content = subprocess.check_output(['git', 'show', f'{args.ref}:{name}'], cwd=ROOT, text=True)
        out = dest / p.relative_to('proto/siege')
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(content.replace('res://proto/siege/', prefix))
    # 采用修正后的 T71 驱动，只跳过压力场景的结算；模拟仍来自指定 git 版本。
    for name in ('perf_world.gd', 'perf_runner.gd', 'perf_runner.tscn'):
        content = (ROOT / 'proto/siege/perf' / name).read_text()
        if name == 'perf_runner.gd':
            content = content.replace('perf/perf_siege.gd', 'perf/perf_world.gd')
        out = dest / 'perf' / name
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(content.replace('res://proto/siege/', prefix))
    print(f'T73_BASELINE ref={args.ref} path={dest}')


if __name__ == '__main__':
    main()
