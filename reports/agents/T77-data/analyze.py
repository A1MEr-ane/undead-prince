#!/usr/bin/env python3
"""汇总 T77 样本；只读 results/，写 reports/agents/T77-data/summary.json。"""
import json
import math
from collections import Counter, defaultdict
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parents[3]
RES = ROOT / "proto/siege/results/t77"
OUT = ROOT / "reports/agents/T77-data/summary.json"

OLD = ["main_gate", "highland", "feint", "waves", "idle", "late_batches"]
NEW = ["assassin_first", "giant_breach"]
GROUPS = ["default", "best01", "best02", "best03"]


def load(path):
    file = Path(path)
    if not file.exists():
        return []
    return [json.loads(line) for line in file.read_text().splitlines() if line.strip()]


def wilson(k, n, z=1.96):
    if n == 0:
        return [None, None]
    p = k / n
    den = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / den
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return [max(0.0, centre - half), min(1.0, centre + half)]


def mean(rows, fn):
    vals = [fn(r) for r in rows]
    return statistics.mean(vals) if vals else None


def median(rows, fn):
    vals = [fn(r) for r in rows]
    return statistics.median(vals) if vals else None


def pct(value):
    return None if value is None else round(value * 100, 1)


def deployed(row):
    return row["spawned"]["ghost"] + row["spawned"]["defender"]


def congestion(row):
    return row["congestion_events"] / max(1, deployed(row))


def travel(row):
    return row["travel_congestion_events"] / max(1, deployed(row))


def route_counts(rows):
    out = defaultdict(int)
    for row in rows:
        for route, rec in row.get("route_choice_distribution", {}).items():
            out[route] += int(rec.get("deployed", 0))
    return dict(sorted(out.items()))


def phase_peak(rows, phase, side):
    vals = []
    for row in rows:
        peaks = row.get("phase_live_peaks", {})
        if phase in peaks:
            vals.append(peaks[phase].get(side, 0))
    return mean(vals, lambda x: x)


def mcnemar(b, c):
    n = b + c
    if n == 0:
        return 1.0
    k = min(b, c)
    tail = sum(math.comb(n, i) for i in range(k + 1)) / (2 ** n)
    return min(1.0, 2 * tail)


def describe(rows):
    n = len(rows)
    wins = [r for r in rows if r["won"]]
    methods = Counter(r["victory_method"] for r in wins)
    ann = [r for r in wins if r["victory_method"] == "annihilation"]
    cap = [r for r in wins if r["victory_method"] == "keep_retreat"]
    early = [r["early_archer_kills"] for r in rows]
    return {
        "n": n,
        "wins": len(wins),
        "rate": round(len(wins) / n, 4) if n else None,
        "ci95": [round(x, 4) for x in wilson(len(wins), n)] if n else [None, None],
        "methods": dict(methods),
        "annihilation": len(ann),
        "capture": len(cap),
        "victory_time_mean": round(mean(wins, lambda r: r["victory_time"]), 3) if wins else None,
        "victory_time_median": round(median(wins, lambda r: r["victory_time"]), 3) if wins else None,
        "capture_time_mean": round(mean(cap, lambda r: r["victory_time"]), 3) if cap else None,
        "casualties_ghost": round(mean(rows, lambda r: r["casualties"]["ghost"]), 3),
        "casualties_defender": round(mean(rows, lambda r: r["casualties"]["defender"]), 3),
        "fire_spent": round(mean(rows, lambda r: r["fire_spent"]), 3),
        "fire_wasted": round(mean(rows, lambda r: r["fire_wasted"]), 3),
        "deployed": round(mean(rows, deployed), 3),
        "congestion_mean": round(mean(rows, congestion), 4),
        "congestion_median": round(median(rows, congestion), 4),
        "congestion_max": round(max(congestion(r) for r in rows), 4) if rows else None,
        "congestion_over_05": sum(congestion(r) > 0.5 for r in rows),
        "congestion_events": round(mean(rows, lambda r: r["congestion_events"]), 3),
        "travel_mean": round(mean(rows, travel), 4),
        "travel_events": round(mean(rows, lambda r: r["travel_congestion_events"]), 3),
        "reroutes": round(mean(rows, lambda r: r["reroutes"]), 3),
        "recovery_events": round(mean(rows, lambda r: len(r.get("recovery_events", []))), 3),
        "early_archer_kills_mean": round(mean(rows, lambda r: r["early_archer_kills"]), 3),
        "early_archer_seeds": sum(r["early_archer_kills"] > 0 for r in rows),
        "all_archer_kills_mean": round(mean(rows, lambda r: len(r["archer_kill_times"])), 3),
        "routes": route_counts(rows),
        "ghost_peak_early": round(phase_peak(rows, "early", "ghost"), 2),
        "ghost_peak_middle": round(phase_peak(rows, "middle", "ghost"), 2),
        "ghost_peak_late": round(phase_peak(rows, "late", "ghost"), 2),
    }


def baseline():
    out = {}
    for group in GROUPS:
        old = load(RES / f"matrix/old_{group}/results.jsonl")
        prep = load(RES / f"matrix/prep_{group}/results.jsonl")
        if not old or not prep:
            out[group] = {"complete": False, "old_rows": len(old), "prep_rows": len(prep)}
            continue
        rows = old + prep
        strategies = {}
        for name in OLD + NEW:
            subset = [r for r in rows if r["strategy"] == name]
            if subset:
                strategies[name] = describe(subset)
        rates = {name: rec["rate"] for name, rec in strategies.items()}
        out[group] = {
            "complete": True,
            "params_sha_old": old[0]["params_sha256"],
            "params_sha_prep": prep[0]["params_sha256"],
            "strategies": strategies,
            "target1": {
                "strategies_over_30": sorted(
                    name for name, rate in rates.items() if rate is not None and rate >= 0.30
                ),
                "count": sum(rate is not None and rate >= 0.30 for rate in rates.values()),
                "methods": sorted({m for rec in strategies.values() for m in rec["methods"]}),
                "routes": sorted({route for rec in strategies.values() for route in rec["routes"]}),
            },
            "target2": {
                "idle": rates["idle"],
                "min_feint_waves": min(rates["feint"], rates["waves"]),
                "gap_pp": round(100 * (min(rates["feint"], rates["waves"]) - rates["idle"]), 1),
            },
        }
    return out


def paired(path_on, path_off):
    on = {r["seed"]: r for r in load(path_on)}
    off = {r["seed"]: r for r in load(path_off)}
    seeds = sorted(set(on) & set(off))
    if not seeds:
        return {"complete": False, "on_rows": len(on), "off_rows": len(off)}
    b = sum(on[s]["won"] and not off[s]["won"] for s in seeds)
    c = sum(off[s]["won"] and not on[s]["won"] for s in seeds)
    on_rows = [on[s] for s in seeds]
    off_rows = [off[s] for s in seeds]
    return {
        "complete": True,
        "n": len(seeds),
        "on": describe(on_rows),
        "off": describe(off_rows),
        "rate_diff_pp": round(100 * (mean(on_rows, lambda r: int(r["won"])) - mean(off_rows, lambda r: int(r["won"]))), 1),
        "discordant_on_only": b,
        "discordant_off_only": c,
        "mcnemar_p": round(mcnemar(b, c), 4),
    }


def target3():
    return {
        "main": paired(RES / "target3/main_on/results.jsonl", RES / "target3/main_off/results.jsonl"),
        "side": paired(RES / "target3/side_on/results.jsonl", RES / "target3/side_off/results.jsonl"),
    }


def target4(base):
    out = {}
    for group, rec in base.items():
        if not rec.get("complete"):
            continue
        values = {}
        for name, s in rec["strategies"].items():
            values[name] = {
                "congestion_mean": s["congestion_mean"],
                "congestion_median": s["congestion_median"],
                "congestion_max": s["congestion_max"],
                "runs_over_05": s["congestion_over_05"],
                "travel_mean": s["travel_mean"],
            }
        over = [name for name, v in values.items() if v["congestion_mean"] > 0.5]
        out[group] = {
            "by_strategy": values,
            "strategies_over_05_mean": over,
            "runs_over_05": sum(v["runs_over_05"] for v in values.values()),
            "runs": sum(rec["strategies"][name]["n"] for name in values),
            "worst": max(values, key=lambda name: values[name]["congestion_mean"]),
            "best": min(values, key=lambda name: values[name]["congestion_mean"]),
        }
    return out


def aggregate_units(group):
    out = {}
    for row in group:
        for kind, rec in row.get("unit_results", {}).items():
            dst = out.setdefault(kind, {key: 0 for key in rec})
            for key, value in rec.items():
                dst[key] += value
    for rec in out.values():
        for key in rec:
            if isinstance(rec[key], float):
                rec[key] = round(rec[key], 3)
    return out


def fleet(rows):
    out = {}
    for name in ["assassin_first", "giant_breach", "prep_control"]:
        group = [r for r in rows if r["strategy"] == name]
        if not group:
            continue
        spend = [r["fire_spent"] for r in group]
        prep = aggregate_units(group)
        assassinations = [len(r.get("assassination_events", [])) for r in group]
        first = []
        for r in group:
            ev = r.get("assassination_events", [])
            if ev:
                first.append(ev[0]["time"])
        breach = []
        for r in group:
            work = r.get("structure_work", {}).get("wall_west", {})
            if work.get("breached_at", -1) >= 0:
                breach.append(work["breached_at"])
        out[name] = {
            **describe(group),
            "fire_spent_min": min(spend),
            "fire_spent_max": max(spend),
            "equal_120": sum(abs(x - 120) < 0.01 for x in spend),
            "assassination_count_mean": round(mean(group, lambda r: len(r.get("assassination_events", []))), 2),
            "assassination_first_time_mean": round(statistics.mean(first), 3) if first else None,
            "wall_west_breached": len(breach),
            "wall_west_breach_time_mean": round(statistics.mean(breach), 3) if breach else None,
            "unit_results": prep,
            "detections_mean": round(mean(group, lambda r: len(r.get("detection_events", []))), 2),
        }
    return out


def phase_b():
    rows = load(RES / "phaseb/compare/results.jsonl")
    if not rows:
        return {"complete": False}
    by = {name: [r for r in rows if r["strategy"] == name] for name in ["assassin_first", "giant_breach", "prep_control"]}
    summary = fleet(rows)
    seeds = sorted({r["seed"] for r in rows})
    equal = []
    paired = {}
    for seed in seeds:
        group = {r["strategy"]: r for r in rows if r["seed"] == seed}
        if len(group) == 3 and len({round(r["fire_spent"], 2) for r in group.values()}) == 1:
            equal.append(seed)
    for a, b in [("assassin_first", "prep_control"), ("giant_breach", "prep_control")]:
        b_only = c_only = 0
        for seed in seeds:
            group = {r["strategy"]: r for r in rows if r["seed"] == seed}
            if a not in group or b not in group:
                continue
            if group[a]["won"] and not group[b]["won"]:
                b_only += 1
            if group[b]["won"] and not group[a]["won"]:
                c_only += 1
        paired[f"{a}_vs_prep_control"] = {
            "rate_a": summary[a]["rate"],
            "rate_control": summary[b]["rate"],
            "rate_diff_pp": round(100 * (summary[a]["rate"] - summary[b]["rate"]), 1),
            "discordant_a_only": b_only,
            "discordant_control_only": c_only,
            "mcnemar_p": round(mcnemar(b_only, c_only), 4),
        }
    return {
        "complete": True,
        "strategies": summary,
        "n": len(rows),
        "equal_actual_spend_seeds": equal,
        "paired": paired,
        "all_strategies_equal_spend": len(equal) == len(seeds),
    }


def main():
    base = baseline()
    data = {
        "task": "T77",
        "metric_version": "T74-movement-intent-v1",
        "raw_root": "proto/siege/results/t77/",
        "baseline": base,
        "target3": target3(),
        "target4": target4(base),
        "phase_b": phase_b(),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote {OUT}")

    print("\n## baseline")
    for group, rec in base.items():
        if not rec.get("complete"):
            print(group, "INCOMPLETE", rec)
            continue
        print(f"\n### {group}")
        for name, s in rec["strategies"].items():
            print(
                f"{name:16s} n={s['n']:2d} win={s['rate']*100:5.1f}% "
                f"ci={s['ci95'][0]*100:4.0f}-{s['ci95'][1]*100:4.0f} "
                f"cas={s['casualties_ghost']:6.1f}/{s['casualties_defender']:5.1f} "
                f"cong={s['congestion_mean']:.3f} travel={s['travel_mean']:.3f} "
                f"early={s['early_archer_kills_mean']:.2f} peak={s['ghost_peak_early']:.1f}"
            )
        print("target1", rec["target1"]["count"], rec["target1"]["methods"], rec["target1"]["routes"])
        print("target2 gap", rec["target2"]["gap_pp"])

    print("\n## target3")
    for route, rec in data["target3"].items():
        if rec.get("complete"):
            print(
                f"{route}: on {rec['on']['wins']}/{rec['n']} off {rec['off']['wins']}/{rec['n']} "
                f"diff={rec['rate_diff_pp']}pp b={rec['discordant_on_only']} c={rec['discordant_off_only']} p={rec['mcnemar_p']} "
                f"early {rec['on']['early_archer_kills_mean']:.2f}/{rec['off']['early_archer_kills_mean']:.2f}"
            )
        else:
            print(route, "INCOMPLETE", rec)

    print("\n## target4")
    for group, rec in data["target4"].items():
        print(group, "over", rec["strategies_over_05_mean"], "worst", rec["worst"], "best", rec["best"])

    print("\n## phase_b", data["phase_b"].get("complete"))
    if data["phase_b"].get("complete"):
        for name, s in data["phase_b"]["strategies"].items():
            print(
                f"{name:16s} win={s['rate']*100:5.1f}% time={s['victory_time_mean']} "
                f"cas={s['casualties_ghost']:.1f}/{s['casualties_defender']:.1f} "
                f"spent={s['fire_spent']:.1f} [{s['fire_spent_min']:.1f},{s['fire_spent_max']:.1f}] "
                f"breach={s['wall_west_breach_time_mean']} assass={s['assassination_count_mean']}"
            )
        print("equal spend seeds", data["phase_b"]["equal_actual_spend_seeds"])
        print("paired", data["phase_b"]["paired"])


if __name__ == "__main__":
    main()
