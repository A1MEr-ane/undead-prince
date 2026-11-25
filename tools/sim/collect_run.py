#!/usr/bin/env python3
"""T60：把一局无头对战的日志解析成 runs.jsonl 里的一条记录。

只读日志，不改游戏。RESULT 行保留原文（result_raw），供同种子复跑做逐字比较。
"""

import argparse
import json
import os
import re
import sys

SCRIPT_ERROR_RE = re.compile(r"^(?:SCRIPT ERROR:|Parse Error:)")
HITCH_RE = re.compile(r"^HITCH\b")
RESULT_PREFIX = "RESULT "
STATS_PREFIX = "STATS "


def read_log(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read().splitlines()
    except OSError as exc:
        return ["[collect_run] 无法读取日志 %s: %s" % (path, exc)]


def load_squad_factions(config_path):
    """title -> is_player；用于把 alive 分成玩家/守军。"""
    try:
        with open(config_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return {}
    mapping = {}
    for squad in data.get("squads", []):
        if isinstance(squad, dict) and squad.get("title") is not None:
            mapping[str(squad["title"])] = bool(squad.get("is_player"))
    return mapping


def split_alive(result, factions):
    if not isinstance(result, dict):
        return None
    alive = result.get("alive")
    if not isinstance(alive, dict):
        return None
    player = 0
    defender = 0
    unknown = 0
    for title, count in alive.items():
        try:
            count = int(count)
        except (TypeError, ValueError):
            continue
        side = factions.get(str(title))
        if side is True:
            player += count
        elif side is False:
            defender += count
        else:
            unknown += count
    return {"player": player, "defender": defender, "unknown": unknown}


def parse_run(log_path):
    lines = read_log(log_path)
    result = None
    result_raw = None
    result_error = None
    stats_line = None
    hitches = []
    errors = []
    timed_out = False

    for line in lines:
        if line.startswith(RESULT_PREFIX):
            raw = line[len(RESULT_PREFIX):].strip()
            try:
                parsed = json.loads(raw)
            except ValueError as exc:
                result_error = "%s: %s" % (type(exc).__name__, exc)
                result = None
                result_raw = raw
            else:
                if isinstance(parsed, dict):
                    result = parsed
                    result_raw = raw
                    result_error = None
                else:
                    result_error = "RESULT 不是 JSON 对象"
        elif line.startswith(STATS_PREFIX):
            stats_line = line.strip()
        if HITCH_RE.match(line):
            hitches.append(line.strip())
        if SCRIPT_ERROR_RE.match(line):
            errors.append(line.strip())
        if line.startswith("WATCHDOG:"):
            timed_out = True

    tail = [ln.rstrip() for ln in lines if ln.strip()][-20:]
    return {
        "result": result,
        "result_raw": result_raw,
        "result_parse_error": result_error,
        "stats_line": stats_line,
        "hitch_count": len(hitches),
        "hitch_lines": hitches[:10],
        "script_errors": errors[:20],
        "timed_out": timed_out,
        "log_tail": tail,
    }


def display_path(path, root):
    try:
        rel = os.path.relpath(path, root)
    except ValueError:
        return path
    return rel


def main(argv=None):
    parser = argparse.ArgumentParser(description="解析一局无头对战日志")
    parser.add_argument("--log", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--index", required=True)
    parser.add_argument("--seed", required=True, type=int)
    parser.add_argument("--kind", default="main", choices=["main", "recheck"])
    parser.add_argument("--pair-index", default="")
    parser.add_argument("--exit-code", required=True, type=int)
    parser.add_argument("--duration-s", required=True, type=float)
    parser.add_argument("--config", required=True)
    parser.add_argument("--battle-id", required=True)
    parser.add_argument("--label", default="")
    args = parser.parse_args(argv)

    parsed = parse_run(args.log)
    pair_index = None
    if args.pair_index != "":
        try:
            pair_index = int(args.pair_index)
        except ValueError:
            pair_index = None

    factions = load_squad_factions(args.config)
    alive_by_faction = split_alive(parsed["result"], factions)
    root = os.getcwd()
    record = {
        "index": int(args.index),
        "kind": args.kind,
        "pair_index": pair_index,
        "seed": args.seed,
        "battle_id": args.battle_id,
        "config": display_path(args.config, root),
        "exit_code": args.exit_code,
        "duration_s": args.duration_s,
        "timed_out": parsed["timed_out"],
        "result": parsed["result"],
        "result_raw": parsed["result_raw"],
        "result_parse_error": parsed["result_parse_error"],
        "stats_line": parsed["stats_line"],
        "hitch_count": parsed["hitch_count"],
        "hitch_lines": parsed["hitch_lines"],
        "script_errors": parsed["script_errors"],
        "alive_by_faction": alive_by_faction,
        "log": display_path(args.log, root),
        "log_tail": parsed["log_tail"],
    }
    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(record, fh, ensure_ascii=False)
        fh.write("\n")

    label = args.label or ("%s #%s" % (args.kind, args.index))
    result = record["result"]
    if result is not None:
        banner = result.get("banner") or "未分胜负"
        print("[%s] seed=%s exit=%s %.2fs -> %s time=%ss hitch=%d err=%d" % (
            label, args.seed, args.exit_code, args.duration_s, banner,
            result.get("time", "?"), record["hitch_count"],
            len(record["script_errors"])))
    else:
        why = "超时" if record["timed_out"] else "无 RESULT"
        print("[%s] seed=%s exit=%s %.2fs -> %s%s" % (
            label, args.seed, args.exit_code, args.duration_s, why,
            "（解析失败）" if record["result_parse_error"] else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
