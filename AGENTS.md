# 亡魂王子复仇（暂名）— 项目说明（AGENTS.md）

单机、即时战术、肉鸽构筑。局内战斗和建模以 Bad North 为模板，玩家站在进攻方。
本文件是所有 AI 协作者（Claude、Codex、DeepSeek 等）共用的项目说明；Claude 通过 CLAUDE.md 引用本文件。

## 文档索引
| 文件 | 内容 |
|---|---|
| `docs/design.md` | 设计决策与待定项（【定】/【议】/【待定】） |
| `docs/story-outline.md` | 剧情大纲（世界、陷害真相、据点 NPC、区域与贵族、结局） |
| `docs/units.md` | 兵种设计（亡魂技能与死亡效果、守军职责、克制关系、招魂循环） |
| `docs/badnorth-reference.md` | Bad North 技术拆解概要 |
| `docs/badnorth-behavior-spec.md` | 行动逻辑规格与参数（读源码整理） |
| `docs/badnorth-art-spec.md` | 美术实现规格：镜头、精灵、烘焙光照、雾、涂色 |
| `docs/collab.md` | 多 AI 协作流程、任务简报与交付模板、已知坑 |
| `TASKS.md` | 任务看板：谁在做什么、在哪个分支 |

## 当前阶段
先做战斗原型，美术和动画按 Bad North 的标准规划，"功能和小巧思都要有"。
构筑系统和世界观设定之后再说，现在不要提前实现。

## 已定（用户原话或明确决定）
- 切入点是质感，不是玩法创新；操作简单、界面简单、带即时决策
- 局内战斗与建模：以 Bad North 为模板
- 视角：进攻方（反向塔防，参考海岛奇兵、部落冲突）
- 故事：王子被陷害，率亡魂大军向自己的王国复仇（剧情和大地图参考 Kingdom Rush 维兹南的复仇）
- 局外继承与解锁：参考 Hades 2
- 不一定以海岛为背景
- 先做单机

## 技术方向
- 【定】引擎：Godot 4（当前 4.7.2，Homebrew 安装，命令 `godot`）。Blender 5.3（命令 `blender`）用于建模和渲染精灵。
- 3D 地形 + 2D 朝向镜头的小兵（Bad North 的做法）：只画一个侧面，左右翻转
- 小兵精灵存部位编码，由着色器套部位贴图换色，等级、阵营、亡魂版本都不用重画帧
- 第一个原型：1 个兵种、朝向镜头的精灵、部位换色、一步一跳移动、错开的决策节拍、冲击累积与击倒

## 运行与验证
- 运行：`godot --path .`；操作：1/2 或点击小兵选队（时间放慢到 0.3），左键地面下令，右键取消，Q/E 旋转，滚轮缩放，R 重开
- 截图验证（`--` 之后是游戏参数，截图存到 shots/，已在 .gitignore）：
  `godot --path . -- --auto --zoom=9 --focus=12,13 --out=$PWD/shots --shots=3,6,10`
  其他参数：`--zoom=正交尺寸`（默认 15）、`--yaw=度`、`--sun=太阳仰角`（默认 55，从 +X 侧照来）、`--dump_atlas`（导出精灵图集预览）、`--click_test`（模拟点选和下令）、`--trace`（每秒打印各队第一个兵的状态路径、体力、敌距、站位距离）、`--no_prewarm`
- 退出时打印 `STATS`（命中、格挡、拼刀、滑退、击飞、落水次数），帧卡顿超过 0.1 秒打印 `HITCH`
- 光照：不用实时光。`terrain.bake_light()` 烘焙三光瓣天光体积，`shaders/terrain.gdshader` 合成；海面是 `shaders/fog_sea.gdshader` 雾平面；镜头正交俯角 30°
- 代码结构：`scripts/terrain.gd` 地形、流场寻路、天光烘焙；`agent_state.gd` 状态树；`beats.gd` 错相节拍；`presence.gd` 阵营势力场；`unit.gd` 小兵本体（身体追步、受击速度、眩晕、击飞、死亡）；`swordsman.gd` 剑兵大脑；`squad.gd` 小队协调器（蛇形方阵、换槽、到位转身）；`sprite_factory.gd` 精灵帧；`main.gd` 场景、模拟驱动顺序、输入、镜头、特效、胜负
- 行动逻辑按 `docs/badnorth-behavior-spec.md` 实现；数值改动先对照规格第 12 节

## 参考资料
用户本地有 Bad North 的解包文件：`~/Downloads/BadNorth-Unpacked`（反编译源码在 `DecompiledSource/Assembly-CSharp`，素材在 `ExtractedMedia`、`UnityProject/ExportedProject`）。整理过的结论见 `docs/badnorth-*.md`。

## 多 AI 协作规则（必须遵守，细节见 docs/collab.md）
- **主会话（Lead）负责整合**：拆任务、写简报、审查、合并到 main、运行完整验证。其他 AI 不直接改 main。
- **一个任务一个分支 + 一个 worktree**：分支前缀按执行者，`claude/`、`codex/`、`deepseek/`；worktree 放在 `../亡魂王子-<任务名>`。
- **文件所有权**：简报里写明"只能改哪些文件"；两个并行任务不能改同一个文件。共享入口（`scripts/main.gd`、`project.godot`）的改动只做最小接入，或写进报告让 Lead 来改。
- **开工前先读**：本文件、简报指定的 docs、要改的代码。不清楚的需求写进报告的"疑问"，不要自行扩大范围。
- **交付报告**：按 docs/collab.md 的模板写（改动、验证命令与输出、截图路径、风险、未完成、疑问）。不伪造验证结果；没跑或跑不了就写明。
- **决策记录**：新的设计决定只写进 docs 对应文件并标注【定】/【议】；不要在代码注释里埋设计决定。
- 提交信息结尾署名：`Co-Authored-By: <模型名> <邮箱或 noreply>`。

## 协作方式
- 用中文回答，先给结论，少铺垫
- 区分事实、推断、建议；证据不足时直接说
- 不用套话和空泛总结，例如"不是……而是……""真正的……""这也解释了为什么……"
- 视觉改动要用实际运行截图验证，不能只看代码就判定完成
- 用户的方案有问题时直接指出，并给出替代方案
