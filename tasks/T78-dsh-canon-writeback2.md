---
id: T78
title: canon 第二轮写回：T72 列出的表格外残留（光热、召唤与回声、E04 傍晚措辞）
owner: dsh
status: done
branch: dsh/t78-canon-writeback2
worktree: ../亡魂王子-t78
allowed: [docs/canon/A/WORLD-BIBLE.md, docs/canon/A/NARRATIVE-DESIGN.md, docs/canon/shared/CANON-COMPACT.md, docs/canon/WORLD-COMPENDIUM.md, docs/canon/B/, docs/canon/C/, docs/canon/CHANGELOG-R2.md]
forbidden: [docs/world-r2.md, scripts/, art/, tasks/, proto/]
verify: test -f docs/canon/CHANGELOG-R2.md
retry_limit: 2
max_minutes: 150
escalate_if: [改动需要新写剧情而不只是改句子, 发现与 R2 互相矛盾的设定]
---

## 目标
Lead 批准：把 `reports/agents/T72.md` 末尾列出的、表格之外的残留冲突全部写回 canon。规则和 T72 一样：
- 中英文成对修改，只改冲突的句子，不新增剧情。
- 合编本同步修改。
- 每处修改记进 `CHANGELOG-R2.md`。

依据 `docs/world-r2.md`，特别是：
- §1.2：战场生成的是"回声"，没有人格
- §2：光热分离
- §3：圣火龛
- §8：结局措辞

## 交付
`reports/agents/T78.md`，开头用 YAML 摘要。
