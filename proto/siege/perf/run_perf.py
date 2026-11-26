#!/usr/bin/env python3
"""T71 串行性能矩阵：无头模拟与窗口完整帧分开跑，同一场景/同一事件序列。

只改 proto/siege/perf/ 与 reports/agents/；不修改原型代码。
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
PERF = ROOT / "proto/siege/perf"
SCENE = "proto/siege/perf/perf_runner.tscn"
OUT = PERF / "results"

SCENARIOS = ["march", "multi", "melee", "gate", "breach", "reinforce", "cave", "dawn", "camera", "idle"]


def run_one(godot, scenario, units, mode, samples, phase=False, timeout=300, out_dir=None, extra_args=None):
    tag = f"{scenario}_{units}_{mode}" + ("_phase" if phase else "")
    out_dir = (out_dir or OUT).resolve()
    raw = out_dir / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    log = raw / f"{tag}.engine.log"
    args = [
        "--strategy=manual",
        f"--perf_mode={mode}",
        f"--perf_scenario={scenario}",
        f"--perf_units={units}",
        f"--perf_samples={samples}",
        f"--perf_phase={'true' if phase else 'false'}",
        f"--perf_out={raw / (tag + '.json')}",
    ]
    args += extra_args or []
    cmd = [godot]
    if mode == "sim":
        cmd.append("--headless")
    else:
        cmd.append("--disable-vsync")
    cmd += ["--path", str(ROOT), "--log-file", str(log), SCENE, "--", *args]
    started = time.monotonic()
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        stdout, stderr, code = proc.stdout, proc.stderr, proc.returncode
    except subprocess.TimeoutExpired as exc:
        stdout = (exc.stdout or b"").decode() if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        stderr = (exc.stderr or b"").decode() if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        code = -1
    elapsed = time.monotonic() - started
    (raw / f"{tag}.stdout.log").write_text(stdout)
    (raw / f"{tag}.stderr.log").write_text(stderr)
    lines = [line for line in stdout.splitlines() if line.startswith("PERF ")]
    if code != 0 or not lines:
        return {"tag": tag, "ok": False, "exit": code, "seconds": round(elapsed, 2),
                "error": "no PERF line" if not lines else f"exit={code}", "cmd": " ".join(cmd)}
    bad = [line for line in (stdout + stderr).splitlines()
           if ('SCRIPT ERROR' in line or 'Parse Error:' in line or line.startswith('ERROR:')
               or 'ObjectDB instances leaked' in line)
           and not line.startswith('ERROR: Condition "ret != noErr"')]
    if bad:
        return {"tag": tag, "ok": False, "exit": code, "seconds": round(elapsed, 2),
                "error": "; ".join(bad[:5]), "cmd": " ".join(cmd)}
    data = json.loads(lines[-1][5:])
    data["ok"] = True
    data["seconds"] = round(elapsed, 2)
    data["tag"] = tag
    data["cmd"] = " ".join(cmd)
    return data


def samples_for(scenario, units, cap):
    if scenario in ("breach", "dawn"):
        return min(cap, 240)
    if units >= 1000:
        return min(cap, 120)
    if units >= 300:
        return min(cap, 300)
    return cap


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--scenarios", default=",".join(SCENARIOS))
    parser.add_argument("--units", default="100,200,300,500")
    parser.add_argument("--modes", default="sim,render")
    parser.add_argument("--samples", type=int, default=900)
    parser.add_argument("--phase", action="store_true", help="用 perf_siege.gd 子类拆模拟阶段")
    parser.add_argument("--quick", action="store_true", help="冒烟：100 单位、60 样本、仅模拟")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--timeout", type=float, default=300)
    parser.add_argument("--keep", action="store_true", help="保留旧 raw 结果")
    args = parser.parse_args()

    scenarios = [s.strip() for s in args.scenarios.split(",") if s.strip()]
    units = [int(u) for u in args.units.split(",") if u.strip()]
    modes = [m.strip() for m in args.modes.split(",") if m.strip()]
    if args.quick:
        scenarios = ["march", "melee", "gate", "breach", "reinforce", "cave", "multi", "dawn", "camera", "idle"]
        units = [100]
        modes = ["sim"]
        args.samples = 60
    out = (args.out or OUT).resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / ".gdignore").touch()
    raw = out / "raw"
    if not args.keep:
        if raw.exists():
            shutil.rmtree(raw)
        for stale in (out / "T71.jsonl", out / "summary.json"):
            if stale.exists():
                stale.unlink()
    raw.mkdir(parents=True, exist_ok=True)
    rows = []
    started = time.monotonic()
    failures = 0
    total = len(scenarios) * len(units) * len(modes)
    done = 0
    for scenario in scenarios:
        for unit in units:
            for mode in modes:
                if scenario == "camera" and mode != "render":
                    continue
                samples = samples_for(scenario, unit, args.samples)
                done += 1
                print(f"[{done}/{total}] {scenario} {unit} {mode} samples={samples}", flush=True)
                row = run_one(args.godot, scenario, unit, mode, samples, args.phase, args.timeout, out)
                rows.append(row)
                if not row.get("ok"):
                    failures += 1
                    print(f"  FAIL {row.get('error')} {row.get('tag')}", flush=True)
                else:
                    frame = row.get("frame_ms") or {}
                    sim = row.get("sim_ms") or {}
                    print(f"  sim p50={sim.get('p50')} p95={sim.get('p95')} max={sim.get('max')} "
                          f"frame p50={frame.get('p50')} p95={frame.get('p95')} max={frame.get('max')} "
                          f"draw={row.get('draw_calls')}", flush=True)
                with (out / "T71.jsonl").open("a") as stream:
                    stream.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    elapsed = time.monotonic() - started
    good = [r for r in rows if r.get("ok")]
    summary = {
        "runs": len(rows),
        "ok": len(good),
        "failed": failures,
        "seconds": round(elapsed, 1),
        "command": "python3 proto/siege/perf/run_perf.py " + " ".join(sys.argv[1:]),
        "environment": good[0].get("environment") if good else {},
        "rows": good,
    }
    (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(f"PERF_MATRIX {'PASS' if failures == 0 else 'FAIL'} runs={len(rows)} ok={len(good)} "
          f"seconds={elapsed:.1f} out={out}", flush=True)
    sys.exit(0 if failures == 0 else 1)


if __name__ == "__main__":
    main()
