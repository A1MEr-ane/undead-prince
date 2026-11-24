---
id: T29
title: 航海图难度颜色、首领据点覆盖、敌情记忆与残响（局外成长第一版）
owner: codex
status: queued
branch: codex/t29-difficulty
worktree: ../亡魂王子-t29
allowed: [scripts/campaign/, scenes/campaign.tscn, data/campaign/, tests/test_campaign.gd, tests/run_tests.gd]
forbidden: [scripts/main.gd, scripts/unit.gd, scripts/swordsman.gd, scripts/squad.gd, docs/, tasks/, project.godot]
verify: tools/verify/verify.sh all
retry_limit: 3
max_minutes: 150
escalate_if: [需要改 allowed 以外的文件, roguelike.md 的规则互相矛盾, 存档字段需要不兼容的改动]
---

## 目标
在 T28 的航海图和回溯闭环上，实现用户 2026-11-24 定下的三件事：
1. 地点按航路长短分难度，在航海图上用颜色表示。短路径更难。
2. 增加首领据点：盐市港是罗德里克伯爵的据点，王都宫城战是沃尔特宰相。
3. 轮回保留降低难度的机制。本任务只做第一版：敌情记忆、残响结算、航路知识。

## 输入（先读）
- `docs/roguelike.md` 第 5、8、9 节。**以文档为准**；文档没写死的数值，你定一个，写进数据文件并在报告里列出。
- T28 的代码：`scripts/campaign/`、`data/campaign/reward_map.json`、`reports/agents/T28.md`。
- `docs/canon/C/CAMPAIGN-DATA.json`：只读，不改。

## 要做
1. `data/campaign/overrides.json`：
   - 按地点 id 覆盖类型、首领、难度手调。
   - 写入盐市港和王都宫城两处首领覆盖。首领名字用 canon 角色 id。
   - 运行时先读 canon，再叠加覆盖。
2. 难度计算放在 `scripts/campaign/difficulty.gd`：
   - 难度 = 深度分 + 捷径分 + 手调 − 敌情记忆。按 roguelike.md 第 8 节，结果取整并限制在 1–5 档。首领固定第 5 档（紫），可以被敌情记忆降档。
   - 难度影响奖励档次（稀有度或魂火数量）。战斗还是桩，所以本任务里难度另外决定桩的胜率，例如第 1 档 90%、第 5 档 25%，写进数据文件。
   - 战斗桩的胜率再受本轮已获奖励数影响，模拟"走远路攒战力"。这条规则写进数据文件，标注"临时，等接入真实战斗后删除"。
3. 航海图显示：
   - 节点按难度上色：1 绿、2 黄、3 橙、4 红、5 紫。图例写在左下角。
   - 节点名改用中文（`zh` 字段），英文只在面板里显示。
   - 修正节点重叠：断桅滩、沉钟湾、天涯灯塔一带，折桨港和盐市港一带。canon 坐标只作参考，可以在 overrides 里给显示坐标偏移。
4. 局外成长第一版，写进存档持久部分，字段名在报告里列出：
   - **敌情记忆**：每个打赢过的地点记 1 次；首领据点打赢 2 次再降一档。面板里显示"已知守军布置"。
   - **残响**：每局结算，按攻下的地点数、首领数、新知识数计算，失败也给。本任务只累计显示，不做商店。
   - **航路知识**：走过的边记下来；已知的边上，下一站之后再多显示一层奖励图标。
5. `--auto_run` 加一个参数 `--runs=N`：连续跑 N 局，打印每局路线、结局，以及经过地点的平均难度。用来看"前几局走长路、后几局能走短路"的趋势。
   - 自动选路策略：前几局偏好低难度，残响或敌情记忆多了之后偏好短路。策略写在 auto_run 代码里即可。
6. 测试：
   - 难度计算的边界：最短路线的地点比长路线同深度的地点难。
   - 覆盖文件生效。
   - 敌情记忆降档并跨回溯保留。
   - 残响累计。
   - 旧存档（没有新字段）能正常读入。

## 产物
- 上述代码、数据和测试
- 截图：`--capture_t28` 改成也输出 `shots/t29/chart_difficulty.png`（第 1 局开局）和 `shots/t29/chart_run5.png`（auto 跑 4 局后的第 5 局，能看到颜色变浅）。如果截不了图，在报告里写明，Lead 来补拍。

## 验收
- [ ] `tools/verify/verify.sh all` 通过
- [ ] `--auto_run --runs=8 --seed=1` 的输出里，后几局经过地点的平均难度或路线长度，相比前几局有可见变化
- [ ] 没有改动 forbidden 中的文件
- [ ] 由 Lead 看截图判断：颜色是否一眼能分、节点是否还有重叠

## 交付报告
写到 `reports/agents/T29.md`，格式见 docs/collab.md 第 4 节。列出新增的所有数值和它们的位置。
