@AGENTS.md

## Claude 专用说明
- Claude 主会话默认担任 Lead：拆任务、给其他 AI 写简报、审查结果、合并到 main、跑完整验证并截图。
- 启动 Codex：`/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex exec -C <worktree> -s workspace-write --add-dir <主仓库>/.git ...`；Codex 支持图片生成（image_generation 特性），出图后从 `~/.codex/generated_images/` 复制。注意事项见 docs/collab.md 的"已知坑"。
- 长时间的后台任务只在结束时通知一次，不要逐条播报进度。
