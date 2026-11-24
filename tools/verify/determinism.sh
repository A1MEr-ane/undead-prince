#!/bin/bash
# 同种子可复现性检查：每个 seed 跑两次无头对战，逐字比较 RESULT 行。
# 用法：tools/verify/determinism.sh            （默认 seeds 1,2,3）
#       tools/verify/determinism.sh 2 7        （只查指定 seeds）
#       SEEDS="1 2 3" QUIT_AT=60 tools/verify/determinism.sh
# 全部一致退出 0；任一种子两次不一致、缺 RESULT 或提前崩溃退出 1。
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
GODOT=${GODOT:-godot}
QUIT_AT=${QUIT_AT:-60}
if [ $# -gt 0 ]; then
  SEEDS="$*"
else
  SEEDS=${SEEDS:-"1 2 3"}
fi

# 新 worktree 没有全局类缓存，不先导入会解析失败且主脚本不加载、进程永不退出。
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  echo "首次运行：导入项目缓存…"
  if ! "$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1; then
    echo "[失败] godot --import 失败"
    exit 2
  fi
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/t23-determinism.XXXXXX") || exit 2
FAIL=0

run_one() { # $1=seed $2=log
  local seed=$1 log=$2 pid wd code
  "$GODOT" --headless --path "$ROOT" -- --auto --quit_at="$QUIT_AT" --quit_on_end --seed="$seed" >"$log" 2>&1 &
  pid=$!
  # 看门狗：正常情况下 quit_at 秒内必定退出；主脚本加载失败时会挂住。
  ( sleep $((QUIT_AT + 120)); if kill -0 "$pid" 2>/dev/null; then
      echo "WATCHDOG: 超过 $((QUIT_AT + 120)) 秒仍未退出" >>"$log"
      kill "$pid" 2>/dev/null
    fi ) &
  wd=$!
  wait "$pid"
  code=$?
  kill "$wd" 2>/dev/null
  wait "$wd" 2>/dev/null
  return $code
}

for s in $SEEDS; do
  ok=1
  for run in 1 2; do
    LOG="$TMP/seed${s}_run${run}.log"
    run_one "$s" "$LOG"
    code=$?
    RESULT=$(grep '^RESULT ' "$LOG" | tail -1)
    if [ -z "$RESULT" ]; then
      echo "[失败] seed $s 第 $run 次没有 RESULT（退出码 $code）"
      tail -5 "$LOG" | sed 's/^/    /'
      FAIL=1
      ok=0
      continue
    fi
    printf '%s\n' "$RESULT" >"$TMP/seed${s}_run${run}.result"
  done
  if [ "$ok" -eq 1 ]; then
    if diff -u "$TMP/seed${s}_run1.result" "$TMP/seed${s}_run2.result" >"$TMP/seed${s}.diff"; then
      echo "[通过] seed $s 两次 RESULT 一致"
    else
      echo "[失败] seed $s 两次 RESULT 不一致："
      cat "$TMP/seed${s}.diff"
      FAIL=1
    fi
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo "日志保留在 $TMP"
  exit 1
fi
rm -rf "$TMP"
echo "全部通过：seeds [$SEEDS] 同种子结果一致"
exit 0
