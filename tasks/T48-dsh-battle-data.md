---
id: T48
title: 战斗配置数据化（守军、出生点、夺旗规则从代码移到数据文件）
owner: dsh
status: done
branch: dsh/t48-battle-data
worktree: ../亡魂王子-t48
allowed: [scripts/main.gd, data/battles/, tests/test_battles.gd, tests/run_tests.gd]
forbidden: [scripts/unit.gd, scripts/swordsman.gd, scripts/squad.gd, scripts/terrain.gd, shaders/, docs/, scripts/campaign/]
verify: tools/verify/verify.sh all
retry_limit: 2
max_minutes: 60
escalate_if: [默认配置下同种子结果和改动前不一致且无法消除, 需要改 allowed 以外的文件]
---

## 目标
现在一场战斗的军队、站位、夺旗条件都写死在 `scripts/main.gd` 的 `_spawn_armies` 和 `_check_goal` 里。
战役里每个地点需要不同的守军配置，平衡调整（T19、T49）也需要不改代码就能换参数。
本任务只做"搬家"：把这些值移到 `data/battles/*.json`，行为完全不变。

## 要做
1. **改动前先记基线**：在未修改的代码上运行 `tools/verify/verify.sh battle --seeds 1,2,3,4,5,6,7,8,9,10`，把 10 行 RESULT 存到 `reports/agents/T48-baseline.jsonl`。
2. 新建 `data/battles/proto.json`，内容等价于现在 `_spawn_armies` 的写法：
   - `squads`：数组。每项包含 `title`、`faction`（0 亡魂 / 1 王国）、`look`（palette_row）、`count`、`anchor`、`offset`（可选，世界坐标偏移）、`stats`、`is_player`。
   - `anchor` 只允许 `beach_left`、`beach_right`、`flag`、`mid`，含义和现在代码里 pa、pb、flag_pos、mid 的算法一致。王旗卫队现在的 `face_down.normalized() * 0.4` 偏移用 `flag` 加一个字段 `toward_beach: 0.4` 表达。
   - `capture`：`player_radius` 1.3，`defender_radius` 2.5，`time` 3.0，`decay` 0.5。
   - `trees`：7。
3. `main.gd`：
   - `_parse_args` 新增 `--battle=<id>`，默认 `proto`。
   - 新增读取函数，`_spawn_armies`、`_check_goal` 改为读配置。
   - 王国精灵的选择逻辑（shieldman / proc）保持现状，不进配置。
   - 不改 RNG 的调用顺序：读配置不能引入额外的 `sim_rng` 调用。
4. 新建 `tests/test_battles.gd`，在 `tests/run_tests.gd` 加一行调用。测试内容：`data/battles/` 下每个 JSON 都能读取，字段齐全、类型正确，anchor 合法，count 大于 0，且每场至少有一支 `is_player=true` 的部队。
5. **改动后**重跑第 1 步的命令，10 行 RESULT 必须和基线逐字一致。

## 产物
- `data/battles/proto.json`
- `scripts/main.gd` 的改动
- `tests/test_battles.gd`，以及 `run_tests.gd` 新增的一行
- `reports/agents/T48-baseline.jsonl`、`reports/agents/T48-after.jsonl`

## 验收
- [ ] `tools/verify/verify.sh all` 通过
- [ ] T48-baseline.jsonl 与 T48-after.jsonl 逐字一致（用 `diff` 检查，结果写进报告）
- [ ] `main.gd` 里不再出现部队名称、人数、夺旗半径这些字面量

## 交付报告
写到 `reports/agents/T48.md`，格式见 docs/collab.md 第 4 节。
`tests/run_tests.gd` 可能和其他任务同时新增一行，合并冲突由 Lead 处理。
