#!/usr/bin/env python3
"""同策略同种子：原无头入口与两组真实显示节点回放，逐字比较完整 SIEGE。"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("siege_matrix", ROOT / "proto/siege/run_matrix.py")
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)


def result_line(output):
    lines = [line for line in output.splitlines() if line.startswith("SIEGE ")]
    if len(lines) != 1:
        raise RuntimeError(f"要求恰好一行 SIEGE，得到 {len(lines)}")
    return lines[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--params", type=Path, default=matrix.DEFAULT_PARAMS)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--timeout", type=float, default=300)
    # 与矩阵脚本共享命令行；矩阵尺寸不改变本项固定 feint/seed7 回放。
    parser.add_argument("--seeds", "-n", type=int, default=20)
    parser.add_argument("--start-seed", type=int, default=1)
    args = parser.parse_args()
    out = (args.out or ROOT / "proto/siege/results/verify").resolve() / "camera"
    out.mkdir(parents=True, exist_ok=True)
    (out / ".gdignore").touch()
    feature_output = matrix.execute(args.godot, ["--script", "proto/siege/camera/test_camera.gd"],
                                    out / "features.log", args.timeout)
    if "CAMERA_FEATURES PASS" not in feature_output:
        raise RuntimeError("缺少镜头功能通过标记")
    print("CAMERA_FEATURES PASS", flush=True)
    flags = ["--", "--strategy=feint", "--seed=7", f"--params={args.params.resolve()}"]
    baseline = result_line(matrix.execute(args.godot, [matrix.SCENE, *flags],
                                          out / "headless.log", args.timeout))
    summary = {"strategy": "feint", "seed": 7, "comparison": "byte_equal_full_SIEGE_line", "modes": {}}
    for mode in ["zones", "continuous"]:
        output = matrix.execute(args.godot, ["--script", "proto/siege/camera/replay.gd", *flags,
                                             f"--camera_mode={mode}"], out / f"{mode}.log", args.timeout)
        actual = result_line(output)
        if actual != baseline:
            expected_row, actual_row = json.loads(baseline[6:]), json.loads(actual[6:])
            differences = [key for key in expected_row.keys() | actual_row.keys()
                           if expected_row.get(key) != actual_row.get(key)]
            raise RuntimeError(f"ESCALATE: 显示回放结果不一致 mode={mode} fields={differences}; logs={out}")
        diagnostics = [json.loads(line.removeprefix("CAMERA_ROUNDTRIP ")) for line in output.splitlines()
                       if line.startswith("CAMERA_ROUNDTRIP ")]
        summary["modes"][mode] = {"bytes": len(actual.encode()), "sha256": hashlib.sha256(actual.encode()).hexdigest(),
                                  "roundtrip_diagnostic": diagnostics}
        print(f"CAMERA_REPLAY PASS mode={mode} seed=7 strategy=feint byte_equal=true sha256={summary['modes'][mode]['sha256']}", flush=True)
    (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        print(f"CAMERA_REPLAY FAIL: {error}", file=sys.stderr)
        sys.exit(1)
