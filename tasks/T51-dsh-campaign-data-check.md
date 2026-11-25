---
id: T51
title: 战役数据一致性检查 + 航路难度分布报告
owner: dsh
status: done
branch: dsh/t51-campaign-check
worktree: ../亡魂王子-t51
allowed: [tests/test_campaign_data.gd, tests/run_tests.gd, reports/agents/]
forbidden: [scripts/, data/, docs/, shaders/]
verify: godot --headless --path . -s tests/run_tests.gd
retry_limit: 2
max_minutes: 45
escalate_if: [发现数据错误（写进报告，不要改 data/ 或 canon）]
---

## 目标
战役地图的数据分散在多处：canon 的 `docs/canon/C/CAMPAIGN-DATA.json`（只读），以及 `data/campaign/overrides.json`、`reward_map.json`、`difficulty.json`。
后续改地图时容易出现断链。本任务加一个自动检查，并出一份难度分布报告，用来核对 `docs/roguelike.md` 第 8 节的设计目标。

## 要做
1. 新建 `tests/test_campaign_data.gd`，在 `run_tests.gd` 加一行调用。检查内容：
   - 每个地点 id 在 `reward_map.json` 里都有条目；`overrides.json` 引用的 id 都存在
   - 每条边的起点和终点都存在
   - 从据点出发，所有地点都可达；每个地点都至少有一条路能到王都入口
   - 每个地点都能算出 1–5 档难度。算法照搬 `scripts/campaign/difficulty.gd`，直接调用，不要重写
2. 报告 `reports/agents/T51.md` 写以下内容：
   - 据点到王都的最短和最长路径步数，以及路径条数
   - 每条走廊（军道、沿岸、粮运、葬海、旧王庭，划分见 roguelike.md 第 8、9 节）上各档难度的地点数
   - 和 roguelike.md 第 8 节"用现有图算出来的效果"逐条对照：是否成立，不成立的列出具体地点
   - 首领据点是否每条走廊各一个（第 9 节）

## 产物
- `tests/test_campaign_data.gd`，以及 `run_tests.gd` 新增的一行
- `reports/agents/T51.md`

## 验收
- [ ] 测试通过。如果数据本身有错导致测试失败，测试照实失败，报告写清楚原因，由 Lead 决定改数据还是改规则
- [ ] 报告含第 2 步的四项内容
