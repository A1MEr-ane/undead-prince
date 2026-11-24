---
id: T28
title: 航海图与回溯闭环（第一阶段 E00/E01，战斗先用桩）
owner: codex
status: done
branch: codex/t28-campaign
worktree: ../亡魂王子-t28
allowed: [scripts/campaign/, scenes/campaign.tscn, data/campaign/, tests/test_campaign.gd, tests/run_tests.gd, project.godot]
forbidden: [scripts/main.gd, scripts/unit.gd, scripts/swordsman.gd, scripts/squad.gd, docs/canon/, docs/roguelike.md, tasks/]
verify: tools/verify/verify.sh all
retry_limit: 3
max_minutes: 150
escalate_if: [需要改 allowed 以外的文件, canon 数据与 roguelike.md 冲突, 需要新增 project.godot 中 autoload 以外的设置, 存档格式取舍]
---

## 目标
把剧情 canon 的一局流程跑通，不含真正的战斗：沉钟湾 → 航海图选路 → 地点结算 → 王都 → 结局卡 → 回溯到沉钟湾，知识跨轮保留，本轮数据清空。
战斗暂时用"桩"：点击"胜/败"按钮或按种子随机给出结果。Lead 之后把桩换成真正的 main.tscn 战斗。

## 输入（先读）
- `docs/roguelike.md` 第 1、3、7 节（一局流程、奖励类型、最小闭环）
- `docs/canon/shared/CANON-COMPACT.md`
- `docs/canon/A/NARRATIVE-DESIGN.md` 第 6、9、12 节：阶段、知识表 K01–K07、结局表、存档字段、验收表
- `docs/canon/C/CAMPAIGN-DATA.json`：39 个地点、75 条有向边（只读，不要改）
- `docs/canon/C/Crownsea-Chart-C3.html`：现成的交互原型，可以参考它的状态逻辑和布局，但用 Godot 重写

## 要做
1. `data/campaign/`：
   - 从 CAMPAIGN-DATA.json 导出 Godot 用的数据，或运行时直接读 `res://docs/canon/C/CAMPAIGN-DATA.json`，二选一，在报告里说明理由。
   - `reward_map.json`：把每个地点的 `reward` 文本映射到 roguelike.md 第 3 节的 8 类奖励之一。逐条列出，不用代码猜。
2. `scripts/campaign/`：
   - `run_state.gd`：本轮数据，字段用 NARRATIVE-DESIGN 第 12 节的名字。
   - `save_state.gd`：存档持久数据，存到 `user://save.json`。
   - 回溯时清空本轮、保留存档持久部分。
   - 第一阶段规则：只开 stage ≤ 1 的地点；首次成功只能是 E01；失败记 E00。
3. `scenes/campaign.tscn`：
   - 航海图：节点、有向边、当前位置。只能沿出边前进，下一站显示奖励图标（占位图形即可）。
   - 地点面板：名称、`scene`、`plot` 文字，加"进攻"按钮，战斗桩给出胜或败。
   - 王都：第一阶段直接执行 E01 的固定决定（坚持王位、保留军誓、延续永昼），不出现灰掉的假选项。
   - 结局卡：E00、E01 各一张文字卡，加渡魂人的回溯台词（取自 NARRATIVE-DESIGN）。
   - 回溯后回到沉钟湾。
4. 注册一个 autoload，例如 `Run`。`project.godot` 里只能加这一行。
5. `tests/test_campaign.gd`，接入 `tests/run_tests.gd`。至少测这些：
   - 从 bay 到 sunhold 的可达性（stage 1）
   - 失败 → E00 → 回溯后本轮清空、知识保留
   - 首胜 → 只能 E01
   - 存档写入后重新读取，数据一致
6. 无头参数：`godot --headless --path . scenes/campaign.tscn -- --auto_run --seed=N`，自动选路走完一局，打印一行 `CAMPAIGN {json}`（路线、结局、知识）。

## 产物
- 上述脚本、场景、数据和测试
- 截图：航海图、地点面板、结局卡各一张，放 `shots/t28/`

## 验收
- [ ] `tools/verify/verify.sh all` 通过（含新测试）
- [ ] `--auto_run` 连续跑 3 个种子，都能正常结束并打印 CAMPAIGN 行
- [ ] 没有改动 forbidden 中的文件
- [ ] 截图由 Lead 判断：信息是否清楚、操作是否简单（这一轮不要求美观）

## 交付报告
写到 `reports/agents/T28.md`，格式见 docs/collab.md 第 4 节。
