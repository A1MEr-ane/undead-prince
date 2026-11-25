#!/bin/bash
# 每小时检查一次正在跑的 codex/dsh 任务是否卡住。不调用任何模型。
# 判定：进程还在，但它的 worktree 里一小时内没有任何文件更新、日志也没有增长 → 卡住。
# 退出：全部结束 → 0（打印 DONE）；发现卡住 → 3（打印 STALL 和任务名）。
# 用法：tools/agents/watch_progress.sh [间隔秒，默认 3600]
cd "$(dirname "$0")/../.." || exit 1
INT=${1:-3600}
ROOT=$PWD
while true; do
  wts=$(pgrep -fl "exec -C $ROOT-t" | grep -o "$ROOT-t[0-9]*" | sort -u)
  if [ -z "$wts" ]; then echo "$(date '+%F %T') DONE 没有在跑的任务"; tail -3 reports/metrics.csv; exit 0; fi
  stalled=""
  for wt in $wts; do
    id=$(basename "$wt" | sed 's/.*-t/T/')
    recent=$(find "$wt" -type f -not -path '*/.git/*' -newermt "-$((INT/60)) minutes" 2>/dev/null | head -1)
    logrecent=$(find reports/inbox -name "${id}.log" -newermt "-$((INT/60)) minutes" 2>/dev/null | head -1)
    imgs=$(find "$wt/art" -name '*.png' -not -path '*/alt/*' -not -path '*/v1/*' 2>/dev/null | wc -l | tr -d ' ')
    echo "$(date '+%F %T') $id 运行中，主图 ${imgs} 张，近 $((INT/60)) 分钟有更新：$([ -n "$recent$logrecent" ] && echo 是 || echo 否)"
    [ -z "$recent$logrecent" ] && stalled="$stalled $id"
  done
  if [ -n "$stalled" ]; then echo "$(date '+%F %T') STALL$stalled"; exit 3; fi
  sleep "$INT"
done
