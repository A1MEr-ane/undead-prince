#!/usr/bin/env python3
"""把 T71 的 summary.json / T71.jsonl 汇总成报告用 Markdown 表格。"""
import argparse
import json
from pathlib import Path
import sys


def load(path):
    path = Path(path)
    if path.suffix == ".jsonl":
        return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    data = json.loads(path.read_text())
    return data.get("rows", data) if isinstance(data, dict) else data


def ms(d, key):
    if not d:
        return "—"
    v = d.get(key)
    return "—" if v is None else f"{v:.2f}"


def table(rows, mode, title):
    group = [r for r in rows if r.get("mode") == mode and r.get("ok", True)]
    if not group:
        return []
    head = ["场景", "单位", "样本", "模拟时长 s", "活跃", "P50 ms", "P95 ms", "P99 ms", "最大 ms"]
    if mode == "render":
        head += ["绘制调用 P50", ">16.7 ms"]
    out = [f"### {title}", "", "| " + " | ".join(head) + " |", "|" + "|".join(["---"] * len(head)) + "|"]
    for r in sorted(group, key=lambda x: (x["scenario"], x["units_target"])):
        sim = r.get("sim_ms") or {}
        met = r.get("frame_ms") if mode == "render" else sim
        if not met:
            continue
        active = r.get("active", {})
        row = [
            r["scenario"], str(r["units_target"]), str(r.get("samples", "")),
            f"{r.get('sample_sim_seconds', 0):.1f}",
            f"{active.get('min', '?')}–{active.get('max', '?')}",
            ms(met, "p50"), ms(met, "p95"), ms(met, "p99"), ms(met, "max"),
        ]
        if mode == "render":
            dc = r.get("draw_calls") or {}
            row += [str(dc.get("p50", "—")), str(r.get("frames_over_16_7", "—"))]
        out.append("| " + " | ".join(row) + " |")
    return out + [""]


def phase_table(rows):
    group = [r for r in rows if r.get("phase_mode") and r.get("ok", True)]
    if not group:
        return []
    keys = ["orders", "sense_nearby", "unit_tick_move_combat", "captures", "spatial_build_1",
            "spatial_build_2", "structures", "director", "regenerate"]
    out = ["### 模拟阶段拆分（无损子类，每步均值）", "",
           "| 场景 | 单位 | 总 sim P50 ms | " + " | ".join(keys) + " | 寻路/流场 |",
           "|---|---:|---:|" + "|".join(["---:"] * len(keys)) + "|---|"]
    for r in sorted(group, key=lambda x: (x["scenario"], x["units_target"])):
        ph = r.get("phase", {})
        ms_ = r.get("map_stat", {})
        vals = [f"{ph.get(k, {}).get('mean_ms', 0):.3f}" for k in keys]
        path = (f"dir {ms_.get('direction_calls', 0)} / {ms_.get('direction_us', 0)/1000:.1f} ms; "
                f"field {ms_.get('field_builds', 0)} builds; change {ms_.get('change_calls', 0)} / {ms_.get('change_us', 0)/1000:.1f} ms")
        out.append(f"| {r['scenario']} | {r['units_target']} | {ms(r.get('sim_ms') or {}, 'p50')} | " +
                   " | ".join(vals) + f" | {path} |")
    return out + [""]


def hashes(rows):
    group = {}
    for r in rows:
        if r.get("ok", True):
            group.setdefault((r["scenario"], r["units_target"]), {})[r["mode"]] = r.get("state_hash")
    out = ["### 无头/窗口同事件序列校验", "", "| 场景 | 单位 | sim hash | render hash | 一致 |", "|---|---:|---|---|---|"]
    for (sc, u), m in sorted(group.items()):
        if "sim" in m and "render" in m:
            same = m["sim"] == m["render"]
            out.append(f"| {sc} | {u} | `{str(m['sim'])[:12]}` | `{str(m['render'])[:12]}` | {'是' if same else '**否**'} |")
    return out + [""]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", help="summary.json 或 T71.jsonl")
    args = parser.parse_args()
    rows = []
    for p in args.paths:
        rows.extend(load(p))
    if not rows:
        print("no rows", file=sys.stderr)
        return 1
    env = next((r.get("environment") for r in rows if r.get("environment")), {})
    print("## 环境", "", json.dumps(env, ensure_ascii=False, indent=2), "")
    for part in table(rows, "render", "窗口完整帧") + table(rows, "sim", "无头模拟（每帧 2 步）") + hashes(rows) + phase_table(rows):
        print(part)
    return 0


if __name__ == "__main__":
    sys.exit(main())
