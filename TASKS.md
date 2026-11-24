# 任务看板

状态：待办 / 进行中 / 待审查 / 已合并 / 搁置。规则见 docs/collab.md。

| 编号 | 任务 | 负责 | 分支 / 位置 | 允许修改 | 状态 |
|---|---|---|---|---|---|
| T01 | 战斗原型（地形、移动、战斗、小队） | Claude | main | — | 已合并 |
| T02 | 烘焙天光、雾海、正交镜头 | Claude | main | — | 已合并 |
| T03 | 行动逻辑按 Bad North 规格重写 | Claude | main | — | 已合并 |
| T04 | UV 精灵与部位贴图（程序化） | Codex | codex/sprites | sprite_factory.gd, unit.gdshader, main.gd 三个函数 | 已合并 |
| T05 | 地形倒角、草丛碎石、树、海岸泡沫 | Codex | codex/terrain-art | terrain.gd, terrain/fog_sea 着色器 | 已合并 |
| T06 | Blender 精灵渲染管线（低模剑盾兵） | Codex | codex/blender-sprites | tools/blender/, assets/sprites/ | 已合并（未接入游戏） |
| T07 | 兵种概念图（王国 8、亡魂 8、卡通版亡魂 4） | Codex | concept/（不入库） | — | 完成，待用户挑选 |
| T08 | 死亡/招魂特效分镜 5 张 | Codex | concept/fx | — | 完成 |
| T09 | 大地图概念图 3 张 | Codex | concept/map | — | 完成，待用户挑选 |
| T10 | 游戏级简化版角色 4 张 | Codex | concept/simple | — | 完成 |
| T11 | 盾兵、普通亡魂三视图与道具图 | Codex | concept/turnaround | — | 完成 |
| T12 | 概念图画板（汇总给用户看） | Claude | Artifact https://claude.ai/artifact/RmquNBWoKVqDMo4mgrxunN | — | 完成 |
| T13 | 剧情大纲 | Claude | docs/story-outline.md | — | 初稿，待用户确认 |
| T14 | 兵种设计 | Claude | docs/units.md | — | 初稿，待用户确认 |
| T15 | 多智能体工作流与验证套件 | Claude | docs/workflow.md, tools/ | — | 已合并 |
| T16 | 盾兵试点 P1：资产规格 | Claude | assets/specs/k2_shieldman.yml | — | 完成 |
| T17 | 盾兵试点 P2：按规格建模渲染 | Codex | codex/t17-shieldman（任务卡 tasks/T17） | tools/blender/, assets/ | 已合并（4 次，见 metrics） |
| T18 | 盾兵试点 P3：图集接入游戏、重做走路 | Claude | main | — | 待办（依赖 T17） |
| T19 | 平衡：进攻方偏强（T21：守军两群不互援、夺旗条件宽松） | Claude | — | — | 待办 |
| T20 | DSH 能力冒烟测试 | DSH | tasks/T20 | reports | 完成 |
| T21 | 10 种子对战统计与平衡假设（只出报告） | DSH | tasks/T21 | reports | 已合并 |
| T22 | 状态树单元测试 | DSH | tasks/T22 | tests/ | 已合并 |
| T23 | 同种子对战不可复现（随机源未完全固定） | DSH（谷时队列） | — | — | 待办 |
| T24 | 工程移到 ~/Projects 并安装谷时定时任务（12:01、18:01） | Claude | — | — | 完成 |
| T25 | 盾兵碎步走路 | Codex | codex/t25-walk | tools/blender/, assets/ | 已合并 |
| T28 | 航海图与回溯闭环（第一阶段 E00/E01，战斗用桩） | Codex | codex/t28-campaign | scripts/campaign/, scenes/campaign.tscn, data/campaign/ | 进行中 |
| T27 | Q 版身体模板 + B 比例（2.3 头身）盾兵 | Codex | codex/t27-chibi | tools/blender/, assets/ | 已合并，待用户看可爱度 |

## 待用户决定
- canon 审阅的三项决定（docs/canon-review.md 第 4 节）
- 剧情大纲第 8 节、兵种设计第六节的问题
- 大地图风格（沙盘 / 羊皮纸）
