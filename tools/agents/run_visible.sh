#!/bin/bash
# 在客户端终端面板里运行一张任务卡，实时显示执行者的输出。
# 用法：tools/agents/run_visible.sh 任务卡 [开始时间 HH:MM]
cd "$(dirname "$0")/../.." || exit 1
CARD=$1; AT=$2
ID=$(grep -m1 '^id:' "$CARD" | sed 's/id:[[:space:]]*//')
if [ -n "$AT" ]; then
  t=$(date -j -f '%Y-%m-%d %H:%M' "$(date +%F) $AT" +%s); now=$(date +%s)
  [ "$t" -gt "$now" ] && { echo "等到 $AT 再启动 $ID（Codex 额度重置）"; sleep $((t-now)); }
fi
LOG=reports/inbox/${ID}.log
: > "$LOG"
echo "===== 启动 $ID：$(date '+%F %T') ====="
tools/agents/run_agent.sh "$CARD" --fg &
P=$!
tail -n +1 -f "$LOG" &
T=$!
wait $P; code=$?
sleep 2; kill $T 2>/dev/null
echo "===== $ID 结束：退出码 $code，$(date '+%F %T') ====="
REP=$(ls ../亡魂王子-$(echo $ID | tr 'T' 't')/reports/agents/${ID}.md 2>/dev/null)
[ -n "$REP" ] && { echo "----- 报告摘要 -----"; sed -n 1,20p "$REP"; }
