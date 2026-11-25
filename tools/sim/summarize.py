#!/usr/bin/env python3
"""T60：读取批量对战 runs.jsonl，输出 summary.json 和可读的 summary.md。

异常检测阈值集中在文件顶部的常量里；改阈值只改这里。
坐标类异常只在 RESULT 带 positions/units/squads 坐标字段时才能检查；
当前 main.gd 的 RESULT 没有坐标（加字段要走 handoff），所以默认会标注"坐标检查不可用"。
"""

import argparse
import datetime
import glob
import json
import math
import os
import sys
from collections import Counter

# ---------- 阈值 / 规则常量 ----------
WIN_BANNERS = ("王旗已夺取",)
LOSS_BANNERS = ("亡魂散尽",)
ENGAGEMENT_STATS = ("hit", "parry", "clash", "counter")  # 任一项 > 0 视为已接战
NO_ENGAGE_WINDOW_S = 60.0       # "60 秒内双方都没有接战"
UNRESOLVED_TOLERANCE_S = 0.5    # time >= quit_at - 0.5 仍未分胜负
HITCH_ALLOWED = 0               # 出现任意 HITCH 即异常
MAP_SIZE_DEFAULT = 24.0         # scripts/terrain.gd 的 SIZE
MAP_MARGIN = 2.0                # 允许贴岸/落水前的余量
Y_MIN = -10.0
Y_MAX = 50.0
DETERMINISM_SAMPLE = 3          # 期望复跑抽查局数（仅用于摘要提示）

REASON_LABELS = {
    "missing_result": "没有 RESULT（崩溃或卡死）",
    "unresolved": "到时间仍未分胜负",
    "script_error": "脚本错误",
    "hitch": "出现 HITCH",
    "no_engagement": "60 秒内没有接战",
    "nan_value": "数值出现 NaN/Inf",
    "nan_coord": "坐标出现 NaN/Inf",
    "out_of_map": "单位离开地图",
    "determinism_mismatch": "同种子复跑不一致",
    "nonzero_exit": "退出码非 0",
    "unknown_result": "未知胜负结果",
}


# ---------- 基础工具 ----------

def is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def percentile(values, p):
    """线性插值分位数（与 numpy 默认一致），p 取 0–100。"""
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return float(ordered[0])
    pos = (len(ordered) - 1) * p / 100.0
    low = int(math.floor(pos))
    high = int(math.ceil(pos))
    if low == high:
        return float(ordered[low])
    return float(ordered[low] * (high - pos) + ordered[high] * (pos - low))


def stats_block(values):
    if not values:
        return None
    return {
        "n": len(values),
        "mean": round(sum(values) / len(values), 4),
        "p50": round(percentile(values, 50), 4),
        "p90": round(percentile(values, 90), 4),
        "min": round(min(values), 4),
        "max": round(max(values), 4),
    }


def mean_or_none(values):
    return round(sum(values) / len(values), 4) if values else None


def fmt(value, digits=2):
    if value is None:
        return "—"
    if isinstance(value, float):
        return ("%." + str(digits) + "f") % value
    return str(value)


def fmt_pct(value):
    return "—" if value is None else "%.1f%%" % (value * 100.0)


# ---------- 记录读取 ----------

def load_jsonl(path):
    records = []
    with open(path, "r", encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except ValueError as exc:
                print("[警告] %s:%d 不是合法 JSON，已跳过（%s）" % (path, lineno, exc),
                      file=sys.stderr)
                continue
            if isinstance(record, dict):
                records.append(record)
    return records


def load_meta(path):
    if not path or not os.path.isfile(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def find_latest_runs():
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    pattern = os.path.join(root, "reports", "sim", "*", "runs.jsonl")
    candidates = glob.glob(pattern)
    if not candidates:
        return None
    return max(candidates, key=lambda p: os.path.getmtime(p))


# ---------- 异常判定 ----------

def _vec3(value):
    if isinstance(value, dict):
        if all(k in value for k in ("x", "y", "z")):
            nums = (value["x"], value["y"], value["z"])
            if all(is_number(v) for v in nums):
                return tuple(float(v) for v in nums)
        return None
    if isinstance(value, (list, tuple)) and len(value) >= 3:
        nums = value[:3]
        if all(is_number(v) for v in nums):
            return tuple(float(v) for v in nums)
    return None


def extract_positions(result):
    """返回 (positions, available)。支持 positions / units / squads 三种载体。"""
    positions = []
    available = False

    def add(value):
        nonlocal available
        vec = _vec3(value)
        if vec is not None:
            positions.append(vec)
            available = True
            return True
        return False

    if "positions" in result:
        available = True
        raw = result["positions"]
        if isinstance(raw, list):
            for item in raw:
                add(item)
        elif isinstance(raw, dict):
            for item in raw.values():
                add(item)

    for key in ("units", "squads"):
        raw = result.get(key)
        if isinstance(raw, list):
            for entry in raw:
                if isinstance(entry, dict):
                    for pos_key in ("pos", "position", "center"):
                        if pos_key in entry:
                            add(entry[pos_key])
                            break
                else:
                    add(entry)
        elif isinstance(raw, dict):
            for entry in raw.values():
                if isinstance(entry, dict):
                    for pos_key in ("pos", "position", "center"):
                        if pos_key in entry:
                            add(entry[pos_key])
                            break
                else:
                    add(entry)
    return positions, available


def find_nonfinite(value, path="result", out=None):
    if out is None:
        out = []
    if isinstance(value, float) and not math.isfinite(value):
        out.append(path)
    elif isinstance(value, dict):
        for key, item in value.items():
            find_nonfinite(item, "%s.%s" % (path, key), out)
    elif isinstance(value, list):
        for idx, item in enumerate(value):
            find_nonfinite(item, "%s[%d]" % (path, idx), out)
    return out


def evaluate_run(record, quit_at, map_size=MAP_SIZE_DEFAULT):
    """对单局做异常判定。返回 reasons/messages 与坐标检查可用性。"""
    reasons = []
    messages = []

    def add(reason, message):
        if reason not in reasons:
            reasons.append(reason)
        messages.append(message)

    result = record.get("result")
    if not isinstance(result, dict):
        detail = "退出码 %s" % record.get("exit_code", "?")
        if record.get("timed_out"):
            detail += "，看门狗判定超时"
        if record.get("result_parse_error"):
            detail += "，RESULT 解析失败：%s" % record["result_parse_error"]
        add("missing_result", "没有 RESULT（%s）" % detail)

    if record.get("script_errors"):
        errors = record["script_errors"]
        add("script_error", "脚本错误 %d 条：%s" % (len(errors), errors[0]))
    if int(record.get("hitch_count") or 0) > HITCH_ALLOWED:
        add("hitch", "HITCH %d 次：%s" % (
            int(record.get("hitch_count") or 0),
            (record.get("hitch_lines") or ["?"])[0]))
    if int(record.get("exit_code", 0) or 0) != 0:
        add("nonzero_exit", "退出码 %s" % record.get("exit_code"))

    coord_available = False
    if not isinstance(result, dict):
        return {
            "reasons": reasons,
            "messages": messages,
            "coord_available": False,
            "time": None,
            "banner": "",
        }

    banner = result.get("banner") or ""
    run_time = result.get("time") if is_number(result.get("time")) else None
    if banner == "":
        if run_time is not None:
            add("unresolved", "time=%ss，banner 为空（quit_at=%ss）" % (run_time, quit_at))
        else:
            add("unresolved", "banner 为空且没有 time")
    elif banner not in WIN_BANNERS and banner not in LOSS_BANNERS:
        add("unknown_result", "未知 banner：%s" % banner)

    stats = result.get("stats")
    stats = stats if isinstance(stats, dict) else {}
    window = min(run_time, float(quit_at)) if run_time is not None else float(quit_at)
    if window >= NO_ENGAGE_WINDOW_S - UNRESOLVED_TOLERANCE_S:
        engagement = 0
        for key in ENGAGEMENT_STATS:
            value = stats.get(key, 0)
            if is_number(value):
                engagement += value
        if engagement == 0:
            add("no_engagement", "%ss 内 hit/parry/clash/counter 全为 0" % fmt(window, 1))

    bad_values = find_nonfinite(result)
    if bad_values:
        add("nan_value", "NaN/Inf：%s" % "、".join(bad_values[:5]))

    positions, coord_available = extract_positions(result)
    if coord_available:
        size = result.get("map_size")
        size = float(size) if is_number(size) else float(map_size)
        bad_coords = []
        outside = []
        for idx, (x, y, z) in enumerate(positions):
            if not (math.isfinite(x) and math.isfinite(y) and math.isfinite(z)):
                bad_coords.append("#%d(%s,%s,%s)" % (idx, x, y, z))
                continue
            if (x < -MAP_MARGIN or x > size + MAP_MARGIN or
                    z < -MAP_MARGIN or z > size + MAP_MARGIN or
                    y < Y_MIN or y > Y_MAX):
                outside.append("#%d(%s,%s,%s)" % (
                    idx, fmt(x, 1), fmt(y, 1), fmt(z, 1)))
        if bad_coords:
            add("nan_coord", "坐标 NaN/Inf：%s" % "、".join(bad_coords[:5]))
        if outside:
            add("out_of_map", "单位离开地图 [0,%s]：%s" % (
                fmt(size, 1), "、".join(outside[:5])))

    return {
        "reasons": reasons,
        "messages": messages,
        "coord_available": coord_available,
        "time": run_time,
        "banner": banner,
    }


# ---------- 汇总 ----------

def build_summary(records, meta, quit_at, map_size=MAP_SIZE_DEFAULT):
    mains = [r for r in records if r.get("kind", "main") == "main"]
    rechecks = [r for r in records if r.get("kind") == "recheck"]
    mains.sort(key=lambda r: (r.get("index", 0), r.get("seed", 0)))
    rechecks.sort(key=lambda r: (r.get("pair_index") or 0, r.get("seed", 0)))

    completed = [r for r in mains if isinstance(r.get("result"), dict)]
    missing = len(mains) - len(completed)

    banners = [(r["result"].get("banner") or "") for r in completed]
    wins = sum(1 for b in banners if b in WIN_BANNERS)
    losses = sum(1 for b in banners if b in LOSS_BANNERS)
    unresolved = sum(1 for b in banners if b == "")
    other = len(completed) - wins - losses - unresolved
    decided = wins + losses

    if not meta:
        meta = {}
    meta_quit = meta.get("quit_at")
    if is_number(meta_quit):
        quit_at = float(meta_quit)
    meta_squads = {}
    for squad in meta.get("squads", []):
        if isinstance(squad, dict) and squad.get("title") is not None:
            meta_squads[str(squad["title"])] = squad

    # --- 异常 ---
    evaluations = {}
    anomalies = {}
    for record in mains:
        index = record.get("index")
        evaluation = evaluate_run(record, quit_at, map_size)
        evaluations[index] = evaluation
        if evaluation["reasons"]:
            anomalies[index] = {
                "index": index,
                "seed": record.get("seed"),
                "time": evaluation["time"],
                "banner": evaluation["banner"],
                "reasons": list(evaluation["reasons"]),
                "messages": list(evaluation["messages"]),
                "log": record.get("log"),
            }

    # --- 同种子复跑 ---
    main_by_index = {r.get("index"): r for r in mains}
    det_items = []
    det_matched = 0
    for record in rechecks:
        pair = record.get("pair_index")
        main = main_by_index.get(pair)
        main_raw = main.get("result_raw") if isinstance(main, dict) else None
        recheck_raw = record.get("result_raw")
        match = bool(main_raw and recheck_raw and main_raw == recheck_raw)
        if match:
            det_matched += 1
        issues = []
        if not isinstance(record.get("result"), dict):
            issues.append("复跑没有 RESULT")
        if record.get("script_errors"):
            issues.append("复跑有脚本错误")
        if record.get("timed_out"):
            issues.append("复跑超时")
        item = {
            "index": pair,
            "seed": record.get("seed"),
            "match": match,
            "recheck_issues": issues,
            "recheck_hitch": int(record.get("hitch_count") or 0),
            "main_result": main_raw,
            "recheck_result": recheck_raw,
        }
        det_items.append(item)
        if not match and isinstance(main, dict):
            entry = anomalies.setdefault(pair, {
                "index": pair,
                "seed": main.get("seed"),
                "time": evaluations.get(pair, {}).get("time"),
                "banner": evaluations.get(pair, {}).get("banner", ""),
                "reasons": list(evaluations.get(pair, {}).get("reasons", [])),
                "messages": list(evaluations.get(pair, {}).get("messages", [])),
                "log": main.get("log"),
            })
            if "determinism_mismatch" not in entry["reasons"]:
                entry["reasons"].append("determinism_mismatch")
            detail = "seed=%s 复跑 RESULT 与主跑不一致" % record.get("seed")
            if issues:
                detail += "（%s）" % "、".join(issues)
            entry["messages"].append(detail)

    anomalies = dict(sorted(anomalies.items(), key=lambda kv: (kv[0] is None, kv[0])))
    reason_counter = Counter()
    for entry in anomalies.values():
        for reason in entry["reasons"]:
            reason_counter[reason] += 1

    # --- 用时 ---
    all_times = [float(r["result"]["time"]) for r in completed
                 if is_number(r["result"].get("time"))]
    decided_times = [float(r["result"]["time"]) for r in completed
                     if is_number(r["result"].get("time"))
                     and (r["result"].get("banner") or "") in WIN_BANNERS + LOSS_BANNERS]

    # --- 剩余人数 ---
    total_alive = []
    player_alive = []
    defender_alive = []
    alive_titles = set(meta_squads.keys())
    for record in completed:
        result = record["result"]
        alive = result.get("alive")
        if isinstance(alive, dict):
            row_total = 0
            for title, count in alive.items():
                if not is_number(count):
                    continue
                row_total += count
                alive_titles.add(str(title))
            total_alive.append(float(row_total))
        faction = record.get("alive_by_faction")
        if isinstance(faction, dict):
            player = faction.get("player")
            defender = faction.get("defender")
            if is_number(player) and is_number(defender) and (player + defender) > 0:
                player_alive.append(float(player))
                defender_alive.append(float(defender))

    # 同一配置下每局都有这些队伍；某局 alive 里缺项按 0 计。
    per_squad_out = {}
    for title in sorted(alive_titles):
        values = []
        for record in completed:
            alive = record["result"].get("alive")
            if not isinstance(alive, dict):
                continue
            count = alive.get(title, 0)
            values.append(float(count) if is_number(count) else 0.0)
        squad_meta = meta_squads.get(title, {})
        per_squad_out[title] = {
            "mean": mean_or_none(values),
            "samples": len(values),
            "faction": squad_meta.get("faction"),
            "is_player": squad_meta.get("is_player"),
        }
    alive_out = {
        "samples": len(total_alive),
        "mean_total": mean_or_none(total_alive),
        "mean_player": mean_or_none(player_alive),
        "mean_defender": mean_or_none(defender_alive),
        "per_squad": per_squad_out,
    }

    # --- STATS ---
    stat_keys = set()
    for record in completed:
        stats = record["result"].get("stats")
        if isinstance(stats, dict):
            stat_keys.update(str(k) for k in stats.keys())
    stats_out = {}
    for key in sorted(stat_keys):
        values = []
        for record in completed:
            stats = record["result"].get("stats")
            value = stats.get(key, 0) if isinstance(stats, dict) else 0
            values.append(float(value) if is_number(value) else 0.0)
        block = stats_block(values)
        if block is not None:
            stats_out[key] = block

    coord_available = any(ev.get("coord_available") for ev in evaluations.values())
    coordinate_check = {
        "available": coord_available,
        "map_size": float(map_size),
        "why": None if coord_available else "RESULT 未包含 positions/units/squads 坐标字段（需 handoff 改 main.gd）",
    }

    counts = {
        "total": len(mains),
        "completed": len(completed),
        "missing_result": missing,
        "wins": wins,
        "losses": losses,
        "unresolved": unresolved,
        "other": other,
        "win_rate": round(wins / len(completed), 4) if completed else None,
        "win_rate_decided": round(wins / decided, 4) if decided else None,
        "runs_with_script_error": sum(1 for r in mains if r.get("script_errors")),
        "runs_with_hitch": sum(1 for r in mains if int(r.get("hitch_count") or 0) > HITCH_ALLOWED),
        "anomaly_runs": len(anomalies),
    }

    batch = {
        "config": meta.get("config"),
        "config_arg": meta.get("config_arg"),
        "battle_id": meta.get("battle_id"),
        "requested": meta.get("requested", len(mains)),
        "seed_start": meta.get("seed_start"),
        "seed_end": meta.get("seed_end"),
        "jobs": meta.get("jobs"),
        "quit_at": quit_at,
        "recheck": meta.get("recheck"),
        "cores": meta.get("cores"),
        "godot": meta.get("godot"),
        "git_commit": meta.get("git_commit"),
        "started_at": meta.get("started_at"),
        "finished_at": meta.get("finished_at"),
        "batch_dir": meta.get("batch_dir"),
        "squads": meta.get("squads", []),
    }

    summary = {
        "task": "T60",
        "generated_at": None,  # 由 main() 填
        "batch": batch,
        "counts": counts,
        "time": stats_block(all_times),
        "time_decided": stats_block(decided_times),
        "alive": alive_out,
        "stats": stats_out,
        "determinism": {
            "checked": len(det_items),
            "matched": det_matched,
            "expected_sample": DETERMINISM_SAMPLE,
            "items": det_items,
        },
        "coordinate_check": coordinate_check,
        "anomaly_summary": dict(sorted(reason_counter.items())),
        "anomalies": list(anomalies.values()),
    }
    return summary


# ---------- Markdown ----------

def render_markdown(summary):
    batch = summary["batch"]
    counts = summary["counts"]
    lines = []
    add = lines.append

    add("# 批量模拟摘要")
    add("")
    add("- 批次目录：`%s`" % (batch.get("batch_dir") or "—"))
    add("- 战斗配置：`%s`（battle id `%s`）" % (
        batch.get("config") or "—", batch.get("battle_id") or "—"))
    seed_start = batch.get("seed_start")
    seed_end = batch.get("seed_end")
    if seed_start is not None and seed_end is not None:
        add("- 种子：%s–%s（%s 局）" % (seed_start, seed_end, counts["total"]))
    else:
        add("- 局数：%s" % counts["total"])
    add("- 并行：%s；quit_at：%ss；复跑抽查：%s 局" % (
        fmt(batch.get("jobs")), fmt(batch.get("quit_at")),
        summary["determinism"]["checked"]))
    add("- 完成：%d/%d；缺失 RESULT：%d；异常局：%d" % (
        counts["completed"], counts["total"], counts["missing_result"],
        counts["anomaly_runs"]))
    add("- 复跑一致：%d/%d" % (
        summary["determinism"]["matched"], summary["determinism"]["checked"]))
    if summary.get("generated_at"):
        add("- 生成时间：%s" % summary["generated_at"])
    add("")

    add("## 胜负")
    add("")
    add("| 结果 | 局数 | 占比 |")
    add("|---|---:|---:|")
    completed = counts["completed"] or 0

    def pct(n):
        return fmt_pct(n / completed) if completed else "—"

    add("| 王旗已夺取（胜） | %d | %s |" % (counts["wins"], pct(counts["wins"])))
    add("| 亡魂散尽（负） | %d | %s |" % (counts["losses"], pct(counts["losses"])))
    add("| 到时间未分胜负 | %d | %s |" % (counts["unresolved"], pct(counts["unresolved"])))
    if counts["other"]:
        add("| 其他结果 | %d | %s |" % (counts["other"], pct(counts["other"])))
    if counts["missing_result"]:
        add("| 没有 RESULT | %d | — |" % counts["missing_result"])
    add("")
    add("胜率（全部完成局）：**%s**（%d/%d）；已分胜负局胜率：**%s**（%d/%d）" % (
        fmt_pct(counts["win_rate"]), counts["wins"], counts["completed"],
        fmt_pct(counts["win_rate_decided"]), counts["wins"],
        counts["wins"] + counts["losses"]))
    add("")

    add("## 用时（秒）")
    add("")
    add("| 指标 | 全部完成局 | 已分胜负 |")
    add("|---|---:|---:|")
    for label, key in (("平均", "mean"), ("p50", "p50"), ("p90", "p90"),
                       ("最小", "min"), ("最大", "max")):
        all_block = summary.get("time") or {}
        dec_block = summary.get("time_decided") or {}
        add("| %s | %s | %s |" % (
            label, fmt(all_block.get(key)), fmt(dec_block.get(key))))
    add("")

    alive = summary.get("alive") or {}
    add("## 剩余人数（平均）")
    add("")
    add("- 玩家平均剩余：%s" % fmt(alive.get("mean_player")))
    add("- 守军平均剩余：%s" % fmt(alive.get("mean_defender")))
    add("- 双方合计：%s（%s 个样本）" % (
        fmt(alive.get("mean_total")), alive.get("samples", 0)))
    add("")
    per_squad = alive.get("per_squad") or {}
    if per_squad:
        add("| 队伍 | 阵营 | 平均剩余 | 样本 |")
        add("|---|---|---:|---:|")
        for title, entry in per_squad.items():
            if entry.get("is_player") is True:
                side = "玩家"
            elif entry.get("is_player") is False:
                side = "守军"
            else:
                side = "未知"
            faction = entry.get("faction")
            if faction is not None:
                side += "（%s）" % faction
            add("| %s | %s | %s | %s |" % (
                title, side, fmt(entry.get("mean")), entry.get("samples", 0)))
        add("")

    add("## STATS 平均")
    add("")
    stats = summary.get("stats") or {}
    if not stats:
        add("没有可用的 STATS。")
    else:
        add("| STATS | 平均 | p50 | p90 | 样本 |")
        add("|---|---:|---:|---:|---:|")
        for key, block in stats.items():
            add("| %s | %s | %s | %s | %s |" % (
                key, fmt(block.get("mean")), fmt(block.get("p50")),
                fmt(block.get("p90")), block.get("n", 0)))
    add("")

    det = summary.get("determinism") or {}
    add("## 同种子复跑")
    add("")
    if not det.get("checked"):
        add("未做复跑抽查（--no-recheck）。")
    else:
        add("抽查 %d 局，一致 %d 局。" % (det.get("checked", 0), det.get("matched", 0)))
        add("")
        add("| seed | 结果 | 说明 |")
        add("|---:|---|---|")
        for item in det.get("items", []):
            state = "一致" if item.get("match") else "**不一致**"
            note = "、".join(item.get("recheck_issues") or [])
            if item.get("recheck_hitch"):
                note = (note + "；" if note else "") + "复跑 HITCH %d 次" % item["recheck_hitch"]
            add("| %s | %s | %s |" % (item.get("seed"), state, note or "—"))
    add("")

    if not summary.get("coordinate_check", {}).get("available"):
        add("> 坐标检查不可用：%s" % summary["coordinate_check"].get("why"))
        add("")

    add("## 异常局")
    add("")
    anomalies = summary.get("anomalies") or []
    if not anomalies:
        add("无异常局。")
    else:
        add("共 %d 局异常。" % len(anomalies))
        add("")
        add("| # | 类型 | seed | 说明 | 日志 |")
        add("|---:|---|---:|---|---|")
        for entry in anomalies:
            kinds = "、".join(REASON_LABELS.get(r, r) for r in entry.get("reasons", []))
            details = "；".join(entry.get("messages", []))
            log = entry.get("log") or "—"
            add("| %s | %s | %s | %s | `%s` |" % (
                entry.get("index"), kinds, entry.get("seed"), details, log))
        add("")
        add("按类型统计：" + "，".join(
            "%s %d" % (REASON_LABELS.get(k, k), v)
            for k, v in (summary.get("anomaly_summary") or {}).items()))
    add("")
    return "\n".join(lines)


# ---------- CLI ----------

def main(argv=None):
    parser = argparse.ArgumentParser(description="汇总批量对战 runs.jsonl")
    parser.add_argument("runs", nargs="?", help="runs.jsonl 路径；省略则取最新批次")
    parser.add_argument("--input", dest="input_opt", help="同 runs")
    parser.add_argument("--out-dir", help="输出目录，默认与 runs.jsonl 同目录")
    parser.add_argument("--meta", help="meta.json 路径，默认同目录 meta.json")
    parser.add_argument("--quit-at", type=float, default=None,
                        help="未分胜负判定阈值（秒），默认读 meta 或 60")
    parser.add_argument("--map-size", type=float, default=None,
                        help="地图边长，默认读 RESULT.map_size 或 24")
    args = parser.parse_args(argv)

    runs_path = args.input_opt or args.runs
    if not runs_path:
        runs_path = find_latest_runs()
        if not runs_path:
            print("[错误] 没找到 reports/sim/*/runs.jsonl，请显式传入路径", file=sys.stderr)
            return 2
    runs_path = os.path.abspath(runs_path)
    if not os.path.isfile(runs_path):
        print("[错误] 找不到 runs.jsonl：%s" % runs_path, file=sys.stderr)
        return 2

    out_dir = os.path.abspath(args.out_dir) if args.out_dir else os.path.dirname(runs_path)
    os.makedirs(out_dir, exist_ok=True)
    meta_path = args.meta or os.path.join(os.path.dirname(runs_path), "meta.json")
    meta = load_meta(meta_path)
    quit_at = args.quit_at
    if quit_at is None:
        quit_at = float(meta.get("quit_at", 60)) if is_number(meta.get("quit_at")) else 60.0
    map_size = args.map_size
    if map_size is None:
        map_size = float(meta.get("map_size", MAP_SIZE_DEFAULT)) \
            if is_number(meta.get("map_size")) else MAP_SIZE_DEFAULT

    records = load_jsonl(runs_path)
    if not records:
        print("[错误] runs.jsonl 没有记录：%s" % runs_path, file=sys.stderr)
        return 2

    summary = build_summary(records, meta, quit_at, map_size)
    summary["generated_at"] = datetime.datetime.now().astimezone().isoformat(
        timespec="seconds")
    summary["inputs"] = {
        "runs": os.path.relpath(runs_path, os.getcwd()) if runs_path.startswith(os.getcwd()) else runs_path,
        "meta": os.path.relpath(meta_path, os.getcwd()) if os.path.isfile(meta_path) else None,
    }

    json_path = os.path.join(out_dir, "summary.json")
    md_path = os.path.join(out_dir, "summary.md")
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(summary, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    with open(md_path, "w", encoding="utf-8") as fh:
        fh.write(render_markdown(summary))
        fh.write("\n")

    print("summary.json -> %s" % json_path)
    print("summary.md   -> %s" % md_path)
    print("局数 %d，完成 %d，缺失 %d，异常 %d，胜率 %s" % (
        summary["counts"]["total"], summary["counts"]["completed"],
        summary["counts"]["missing_result"], summary["counts"]["anomaly_runs"],
        fmt_pct(summary["counts"]["win_rate"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
