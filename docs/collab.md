# 多 AI 协作流程

## 1. 角色
| 角色 | 谁 | 做什么 |
|---|---|---|
| 用户 | 你 | 定方向、拍板【议】→【定】、验收 |
| Lead | Claude 主会话（默认） | 拆任务、写简报、启动其他 AI、审查、合并、完整验证、向用户汇报 |
| 执行者 | Codex / DeepSeek / Claude 子会话 | 在自己的分支和 worktree 里完成一个任务，交报告 |

适合分工的方向（按目前观察）：
- **Codex**：图片生成（概念图、三视图、地图）、Blender 脚本、独立的程序化素材、明确边界的功能实现
- **DeepSeek**：【待观察】适合先给文字类或边界清楚的代码任务（例如数值表、对话文本、单个独立脚本），确认质量后再加大
- **Claude**：架构、行动逻辑、跨模块整合、审查

## 2. 一个任务的生命周期
1. Lead 在 `TASKS.md` 登记：编号、负责人、分支、允许修改的文件、状态
2. Lead 建 worktree：`git worktree add -b <前缀>/<任务名> ../亡魂王子-<任务名> main`
3. Lead 写简报（模板见第 3 节），执行者开工
4. 执行者在分支上提交，写交付报告（模板见第 4 节）
5. Lead 审查：读 diff、跑验证、看截图；不合格就把具体问题写回给同一个执行者
6. Lead 合并到 main（`git merge --no-ff`），再跑一次完整验证，更新 `TASKS.md`，清理 worktree

## 3. 任务简报模板
```
你在 <worktree 绝对路径>（分支 <分支名>）工作。先读 AGENTS.md 和 <相关 docs>。

## 目标
<一句话目标 + 背景>

## 要做
<编号列出具体要求；给出接口约束（函数签名、数据格式、动画名等）>

## 约束
- 只修改：<文件列表>；可新增：<目录>
- 不要修改：<文件列表>（其他任务在改）
- 需要别处配合的改动写进报告，不要自己改

## 验证
<具体命令；需要截图的写明截图参数>

## 交付报告
按 docs/collab.md 第 4 节模板。
```

## 4. 交付报告模板
```
## 结果：完成 / 部分完成 / 失败
## 改动
- 文件：做了什么
## 验证
- 命令：输出摘要（原样贴关键行）
- 截图：路径
## 风险与已知不足
## 未完成
## 疑问（需要用户或 Lead 决定的）
```

## 5. 质量底线
- 视觉改动必须有实际运行截图；跑不了窗口就写明"未截图"，由 Lead 补
- 不改动接口语义；要改就写进报告让 Lead 决定
- 不提交 `concept/`、`shots/`、`.godot/`、临时文件；`.uid` 文件要提交（Godot 4 的资源 ID）
- 数值改动对照 `docs/badnorth-behavior-spec.md` 第 12 节和 `docs/units.md`

## 6. 已知坑（踩过的）
- **Codex 沙箱不能在 worktree 里提交**：worktree 的 git 元数据在主仓库的 `.git/worktrees/` 下，`workspace-write` 沙箱写不了 `index.lock`。处理：启动时加 `--add-dir <主仓库>/.git`（仍可能失败），失败就让执行者保留改动和补丁，由 Lead 提交。
- **Codex 沙箱打不开 Godot 窗口**：只能跑 `--headless`。截图验证由 Lead 做。
- **新增 `class_name` 脚本后**要先跑一次 `godot --headless --path . --import`，否则全局类找不到。
- **shots/ 里的图片会被 Godot 当资源导入**：目录里放 `.gdignore`（已放）。
- **zsh 的通配符没匹配到会报错**：脚本里用 `ls 目录 | grep` 或 `setopt nullglob`，不要裸写 `*.png`。
- **macOS 证书报错**（`certificate` 相关）是 Godot 的系统日志，无害。
- **退出时 ObjectDB 泄漏警告**：状态树有循环引用，暂不影响运行（待修）。
- **并行跑多个 Godot/Blender 会拖慢帧率**：做性能或时间相关验证时不要同时跑别的重任务。
- **AI 生成的图不能直接当游戏素材**：游戏精灵需要多帧一致的侧面动画和"部位坐标"格式；概念图只用来定造型，之后出三视图 → Blender 建模 → 渲染管线（`tools/blender/`，在分支 codex/blender-sprites）。

## 7. 给其他 AI 的上下文注意
- 不同 AI 读的入口不同：Claude 读 CLAUDE.md（已引用 AGENTS.md），Codex 读 AGENTS.md，DeepSeek 需要在简报里明确让它先读 AGENTS.md。
- 上下文有限的模型（或网页版）：在简报里直接贴相关文档的段落，不要只给路径。
- 网页版 AI（例如 ChatGPT 网页生图）产出的文件需要用户手动放进 `concept/` 对应目录，并在 `TASKS.md` 记一笔。

## 8. GitHub 备份
- 远程：https://github.com/A1MEr-ane/undead-prince（私有）。每次提交后由 `.git/hooks/post-commit` 在后台静默推送（结果在 `.git/push.log`）；钩子不随仓库同步。
