---
id: T22
title: 状态树 AgentState 的无头单元测试
owner: dsh
status: queued
branch: dsh/t22-agentstate-tests
worktree: ../亡魂王子-t22
allowed: [tests/]
forbidden: [scripts/, shaders/, docs/, tasks/, project.godot]
verify: godot --headless --path . -s tests/run_tests.gd
retry_limit: 2
max_minutes: 45
escalate_if: [发现 scripts/agent_state.gd 的行为和 docs/badnorth-behavior-spec.md 第 2.2 节不一致（写进报告，不要改源码）]
---

## 目标
给 `scripts/agent_state.gd`（状态树）加回归测试，以后改行动逻辑时能自动发现状态树被改坏。

## 要做
1. 新建 `tests/run_tests.gd`（`extends SceneTree`，在 `_init` 里跑完所有测试后 `quit(失败数 > 0 ? 1 : 0)`），以及 `tests/test_agent_state.gd`。
2. 覆盖规格 2.2 节的每条规则，至少：激活子状态连带激活祖先；互斥状态顶掉互斥兄弟、不影响非互斥兄弟；停用递归停用子孙；on_empty 在"激活且没有互斥子状态"时触发（含停用最后一个互斥子状态后父状态触发）；since() 用 AgentState.now 计时；update() 只调用激活状态的回调且按树序。
3. 每个测试失败时打印清楚的期望值和实际值。运行方式：`godot --headless --path . -s tests/run_tests.gd`。
4. 不修改 `scripts/` 下的任何文件。如果发现源码行为与规格不符，测试标记为"已知问题"并写进报告。

## 产物
- `tests/run_tests.gd`、`tests/test_agent_state.gd`，在分支上提交
- `reports/agents/T22.md`
