#!/usr/bin/env python3
"""生成 T77 的参数覆盖文件；只写 proto/siege/params/，不改原型代码。"""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PARAMS = ROOT / "proto/siege/params"
BASE = json.loads((ROOT / "proto/siege/siege_params.json").read_text())
ANALYSIS = json.loads((PARAMS / "analysis_v2.json").read_text())
PHASE_B = json.loads((PARAMS / "phase_b.json").read_text())

OLD = ["main_gate", "highland", "feint", "waves", "idle", "late_batches"]
NEW = ["assassin_first", "giant_breach"]
PREP = ["assassin_first", "giant_breach", "prep_control"]


def merge(base, overlay):
    out = copy.deepcopy(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = merge(out[key], value)
        else:
            out[key] = copy.deepcopy(value)
    return out


def write(name, data):
    path = PARAMS / name
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(path.relative_to(ROOT))


def old_file(name, overlay):
    data = merge(ANALYSIS, overlay)
    data.setdefault("strategies", {})["names"] = OLD
    write(name, data)


def prep_file(name, overlay, names):
    data = merge(PHASE_B, overlay)
    data["strategies"]["names"] = names
    write(name, data)


BEST = {
    "default": {},
    "best01": {
        "targeting": {"values": {"archer": 10, "gate": 2, "weak": 2.3, "zone": 2.5, "keep": 5}},
    },
    "best02": {
        "targeting": {"values": {"archer": 10, "gate": 2, "weak": 2.3, "zone": 2.5, "keep": 5}},
        "combat": {"separation_radius": 0.8, "max_separation_speed": 2.0},
    },
    "best03": {
        "targeting": {"values": {"archer": 10, "gate": 2, "weak": 2.3, "zone": 2.5, "keep": 5}},
        "structures": {"weak_hp": 16},
        "combat": {"separation_radius": 0.8, "max_separation_speed": 2.0},
    },
}

for label, overlay in BEST.items():
    old_file(f"t77_old_{label}.json", overlay)
    prep_file(f"t77_prep_{label}.json", overlay, NEW)

# 阶段 B 三组等预算对照：完全沿用 T74 的 phase_b.json 默认配置。
prep_file("t77_phaseb_compare.json", {}, PREP)

# 目标 3：同路线、只切换 archer_focus_by_strategy；两臂都固定 archer=10、禁用改道。
for route, strategy in [("main", "main_gate"), ("side", "highland")]:
    for focus in (True, False):
        data = merge(ANALYSIS, {
            "targeting": {
                "values": {"archer": 10, "gate": 2, "weak": 2.3, "zone": 2.5, "keep": 5},
                "max_reroutes": 0,
            },
            "strategies": {
                "names": [strategy],
                "route_by_strategy": {strategy: route},
                "archer_focus_by_strategy": {strategy: focus},
            },
        })
        write(f"t77_focus_{route}_{'on' if focus else 'off'}.json", data)
