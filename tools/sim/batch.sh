#!/bin/bash
# T60：批量无头对战 → 汇总 → 异常检测。
#
# 用法：
#   tools/sim/batch.sh N [起始种子] [配置文件]
#   tools/sim/batch.sh N --config data/battles/foo.json [--seed 1] [--jobs 4] [--quit-at 60]
#
# 默认并行数 = CPU 核数一半（macOS 用 sysctl，Linux 用 nproc）。
# 每局 RESULT 写到 reports/sim/<时间>/runs.jsonl，跑完自动生成 summary.json/summary.md。
# 配置文件可在项目内任意 .json；T49 的 data/battles/sweep_*.json 最省事。
# 实际传给 main.gd 的是 --battle=<相对 data/battles/ 的路径>。
# 最后会自动抽 3 个种子复跑，比较 RESULT 是否逐字一致；--no-recheck 可跳过。
set -u

cd "$(dirname "$0")/../.." || exit 2
ROOT=$(pwd -P)
GODOT=${GODOT:-godot}

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  echo "[错误] $*" >&2
  exit 2
}

# ---------- 参数 ----------
[ $# -ge 1 ] || { usage >&2; exit 2; }
case "$1" in
  -h|--help) usage; exit 0;;
esac
N=$1; shift
case "$N" in
  ''|*[!0-9]*) die "局数 N 必须是正整数：$N";;
esac
[ "$N" -gt 0 ] || die "局数 N 必须大于 0"

START_SEED=1
START_SEED_SET=0
CONFIG_ARG=""
CONFIG_SET=0
RECHECK=1
QUIT_AT=60

# 默认并行数：CPU 核数一半，至少 1。
if CORES=$(sysctl -n hw.ncpu 2>/dev/null); then
  :
elif CORES=$(nproc 2>/dev/null); then
  :
else
  CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
fi
case "$CORES" in ''|*[!0-9]*) CORES=2;; esac
JOBS=$((CORES / 2))
[ "$JOBS" -lt 1 ] && JOBS=1

while [ $# -gt 0 ]; do
  case "$1" in
    --config)
      [ $# -ge 2 ] || die "--config 缺少路径"
      CONFIG_ARG=$2; CONFIG_SET=1; shift 2;;
    --config=*)
      CONFIG_ARG=${1#--config=}; CONFIG_SET=1; shift;;
    --seed)
      [ $# -ge 2 ] || die "--seed 缺少数值"
      START_SEED=$2; START_SEED_SET=1; shift 2;;
    --seed=*)
      START_SEED=${1#--seed=}; START_SEED_SET=1; shift;;
    --jobs)
      [ $# -ge 2 ] || die "--jobs 缺少数值"
      JOBS=$2; shift 2;;
    --jobs=*)
      JOBS=${1#--jobs=}; shift;;
    --quit-at|--quit_at)
      [ $# -ge 2 ] || die "${1} 缺少数值"
      QUIT_AT=$2; shift 2;;
    --quit-at=*|--quit_at=*)
      QUIT_AT=${1#*=}; shift;;
    --no-recheck)
      RECHECK=0; shift;;
    -h|--help)
      usage; exit 0;;
    -*)
      die "未知参数：$1";;
    *)
      if [ "$START_SEED_SET" -eq 0 ] && echo "$1" | grep -Eq '^[0-9]+$'; then
        START_SEED=$1; START_SEED_SET=1
      elif [ "$CONFIG_SET" -eq 0 ]; then
        CONFIG_ARG=$1; CONFIG_SET=1
      else
        die "多余参数：$1"
      fi
      shift;;
  esac
done

case "$START_SEED" in ''|*[!0-9]*) die "起始种子必须是整数：$START_SEED";; esac
case "$JOBS" in ''|*[!0-9]*) die "--jobs 必须是整数：$JOBS";; esac
case "$QUIT_AT" in ''|*[!0-9]*) die "--quit-at 必须是整数秒：$QUIT_AT";; esac
[ "$JOBS" -gt 0 ] || die "--jobs 必须大于 0"
[ "$QUIT_AT" -gt 0 ] || die "--quit-at 必须大于 0"

# 配置文件解析：允许 proto / proto.json / 项目内任意 .json。
# main.gd 只认 --battle=<id>（相对 data/battles/ 的路径），所以这里把路径换算成 id。
[ "$CONFIG_SET" -eq 1 ] || CONFIG_ARG="data/battles/proto.json"
if [ ! -f "$CONFIG_ARG" ]; then
  if [ -f "data/battles/$CONFIG_ARG" ]; then
    CONFIG_ARG="data/battles/$CONFIG_ARG"
  elif [ -f "data/battles/$CONFIG_ARG.json" ]; then
    CONFIG_ARG="data/battles/$CONFIG_ARG.json"
  else
    die "找不到战斗配置：$CONFIG_ARG"
  fi
fi
case "$CONFIG_ARG" in
  *.json) ;;
  *) die "战斗配置必须是 .json：$CONFIG_ARG";;
esac
CONFIG_ABS=$(cd "$(dirname "$CONFIG_ARG")" && pwd -P)/$(basename "$CONFIG_ARG")
BATTLE_DIR_ABS="$ROOT/data/battles"
case "$CONFIG_ABS" in
  "$ROOT"/*) ;;
  *) die "配置必须在项目目录内：$CONFIG_ARG";;
esac
BATTLE_ID=$(python3 - "$CONFIG_ABS" "$BATTLE_DIR_ABS" <<'PY'
import os, sys
rel = os.path.relpath(sys.argv[1], sys.argv[2])
if rel.endswith(".json"):
    rel = rel[:-5]
print(rel)
PY
)
# 简单校验 JSON，避免跑到一半才发现配置坏了。
if ! python3 - "$CONFIG_ABS" <<'PY'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception as exc:
    print("[错误] 配置不是合法 JSON：%s (%s)" % (path, exc), file=sys.stderr)
    sys.exit(1)
if not isinstance(data, dict) or not isinstance(data.get("squads"), list) or not data["squads"]:
    print("[错误] 配置缺少非空 squads 数组：%s" % path, file=sys.stderr)
    sys.exit(1)
PY
then
  exit 2
fi

if ! command -v "$GODOT" >/dev/null 2>&1; then
  die "找不到 Godot 命令：$GODOT"
fi

# ---------- 输出目录 ----------
TS=$(date +%Y%m%d-%H%M%S)
OUT="$ROOT/reports/sim/$TS"
if [ -e "$OUT" ]; then
  OUT="$OUT-$$"
fi
mkdir -p "$OUT/logs" "$OUT/records" || exit 2

# 新 worktree 没有全局类缓存：不先导入会解析失败且主脚本不加载、进程永不退出。
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  echo "首次运行：导入 Godot 项目缓存…"
  if ! "$GODOT" --headless --path "$ROOT" --import >"$OUT/import.log" 2>&1; then
    echo "[错误] godot --import 失败，见 $OUT/import.log" >&2
    exit 2
  fi
fi

STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GODOT_VERSION=$("$GODOT" --version 2>/dev/null | head -1 || echo "unknown")
export OUT CONFIG_ABS BATTLE_ID STARTED_AT GIT_COMMIT GODOT_VERSION

write_meta() {
  local finished=${1:-}
  python3 - "$OUT/meta.json" "$N" "$START_SEED" "$JOBS" "$QUIT_AT" \
    "$CONFIG_ARG" "$CONFIG_ABS" "$BATTLE_ID" "$OUT" "$ROOT" \
    "$STARTED_AT" "$finished" "$GIT_COMMIT" "$CORES" "$GODOT_VERSION" "$RECHECK" <<'PY'
import json, os, sys
(out, n, seed, jobs, quit_at, config_arg, config_abs, battle_id,
 out_dir, root, started, finished, commit, cores, godot_version, recheck) = sys.argv[1:]
try:
    cfg = json.load(open(config_abs, encoding="utf-8"))
except Exception:
    cfg = {}
squads = []
for s in cfg.get("squads", []):
    if isinstance(s, dict):
        squads.append({
            "title": s.get("title"),
            "faction": s.get("faction"),
            "is_player": bool(s.get("is_player")),
        })
meta = {
    "task": "T60",
    "batch_dir": os.path.relpath(out_dir, root),
    "config_arg": config_arg,
    "config": os.path.relpath(config_abs, root),
    "battle_id": battle_id,
    "requested": int(n),
    "seed_start": int(seed),
    "seed_end": int(seed) + int(n) - 1,
    "jobs": int(jobs),
    "quit_at": int(quit_at),
    "recheck": recheck == "1",
    "cores": int(cores),
    "godot": godot_version,
    "git_commit": commit,
    "started_at": started,
    "finished_at": finished,
    "squads": squads,
}
with open(out, "w", encoding="utf-8") as fh:
    json.dump(meta, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
}
write_meta ""

# ---------- 单局 ----------
run_one() {
  # $1=kind $2=index(3位) $3=seed $4=pair_index $5=进度标签
  local kind=$1 idx=$2 seed=$3 pair=$4 label=$5
  local log="$OUT/logs/${kind}_${idx}_seed${seed}.log"
  local rec="$OUT/records/${kind}_${idx}.json"
  local t0 t1 dur code pid wd
  t0=$(python3 -c 'import time; print(time.time())')
  "$GODOT" --headless --path "$ROOT" -- --auto --quit_at="$QUIT_AT" --quit_on_end \
    --seed="$seed" --battle="$BATTLE_ID" >"$log" 2>&1 &
  pid=$!
  # 看门狗：主脚本加载失败时会挂住；正常情况下 quit_at 秒内必定退出。
  # 看门狗：主脚本加载失败时会挂住；正常情况下 quit_at 秒内必定退出。
  # stdout/stderr 必须重定向，否则 sleep 子进程会继承批量脚本的管道，
  # 让调用方（例如 `batch.sh ... | grep`）一直等到 sleep 结束。
  (
    sleep $((QUIT_AT + 120))
    if kill -0 "$pid" 2>/dev/null; then
      echo "WATCHDOG: 超过 $((QUIT_AT + 120)) 秒仍未退出" >>"$log"
      kill "$pid" 2>/dev/null
    fi
  ) >/dev/null 2>&1 &
  wd=$!
  wait "$pid"
  code=$?
  # 先杀 sleep 子进程，避免留下 120 秒的孤儿进程。
  if command -v pkill >/dev/null 2>&1; then
    pkill -P "$wd" >/dev/null 2>&1 || true
  fi
  kill "$wd" 2>/dev/null || true
  wait "$wd" 2>/dev/null
  t1=$(python3 -c 'import time; print(time.time())')
  dur=$(python3 -c "print(round(float('$t1') - float('$t0'), 2))")
  if ! python3 "$ROOT/tools/sim/collect_run.py" \
      --log "$log" --output "$rec" --index "$idx" --seed "$seed" \
      --kind "$kind" --pair-index "$pair" --exit-code "$code" \
      --duration-s "$dur" --config "$CONFIG_ABS" --battle-id "$BATTLE_ID" \
      --label "$label"; then
    echo "[错误] 记录失败：$log" >&2
  fi
}

# ---------- 主跑 ----------
echo "批次：$OUT"
echo "配置：${CONFIG_ARG}（battle=${BATTLE_ID}）  种子：${START_SEED}–$((START_SEED + N - 1))  并行：${JOBS}  quit_at：${QUIT_AT}s"
i=0
while [ "$i" -lt "$N" ]; do
  launched=0
  while [ "$launched" -lt "$JOBS" ] && [ "$i" -lt "$N" ]; do
    seed=$((START_SEED + i))
    idx=$(printf '%03d' "$i")
    run_one main "$idx" "$seed" "" "main $((i + 1))/$N" &
    i=$((i + 1))
    launched=$((launched + 1))
  done
  wait
done

# ---------- 同种子复跑抽查 ----------
RE_INDICES=""
RE_COUNT=0
if [ "$RECHECK" -eq 1 ]; then
  if [ "$N" -le 3 ]; then
    RE_INDICES=$(seq 0 $((N - 1)))
  else
    RE_INDICES="0 $((N / 2)) $((N - 1))"
  fi
  RE_COUNT=$(echo "$RE_INDICES" | wc -w | tr -d ' ')
  echo "同种子复跑抽查：${RE_COUNT} 局（索引 ${RE_INDICES}）"
  for ri in $RE_INDICES; do
    seed=$((START_SEED + ri))
    idx=$(printf '%03d' "$ri")
    run_one recheck "$idx" "$seed" "$ri" "recheck seed=$seed"
  done
fi
write_meta "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---------- 汇总 ----------
: >"$OUT/runs.jsonl"
i=0
while [ "$i" -lt "$N" ]; do
  idx=$(printf '%03d' "$i")
  if [ -f "$OUT/records/main_$idx.json" ]; then
    cat "$OUT/records/main_$idx.json" >>"$OUT/runs.jsonl"
  else
    echo "[错误] 缺少记录：$OUT/records/main_$idx.json" >&2
    exit 1
  fi
  i=$((i + 1))
done
for ri in $RE_INDICES; do
  idx=$(printf '%03d' "$ri")
  if [ -f "$OUT/records/recheck_$idx.json" ]; then
    cat "$OUT/records/recheck_$idx.json" >>"$OUT/runs.jsonl"
  fi
done

if ! python3 "$ROOT/tools/sim/summarize.py" \
    --input "$OUT/runs.jsonl" --out-dir "$OUT" --meta "$OUT/meta.json" \
    --quit-at "$QUIT_AT"; then
  echo "[错误] 汇总失败" >&2
  exit 1
fi

echo ""
echo "批次目录：$OUT"
echo "摘要：$OUT/summary.md"
echo ""
cat "$OUT/summary.md"
echo ""

# 只有崩溃/脚本错误/全军覆没式的基础设施问题才让 batch 失败；
# HITCH、超时未分胜负等属于数据异常，写在 summary 里由调用者判断。
FAIL=$(python3 - "$OUT/summary.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
c = s["counts"]
bad = c["completed"] == 0 or c["missing_result"] > 0 or c["runs_with_script_error"] > 0
print(1 if bad else 0)
PY
)
if [ "$FAIL" -ne 0 ]; then
  echo "[失败] 批次存在崩溃/脚本错误/没有完成局，见 $OUT/summary.md" >&2
  exit 1
fi
exit 0
