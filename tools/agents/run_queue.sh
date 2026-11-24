#!/bin/bash
# DSH 谷时队列：按文件名顺序依次执行 tasks/ 里 owner=dsh 且 status=queued 的任务卡。
# 每张卡开始前检查谷时；本段谷时不够就停下，剩下的留到下一段。
# 执行后把卡片的 status 改成 done（退出码 0 且有交付报告）或 failed，结果写进 reports/queue.log。
# 用法：tools/agents/run_queue.sh            （通常由定时任务在谷时开始时调用）
#       tools/agents/run_queue.sh --check    只检查 DSH 凭据能否用，不执行任务
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
QLOG="$ROOT/reports/queue.log"; mkdir -p reports
DSH="/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh"
say() { echo "$(date '+%F %T') $*" | tee -a "$QLOG"; }
# 防止两次运行叠在一起（定时任务和手动运行同时触发时）
LOCK="$ROOT/reports/.queue.lock"
if ! mkdir "$LOCK" 2>/dev/null; then say "已有队列在运行，跳过"; exit 0; fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# 凭据检查：用最短的任务试一次；缺密钥时直接退出，不浪费谷时
check=$("$DSH" --profile headless --patch "$ROOT/tools/agents/dsh-account.patch.yml" "只回答两个字：就绪" 2>&1 | tail -3)
if echo "$check" | grep -q "MISSING_CREDENTIAL\|SIGN_IN_REQUIRED"; then
  say "DSH 凭据不可用：$(echo "$check" | tail -1)"; exit 3
fi
say "DSH 凭据可用"
[ "${1:-}" = "--check" ] && exit 0

for card in $(ls tasks/T*.md 2>/dev/null | sort); do
  owner=$(sed -n '2,20p' "$card" | grep -m1 '^owner:' | sed 's/owner:[[:space:]]*//; s/[[:space:]]*#.*//')
  status=$(sed -n '2,20p' "$card" | grep -m1 '^status:' | sed 's/status:[[:space:]]*//; s/[[:space:]]*#.*//')
  [ "$owner" = "dsh" ] && [ "$status" = "queued" ] || continue
  if ! tools/agents/offpeak.sh >/dev/null; then say "已到高峰，队列暂停：$(tools/agents/offpeak.sh)"; break; fi
  id=$(sed -n '2,20p' "$card" | grep -m1 '^id:' | sed 's/id:[[:space:]]*//; s/[[:space:]]*#.*//')
  say "开始 ${id}（${card}）"
  sed -i '' 's/^status:[[:space:]]*queued/status: running/' "$card"
  tools/agents/run_agent.sh "$card" --fg; code=$?
  if [ $code -eq 0 ] && { [ -f "reports/agents/${id}.md" ] || [ -f "reports/inbox/${id}.md" ]; }; then st=done; else st=failed; fi
  sed -i '' "s/^status:[[:space:]]*running/status: $st/" "$card"
  say "结束 ${id}：${st}（退出码 ${code}）"
done
say "队列结束"

exit 0
