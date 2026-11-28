#!/usr/bin/env python3
"""T77：指定策略子集的串行矩阵运行器。

复用 proto/siege/run_matrix.py 的 Godot 调用、日志检查和 SIEGE 字段校验；
只用于组合旧六策略（analysis 口径）与阶段 B 新策略的样本。
"""
import argparse
import copy
import json
import os
from pathlib import Path
import statistics
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "proto/siege"))
import run_matrix  # noqa: E402


def fmt(value):
    return "—" if value is None else f"{value:.3f}"


def mean(rows, fn):
    return statistics.mean(fn(row) for row in rows) if rows else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--params", type=Path, required=True)
    parser.add_argument("--strategies", required=True, help="逗号分隔")
    parser.add_argument("--seeds", type=int, default=20)
    parser.add_argument("--start-seed", type=int, default=1)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--timeout", type=float, default=300)
    parser.add_argument("--verify", action="store_true", help="每局重复一次，完整 JSON 必须一致")
    args = parser.parse_args()

    strategies = [s for s in args.strategies.split(",") if s]
    params_path = args.params.resolve()
    params = run_matrix.merged(
        copy.deepcopy(json.loads(run_matrix.DEFAULT_PARAMS.read_text())),
        json.loads(params_path.read_text()),
    )
    for strategy in strategies:
        if strategy not in params["strategies"]["names"]:
            raise RuntimeError(f"{strategy} 不在 {params_path.name} 的 strategies.names 中")
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / ".gdignore").touch()
    (out / "effective_params.json").write_text(
        json.dumps(params, ensure_ascii=False, indent=2) + "\n"
    )
    start = time.monotonic()
    rows = []
    with (out / "results.jsonl").open("w") as stream:
        for strategy in strategies:
            for seed in range(args.start_seed, args.start_seed + args.seeds):
                row = run_matrix.one(
                    args.godot, strategy, seed, params_path, params, out, args.timeout
                )
                if args.verify:
                    repeat = run_matrix.one(
                        args.godot, strategy, seed, params_path, params, out,
                        args.timeout, "_repeat",
                    )
                    if row != repeat:
                        diff = [key for key in row if row[key] != repeat.get(key)]
                        raise RuntimeError(f"非确定性 {strategy}/{seed}: {diff}")
                rows.append(row)
                stream.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
                stream.flush()
                print(
                    f"{'DETERMINISTIC' if args.verify else 'MATRIX'} {strategy} seed={seed} "
                    f"won={row['won']} method={row['victory_method']} "
                    f"fire={row['fire_spent']} casualties={row['casualties']}",
                    flush=True,
                )
    lines = [
        "# T77 策略子集矩阵",
        "",
        f"参数文件：`{params_path.relative_to(ROOT)}`",
        f"参数 SHA256：`{rows[0]['params_sha256']}`",
        f"样本：{len(strategies)} 策略 × {args.seeds} 种子（{args.start_seed}–{args.start_seed + args.seeds - 1}）",
        "",
        "| 策略 | N | 胜率 | 全歼/攻占 | 胜利/攻占用时 s | 亡魂/守军伤亡 | 冥火投入 | 新拥堵/出生 | 行军拥堵/出生 |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for strategy in strategies:
        group = [r for r in rows if r["strategy"] == strategy]
        wins = [r for r in group if r["won"]]
        annihilation = sum(r["victory_method"] == "annihilation" for r in wins)
        capture = len(wins) - annihilation
        captured = [r for r in wins if r["victory_method"] == "keep_retreat"]
        deployed = mean(group, lambda r: r["spawned"]["ghost"] + r["spawned"]["defender"])
        congestion = mean(group, lambda r: r["congestion_events"] / max(1, r["spawned"]["ghost"] + r["spawned"]["defender"]))
        travel = mean(group, lambda r: r["travel_congestion_events"] / max(1, r["spawned"]["ghost"] + r["spawned"]["defender"]))
        lines.append(
            f"| {strategy} | {len(group)} | {len(wins) / len(group):.0%} | {annihilation}/{capture} | "
            f"{fmt(mean(wins, lambda r: r['victory_time']))}/{fmt(mean(captured, lambda r: r['victory_time']))} | "
            f"{fmt(mean(group, lambda r: r['casualties']['ghost']))}/{fmt(mean(group, lambda r: r['casualties']['defender']))} | "
            f"{fmt(mean(group, lambda r: r['fire_spent']))} | {fmt(congestion)} | {fmt(travel)} |"
        )
    lines += [
        "",
        "新拥堵口径：有移动意图、未到位、连续 3 秒净位移不足 0.15 格；排除站岗、近战、攻击结构、眩晕、转移和撤退。",
        f"每局双方平均出生人数：{fmt(mean(rows, lambda r: r['spawned']['ghost'] + r['spawned']['defender']))}。",
        "",
        "原始逐局记录见 `results.jsonl`。",
        "",
    ]
    (out / "summary.md").write_text("\n".join(lines))
    print(
        f"T77_MATRIX PASS runs={len(rows)} repeats={len(rows) if args.verify else 0} "
        f"seconds={time.monotonic() - start:.2f} summary={out / 'summary.md'}",
        flush=True,
    )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        print(f"T77 FAIL: {error}", file=sys.stderr)
        sys.exit(1)
