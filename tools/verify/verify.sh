#!/bin/bash
# 固定验证套件：任何 AI 或人都直接运行，不需要重新推导怎么测。
# 用法：tools/verify/verify.sh [parse|tests|battle|sprites|all] [--seeds 1,7,13] [--quit-at 60]
# 结果：reports/verify/<时间>.json（机器读）+ 终端摘要；任一项失败则退出码为 1。
# 验收阈值由 Lead 维护（见 docs/workflow.md），修 bug 时不要改阈值。
set -u
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
MODE=${1:-all}; shift || true
SEEDS="1,7,13"
QUIT_AT=60
while [ $# -gt 0 ]; do
  case "$1" in
    --seeds) SEEDS=$2; shift 2;;
    --quit-at) QUIT_AT=$2; shift 2;;
    *) echo "未知参数 $1"; exit 2;;
  esac
done
TS=$(date +%Y%m%d-%H%M%S)
OUT="$ROOT/reports/verify"; mkdir -p "$OUT"
LOG="$OUT/$TS.log"; JSON="$OUT/$TS.json"
: > "$LOG"
results=()

ensure_import() {
  # 新 worktree 没有全局类缓存，不导入会报 "Identifier not declared"
  [ -f .godot/global_script_class_cache.cfg ] || godot --headless --path . --import >>"$LOG" 2>&1
}

run_tests() {
  if [ -f tests/run_tests.gd ]; then
    local out; out=$(godot --headless --path . -s tests/run_tests.gd 2>&1); local code=$?
    echo "$out" >>"$LOG"
    local summary; summary=$(echo "$out" | grep "结果" | tail -1 | sed 's/"/\\"/g')
    if [ $code -eq 0 ]; then results+=("{\"check\":\"tests\",\"ok\":true,\"detail\":\"$summary\"}")
    else results+=("{\"check\":\"tests\",\"ok\":false,\"detail\":\"$summary\"}"); fi
  else
    results+=("{\"check\":\"tests\",\"ok\":true,\"skipped\":true}")
  fi
}

run_parse() {
  godot --headless --path . --import >>"$LOG" 2>&1
  local out; out=$(godot --headless --path . --quit-after 30 2>&1); echo "$out" >>"$LOG"
  if echo "$out" | grep -q "SCRIPT ERROR\|Parse Error"; then
    results+=("{\"check\":\"parse\",\"ok\":false,\"detail\":\"脚本解析错误，见日志\"}")
  else
    results+=("{\"check\":\"parse\",\"ok\":true}")
  fi
}

run_battle() {
  IFS=',' read -ra arr <<< "$SEEDS"
  for s in "${arr[@]}"; do
    local out; out=$(godot --headless --path . -- --auto --quit_at="$QUIT_AT" --quit_on_end --seed="$s" 2>&1)
    echo "== seed $s" >>"$LOG"; echo "$out" >>"$LOG"
    local res; res=$(echo "$out" | grep '^RESULT ' | tail -1 | sed 's/^RESULT //')
    local err; err=$(echo "$out" | grep -c "SCRIPT ERROR")
    if [ -z "$res" ]; then
      results+=("{\"check\":\"battle\",\"seed\":$s,\"ok\":false,\"detail\":\"没有 RESULT 输出（崩溃或卡死）\"}")
      continue
    fi
    # 验收：无脚本错误；有人死亡；双方都有交战（招架或拼刀）；60 秒内分出胜负
    local ok; ok=$(python3 -I -c '
import json,sys
r=json.loads(sys.argv[1]); err=int(sys.argv[2]); st=r["stats"]
fails=[]
if err>0: fails.append("脚本错误")
if st.get("death",0)<5: fails.append("死亡数<5")
if st.get("parry",0)+st.get("clash",0)<1: fails.append("没有招架或拼刀")
if not r["banner"]: fails.append("未分胜负")
print(json.dumps({"check":"battle","seed":r["seed"],"ok":not fails,"fails":fails,"result":r},ensure_ascii=False))
' "$res" "$err")
    results+=("$ok")
  done
}

run_sprites() {
  # Blender 精灵管线自检（管线不在当前分支时跳过）
  if [ -f tools/blender/validate.py ]; then
    if blender -b --factory-startup --python-exit-code 1 -P tools/blender/validate.py >>"$LOG" 2>&1; then
      results+=("{\"check\":\"sprites\",\"ok\":true}")
    else
      results+=("{\"check\":\"sprites\",\"ok\":false,\"detail\":\"validate.py 失败，见日志\"}")
    fi
  else
    results+=("{\"check\":\"sprites\",\"ok\":true,\"skipped\":true}")
  fi
}

run_determinism() {
  # 同种子跑两次，RESULT 必须逐字一致（T23）
  if [ -x tools/verify/determinism.sh ]; then
    if tools/verify/determinism.sh 1 >>"$LOG" 2>&1; then
      results+=("{\"check\":\"determinism\",\"ok\":true}")
    else
      results+=("{\"check\":\"determinism\",\"ok\":false,\"detail\":\"同种子两次结果不一致，见日志\"}")
    fi
  fi
}

ensure_import
case "$MODE" in
  parse) run_parse;;
  tests) run_tests;;
  battle) run_battle;;
  sprites) run_sprites;;
  determinism) run_determinism;;
  all) run_parse; run_tests; run_battle; run_determinism; run_sprites;;
  *) echo "用法：$0 [parse|tests|battle|determinism|sprites|all]"; exit 2;;
esac

python3 -I - "$JSON" "$LOG" "$(git rev-parse --short HEAD 2>/dev/null)" "${results[@]}" <<'PY'
import json,sys
path,log,commit=sys.argv[1],sys.argv[2],sys.argv[3]
items=[json.loads(x) for x in sys.argv[4:]]
ok=all(i["ok"] for i in items)
rep={"ok":ok,"commit":commit,"log":log,"checks":items}
json.dump(rep,open(path,"w"),ensure_ascii=False,indent=1)
for i in items:
    tag="通过" if i["ok"] else "失败"
    extra=""
    if i["check"]=="battle":
        r=i.get("result",{})
        extra=f" seed={i.get('seed')} 用时={r.get('time')}s 结果={r.get('banner') or '-'} " + (",".join(i.get("fails",[])) if not i["ok"] else "")
    elif i.get("skipped"): extra=" （跳过）"
    elif i.get("detail"): extra=" "+i.get("detail","")
    print(f"[{tag}] {i['check']}{extra}")
print(("全部通过" if ok else "有失败项")+f" → {path}")
sys.exit(0 if ok else 1)
PY
