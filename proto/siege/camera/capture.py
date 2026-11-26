#!/usr/bin/env python3
"""串行录制同种子同策略的 A/B PNG 序列和四战区静帧；比较完整 SIEGE JSON。"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
SCENE = "proto/siege/camera/siege_camera.tscn"


def run(args, label, flags):
    folder = args.out / label
    folder.mkdir(parents=True, exist_ok=True)
    command = [args.godot, "--path", str(ROOT), "--log-file", str(folder / "engine.log"),
               SCENE, "--", "--capture", f"--strategy={args.strategy}", f"--seed={args.seed}",
               f"--out={folder}", f"--camera_out={folder}", *flags]
    (folder / "command.json").write_text(json.dumps(command, ensure_ascii=False, indent=2))
    try:
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=args.timeout)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        (folder / "stdout.log").write_text(output.decode(errors="replace") if isinstance(output, bytes) else output)
        raise RuntimeError(f"{label} 窗口/渲染超时；保留日志，未生成画面不能算验收通过") from error
    output = process.stdout + process.stderr
    (folder / "stdout.log").write_text(output)
    bad = [line for line in output.splitlines() if "SCRIPT ERROR" in line or line.startswith("ERROR:")]
    bad = [line for line in bad if 'Condition "ret != noErr"' not in line]
    if process.returncode or bad:
        raise RuntimeError(f"{label} exit={process.returncode} errors={bad[:3]}")
    frames = sorted(folder.glob("*.png"))
    if not frames:
        raise RuntimeError(f"{label} 没有实际 PNG")
    rows = [json.loads(line[6:]) for line in output.splitlines() if line.startswith("SIEGE ")]
    if "--camera_record" in flags:
        if len(rows) != 1:
            raise RuntimeError(f"{label} 结算记录数量不是 1")
        (folder / "result.json").write_text(json.dumps(rows[0], ensure_ascii=False, indent=2))
    print(f"CAPTURE {label} frames={len(frames)}", flush=True)
    return rows[0] if rows else None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--strategy", default="feint")
    parser.add_argument("--fps", type=int, default=10)
    parser.add_argument("--timeout", type=float, default=900)
    parser.add_argument("--out", type=Path, default=ROOT / "shots/t70")
    args = parser.parse_args()
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / ".gdignore").touch()
    results = []
    for mode in ["zones", "continuous"]:
        results.append(run(args, mode, [f"--camera_mode={mode}", "--camera_record", "--camera_patrol",
                                       f"--camera_fps={args.fps}", "--speed=1"]))
    if results[0] != results[1]:
        differences = [key for key in results[0] if results[0][key] != results[1].get(key)]
        raise RuntimeError(f"ESCALATE: A/B 模拟结算不一致 {differences}；停止录制")
    for zone in ["coast", "highland", "plaza", "keep"]:
        run(args, f"stills/{zone}", ["--camera_mode=zones", f"--zone={zone}", "--camera_still", "--speed=1"])
    print("CAMERA_CAPTURE PASS exact_result_match=true")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError) as error:
        print(f"CAMERA_CAPTURE FAIL: {error}", file=sys.stderr)
        sys.exit(1)
