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
# DSH 只在谷时运行（FORCE=1 可强制），并且必须在本段谷时结束前收工
MAXMIN=$(field max_minutes); [ -z "$MAXMIN" ] && MAXMIN=60
if [ "$OWNER" = "dsh" ]; then
  if [ "${FORCE:-}" != "1" ] && ! tools/agents/offpeak.sh >/dev/null; then
    echo "高峰时段，不启动 DSH：$(tools/agents/offpeak.sh)"; exit 4
  fi
  left=$(tools/agents/offpeak.sh --minutes)
  if [ "${FORCE:-}" != "1" ] && [ "$left" -lt $((MAXMIN + 5)) ]; then MAXMIN=$((left - 5)); fi
  [ "$MAXMIN" -lt 5 ] && { echo "本段谷时剩余不足，不启动"; exit 4; }
fi
WT=$(cd "$ROOT" && python3 -I -c 'import os,sys;print(os.path.abspath(sys.argv[1]))' "$WT")
mkdir -p reports/agents
mkdir -p "$ROOT/reports/inbox"
LOG="$ROOT/reports/inbox/$ID.log"; REPORT="$ROOT/reports/inbox/$ID.md"   # 收件箱不入库；正式报告随分支合并进来

# 1. worktree（已存在就复用）
if [ ! -d "$WT" ]; then
  git worktree add -b "$BRANCH" "$WT" main >/dev/null 2>&1 || git worktree add "$WT" "$BRANCH" >/dev/null
fi

PROMPT="你是本项目的执行者。先读 AGENTS.md 和 docs/collab.md，再按下面的任务卡完成工作。
只修改 allowed 里的文件；verify 命令必须通过；自我修复最多 retry_limit 次，超过或遇到 escalate_if 的情况就停止并在报告里说明。
完成后把交付报告写到 reports/agents/$ID.md（相对你的工作目录；格式见 docs/collab.md 第 4 节），并在分支 $BRANCH 上提交（提交失败就保留改动并在报告里说明）。

$(cat "$CARD")"

# 参考图：front matter 里 images: [绝对路径, ...]，codex 用 -i 附上，dsh 在提示里给路径
IMG_ARGS=()
IMGS=$(field images | tr -d '[]')
if [ -n "$IMGS" ]; then
  IFS=',' read -ra _imgs <<< "$IMGS"
  for i in "${_imgs[@]}"; do i=$(echo "$i" | xargs); [ -f "$i" ] && IMG_ARGS+=(-i "$i"); done
fi
start=$(date +%s)
run() {
  case "$OWNER" in
    codex)
      /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex exec -C "$WT" -s workspace-write \
        --add-dir "$ROOT/.git" --add-dir "$HOME/.codex" ${IMG_ARGS[@]+"${IMG_ARGS[@]}"} \
        -- "$PROMPT" >"$LOG" 2>&1 ;;
    dsh)
      (cd "$WT" && exec "/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh" \
        --profile headless --patch "$ROOT/tools/agents/dsh-account.patch.yml" --json "$PROMPT") >"$LOG" 2>&1 &
      local pid=$!
      ( sleep $((MAXMIN * 60)); kill "$pid" 2>/dev/null && echo "[run_agent] 超过 ${MAXMIN} 分钟被终止" >>"$LOG" ) &
      local wd=$!
      wait "$pid"; local code=$?
      kill "$wd" 2>/dev/null
      return $code ;;
    *) echo "owner=$OWNER 不由脚本启动（claude 由主会话自己做）" >"$LOG"; return 3 ;;
  esac
}
# 执行者在沙箱里提交不了（worktree 的 git 元数据在主仓库 .git 下），由本脚本在沙箱外代为提交：
# 只暂存任务卡 allowed 里的路径和交付报告，其他改动留在工作区不提交。
autocommit() {
  local allowed; allowed=$(field allowed | tr -d '[]')
  [ -z "$allowed" ] && return 0
  local paths=() a
  IFS=',' read -ra _al <<< "$allowed"
  for a in "${_al[@]}"; do a=$(echo "$a" | xargs); [ -e "$WT/$a" ] && paths+=("$a"); done
  [ -f "$WT/reports/agents/$ID.md" ] && paths+=("reports/agents/$ID.md")
  [ ${#paths[@]} -eq 0 ] && return 0
  ( cd "$WT" && git add -f -- "${paths[@]}" 2>/dev/null
    git diff --cached --quiet || git -c user.name="$OWNER-agent" -c user.email="$OWNER-agent@local" \
      commit -q -m "$ID: $(field title)

Co-Authored-By: $OWNER <noreply@local>" ) >>"$LOG" 2>&1
}
finish() {
  local code=$1 end; end=$(date +%s)
  autocommit
  [ -f "$WT/reports/agents/$ID.md" ] && cp "$WT/reports/agents/$ID.md" "$REPORT"
  # 指标：用量从日志里尽量提取（codex 打印 "tokens used"，dsh --json 事件里有 usage）
  local usage; usage=$(grep -A1 -i "tokens used" "$LOG" 2>/dev/null | tail -1 | tr -dc '0-9,' )
  [ -f reports/metrics.csv ] || echo "date,id,owner,exit,wall_sec,usage,report_exists" > reports/metrics.csv
  echo "$(date '+%F %T'),$ID,$OWNER,$code,$((end-start)),\"$usage\",$([ -f "$REPORT" ] && echo yes || echo no)" >> reports/metrics.csv
}
if [ "$FG" = "--fg" ]; then run; finish $?; else (run; finish $?) & echo "$ID 已在后台启动（${OWNER}），日志 $LOG"; fi

exit $?
