---
id: T80
title: 行为场景测试套件 B01–B12（只写测试，不改行为代码）
owner: dsh
status: done
branch: dsh/t80-behavior-scenarios
worktree: ../亡魂王子-t80
allowed: [proto/siege/tests/, tools/verify/proto_behavior.sh, reports/agents/]
forbidden: [proto/siege/*.gd, scripts/, docs/, tasks/, art/, assets/]
verify: test -x tools/verify/proto_behavior.sh
retry_limit: 3
max_minutes: 240
escalate_if: [需要改原型代码才能搭场景（列出需要的接口，交给 Codex）]
---

## 目标
用户决定：现阶段只解决行动逻辑，不再测胜率。把 `docs/behavior-goals.md` 第 4 节的 12 个场景写成自动测试。

## 要做
1. 在 `proto/siege/tests/` 里，每个场景一个小地图或场景配置：摆好单位、地形和墙门状态，无头运行，断言第 1–3 节规定的行为（站立超时、来回折返次数、穿墙、拥堵化解、接战时间、派兵比例、任务锁定、撤退路线等）。
2. `tools/verify/proto_behavior.sh`：跑全部场景，逐条打印 PASS 或 FAIL 和原因。每个场景都支持 `--watch` 开窗口回放。
3. **现在失败是正常的**：本任务只写测试，不修行为。报告里列出哪些场景失败、失败的原因（推断即可），供 Codex 修。
4. 搭场景缺少接口（例如没法直接摆放单位、读取单位状态）时，列出需要的接口，交给 Codex，不要自己改原型代码。

## 交付
`reports/agents/T80.md`，开头用 YAML 摘要；正文是 12 个场景的通过或失败表。
