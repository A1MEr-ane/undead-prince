#!/usr/bin/env python3
"""T60 summarize.py 自测：统计口径、异常判定、复跑比较、CLI 产物。

由 tests/test_sim_tools.gd 调用（verify 命令会跑到）。
用假数据，不启动 Godot。
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import summarize as sim  # noqa: E402

DEFAULT_STATS = {
    "hit": 10, "parry": 2, "clash": 1, "counter": 0,
    "death": 5, "fall": 1, "slide": 2, "pursue": 3,
}
ZERO_STATS = {key: 0 for key in DEFAULT_STATS}
ALIVE = {"亡魂一队": 5, "亡魂二队": 4, "王旗卫队": 2, "山腰民兵": 1}


def make_record(index, seed, banner="王旗已夺取", time=20, stats=None,
                has_result=True, kind="main", pair_index=None, hitch=0,
                errors=None, positions=None, exit_code=0, timed_out=False):
    stats = dict(DEFAULT_STATS if stats is None else stats)
    result = None
    if has_result:
        result = {
            "seed": seed,
            "time": time,
            "banner": banner,
            "capture": 3.0,
            "alive": dict(ALIVE),
            "stats": stats,
        }
        if positions is not None:
            result["positions"] = positions
            result["map_size"] = 24
    return {
        "index": index,
        "seed": seed,
        "kind": kind,
        "pair_index": pair_index,
        "battle_id": "proto",
        "config": "data/battles/proto.json",
        "exit_code": exit_code,
        "duration_s": 20.0,
        "timed_out": timed_out,
        "result": result,
        "result_raw": json.dumps(result, ensure_ascii=False) if result else None,
        "result_parse_error": None,
        "stats_line": "STATS {}" if result else None,
        "hitch_count": hitch,
        "hitch_lines": ["HITCH 0.2s at t=1.0"] * hitch,
        "script_errors": list(errors or []),
        "alive_by_faction": {"player": 9, "defender": 3, "unknown": 0},
        "log": "reports/sim/test/logs/%s_%d.log" % (kind, index),
        "log_tail": [],
    }


def full_summary_fixture():
    records = [
        make_record(0, 1, time=20, positions=[[1, 1, 1], [2, 1, 2]]),
        make_record(1, 2, banner="亡魂散尽", time=30),
        make_record(2, 3, time=10, hitch=1),
        make_record(3, 4, banner="", time=60,
                    stats={"hit": 40, "parry": 0, "clash": 0, "counter": 0}),
        make_record(4, 5, has_result=False,
                    errors=["SCRIPT ERROR: boom"]),
        make_record(5, 6, banner="", time=60, stats=ZERO_STATS,
                    errors=["SCRIPT ERROR: boom"]),
        make_record(0, 1, kind="recheck", pair_index=0, time=20,
                    positions=[[1, 1, 1], [2, 1, 2]]),
        make_record(1, 2, kind="recheck", pair_index=1,
                    banner="亡魂散尽", time=31),
        make_record(2, 3, kind="recheck", pair_index=2, has_result=False),
    ]
    meta = {
        "task": "T60",
        "quit_at": 60,
        "jobs": 4,
        "requested": 6,
        "seed_start": 1,
        "seed_end": 6,
        "config": "data/battles/proto.json",
        "battle_id": "proto",
        "batch_dir": "reports/sim/test",
        "squads": [
            {"title": "亡魂一队", "faction": 0, "is_player": True},
            {"title": "亡魂二队", "faction": 0, "is_player": True},
            {"title": "王旗卫队", "faction": 1, "is_player": False},
            {"title": "山腰民兵", "faction": 1, "is_player": False},
        ],
    }
    return records, meta


class PercentileTest(unittest.TestCase):
    def test_percentile(self):
        self.assertIsNone(sim.percentile([], 50))
        self.assertEqual(sim.percentile([5], 90), 5)
        values = [10, 20, 30, 60, 60]
        self.assertEqual(sim.percentile(values, 50), 30)
        self.assertEqual(sim.percentile(values, 90), 60)
        self.assertAlmostEqual(sim.percentile([1, 2, 3, 4], 50), 2.5)
        self.assertAlmostEqual(sim.percentile([1, 2, 3, 4], 90), 3.7)


class EvaluateRunTest(unittest.TestCase):
    def reasons(self, record):
        return sim.evaluate_run(record, 60)["reasons"]

    def test_missing_result(self):
        record = make_record(0, 1, has_result=False)
        self.assertIn("missing_result", self.reasons(record))
        record = make_record(0, 1, has_result=False, timed_out=True)
        self.assertIn("missing_result", self.reasons(record))
        self.assertIn("超时", sim.evaluate_run(record, 60)["messages"][0])

    def test_unresolved(self):
        self.assertIn("unresolved", self.reasons(make_record(0, 1, banner="", time=60)))
        self.assertIn("unresolved", self.reasons(make_record(0, 1, banner="", time=12)))

    def test_script_error_and_hitch(self):
        record = make_record(0, 1, hitch=2, errors=["SCRIPT ERROR: x"])
        reasons = self.reasons(record)
        self.assertIn("script_error", reasons)
        self.assertIn("hitch", reasons)

    def test_nonzero_exit(self):
        self.assertIn("nonzero_exit", self.reasons(make_record(0, 1, exit_code=1)))

    def test_no_engagement_only_after_window(self):
        no_contact = make_record(0, 1, banner="", time=60, stats=ZERO_STATS)
        self.assertIn("no_engagement", self.reasons(no_contact))
        early = make_record(0, 1, banner="", time=30, stats=ZERO_STATS)
        self.assertNotIn("no_engagement", self.reasons(early))
        contact = make_record(0, 1, banner="", time=60,
                              stats={"hit": 0, "parry": 0, "clash": 0, "counter": 1})
        self.assertNotIn("no_engagement", self.reasons(contact))

    def test_nan_coordinate(self):
        record = make_record(0, 1, positions=[[float("nan"), 1, 1]])
        reasons = self.reasons(record)
        self.assertIn("nan_value", reasons)
        self.assertIn("nan_coord", reasons)

    def test_out_of_map(self):
        record = make_record(0, 1, positions=[[-10, 1, 1], [30, 1, 2]])
        self.assertIn("out_of_map", self.reasons(record))

    def test_valid_positions_no_anomaly(self):
        evaluation = sim.evaluate_run(
            make_record(0, 1, positions=[[1, 1, 1], [23, 1, 23]]), 60)
        self.assertEqual(evaluation["reasons"], [])
        self.assertTrue(evaluation["coord_available"])

    def test_coordinate_check_unavailable(self):
        evaluation = sim.evaluate_run(make_record(0, 1), 60)
        self.assertFalse(evaluation["coord_available"])


class BuildSummaryTest(unittest.TestCase):
    def setUp(self):
        records, meta = full_summary_fixture()
        self.summary = sim.build_summary(records, meta, 60)

    def test_counts(self):
        counts = self.summary["counts"]
        self.assertEqual(counts["total"], 6)
        self.assertEqual(counts["completed"], 5)
        self.assertEqual(counts["missing_result"], 1)
        self.assertEqual(counts["wins"], 2)
        self.assertEqual(counts["losses"], 1)
        self.assertEqual(counts["unresolved"], 2)
        self.assertEqual(counts["other"], 0)
        self.assertAlmostEqual(counts["win_rate"], 0.4)
        self.assertAlmostEqual(counts["win_rate_decided"], 2 / 3, places=3)
        self.assertEqual(counts["runs_with_script_error"], 2)
        self.assertEqual(counts["runs_with_hitch"], 1)

    def test_time_distribution(self):
        block = self.summary["time"]
        self.assertEqual(block["n"], 5)
        self.assertAlmostEqual(block["mean"], 36.0)
        self.assertAlmostEqual(block["p50"], 30.0)
        self.assertAlmostEqual(block["p90"], 60.0)
        self.assertAlmostEqual(self.summary["time_decided"]["mean"], 20.0)

    def test_stats_mean(self):
        self.assertAlmostEqual(self.summary["stats"]["hit"]["mean"], 14.0)
        self.assertEqual(self.summary["stats"]["hit"]["n"], 5)
        self.assertAlmostEqual(self.summary["stats"]["parry"]["mean"], 1.2)
        # 缺失的 STATS 键按 0 计（每局平均），不是只对出现过的局取平均。
        self.assertAlmostEqual(self.summary["stats"]["death"]["mean"], 3.0)
        self.assertEqual(self.summary["stats"]["death"]["n"], 5)

    def test_alive(self):
        alive = self.summary["alive"]
        self.assertAlmostEqual(alive["mean_total"], 12.0)
        self.assertAlmostEqual(alive["mean_player"], 9.0)
        self.assertAlmostEqual(alive["mean_defender"], 3.0)
        self.assertTrue(alive["per_squad"]["亡魂一队"]["is_player"])
        self.assertEqual(alive["per_squad"]["亡魂一队"]["samples"], 5)

    def test_determinism(self):
        det = self.summary["determinism"]
        self.assertEqual(det["checked"], 3)
        self.assertEqual(det["matched"], 1)
        self.assertTrue(det["items"][0]["match"])
        self.assertFalse(det["items"][1]["match"])
        self.assertFalse(det["items"][2]["match"])

    def test_anomalies(self):
        by_index = {entry["index"]: entry for entry in self.summary["anomalies"]}
        self.assertEqual(len(by_index), 5)
        self.assertNotIn(0, by_index)
        self.assertIn("determinism_mismatch", by_index[1]["reasons"])
        self.assertIn("hitch", by_index[2]["reasons"])
        self.assertIn("determinism_mismatch", by_index[2]["reasons"])
        self.assertIn("unresolved", by_index[3]["reasons"])
        self.assertIn("missing_result", by_index[4]["reasons"])
        self.assertIn("script_error", by_index[4]["reasons"])
        self.assertIn("no_engagement", by_index[5]["reasons"])
        self.assertEqual(self.summary["anomaly_summary"]["determinism_mismatch"], 2)

    def test_coordinate_available(self):
        self.assertTrue(self.summary["coordinate_check"]["available"])

    def test_markdown_sections(self):
        text = sim.render_markdown(self.summary)
        for heading in ("# 批量模拟摘要", "## 胜负", "## 用时（秒）",
                        "## 剩余人数（平均）", "## STATS 平均",
                        "## 同种子复跑", "## 异常局"):
            self.assertIn(heading, text)
        self.assertIn("同种子复跑不一致", text)


class CliTest(unittest.TestCase):
    def test_cli_writes_outputs(self):
        records = [
            make_record(0, 1, time=20),
            make_record(1, 2, banner="亡魂散尽", time=30),
            make_record(2, 3, banner="", time=60, hitch=1),
        ]
        with tempfile.TemporaryDirectory() as tmp:
            runs = os.path.join(tmp, "runs.jsonl")
            with open(runs, "w", encoding="utf-8") as fh:
                for record in records:
                    fh.write(json.dumps(record, ensure_ascii=False) + "\n")
            meta_path = os.path.join(tmp, "meta.json")
            with open(meta_path, "w", encoding="utf-8") as fh:
                json.dump({"quit_at": 60, "requested": 3}, fh)
            proc = subprocess.run(
                [sys.executable, os.path.join(HERE, "summarize.py"),
                 "--input", runs, "--out-dir", tmp, "--meta", meta_path],
                capture_output=True, text=True,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            summary_path = os.path.join(tmp, "summary.json")
            md_path = os.path.join(tmp, "summary.md")
            self.assertTrue(os.path.isfile(summary_path))
            self.assertTrue(os.path.isfile(md_path))
            with open(summary_path, encoding="utf-8") as fh:
                summary = json.load(fh)
            self.assertEqual(summary["counts"]["total"], 3)
            self.assertEqual(summary["counts"]["completed"], 3)
            self.assertEqual(summary["counts"]["wins"], 1)
            self.assertEqual(summary["counts"]["losses"], 1)
            self.assertEqual(summary["counts"]["unresolved"], 1)
            with open(md_path, encoding="utf-8") as fh:
                text = fh.read()
            self.assertIn("## 异常局", text)
            self.assertIn("出现 HITCH", text)

    def test_cli_rejects_empty_jsonl(self):
        with tempfile.TemporaryDirectory() as tmp:
            runs = os.path.join(tmp, "runs.jsonl")
            open(runs, "w").close()
            proc = subprocess.run(
                [sys.executable, os.path.join(HERE, "summarize.py"),
                 "--input", runs, "--out-dir", tmp],
                capture_output=True, text=True,
            )
            self.assertEqual(proc.returncode, 2)
            self.assertIn("没有记录", proc.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
