---
id: T62
title: 战役状态与结局逻辑：补测试 + 未实现部分的测试规格
owner: dsh
status: queued
branch: dsh/t62-campaign-endings
worktree: ../亡魂王子-t62
allowed: [tests/test_campaign_flow.gd, tests/run_tests.gd, docs/test-specs/campaign-endings.md, reports/agents/]
forbidden: [scripts/, data/, shaders/, assets/, art/, docs/canon/]
verify: godot --headless --path . -s tests/run_tests.gd
retry_limit: 3
max_minutes: 90
escalate_if: [需要改 allowed 以外的文件, 需要改玩法、剧情、美术方向或正式平衡参数, 疑难工程问题（转 Codex）]
---

## 目标
验证战役航路、剧情状态和跨周目回溯的实现是否符合 canon 的数据约定；尚未实现的部分（第二到第四阶段、E02–E08、真结局封档）只写测试规格。

## 先读
- `docs/canon/A/NARRATIVE-DESIGN.md` 第 6、8、9、10、12 节（阶段门槛、王都三次决定、九种结局、真结局、存档字段与验收表）
- `scripts/campaign/`、`tests/test_campaign.gd`、`tests/test_campaign_data.gd`（已有 1000+ 断言，先看覆盖了什么）

## 要做
1. `tests/test_campaign_flow.gd`：只补已有测试没覆盖的。例如：
   - 连续多局回溯后，持久字段（已知事实、航路、敌情记忆、残响）累加正确，本轮字段每次清空
   - 第一阶段任意失败点都记 E00，且不会出现"半个成功"
   - 坏档和旧档读入不丢数据
   - 首领据点覆盖（盐市港、宫城）在每条走廊上都可达
2. `docs/test-specs/campaign-endings.md`：把 NARRATIVE-DESIGN 第 12 节的验收表展开成逐条可执行的测试用例，供以后实现时直接翻译成代码。覆盖：
   - 阶段二到四的开放条件
   - 三次决定的 8 种组合到 E01–E08 的映射
   - K01–K07 的获取与持久化
   - 真结局的不可逆确认与 `COMPLETED` 原子写入
   - "暂不解约"走正常回溯
   每条写：前置状态、操作、期望结果、对应 canon 章节。
3. 发现 canon 与实现不一致的地方，写进报告，不要改代码。

## 验收
- 新测试通过，或失败处在报告里说明是实现 bug
- 规格文档覆盖 NARRATIVE-DESIGN 第 12 节验收表的每一行

## 通用要求
- 开工前先看现有代码、`tests/`、`tools/`、`TASKS.md`，**已有的功能不要重做**，只补缺口；报告里列出"已有 / 新增"。
- 能用本地脚本判断对错的，写成脚本；不要改玩法、剧情、美术方向和正式平衡参数（`data/battles/proto.json` 里的数值只读）。
- 常规问题自己修，重试上限见 retry_limit；疑难工程问题（引擎崩溃、渲染管线、跨模块重构）停下，在报告里写 `needs_claude: false`、`handoff: codex` 和最小复现。
- 报告开头用 `docs/collab.md` 第 4 节的 YAML 摘要；Lead 默认只读摘要。
