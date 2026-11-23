# 任务看板

状态：待办 / 进行中 / 待审查 / 已合并 / 搁置。规则见 docs/collab.md。

| 编号 | 任务 | 负责 | 分支 / 位置 | 允许修改 | 状态 |
|---|---|---|---|---|---|
| T01 | 战斗原型（地形、移动、战斗、小队） | Claude | main | — | 已合并 |
| T02 | 烘焙天光、雾海、正交镜头 | Claude | main | — | 已合并 |
| T03 | 行动逻辑按 Bad North 规格重写 | Claude | main | — | 已合并 |
| T04 | UV 精灵与部位贴图（程序化） | Codex | codex/sprites | sprite_factory.gd, unit.gdshader, main.gd 三个函数 | 已合并 |
| T05 | 地形倒角、草丛碎石、树、海岸泡沫 | Codex | codex/terrain-art | terrain.gd, terrain/fog_sea 着色器 | 已合并 |
| T06 | Blender 精灵渲染管线（低模剑盾兵） | Codex | codex/blender-sprites | tools/blender/, assets/sprites/ | 待审查（未接入游戏） |
| T07 | 兵种概念图（王国 8、亡魂 8、卡通版亡魂 4） | Codex | concept/（不入库） | — | 进行中 |
| T08 | 死亡/招魂特效分镜 5 张 | Codex | concept/fx | — | 进行中 |
| T09 | 大地图概念图 3 张 | Codex | concept/map | — | 完成，待用户挑选 |
| T10 | 游戏级简化版角色 4 张 | Codex | concept/simple | — | 进行中 |
| T11 | 盾兵、普通亡魂三视图与道具图 | Codex | concept/turnaround | — | 进行中 |
| T12 | 概念图画板（汇总给用户看） | Claude | Artifact | — | 待办（等 T07–T11） |
| T13 | 剧情大纲 | Claude | docs/story-outline.md | — | 初稿，待用户确认 |
| T14 | 兵种设计 | Claude | docs/units.md | — | 初稿，待用户确认 |

## 待用户决定
- 兵种造型方向（细节版 / 简化版 / 卡通版）
- 剧情大纲第 8 节、兵种设计第六节的问题
- 大地图风格（沙盘 / 羊皮纸）
