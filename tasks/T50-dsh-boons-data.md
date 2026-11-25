---
id: T50
title: 增益表转成数据文件 + 校验测试
owner: dsh
status: done
branch: dsh/t50-boons-data
worktree: ../亡魂王子-t50
allowed: [data/boons/, tests/test_boons.gd, tests/run_tests.gd]
forbidden: [scripts/, shaders/, docs/, tasks/]
verify: godot --headless --path . -s tests/run_tests.gd
retry_limit: 2
max_minutes: 45
escalate_if: [docs/boons.md 里有字段缺失或互相矛盾（写进报告，不要自己发明内容）]
---

## 目标
`docs/boons.md` 是五位旧部增益的设计草案。之后的增益系统要从数据读取，不能写死在代码里。
本任务把文档逐条转成 JSON，并写一个校验测试。只做转录，不改设计。

## 要做
1. 通读 `docs/boons.md` 和 `docs/roguelike.md` 第 4 节。
2. 每位旧部一个文件：`data/boons/bernard.json`、`matilda.json`、`oswin.json`、`pip.json`、`ferryman.json`。另有 `data/boons/duo.json` 放双人增益。
3. 每个增益的字段：
   - `id`：英文小写加下划线，例如 `bernard_shield_bash`
   - `crew`
   - `slot`：只能是 `blade`、`formation`、`march`、`soulfire`、`raise`、`passive`、`mastery`、`duo` 之一
   - `name_zh`
   - `effect_zh`（原文照抄）
   - `status`：施加的状态 id，没有就写 null
   - `requires`：依赖的系统，取值来自文档"依赖"一列，映射为 `existing`、`squad_skill`、`prince_soulfire`、`corpse`、`raise`、`morale`、`burning`
   - `params`：文档里出现的具体数字，例如 `{"duration": 4}`，没有就写 `{}`
   - 双人增益另加 `crews`（两人）和 `condition_zh`
4. 每个文件顶部写该旧部的状态定义：`status_id`、`name_zh`、`effect_zh`。
5. 新建 `tests/test_boons.gd`，在 `run_tests.gd` 加一行调用。检查内容：
   - 所有文件可解析，id 全局唯一，slot 与 requires 取值合法
   - 每位旧部五个槽位（blade、formation、march、soulfire、raise）各至少 1 个
   - 每位旧部有 mastery
   - 双人增益引用的 crew 都存在
6. 报告里列出：文档中有缺失、需要 Lead 补充的条目（例如某位旧部的被动不足 3 个、专精缺失）；以及按 `requires` 统计的增益数量。这张统计表决定先做哪个战斗系统。

## 产物
- `data/boons/*.json`
- `tests/test_boons.gd`，以及 `run_tests.gd` 新增的一行
- `reports/agents/T50.md`

## 验收
- [ ] `godot --headless --path . -s tests/run_tests.gd` 退出码为 0
- [ ] 抽查 5 条，`effect_zh` 和文档一字不差（报告里列出抽查的 id）
- [ ] 报告含 requires 统计表

## 交付报告
写到 `reports/agents/T50.md`。
