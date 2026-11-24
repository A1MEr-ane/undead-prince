#!/bin/bash
# 按任务卡启动一个执行者（codex 或 dsh），在独立 worktree 里跑，结束后记一行指标。
# 用法：tools/agents/run_agent.sh tasks/T15-xxx.md [--fg]
#   默认后台运行；--fg 前台运行（调试用）。
# 前提：任务卡 front matter 里有 id/owner/branch/worktree；owner=dsh 需要已配置 DEEPSEEK_API_KEY。
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
CARD=$1; FG=${2:-}
[ -f "$CARD" ] || { echo "找不到任务卡 $CARD"; exit 2; }
field() { python3 -I -c '
import sys,re
t=open(sys.argv[1]).read(); m=re.search(r"^---\n(.*?)\n---",t,re.S)
for line in (m.group(1) if m else "").splitlines():
    k,_,v=line.partition(":")
    if k.strip()==sys.argv[2]: print(v.split("#")[0].strip()); break
' "$CARD" "$1"; }
ID=$(field id); OWNER=$(field owner); BRANCH=$(field branch); WT=$(field worktree)
[ -n "$ID" ] && [ -n "$OWNER" ] && [ -n "$BRANCH" ] && [ -n "$WT" ] || { echo "任务卡缺字段 id/owner/branch/worktree"; exit 2; }
WT=$(cd "$ROOT" && python3 -I -c 'import os,sys;print(os.path.abspath(sys.argv[1]))' "$WT")
mkdir -p reports/agents
LOG="$ROOT/reports/agents/$ID.log"; REPORT="$ROOT/reports/agents/$ID.md"

# 1. worktree（已存在就复用）
if [ ! -d "$WT" ]; then
  git worktree add -b "$BRANCH" "$WT" main >/dev/null 2>&1 || git worktree add "$WT" "$BRANCH" >/dev/null
fi

PROMPT="你是本项目的执行者。先读 AGENTS.md 和 docs/collab.md，再按下面的任务卡完成工作。
只修改 allowed 里的文件；verify 命令必须通过；自我修复最多 retry_limit 次，超过或遇到 escalate_if 的情况就停止并在报告里说明。
完成后把交付报告写到 $REPORT（格式见 docs/collab.md 第 4 节），并在分支 $BRANCH 上提交（提交失败就保留改动并在报告里说明）。

$(cat "$CARD")"

start=$(date +%s)
run() {
  case "$OWNER" in
    codex)
      /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex exec -C "$WT" -s workspace-write \
        --add-dir "$ROOT/.git" --add-dir "$ROOT/reports" --add-dir "$HOME/.codex" \
        "$PROMPT" >"$LOG" 2>&1 ;;
    dsh)
      (cd "$WT" && "/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh" \
        --profile headless --json "$PROMPT") >"$LOG" 2>&1 ;;
    *) echo "owner=$OWNER 不由脚本启动（claude 由主会话自己做）" >"$LOG"; return 3 ;;
  esac
}
finish() {
  local code=$1 end; end=$(date +%s)
  # 指标：用量从日志里尽量提取（codex 打印 "tokens used"，dsh --json 事件里有 usage）
  local usage; usage=$(grep -A1 -i "tokens used" "$LOG" 2>/dev/null | tail -1 | tr -dc '0-9,' )
  [ -f reports/metrics.csv ] || echo "date,id,owner,exit,wall_sec,usage,report_exists" > reports/metrics.csv
  echo "$(date '+%F %T'),$ID,$OWNER,$code,$((end-start)),\"$usage\",$([ -f "$REPORT" ] && echo yes || echo no)" >> reports/metrics.csv
}
if [ "$FG" = "--fg" ]; then run; finish $?; else (run; finish $?) & echo "$ID 已在后台启动（$OWNER），日志 $LOG"; fi
