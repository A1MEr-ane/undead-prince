---
id: T63
title: 美术资产自动检查工具
owner: dsh
status: queued
branch: dsh/t63-art-qa
worktree: ../亡魂王子-t63
allowed: [tools/art/, reports/agents/]
forbidden: [art/, scripts/, data/, docs/, shaders/, assets/]
verify: python3 -I tools/art/check_assets.py --selftest
retry_limit: 3
max_minutes: 60
escalate_if: [需要改 allowed 以外的文件, 需要改玩法、剧情、美术方向或正式平衡参数, 疑难工程问题（转 Codex）]
---

## 目标
美术资产越来越多（`art/style`、`art/ui`、`art/chars`、`art/units`、`art/story`，以后还有 `assets/sprites`）。把能用程序判断的验收做成脚本，减少 Lead 看图的次数。**只读 art/，不改图片。**

## 已有（先确认）
- `tools/blender/validate.py`（精灵管线自检，由 `verify.sh sprites` 调用）
- 各批次的 `RESULTS-*.json`（执行者自填的自查记录）
- 提示词：`art/prompts/rendered/`、`rendered_v2/`

## 要做 `tools/art/check_assets.py`
1. 清单一致性：每个 `rendered*/` 提示词都有对应的产物文件；反过来也查，列出多出来、缺少的文件。
2. 规格：尺寸和长宽比（容差 10%）、是否为合法 PNG、文件大小异常（小于 200KB 可能是空图）。
3. 重复检测：主图和 alt 之间、不同角色之间，感知哈希过于接近的列出来，防止误复制。
4. RESULTS 结构：字段齐全；status 只能是 in_review、accepted 或 rejected；checklist 里有"不通过"的项单独列出。
5. 透明和背景：要求暗背景的图，检查四角平均亮度；要求透明背景的精灵，检查 alpha。
6. 输出 `reports/art-qa/<时间>.md`，按"需要 Lead 看 / 程序已判定通过"分两栏。
7. `--selftest` 用临时目录里造的假文件自测。
- 只用 Python 标准库加 macOS 自带的 `sips`；需要 Pillow 的话先检查是否可用，不可用就降级并在报告里说明。

## 验收
- 对现有 `art/` 跑一遍，报告里贴摘要
- `--selftest` 通过

## 通用要求
- 开工前先看现有代码、`tests/`、`tools/`、`TASKS.md`，**已有的功能不要重做**，只补缺口；报告里列出"已有 / 新增"。
- 能用本地脚本判断对错的，写成脚本；不要改玩法、剧情、美术方向和正式平衡参数（`data/battles/proto.json` 里的数值只读）。
- 常规问题自己修，重试上限见 retry_limit；疑难工程问题（引擎崩溃、渲染管线、跨模块重构）停下，在报告里写 `needs_claude: false`、`handoff: codex` 和最小复现。
- 报告开头用 `docs/collab.md` 第 4 节的 YAML 摘要；Lead 默认只读摘要。
