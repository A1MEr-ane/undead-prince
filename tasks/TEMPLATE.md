---
id: T00
title: 一句话任务名
owner: codex            # claude | codex | dsh
branch: codex/t00-name  # 前缀与 owner 一致
worktree: ../亡魂王子-t00
allowed: [scripts/example.gd, tools/example/]   # 只能改这些（文件或目录）
forbidden: [scripts/main.gd]                    # 明确不能碰的
verify: tools/verify/verify.sh all               # 必须通过的命令（Lead 定，执行者不得修改阈值）
retry_limit: 2          # 自己修复重试的最大次数，超过就停下写报告
escalate_if: [需要改接口, 需要改 allowed 以外的文件, 视觉/风格取舍, 验收阈值看起来不合理]
---

## 目标
<为什么做、做完是什么样>

## 输入
- 参考：<docs 段落 / 概念图路径 / 规格文件>

## 要做
1. ...

## 产物
- <文件路径与格式>

## 验收
- [ ] `verify` 命令通过
- [ ] <可客观检查的条件>
- [ ] <需要 Lead 看截图判断的条件（执行者只需给出截图路径）>

## 交付报告
写到 `reports/agents/<id>.md`，格式见 docs/collab.md 第 4 节。
