---
id: T72
title: 把世界观修订 R2 写回 canon（中英双语，只改冲突句）
owner: dsh
status: done
branch: dsh/t72-canon-writeback
worktree: ../亡魂王子-t72
allowed: [docs/canon/A/WORLD-BIBLE.md, docs/canon/A/NARRATIVE-DESIGN.md, docs/canon/shared/CANON-COMPACT.md, docs/canon/WORLD-COMPENDIUM.md, docs/canon/CHANGELOG-R2.md]
forbidden: [docs/world-r2.md, docs/canon/C/, docs/canon/B/, scripts/, art/, tasks/]
verify: test -f docs/canon/CHANGELOG-R2.md
retry_limit: 2
max_minutes: 120
escalate_if: [发现 R2 和 canon 有表格里没列的冲突, 改动需要新写剧情而不只是改句子]
---

## 目标
用户已批准 `docs/world-r2.md`。把它第 10 节表格里的冲突句写回 canon。**只改列出来的句子和段落**，中文和英文成对修改，风格和原文保持一致。

## 规则
- 依据：`docs/world-r2.md` 全文（第 1–8 节是新设定，第 10 节是要改的位置）。
- 每处修改：英文和中文各改一遍，意思一致。不新增剧情，不改人名、地名、结局编号和航路。
- `WORLD-COMPENDIUM.md` 是合编版本，包含 WORLD-BIBLE 和 NARRATIVE-DESIGN 的同样段落，要同步改。
- 写 `docs/canon/CHANGELOG-R2.md`：逐条列出文件、原句（短引用）、新句、依据 R2 的哪一节。
- 表格之外发现的冲突不要改，列进报告给 Lead。

## 交付
报告 `reports/agents/T72.md`，开头用 YAML 摘要。
