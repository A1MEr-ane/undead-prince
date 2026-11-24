# Integration validation / 整合验证

- 13 principal character IDs and 2 supporting IDs, all linked node IDs resolve. / 13个核心、2个配角编号，所有地点关联可解析。
- 27 nodes and 47 directed edges; all endpoints resolve. / 地点及有向连线端点全部可解析。
- 39 legacy site references mapped or explicitly retired as background. / 旧地点均映射或标记为背景。

| Stage | Available nodes | Available edges | Reachable from bay and to sunhold |
|---|---:|---:|---|
| 1 | 19 | 27 | PASS |
| 2 | 24 | 40 | PASS |
| 3 | 27 | 47 | PASS |
| 4 | 27 | 47 | PASS |

These are data checks, not combat balancing or a final plot audit. / 这是数据核查，不等于战斗平衡或最终剧情验收。

## B.3 checks / B.3 核对
- 12 arcs, 39 beats; all character IDs and node IDs resolve, stage floors respected. / 十二条故事、39个场景；角色地点编号及最早阶段检查通过。
- 24 possible memory flags (including existing K07), 31 possible run flags; all referenced prerequisites resolve or use explicit A.5 aliases. / 记忆和本轮标记依赖可解析。
- All scene sites are reachable from the anchor and can reach the capital at their declared stage. Representative trade/grain/naval/old-realm/funerary paths checked. / 所有场景地点在声明阶段均可从锚点抵达并通往王都，代表航路通过检查。
- No map changes. This is a design-data validation, not an implementation or gameplay test. / 未修改地图。仅设计数据校验，尚未实现或进行游戏测试。

## C.2 checkpoint
- Verified 27 existing node IDs, 12 unique new candidate IDs, no collision; all 24 proposed adjacent anchors resolve to existing node IDs. / 已核对27个既有编号、12个候选编号无冲突、24个前后锚点均可解析。
- 39 total rows including hub; 38 non-hub sites. Existing graph and B.3 files unchanged. Candidate routes not yet implemented or validated for stage reachability; C.3 owns that task. / 共39行含据点，38个非据点。原图与B.3未修改；候选路线未实现、未验证阶段可达性，留给C.3。

## C.3 checkpoint / C.3 检查
- Act 1: 25 nodes, 41 edges, 68 complete routes, 5–13 intermediate stops; reachability PASS.
- Act 2: 34 nodes, 64 edges, 536 complete routes, 5–17 intermediate stops; reachability PASS.
- Act 3: 39 nodes, 75 edges, 1364 complete routes, 5–19 intermediate stops; reachability PASS.
- Act 4: 39 nodes, 75 edges, 1364 complete routes, 5–19 intermediate stops; reachability PASS.
- All B.3 scene sites and seven ordered location pairs checked. No cycles; all edges on a complete path. Combat and full dialogue logic untested. / 支线地点与七组有序地点通过，无环，所有边属于完整路径；战斗及完整对白逻辑尚未测试。

- Browser simulation (Chromium, 1440×900, injected in-memory storage): 39 DOM nodes, four successful expeditions using new detours, E01/E04/E08/E05, Return clears current assets, K07 unlock and Final Crossing completed, no JS errors. Actual file storage persistence and battle mechanics not tested. / Chromium浏览器以模拟存储验证39节点、四轮新航路、结局与回溯、真结局；未验证真实文件存储及战斗机制。

## R1 checkpoint

1 25 41 68 5 13
2 34 64 536 5 17
3 39 75 1364 5 19
4 39 75 1364 5 19
PASS topology + side-story locations and ordered pairs

Art queue: 73 unique IDs, all declared dependencies and file references resolve. Art itself not generated or geometrically validated in this round. / 美术任务ID唯一、依赖及路径可解析；本轮未生图或校验几何。
