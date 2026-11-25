#!/usr/bin/env python3
"""串行 Godot 批跑、完整 JSON 确定性比较、SIEGE 数据汇总。仅依赖标准库。"""
import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PARAMS = ROOT / "proto/siege/siege_params.json"
SCENE = "proto/siege/siege.tscn"


def merged(base, overlay):
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            merged(base[key], value)
        else:
            base[key] = value
    return base


def check_log(output):
    # 已知 macOS 证书查询报错，精确排除这一条；其他 ERROR 都失败。
    bad = []
    for line in output.splitlines():
        if line.startswith('ERROR: Condition "ret != noErr" is true. Returning: ""'):
            continue
        if "SCRIPT ERROR" in line or line.startswith("ERROR:") or "Parse Error:" in line or "ObjectDB instances leaked" in line:
            bad.append(line)
    if bad:
        raise RuntimeError("Godot 日志错误: " + "; ".join(bad[:5]))


def execute(godot, args, log, timeout):
    command = [godot, "--headless", "--path", str(ROOT), "--log-file", str(log.with_suffix(".engine.log")), *args]
    try:
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        log.write_text((error.stdout or b"").decode() if isinstance(error.stdout, bytes) else (error.stdout or ""))
        raise RuntimeError(f"超时 {timeout}s: {log}") from error
    log.write_text(run.stdout + run.stderr)
    check_log(run.stdout + run.stderr)
    if run.returncode:
        raise RuntimeError(f"Godot exit={run.returncode}: {log}")
    return run.stdout


def validate(row, params):
    required = {"seed", "strategy", "params_sha256", "won", "victory_method", "victory_time", "ended_at", "zone_captures", "zone_losses", "retreat", "casualties", "spawned", "waves", "fire_wasted", "fire_generated", "fire_spent", "fire_remaining", "defender_dispatches", "congestion_events", "early_archer_kills", "archer_kill_times"}
    if missing := required - row.keys():
        raise RuntimeError(f"SIEGE 缺字段: {missing}")
    if row["won"] != (row["victory_method"] in {"annihilation", "keep_retreat"}):
        raise RuntimeError("胜负与胜利方式矛盾")
    if not 0 < row["ended_at"] <= params["simulation"]["night_seconds"] + params["simulation"]["step"]:
        raise RuntimeError("非法结束时间")
    if row["won"] and not 0 <= row["victory_time"] <= row["ended_at"]:
        raise RuntimeError("非法胜利用时")
    for side in ["ghost", "defender"]:
        if not 0 <= row["casualties"][side] <= row["spawned"][side]:
            raise RuntimeError("伤亡超出出生人数")
    if sum(w["count"] for w in row["waves"]) != row["spawned"]["ghost"]:
        raise RuntimeError("波次人数与部署人数不一致")
    budget = params["economy"]["initial"] + row["fire_generated"] - row["fire_spent"] - row["fire_wasted"]
    if abs(budget - row["fire_remaining"]) > 0.01:
        raise RuntimeError("冥火收支不守恒")
    if not 0 <= row["fire_remaining"] <= params["economy"]["capacity"]:
        raise RuntimeError("冥火超出上限")
    if row["retreat"]["escaped"] + row["retreat"]["stranded"] + row["casualties"]["defender"] > row["spawned"]["defender"]:
        raise RuntimeError("撤退人数不守恒")
    if any(v < 0 for v in row["casualties"].values()) or row["fire_wasted"] < 0:
        raise RuntimeError("负数指标")


def one(godot, strategy, seed, params_path, effective, out, timeout, suffix=""):
    log = out / f"{strategy}_{seed}{suffix}.log"
    output = execute(godot, [SCENE, "--", f"--strategy={strategy}", f"--seed={seed}", f"--params={params_path}"], log, timeout)
    lines = [line[6:] for line in output.splitlines() if line.startswith("SIEGE ")]
    if len(lines) != 1:
        raise RuntimeError(f"要求恰好一行 SIEGE，得到 {len(lines)}: {log}")
    row = json.loads(lines[0])
    validate(row, effective)
    if row["strategy"] != strategy or row["seed"] != seed:
        raise RuntimeError("策略/种子未生效")
    return row


def mean(rows, accessor):
    return statistics.mean(accessor(r) for r in rows) if rows else None


def summary(rows, params):
    def fmt(value):
        return "—" if value is None else f"{value:.1f}"

    text = ["# T67 攻城策略矩阵", "", f"参数 SHA256（Godot 合并后）: `{rows[0]['params_sha256']}`", "", "胜利用时只统计胜局，攻占用时只统计攻占主堡胜局；伤亡、冥火溢出和拥堵为每局均值。数据不代表平衡验收通过。", "", "| 策略 | N | 胜率 | 全歼/攻占 | 胜利/攻占用时 s | 亡魂/守军伤亡 | 冥火浪费 | 同格>3s | 行军堵塞 | 改道 |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    rates = {}
    methods = set()
    for name in params["strategies"]["names"]:
        group = [r for r in rows if r["strategy"] == name]
        wins = [r for r in group if r["won"]]
        rates[name] = len(wins) / len(group)
        methods.update(r["victory_method"] for r in wins)
        annihilation = sum(r["victory_method"] == "annihilation" for r in wins)
        capture = len(wins) - annihilation
        captured = [r for r in wins if r["victory_method"] == "keep_retreat"]
        text.append(f"| {name} | {len(group)} | {rates[name]:.0%} | {annihilation}/{capture} | {fmt(mean(wins, lambda r: r['victory_time']))}/{fmt(mean(captured, lambda r: r['victory_time']))} | {fmt(mean(group, lambda r: r['casualties']['ghost']))}/{fmt(mean(group, lambda r: r['casualties']['defender']))} | {fmt(mean(group, lambda r: r['fire_wasted']))} | {fmt(mean(group, lambda r: r['congestion_events']))} | {fmt(mean(group, lambda r: r['travel_congestion_events']))} | {fmt(mean(group, lambda r: r['reroutes']))} |")
    metrics = params["metrics"]
    viable = sum(rate >= metrics["minimum_strategy_win_rate"] for rate in rates.values())
    gap = min(rates["feint"], rates["waves"]) - rates["idle"]
    text += ["", "## 四个验证目标的观测", "", f"1. ≥{metrics['minimum_strategy_win_rate']:.0%} 的策略：{viable} / 目标 {metrics['minimum_distinct_winning_strategies']}；观测到的胜利方式：{', '.join(sorted(methods)) or '无'}。用 `won`、`victory_method`、`waves[].routes` 分别区分胜率、胜法、路线。", f"2. min(佯攻, 分波) − 挂机：{gap:.0%}；初始判据 ≥{metrics['idle_win_rate_gap']:.0%}。", "3. 早期击杀弓兵分组（相关性；策略/种子会混杂，因果结论需 T68 做配对参数实验）：", "", "| 早期弓兵击杀 | N | 胜率 |", "|---|---:|---:|"]
    for early in [True, False]:
        group = [r for r in rows if (r["early_archer_kills"] > 0) == early]
        rate = mean(group, lambda r: int(r["won"]))
        text.append(f"| {'有' if early else '无'} | {len(group)} | {'—' if rate is None else format(rate, '.0%')} |")
    ratio = mean(rows, lambda r: r["congestion_per_deployed"])
    text += ["", f"4. `congestion_events / (spawned.ghost + spawned.defender)` 均值 {ratio:.3f}；初值参考上限 {metrics['acceptable_congestion_per_deployed']:.3f}。原始指标包括站岗和近战，`travel_congestion_events` 补充过滤无敌人且未到位的行军堵塞。", "", "原始记录见 `results.jsonl`；每局 stdout/stderr 和引擎日志均保留。", ""]
    return "\n".join(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", "-n", type=int, default=20, help="每种策略的种子数（默认 20）")
    parser.add_argument("--start-seed", type=int, default=1)
    parser.add_argument("--params", type=Path, default=DEFAULT_PARAMS)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--timeout", type=float, default=300)
    parser.add_argument("--verify", action="store_true", help="5×2 各重复一次，完整 JSON 必须一致")
    args = parser.parse_args()
    if args.seeds <= 0:
        parser.error("--seeds 必须为正")
    params_path = args.params.resolve()
    params = merged(json.loads(DEFAULT_PARAMS.read_text()), json.loads(params_path.read_text()))
    label = "verify" if args.verify else "matrix"
    out = (args.out or ROOT / "proto/siege/results" / label).resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / ".gdignore").touch()
    (out / "effective_params.json").write_text(json.dumps(params, ensure_ascii=False, indent=2) + "\n")
    start = time.monotonic()
    if args.verify:
        stdout = execute(args.godot, ["--script", "proto/siege/test_siege.gd"], out / "features.log", args.timeout)
        if "SIEGE_FEATURES PASS" not in stdout:
            raise RuntimeError("缺少机制验收通过标记")
        print("SIEGE_FEATURES PASS", flush=True)
    rows = []
    seeds = 2 if args.verify else args.seeds
    with (out / "results.jsonl").open("w") as stream:
        for strategy in params["strategies"]["names"]:
            for seed in range(args.start_seed, args.start_seed + seeds):
                row = one(args.godot, strategy, seed, params_path, params, out, args.timeout)
                if args.verify:
                    repeat = one(args.godot, strategy, seed, params_path, params, out, args.timeout, "_repeat")
                    if row != repeat:
                        diff = [key for key in row if row[key] != repeat.get(key)]
                        raise RuntimeError(f"非确定性 {strategy}/{seed}: {diff}")
                rows.append(row)
                stream.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
                stream.flush()
                print(f"{'DETERMINISTIC' if args.verify else 'MATRIX'} {strategy} seed={seed} won={row['won']} method={row['victory_method']} casualties={row['casualties']}", flush=True)
    (out / "summary.md").write_text(summary(rows, params))
    print(f"SIEGE_{'VERIFY' if args.verify else 'MATRIX'} PASS runs={len(rows)} repeats={len(rows) if args.verify else 0} seconds={time.monotonic() - start:.2f} summary={out / 'summary.md'}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        print(f"SIEGE FAIL: {error}", file=sys.stderr)
        sys.exit(1)
