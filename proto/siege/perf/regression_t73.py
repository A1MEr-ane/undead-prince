#!/usr/bin/env python3
"""比较 T73 优化前后矩阵；战斗差异必须停止，诊断计数差异逐项列出。"""
import argparse
import json
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path)
    parser.add_argument('after', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    before = {(r['strategy'], r['seed']): r for r in map(json.loads, args.before.read_text().splitlines())}
    after = {(r['strategy'], r['seed']): r for r in map(json.loads, args.after.read_text().splitlines())}
    if before.keys() != after.keys():
        raise RuntimeError('对照策略/种子集合不等')
    rows = []
    bad = []
    for key in sorted(before):
        a, b = before[key], after[key]
        diff = {k: {'before': a.get(k), 'after': b.get(k)}
                for k in sorted(a.keys() | b.keys()) if a.get(k) != b.get(k)}
        material = {k: v for k, v in diff.items() if k not in {'params_sha256', 'flow_relaxed_cells', 'topology_events'}}
        if 'topology_events' in diff:
            clean = lambda values: [{k: v for k, v in e.items() if k != 'relaxed_cells'} for e in values]
            if clean(a['topology_events']) != clean(b['topology_events']):
                material['topology_events'] = diff['topology_events']
        rows.append({'strategy': key[0], 'seed': key[1], 'equal_battle_result': not material,
                     'differences': diff})
        if material:
            bad.append({'strategy': key[0], 'seed': key[1], 'fields': list(material)})
    report = {'pairs': len(rows), 'equal_battle_results': len(rows) - len(bad),
              'material_differences': bad, 'rows': rows}
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'T73_REGRESSION {"FAIL" if bad else "PASS"} pairs={len(rows)} battle_equal={len(rows)-len(bad)}')
    if bad:
        print('ESCALATE: ' + json.dumps(bad, ensure_ascii=False))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
