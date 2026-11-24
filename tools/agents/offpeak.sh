#!/bin/bash
# DeepSeek API 谷时判断（官方价格页，2026-11-24 核实）：
#   高峰 = 周一至周五 UTC 01:00–04:00、06:00–10:00（北京时间 09:00–12:00、14:00–18:00），不含中国法定节假日
#   其余时间（含周末、节假日）为谷时，价格为高峰的一半
# 节假日没有内置清单，按工作日规则保守处理（节假日会被当成高峰，只是少用了优惠）。
# 用法：offpeak.sh            → 谷时退出码 0，高峰 1；打印当前状态和本段剩余/下段开始时间
#       offpeak.sh --minutes  → 打印本段谷时剩余分钟数（高峰时打印 0）
python3 -I - "$@" <<'PY'
import sys, datetime as dt
now = dt.datetime.now(dt.timezone.utc)
PEAK = [(1, 4), (6, 10)]  # UTC 小时区间 [起, 止)
def is_peak(t):
    return t.weekday() < 5 and any(a <= t.hour < b for a, b in PEAK)
def next_change(t):
    s = t.replace(second=0, microsecond=0)
    cur = is_peak(s)
    for i in range(1, 7 * 24 * 60):
        u = s + dt.timedelta(minutes=i)
        if is_peak(u) != cur:
            return u
    return None
peak = is_peak(now)
nc = next_change(now)
mins = int((nc - now).total_seconds() // 60) if nc else 0
bj = lambda t: t.astimezone(dt.timezone(dt.timedelta(hours=8))).strftime("%m-%d %H:%M")
if "--minutes" in sys.argv:
    print(0 if peak else mins)
else:
    if peak:
        print(f"高峰（北京时间 {bj(now)}）；谷时从 {bj(nc)} 开始")
    else:
        print(f"谷时（北京时间 {bj(now)}）；还剩 {mins} 分钟，到 {bj(nc)}")
sys.exit(1 if peak else 0)
PY
