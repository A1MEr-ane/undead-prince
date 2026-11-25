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
| T18 | 盾兵试点 P3：图集接入游戏、重做走路 | Codex | — | — | 搁置（被新画风局内方案取代，并入 T44） |
| T19 | 平衡：进攻方偏强（T21：守军两群不互援、夺旗条件宽松） | Codex 实现 + DSH 批量对战；Claude 只定目标胜率 | — | — | 待办 |
| T20 | DSH 能力冒烟测试 | DSH | tasks/T20 | reports | 完成 |
| T21 | 10 种子对战统计与平衡假设（只出报告） | DSH | tasks/T21 | reports | 已合并 |
| T22 | 状态树单元测试 | DSH | tasks/T22 | tests/ | 已合并 |
| T23 | 同种子对战不可复现（固定步长 + 模拟/表现随机源分离） | DSH | dsh/t23-determinism | scripts/main.gd 等 | 已合并；verify all 新增 determinism |
| T24 | 工程移到 ~/Projects 并安装谷时定时任务（12:01、18:01） | Claude | — | — | 完成 |
| T25 | 盾兵碎步走路 | Codex | codex/t25-walk | tools/blender/, assets/ | 已合并 |
| T28 | 航海图与回溯闭环（第一阶段 E00/E01，战斗用桩） | Codex | codex/t28-campaign | scripts/campaign/, scenes/campaign.tscn, data/campaign/ | 已合并 |
| T32 | 新画风人物：王室与渡魂人（6 人） | Codex | codex/t32-royals | art/chars/ | 不采用（风格不统一，由 T46 重画） |
| T33 | 新画风人物：据点旧部（4 人） | Codex | codex/t33-crew | art/chars/ | 不采用（由 T46 重画） |
| T34 | 新画风人物：五名仇人 | Codex | codex/t34-council | art/chars/ | 不采用（由 T47 重画） |
| T35 | 新画风 UI 套件与界面样张 | Codex | codex/t35-ui | art/ui/ | 已合并（效果好，保留） |
| T52 | 剧情插画 8 张、结局图（Claude 提示词；原编号 T50 与 DSH 任务撞号） | Codex | claude/t50-story-art | art/story/ | 已合并剧情插画；结局图中途停止，E00–E05 仅占位 |
| T53 | 结局插画按史诗风重画（STYLE_EPIC，E00–E08 + 真结局） | Codex（提示词 Claude） | — | art/story/ | 后期 |
| T38–T40 | 新画风场景：地区套件 7 + 地点 39 | Codex | — | art/env/ | 搁置（Codex 额度用尽未完成；地图可能重新设计，定稿后再出） |
| T42 | 新画风兵种阵容（亡魂、王国、局内 Q 版） | Codex | codex/t42-units | art/units/ | 不采用（王子失去骷髅脸，由 T47 重画） |
| T54 | Bad North 本地取证（镜头、精灵、飞行物、特效、地形；原编号 T48 撞号） | Codex | codex/t48-bn-evidence | docs/research/ | 排队 |
| T65 | 战斗 bug 修复（1.2 米僵持、拼刀进度差、蛇形末行偏移） | Codex | codex/t65-battle-fixes | scripts/ | 搁置（用户 2026-11-26：战斗数值和逻辑不急） |
| T66 | 修复后重跑守军参数扫描（T49 续） | DSH | dsh/t66-defender-resweep | data/battles/ | 搁置 |
| T60 | T19 前置：批量模拟、统计、异常检测工具 | DSH | dsh/t60-sim-tools | tools/sim/ | 已合并 |
| T61 | 战斗系统基线测试（寻路、碰撞、攻击、行为、性能） | DSH | dsh/t61-battle-baseline | tests/ | 已合并 |
| T62 | 战役状态与结局逻辑测试 + 未实现部分测试规格 | DSH | dsh/t62-campaign-endings | tests/, docs/test-specs/ | 已合并 |
| T63 | 美术资产自动检查工具 | DSH | dsh/t63-art-qa | tools/art/ | 已合并 |
| T64 | T45 前置：Blender 精灵管线端到端小规模验证 | DSH | dsh/t64-sprite-e2e | tools/blender/, assets/sprites/e2e/ | 已合并 |
| T58 | 立绘 A 风格重画：王室、渡魂人、旧部（30 张） | Codex | codex/t58-chars-v2a | art/chars/ | 进行中 |
| T59 | 立绘 A 风格重画：五名仇人（15 张） | Codex | codex/t59-chars-v2b | art/chars/ | 进行中 |
| T57 | 立绘高级化对比：3 风格 × 3 角色 | Codex | codex/t57-portrait-compare | art/compare/ | 进行中 |
| T56 | UI 动效与转场原型 + 中文字体候选 | Codex | codex/t56-ui-motion | proto/ui_motion/ | 已合并，待用户试玩校准 |
| T55 | 实验 A：360° 连续旋转 + 飞行物 + 魔法特效原型（原编号 T49 撞号） | Codex | codex/t49-rotation-proto | proto/rotation/ | 排队 |
| T46 | 按 Claude 提示词重画人物 A（29 张） | Codex | codex/t46-chars-a | art/chars/ | 已合并（Codex 自判 5 张不合格，Lead 复审均可用） |
| T47 | 按 Claude 提示词重画仇人 + 兵种阵容（18 张） | Codex | codex/t47-chars-b | art/chars/, art/units/ | 已合并（抽查通过） |
| T43 | 开发者设定集（网页） | Claude（内容、文案、版式）；脚本负责出图和生成页面 | — | — | 待办（依赖全部美术） |
| T44 | 局内新画风落地（按 FLEET_ART_TECH_DECISION 第 3 节）+ 战役接入真实战斗 | Codex | — | scripts/, shaders/ | 待办（依赖 T49 实验结果与兵种图审批） |
| T45 | Blender 精灵按新兵种 Q 版批量重做 | DSH（谷时，先做能力验证）；管线问题 Codex | — | tools/blender/, assets/ | 待办（依赖 T42、T44） |
| T31 | 新画风样张：王子立绘、对话、增益、航海图、局内战斗 | Codex | codex/t31-style | art/style/ | 已合并（全部通过） |
| T30 | 旧部概念图 P0：玛蒂尔达、奥斯温、皮普 | Codex | codex/t30-crew-art | art/canon/ | 已合并（3 张均通过） |
| T29 | 航海图难度颜色、首领据点覆盖、敌情记忆与残响 | Codex | codex/t29-difficulty | data/campaign/, scripts/campaign/ | 已合并（UI 待按新画风重做） |
| T27 | Q 版身体模板 + B 比例（2.3 头身）盾兵 | Codex | codex/t27-chibi | tools/blender/, assets/ | 已合并，待用户看可爱度 |
| T48 | 战斗配置数据化（行为不变，同种子结果逐字一致） | DSH | dsh/t48-battle-data | scripts/main.gd, data/battles/, tests/ | 已合并（verify 全过，结果逐字一致） |
| T49 | 守军联动 + 夺旗条件 + 24 组参数扫描（T19 第一步） | DSH | dsh/t49-defender-balance | scripts/squad.gd, scripts/main.gd, data/battles/ | 已合并 |
| T50 | 增益表转数据文件 + 校验测试 | DSH | dsh/t50-boons-data | data/boons/, tests/ | 已合并 |
| T51 | 战役数据一致性检查 + 走廊难度分布报告 | DSH | dsh/t51-campaign-check | tests/, reports/ | 已合并 |

## 待用户决定
- 开发期剧本语言：中文为主还是英文原稿
- 剧情大纲第 8 节、兵种设计第六节的问题
- 大地图风格（沙盘 / 羊皮纸）
