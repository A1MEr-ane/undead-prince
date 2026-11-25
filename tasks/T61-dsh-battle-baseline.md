---
id: T61
title: 现有战斗系统基线测试：寻路、碰撞、攻击判定、兵种行为、性能
owner: dsh
status: done
branch: dsh/t61-battle-baseline
worktree: ../亡魂王子-t61
allowed: [tests/test_battle_baseline.gd, tests/run_tests.gd, tools/sim/perf.sh, reports/agents/]
forbidden: [scripts/, data/, docs/, shaders/, assets/, art/]
verify: godot --headless --path . -s tests/run_tests.gd
retry_limit: 3
max_minutes: 120
escalate_if: [需要改 allowed 以外的文件, 需要改玩法、剧情、美术方向或正式平衡参数, 疑难工程问题（转 Codex）]
---

## 目标
给现有战斗系统建一套基线测试，以后改战斗（T44 新画风、T49 平衡）时能马上发现退化。**只测不改**：发现 bug 写进报告，附最小复现，不要修改 `scripts/`。

## 先读
`docs/badnorth-behavior-spec.md`（行为规格）、`scripts/unit.gd`、`swordsman.gd`、`squad.gd`、`terrain.gd`、`tests/test_battles.gd`（T48 已有）。

## 要做
1. `tests/test_battle_baseline.gd`，在无头模式下搭小场景断言：
   - 寻路：流场能把单位从 A 带到 B；被地形挡住时绕行；不可达时不卡死
   - 碰撞与站位：小队到位后单位不重叠（间距下限取规格值）；不会穿过悬崖
   - 攻击判定：攻击命中、格挡、拼刀、击倒、落水各至少触发一次，触发条件和规格一致
   - 兵种行为：备战、冲锋传播、威慑后退、眩晕恢复的状态切换顺序符合规格第 7 节
   - 每条断言写清楚对应规格的哪一节
2. `tools/sim/perf.sh`：无头跑 50、100、200 个单位各 30 秒，输出平均和 p95、p99 帧时间（物理帧和处理帧分开）。若需要在 main.gd 里加生成单位数量的参数，写进报告并 handoff，不要自己改。
3. 报告里列出：通过的断言、发现的问题（按严重程度排序）、性能表。

## 验收
- 测试套件能跑完；失败的断言要么是真 bug（在报告里给复现），要么修正测试本身
- 性能表注明机器和 Godot 版本

## 通用要求
- 开工前先看现有代码、`tests/`、`tools/`、`TASKS.md`，**已有的功能不要重做**，只补缺口；报告里列出"已有 / 新增"。
- 能用本地脚本判断对错的，写成脚本；不要改玩法、剧情、美术方向和正式平衡参数（`data/battles/proto.json` 里的数值只读）。
- 常规问题自己修，重试上限见 retry_limit；疑难工程问题（引擎崩溃、渲染管线、跨模块重构）停下，在报告里写 `needs_claude: false`、`handoff: codex` 和最小复现。
- 报告开头用 `docs/collab.md` 第 4 节的 YAML 摘要；Lead 默认只读摘要。
