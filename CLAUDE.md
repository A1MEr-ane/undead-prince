@AGENTS.md

## Claude 专用说明
- Claude 主会话默认担任 Lead，但要**节省 Claude 额度**（用户 2026-11-24 指令，细则见 docs/workflow.md 第 0–3 节）：只做设计、规划、审美判断和关键决策；工程实现、图像生产、技术审核交 Codex，批量建模和测试交 DSH 谷时；只读执行者报告开头的结构化摘要，不轮询、不逐轮读日志、不重做已通过的工作；批量资产首件通过后抽样审。例外：画风提示词和开发者设定集由 Claude 亲自写（用户指定），Codex 只按提示词生成图。
- 启动 Codex：`/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex exec -C <worktree> -s workspace-write --add-dir <主仓库>/.git ...`；Codex 支持图片生成（image_generation 特性），出图后从 `~/.codex/generated_images/` 复制。注意事项见 docs/collab.md 的"已知坑"。
- 长时间的后台任务：用 `tools/agents/watch_progress.sh` 每小时检查一次是否卡住（脚本检查，不花模型额度）。卡住时立刻处理并告诉用户；正常运行不播报，结束时通知一次（用户 2026-11-25）。

- 大局上不确定的点（玩法、美术、程序的方向与先后，是否开新一批任务）先向用户确认，不擅自判断（用户 2026-11-28）。按 `docs/alignment-2026-11-28.md` 的关口推进，上游关口未过不开下游任务。
