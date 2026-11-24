#!/bin/bash
# 按顺序启动一批 codex 任务卡，同时最多 MAX 个在跑；全部结束后退出。
# 用法：tools/agents/run_batch.sh MAX card1 card2 ...
cd "$(dirname "$0")/../.." || exit 1
MAX=$1; shift
running() { pgrep -f "codex exec -C /Users/cyy/Projects/亡魂王子-t" | wc -l | tr -d ' '; }
for c in "$@"; do
  while [ "$(running)" -ge "$MAX" ]; do sleep 30; done
  id=$(grep -m1 '^id:' "$c" | sed 's/id:[[:space:]]*//')
  echo "$(date '+%F %T') 启动 ${id}"
  tools/agents/run_agent.sh "$c" </dev/null >/dev/null 2>&1
  sleep 20
done
while [ "$(running)" -gt 0 ]; do sleep 30; done
sleep 30
echo "$(date '+%F %T') 全部结束"
tail -n $(( $# + 1 )) reports/metrics.csv
exit 0
