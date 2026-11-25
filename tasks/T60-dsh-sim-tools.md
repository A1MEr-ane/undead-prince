---
id: T60
title: T19 前置：批量模拟、统计与异常检测工具
owner: dsh
status: queued
branch: dsh/t60-sim-tools
worktree: ../亡魂王子-t60
allowed: [tools/sim/, tests/test_sim_tools.gd, tests/run_tests.gd]
forbidden: [scripts/, data/, docs/, shaders/, assets/, art/]
verify: tools/sim/batch.sh 5 && godot --headless --path . -s tests/run_tests.gd
retry_limit: 3
max_minutes: 90
escalate_if: [需要改 allowed 以外的文件, 需要改玩法、剧情、美术方向或正式平衡参数, 疑难工程问题（转 Codex）]
---

## 目标
平衡调整（T19、T49）要靠大量对战数据。把"跑很多局、汇总、找异常"做成一条命令。

## 已有（先确认）
- `godot --headless --path . -- --auto --quit_at=60 --quit_on_end --seed=N` 输出一行 `RESULT {json}`，退出时打印 `STATS` 和 `HITCH`
- `tools/verify/determinism.sh`（同种子两次逐字一致）
- `data/battles/proto.json`（战斗配置，T48）

## 要做
1. `tools/sim/batch.sh N [起始种子] [配置文件]`：并行跑 N 局（并行数取 CPU 核数一半），把每局的 RESULT 写进 `reports/sim/<时间>/runs.jsonl`。
2. `tools/sim/summarize.py`：读 runs.jsonl，输出 `summary.json` 和一张可读的 `summary.md`。内容：
   - 胜率、用时分布（平均、p50、p90）、剩余人数
   - 各项 STATS 的平均值
   - 异常局列表
3. 异常检测规则（写在 summarize.py 里，阈值放在文件顶部常量）：
   - 没有 RESULT（崩溃或卡死）
   - 到时间仍未分胜负
   - 有脚本错误
   - 出现 HITCH
   - 双方 60 秒内都没有接战
   - 单位坐标出现 NaN 或离开地图（需要的话，在 RESULT 里加字段要走 handoff，不要自己改 main.gd）
4. 同种子复跑一次抽查 3 局，确认结果一致；不一致就记为异常。
5. 用 `tests/test_sim_tools.gd` 或 Python 自测覆盖 summarize 的统计和异常判定（造几条假数据即可）。

## 验收
- `tools/sim/batch.sh 50` 在本机跑完，产出 summary.md，报告里贴摘要
- 能用 `--config` 指向另一份战斗配置（为 T49 的参数扫描准备）

## 通用要求
- 开工前先看现有代码、`tests/`、`tools/`、`TASKS.md`，**已有的功能不要重做**，只补缺口；报告里列出"已有 / 新增"。
- 能用本地脚本判断对错的，写成脚本；不要改玩法、剧情、美术方向和正式平衡参数（`data/battles/proto.json` 里的数值只读）。
- 常规问题自己修，重试上限见 retry_limit；疑难工程问题（引擎崩溃、渲染管线、跨模块重构）停下，在报告里写 `needs_claude: false`、`handoff: codex` 和最小复现。
- 报告开头用 `docs/collab.md` 第 4 节的 YAML 摘要；Lead 默认只读摘要。
