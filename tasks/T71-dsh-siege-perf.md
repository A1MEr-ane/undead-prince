---
id: T71
title: 攻城原型性能压力测试（按审查第 5 节的测量规范）
owner: dsh
status: blocked   # 等 T69 合并后改成 queued
branch: dsh/t71-siege-perf
worktree: ../亡魂王子-t71
allowed: [proto/siege/perf/, reports/agents/]
forbidden: [proto/siege/*.gd, scripts/, docs/, tasks/, art/, assets/]
verify: test -f reports/agents/T71.md
retry_limit: 2
max_minutes: 180
escalate_if: [需要改原型代码才能测量（转 Codex）]
---

## 目标
之前"200 个单位约 7 毫秒"测的只是无头模拟（T61），不能外推到完整画面。按规范重新测。

## 规范
- 每组数据都写明：硬件、Godot 版本、渲染后端、分辨率、Debug 或 Release、场景、活跃单位数、测量范围（模拟或完整帧）、采样时长，以及 P50、P95、P99 和最大帧时间。
- 无头模拟和窗口渲染分开测，同一场景、同一事件序列。
- 单位梯度：100、200、300、500，必要时 1000。这些是压力档位，不是人口上限。
- 场景：常规行军、密集近战、窄门争夺、破墙瞬间、跨区增援、山洞转移、多线投放、黎明前高回复、镜头缩放和切换。
- 能拆分的耗时尽量拆分：寻路请求、流场重算、索敌和近邻查询、调度、物理、动画、绘制调用、内存、帧尖峰。

## 交付
`reports/agents/T71.md`，开头用 YAML 摘要；正文包括性能表、瓶颈排序、复现命令。只测不改；需要加测量点时交给 Codex。
