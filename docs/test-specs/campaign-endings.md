# 战役结局测试规格（T62）

状态：**规格 + 现状说明**。当前 `scripts/campaign/` 只实现第一阶段、E00/E01、K01 与普通回溯；第二至第四阶段、E02–E08、K02–K07、终章封档尚未实现。本文件把这些未实现部分的验收标准写成可直接翻译成 GDScript 的测试用例；已有实现的回归测试见 `tests/test_campaign.gd`、`tests/test_campaign_data.gd` 与 `tests/test_campaign_flow.gd`。

依据：`docs/canon/A/NARRATIVE-DESIGN.md` 第 6、8、9、10、12 节（下称 “ND §x”），以及 `docs/canon/C/CAMPAIGN-DATA.json`。本文件不改变 canon；发现实现与 canon 不一致时只回报，不在此处改代码或改 canon。

---

## 0. 公共测试夹具

### 0.1 持久字段、本轮字段、终章字段

沿用 ND §12 的字段名；测试不要用周目数字替代阶段条件。

| 范围 | 字段 | 断言要点 |
|---|---|---|
| 持久 | `known_facts`, `known_routes`, `endings_seen`, `last_outcome`, `permanent_unlocks`, `ferryman_recognised`, `pact_release_known`, `save_status` | 普通回溯后原值保留；`known_facts`/`endings_seen` 去重；`save_status` 只允许 `ACTIVE` / `COMPLETED` |
| 本轮 | `run_id`, `capital_entry`, `site_results`, `evidence`, `allegiance`, `councillor_fates`, `civilian_harm`, `stores`, `crown`, `oath`, `day`, `settlement_committed`, `aftermath_seen` | 每次 Return 后清空；`run_id` 递增；`settlement_committed == true` 才允许成功结算 |
| 终章 | `final_history_outcome`, `successor_settled`, `final_oath_released`, `closure_confirmed`, `credits_seen` | 与普通结局分开记录；只在真结局流程写入；`COMPLETED` 必须在 credits 之前原子落盘 |

建议的公共前置：`RunState.initialize(false, seed)` 或使用临时路径 `initialize(true, seed, path)`；测试结束删除临时存档。构造未来阶段时，可以像现有测试注入 `permanent_unlocks` 一样直接设置持久字段，但必须同时断言生产路径也能自然到达该状态。

### 0.2 判定术语

- **见证（witnessed）**：该轮成功结算，`outcome` 被写入 `last_outcome` 且 `endings_seen` 新增该 ID；不是仅仅看到场景、进入房间或尝试操作。
- **新结局**：本轮结束时记录的 ID 不在本轮开始前的 `endings_seen` 中。
- **已提交决定**：`crown`、`oath`、`day` 均有值，且 `settlement_committed == true`；未提交前这些字段即使被填写也不得参与结局判定。
- **阶段开放**：由持久知识与亲历结果推导，不由 `run_id` 或失败次数推导。

### 0.3 辅助操作（或用等价 API）

```gdscript
# 走一条有向航路；lore 点调查，battle/boss/entry 点胜利结算，sunhold 停在 capital。
tr.run_path(["bay", "wreck", "pilot", "gate", "sunhold"])

# 提交王都决定；未实现的阶段应提供等价的 commit_capital(choice) 接口。
tr.commit_crown("claim" | "recognise")
tr.commit_oath("keep" | "release")
tr.commit_day("continue" | "end")

# 结算当前战斗并验证结局。
tr.win_battle()
tr.fail_battle()

# 回溯并检查本轮清空。
tr.return_to_bay()
tr.assert_current_run_cleared(expected_run_id)
```

如果后续实现改变了函数名，测试语义不变；不要为了测试新增只存在于测试里的旁路写入。需要注入未来状态时，用 `SaveState` 的持久字段构造，并在测试注释中标明“未来阶段桩”。

---

## 1. ND §12 验收表覆盖矩阵

| ND §12 验收行 | 本规格的测试 | 现状 |
|---|---|---|
| First success | END-01, END-12 | 已实现（E01） |
| Stage II | STAGE-01–02, END-02–04 | 未实现 |
| Stage III | STAGE-03, END-05–08, END-11 | 未实现 |
| Failed capital | FAIL-01–05 | E00/回溯已实现；阶段二至四的王都失败待接 |
| Capital branches | CAP-01–03, CAP-05 | 第一阶段固定 claim/keep；分支未实现 |
| Untouched councillor | CAP-04 | 字段存在，完整结算未实现 |
| Return after late ending | KNOW-07, TRUE-01 | 未实现 |
| Decline closure | TRUE-04 | 未实现 |
| True ending | TRUE-02–07, PERSIST-03 | 未实现 |
| New Game | NEW-01–02 | 新存档已实现；完结档内重玩限制待接 |
| §12 判定段（失败记 E00、已提交才判定、清空本轮、原子 COMPLETED） | ACC-00, FAIL-01–03, PERSIST-01–03, TRUE-05 | E00/清空已实现；终章原子写入未实现 |

---

## 2. 基础契约与持久化

### ACC-00 胜负判定只读取已提交决定

- **Canon**：ND §12 判定段。
- **前置**：新存档；Stage I 已抵达王都；`crown`/`oath`/`day` 中至少一个为空或 `settlement_committed == false`。
- **操作**：尝试结算成功；随后直接调用结局判定（不经过完整王都流程）。
- **期望**：
  - 不得产生 E01–E08 中的任何结局；不得把空字符串、`null`、未初始化值当成 `claim`/`keep`/`continue`。
  - 结局判定不修改 `known_facts`、`endings_seen`、`last_outcome`。
  - 如果此时失败，只记 E00（见 FAIL-01）。
- **现状**：`advance_capital()` 的 `day` 分支要求 `crown == "claim" and oath == "keep"`；满足“未初始化不算选择”的基本行为，但尚无通用阶段判定。

### PERSIST-01 多轮持久字段累加，本轮字段每轮清空

- **Canon**：ND §12 字段表、判定段“Clear all current-run data on Return”。
- **前置**：连续完成至少三次成功或失败的历史，且中途获得知识、航路、敌情胜利与残响。
- **操作**：每轮结束调用 Return，记录前后快照。
- **期望**：
  - `known_facts`、`known_routes`、`enemy_memory`（实现扩展）、`echoes`（实现扩展）、`endings_seen`、`permanent_unlocks`、`ferryman_recognised`、`pact_release_known`、`save_status` 按语义保留。
  - `known_facts` / `endings_seen` 不产生重复项；重复达成同一结局不重复写入。
  - 每轮 `current_data()` 全部回到默认值；只有 `run_id` 递增；`route == ["bay"]`、`phase == "map"`、`outcome/capital_step` 为空、`route_difficulties`/`echo_settlement` 清空。
  - 同一轮的 `site_results`、`stores`、`evidence` 不能泄漏到下一轮。
- **现状**：`tests/test_campaign.gd` 覆盖单轮清空与两轮残响；`tests/test_campaign_flow.gd` 覆盖 4 轮（沿岸/军道/粮运/失败）的累加与逐轮清空。

### PERSIST-02 坏档、旧档不丢数据

- **Canon**：ND §12 字段表；现有 `SaveState` 的兼容约定。
- **前置**：一份完整存档；一份缺少实现新增字段的旧八字段存档；一份合法 JSON 但含非法字段值的坏档。
- **操作**：分别 `SaveState.read_from_disk` 与 `RunState.initialize(true, seed, path)`。
- **期望**：
  - 完整存档全部字段往返一致。
  - 旧档的全部旧字段保留，缺失的新字段补默认值，不把旧知识/航路/结局清零。
  - 坏档返回 `ERR_FILE_CORRUPT`；已读入内存的字段不被部分覆盖；启动失败不覆盖磁盘原文件；不静默创建空白存档。
- **现状**：已实现；`tests/test_campaign_flow.gd` 新增“合法 JSON + 非法旧字段”的整档拒绝、旧档正式入口载入与迁移往返。

### PERSIST-03 新存档与完结存档

- **Canon**：ND §12 判定段“A new save starts fresh”“A completed story is a completed save”。
- **前置**：已有一个 `COMPLETED` 存档；另建新存档。
- **操作**：尝试在完结档内发起新出征；读取新档。
- **期望**：
  - 完结档不能进入新出征；只能查看完成档或重播 credits（见 TRUE-05）。
  - 新档所有持久字段回到初始值：初始知识、基础部队、初始解锁；不继承完结档的 `endings_seen`/`known_facts` 等。
  - 新档不受旧档的 `save_status` 影响。
- **现状**：`COMPLETED` 读取与 `available_next()` 空结果已存在；完整的新档/完结档流程待实现。

---

## 3. 阶段开放条件（ND §6）

### STAGE-01 第一阶段

- **Canon**：ND §6 Stage I、§9 E00/E01、§12 First success。
- **前置**：新存档；`known_facts`/`endings_seen` 为空；`run_id == 1`。
- **操作**：完成任意一条第一阶段航路并成功提交王都三项决定。
- **期望**：
  - 只可能得到 E01；失败只可能得到 E00。
  - 不出现 E05–E08，也不出现“终止永昼”的可选项；`day` 通过继承政策固定为 `continue`。
  - `crown == "claim"`、`oath == "keep"`；首次成功不展示灰掉的 Claim/Recognise 双菜单。
  - 首胜后 `endings_seen` 含 E01；Stage II 在 Return 后开放。
- **现状**：已实现；E01 固定，Day 步骤只有“延续永昼”。

### STAGE-02 第二阶段

- **Canon**：ND §6 Stage II、§8 C05A/C05C、§9 E02–E04、§12 Stage II。
- **前置**：`endings_seen` 含 E01，且至少完成一次 Return；`pact_release_known == false`。
- **操作**：进入下一次出征，抵达王都；分别提交 E02/E03/E04 三种组合；另跑一局重复 E01。
- **期望**：
  - E01–E04 均可达；E02–E04 任一“新结局”都是有效的 Stage III 进度门槛。
  - 重复 E01 不开放 Stage III；只有失败 E00 也不开放。
  - 王都展示 Crown 的两种选择（Claim / Recognise）与 Oath 的两种选择（Keep / Release）；第一阶段不出现的选项在第二阶段可用。
  - Day 仍只有继承政策（`continue`），不出现秘印干预。
- **现状**：未实现。

### STAGE-03 第三阶段

- **Canon**：ND §6 Stage III、§6.1 K04–K06、§9 E05–E08、§12 Stage III。
- **前置**：Stage II 已开放，且 `endings_seen` 含至少一个**新**的 E02/E03/E04；本轮取得 K04、K05、K06 与通往秘印的本轮入口。
- **操作**：完成调查并在王都提交 Day 决策；分别测试八种组合与无入口时的分支。
- **期望**：
  - 八种成功组合全部可达，包括 E08；四种新的 Day-end 组合同时开放，不因信任/道德隐藏锁缺失。
  - K04/K05/K06 的知识永久保留，但本轮 `evidence`/`allegiance`/`stores` 清空后不能替代本轮入口；没有入口时不能“终止永昼”。
  - 第一、第二次成功历史不能终止永昼；即使注入 K04/K05/K06，只要阶段未到，Day 仍只能是继承政策 `continue`。
  - K06 不得依赖稀有随机岛；后期王都保底来源随主线进度开放，初始不可用。
- **现状**：未实现；当前 `STAGE` 常量为 1，`available_next()` 不开放 stage 2/3 地点。

### STAGE-04 第四阶段

- **Canon**：ND §6 Stage IV、§10.1–10.3、§12 Return after late ending。
- **前置**：Stage III 已开放；此前已**亲历** E05–E08 中的至少一个（`endings_seen` 含之），并完成 Return；K07 已由渡魂人解释。
- **操作**：进入最终候选出征，完成一轮成功历史，再选择 Farewell 或暂不继续。
- **期望**：
  - 仅“看到秘印”“尝试停机”不算 Stage IV 条件；必须此前有成功结算的 Day-end 结局。
  - K07 在第一次亲历 E05–E08 后的 Return 时获得，不追溯改记旧结局；之后即使玩家改选其他结局，`pact_release_known` 仍保留。
  - 最终候选出征从 S00/基础部队开始，既有政治选择保持开放；失败仍正常记 E00 并 Return。
  - 可在最终候选轮记录 E01–E08 中任意一个；不强制 E08。
- **现状**：未实现。

### STAGE-05 阶段不由周目计数或失败次数决定

- **Canon**：ND §6“Each stage checks actual knowledge and witnessed outcomes, not a generic run counter”；§9 E00“No ending unlock purely from defeat count”。
- **前置**：新存档；连续失败 5–10 次且没有任何 E01；所有阶段标志为空。
- **操作**：每次失败后 Return；观察阶段与可选项。
- **期望**：
  - 始终只有 Stage I、E00；`permanent_unlocks`/`pact_release_known` 不被失败次数改变。
  - 不因 `run_id` 增大而开放 E02–E08 或 Stage II。
  - 仅当亲历并记录 E01 后 Stage II 才开放。
- **现状**：当前实现无阶段系统，但“失败不解锁”已有测试覆盖（`tests/test_campaign.gd`、`tests/test_campaign_flow.gd`）。

### STAGE-06 阶段状态派生与存档兼容

- **Canon**：ND §6、§12 字段表。
- **前置**：持久字段来自旧版本或手工构造，例如 `endings_seen == ["E00","E01"]`、`known_facts == ["K01","K04","K05","K06"]`。
- **操作**：载入存档并计算阶段。
- **期望**：
  - 阶段由 `endings_seen` + 本轮知识/入口 + 终章字段推导，不由 `run_id` 推导。
  - 旧档没有新字段时按默认值处理，不误开 Stage III/IV。
  - `save_status == "COMPLETED"` 时任何阶段推导都不能重新打开可出征状态。
- **现状**：未实现阶段推导；`COMPLETED` 读取已存在。

---

## 4. 三次决定与 E01–E08 映射（ND §8、§9）

### END-00 结局映射表

固定映射；成功结算时从**已提交**的 `crown`/`oath`/`day` 一次计算，不得再弹结局选择菜单。

| ID | Crown | Oath | Day | 首轮开放 | Canon |
|---|---|---|---|---|---|
| E01 | Claim | Keep | Continue | I | ND §9 E01 |
| E02 | Claim | Release | Continue | II | ND §9 E02 |
| E03 | Recognise | Keep | Continue | II | ND §9 E03 |
| E04 | Recognise | Release | Continue | II | ND §9 E04 |
| E05 | Claim | Keep | End | III | ND §9 E05 |
| E06 | Claim | Release | End | III | ND §9 E06 |
| E07 | Recognise | Keep | End | III | ND §9 E07 |
| E08 | Recognise | Release | End | III | ND §9 E08 |

### END-01–08 八种组合逐条

每条用例共用：

- **前置**：对应阶段已开放；王都流程到达最后一次决定前；本轮没有失败；`settlement_committed == false`。
- **操作**：按表中组合提交三项决定；宫城战斗获胜；播放尾声；Return。
- **期望**：
  - 记录且仅记录表中一个 ID；`last_outcome` 为该 ID；`endings_seen` 新增该 ID 一次。
  - `crown`/`oath`/`day` 保留已提交值直到 Return；`settlement_committed == true`。
  - 尾声场景与对应结局匹配；普通结局不播放 credits。
  - Return 后本轮字段清空，持久字段保留；不因同一轮再结算产生第二个结局。

| 用例 | 前置阶段 | Crown | Oath | Day | 期望 | Canon |
|---|---|---|---|---|---|---|
| END-01 | I | Claim | Keep | Continue | E01；首轮不出现 Day 菜单 | ND §9 E01、§12 First success |
| END-02 | II | Claim | Release | Continue | E02；解除军誓后政府靠常规机构与自愿者 | ND §9 E02 |
| END-03 | II | Recognise | Keep | Continue | E03；妹妹在位，保留军誓的军事影响 | ND §9 E03 |
| END-04 | II | Recognise | Release | Continue | E04；兄妹普通下午，制度问题未解 | ND §9 E04 |
| END-05 | III | Claim | Keep | End | E05；解除秘印但保留强制军令 | ND §9 E05 |
| END-06 | III | Claim | Release | End | E06；凡世制度承担过渡 | ND §9 E06 |
| END-07 | III | Recognise | Keep | End | E07；女王在位、共同安排冬季守望 | ND §9 E07 |
| END-08 | III | Recognise | Release | End | E08；第一次自然日落，仍需 K07 才能解约 | ND §9 E08 |

### END-09 未提交/未初始化不得猜结局

- **Canon**：ND §12 判定段。
- **前置**：三项决定中任一为空；或 `settlement_committed == false`。
- **操作**：调用成功结算/结局判定。
- **期望**：不产生 E01–E08；不把空值默认成 Claim/Keep/Continue；返回明确错误或保持未结算；失败时才走 E00。
- **现状**：第一阶段有固定顺序保护；通用判定未实现。

### END-10 一轮只记录一个结局

- **Canon**：ND §9“A single run can record only one of E00–E08”。
- **前置**：已成功记录 E01；本轮 `phase == "ending"`。
- **操作**：再次尝试成功结算或失败结算。
- **期望**：`outcome` 不被覆盖；`endings_seen` 不增加第二个 ID；`echo_settlement` 不重复发残响；Return 仍只清空一次。
- **现状**：已实现并由现有测试覆盖。

### END-11 第三阶段八组合同时可达，E08 无额外道德锁

- **Canon**：ND §6 Stage III、§8 C06“No hidden trust threshold blocks a combination”、§12 Stage III。
- **前置**：Stage III 开放；K04/K05/K06 已取得；本轮入口已取得。
- **操作**：对 END-01–08 的八种组合分别跑一轮；另跑一局把 `civilian_harm` 设高、`allegiance` 设低，但保持相同三项决定。
- **期望**：
  - 八种组合都能得到对应 ID，包括 E08。
  - 低信任/高平民伤害只改变尾声代价与语气，不改变结局 ID，不锁 E08。
  - 不存在隐藏的“道德值”第四轴；测试中不要新增 canon 没有的字段作为门槛。
- **现状**：未实现。

### END-12 第一阶段只开放 E01 的 Day 继承政策

- **Canon**：ND §6 Stage I、§8 C06、§9 E01、§12 First success。
- **前置**：Stage I；未取得秘印知识；`day` 尚未提交。
- **操作**：走到永昼步骤，检查 UI/可选项；提交。
- **期望**：只有“延续永昼/继承政策”路径；不展示“终止永昼”的假选项；`day == "continue"` 且结算为 E01。
- **现状**：已实现；`tests/test_campaign.gd` 断言 `day == "continue"`，`campaign.gd` 只有延续按钮。

---

## 5. K01–K07 的获取与持久化（ND §6.1）

所有 K 用例都需额外断言：知识写入 `known_facts` 后去重、普通 Return 后保留、坏档/旧档读取不丢；`evidence`、`allegiance`、`stores` 等本轮实物/证人/补给清空；`K` 知识本身不能替代本轮入口。

### KNOW-01 K01 阴谋

- **Canon**：ND §6.1 K01、§8 C05B。
- **前置**：Stage I；本轮未取得 K01。
- **操作 A**：走任一带有 `evidence_fragment == "K01"` 的地点并结算（`light`、`oar`、`pilot`、`gate`、`roads`、`granary`、`abbey`）。
- **操作 B**：不走上述地点，直接进入王都宫城对质并获胜。
- **期望**：
  - 操作 A 或 B 至少一个使 `known_facts` 含 K01；B 是王都保底来源，不依赖随机地点。
  - 重复获取不产生重复项；Return 后仍在；`evidence` 中的本轮文书清空，但知识不清空。
  - K01 只暴露阴谋，不自动等于 K02–K07。
- **现状**：已实现（`light` 等证据点与宫城获胜均学习 K01）。

### KNOW-02 K02 女王意志

- **Canon**：ND §6.1 K02、§8 C05A。
- **前置**：Stage II 已开放；本轮未取得 K02。
- **操作**：在旧王果园取得童年速写，或在王室会面/家书/童年信物来源取得；进入王室会面。
- **期望**：`known_facts` 含 K02 并永久保留；能识别女王意志，但不自动强制退位、不自动取得本轮同意；保留军誓仍可能威胁女王独立性。
- **现状**：stage 2 地点不可达，K02 未实现。

### KNOW-03 K03 军誓强制

- **Canon**：ND §6.1 K03、§8 C05C。
- **前置**：Stage II 已开放；军团集结场景可进入。
- **操作**：在集结（Muster）听取军团对白；或走等价保底解释。
- **期望**：`known_facts` 含 K03；Muster 是保底来源，不依赖随机支线；有 K03 才开放 `release` 军誓选择；`keep` 仍可自由选择。
- **现状**：未实现；Stage I 的 Muster 固定 `keep`，不学习 K03。

### KNOW-04 K04 截留亡魂

- **Canon**：ND §6.1 K04、§9 E05–E08。
- **前置**：Stage III 调查已开放；本轮未取得 K04。
- **操作**：在 `funeral`（灵渡码头）或 `sealquay`（封印码头）取得 K04；检查本轮入口。
- **期望**：`known_facts` 含 K04；理解燃料来源；本轮 `stores`/`evidence`/入口仍须单独取得，不因知识自动获得；Return 后 K04 保留、入口清空。
- **现状**：stage 3 地点不可达，K04 未实现。

### KNOW-05 K05 初始盟约

- **Canon**：ND §6.1 K05、§9 E05–E08。
- **前置**：Stage III；本轮未取得 K05。
- **操作**：在 `archive`（沉水藏书阁）或 `winterpalace`（寒宫）取得 K05。
- **期望**：`known_facts` 含 K05；理解永昼起源；不自动取得 K06 或本轮入口；可在 Stage III 前埋伏笔，但正式知识只在取得时写入。
- **现状**：未实现。

### KNOW-06 K06 秘印停机

- **Canon**：ND §6.1 K06、§8 C06、§9 E05–E08。
- **前置**：Stage III；已知 K04、K05；本轮已取得入口/通道图。
- **操作**：由 Oswin 解读 K04/K05 与通道图，取得 K06。
- **期望**：`known_facts` 含 K06；K06 不得依赖稀有随机岛；后期王都保底来源随主线进度开放，初始不可用；没有本轮入口时不能终止永昼；K06 不自动等于成功，仍需合法君主授权。
- **现状**：未实现。

### KNOW-07 K07 自愿解约

- **Canon**：ND §6.1 K07、§9 E05–E08、§10.1、§12 Return after late ending。
- **前置**：此前未亲历 E05–E08；`pact_release_known == false`。
- **操作**：完成一轮 E05–E08 之一；在结局卡阶段检查 K07 状态；执行 Return；回到据点后再检查。
- **期望**：
  - 结局卡阶段 `pact_release_known == false`；不得在结局前追溯解约。
  - Return 后 `pact_release_known == true`，并解锁渡魂人的自愿解约解释；这是首次 E05–E08 的持久效果。
  - 之后再选 E01–E04 不会取消 K07；K07 不能替代本轮成功历史。
  - K07 不是 E05–E08 的替代品，不改变已记录结局。
- **现状**：未实现；`pact_release_known` 字段可读写，但没有解锁路径。

### KNOW-08 知识永久、实物/证人本轮有效

- **Canon**：ND §6.1“A discovered fact is permanent; a document, witness or military ally must be present in the active history”；§12 字段表。
- **前置**：已取得 K04/K05/K06/K07；新的一轮开始。
- **操作**：不重新访问相关地点，直接进入王都/秘印；检查 `known_facts`、`evidence`、`allegiance`、`stores`。
- **期望**：
  - `known_facts` 含全部已学 K；可以在对白/提示中复述知识。
  - `evidence`、`allegiance`、`stores`、`capital_entry` 为本轮值；没有本轮入口/文书不能提交秘印行动。
  - 旧知识不能替代本轮实物；本轮实物也不能自动写回永久知识以外的字段。
- **现状**：字段语义已实现（`known_facts` 持久，`evidence`/`allegiance` 本轮）；K04–K07 未实现。

### KNOW-09 知识持久化与存档往返

- **Canon**：ND §6.1、§12 字段表。
- **前置**：`known_facts` 含 K01–K07 全部。
- **操作**：写入磁盘、重新读取、启动 RunState、Return。
- **期望**：K01–K07 完整保留且顺序不重复；`pact_release_known` 保留；坏档/旧档读取不丢已读知识；新档为空。
- **现状**：持久化机制已实现；K02–K07 生产路径未实现。

---

## 6. 失败与回溯（ND §9 E00、§12）

### FAIL-01 任何岛屿失败都记 E00

- **Canon**：ND §9 E00、§12 Failed capital。
- **前置**：Stage I–IV 任一轮；尚未提交成功结算。
- **操作**：在任一 `battle`/`boss`/`entry` 地点失败；覆盖普通战斗、首领、王都入口、宫城战。
- **期望**：`outcome == "E00"`；`settlement_committed == false`；`endings_seen` 只追加 E00（一次）；不出现 E01–E08；不产生“半个成功”。
- **现状**：`tests/test_campaign_flow.gd` 对 Stage I 的 23 个战斗/首领/入口/王都节点逐个失败验证。

### FAIL-02 王都部分决定后失败

- **Canon**：ND §9 E00、§12 Failed capital。
- **前置**：抵达王都；已提交 Crown 或已进入 Muster；宫城战失败。
- **操作**：在 C05B 宫城对质失败；或阶段二至四的对应王都战斗失败。
- **期望**：记 E00；`crown`/`oath`/`day`/`capital_entry`/`allegiance`/`councillor_fates`/`civilian_harm`/`stores`/`evidence`/`site_results` 在 Return 后全部清空；`known_facts`、`known_routes`、`enemy_memory`、`echoes` 按已取得内容保留；不记录部分政治结果。
- **现状**：Stage I 宫城 council 失败已实现；阶段二至四待接。

### FAIL-03 “半个成功”不得结算

- **Canon**：ND §12 判定段“do not evaluate uninitialised values as choices”“no partial success”。
- **前置**：三项决定已填写，但 `settlement_committed == false`；随后失败。
- **操作**：调用失败结算；检查 outcome 与持久字段。
- **期望**：E00；`settlement_committed` 保持 false；不得用已填写但未提交的值计算 E01–E08；Return 清空部分决定。
- **现状**：实现中 `_finish("E00")` 不读取选择，行为正确；测试覆盖。

### FAIL-04 失败次数不单独解锁

- **Canon**：ND §9 E00“No ending unlock purely from defeat count”；§12。
- **前置**：连续失败多次，未取得 E01/E05–E08。
- **操作**：每次 Return；检查阶段与 `permanent_unlocks`/`pact_release_known`。
- **期望**：只记录 E00；阶段不前进；不解锁 K07、真结局或后期地点；`endings_seen` 中 E00 只出现一次。
- **现状**：现有测试已覆盖失败不解锁后期。

### FAIL-05 回溯清空本轮、保留持久

- **Canon**：ND §12 判定段“Clear all current-run data on Return”。
- **前置**：本轮有 `site_results`、`stores`、`evidence`、`capital_entry`、部分决定与结局。
- **操作**：`return_to_bay()`。
- **期望**：`current_data()` 等于新档默认值（仅 `run_id` 递增）；`route == ["bay"]`、`phase == "map"`；持久字段与结局记忆保留；不能重复 Return（第二次返回 false）。
- **现状**：已实现并有现有测试覆盖。

---

## 7. 王都分支、议员与决定顺序（ND §8、§12）

### CAP-01 王权：Claim / Recognise

- **Canon**：ND §8 C05A–C05D、§12 Capital branches。
- **前置**：Stage II 或之后；抵达王都。
- **操作**：分别提交 `claim` 与 `recognise`；观察宫卫/议会/主持人字段与场景。
- **期望**：
  - `claim`：Edmund 签署撤销摄政并主持过渡会议；宫卫可能反抗；`allegiance` 反映本轮证人/守卫状态。
  - `recognise`：Eleanor 签发政令、召集效忠宫卫并质问 Walter；她主持后续会议；不自动获得她的同意/信任。
  - 两条都不能自动跳过 C05B/C05C/C05D/C06，也不能在结算时重问。
- **现状**：Stage I 固定 `claim`；分支未实现。

### CAP-02 军誓：Keep / Release

- **Canon**：ND §8 C05C、§9 E02/E04/E06/E08、§12 Capital branches。
- **前置**：宫城胜利后、过渡会议前。
- **操作**：分别提交 `keep` 与 `release`；观察军队/参与者/尾声字段。
- **期望**：
  - `keep`：保留强制指挥；可强行调度守港/救急；尾声出现不安或抵抗。
  - `release`：具名人物自行决定留下/离开/完成最后任务；不暗扣本轮构筑；自愿护送仍可用。
  - 决定必须在过渡会议和任何后期遭遇前提交；下一场景反映选择，不重问。
- **现状**：Stage I 固定 `keep`；分支未实现。

### CAP-03 永昼：Continue / End

- **Canon**：ND §8 C06、§9 E05–E08、§12 Capital branches。
- **前置**：Stage III；K04–K06 与本轮入口已取得；合法君主授权。
- **操作**：分别提交 `continue` 与 `end`；对四种前序组合各跑一次。
- **期望**：
  - `continue`：设施继续运行，囚魂仍受束缚；不能魔法消除现存剥削。
  - `end`：Oswin 安全解除束缚；尚存囚魂离去；自然日落到来；王子与自愿者不会消散。
  - 后期开放后，前两决定的任意组合都能选择两者；证据/同意方式只改变政治代价与语气，不改变结局 ID。
  - 早期阶段没有“终止”选项。
- **现状**：Stage I 固定 `continue`；Day 选项未实现。

### CAP-04 未交战议员状态如实记录

- **Canon**：ND §12 Untouched councillor；§8 C05B；WORLD-BIBLE“不能因沃尔特倒台就默认不在场议员死亡”。
- **前置**：本轮未访问/未击败某议员（例如走军道但未去万谷仓，Agnes 未交战）；Walter 已在宫城落败。
- **操作**：结算王都；检查 `councillor_fates` 与尾声文本。
- **期望**：
  - 未交战议员必须有明确状态（建议 `alive`、`unknown` 或 canon 允许的 `fled`/`summoned` 等），不能自动写成 `dead`。
  - 只有本轮 `site_results`/`evidence` 能支持“已击败/已处理”的断言。
  - Walter 的倒台只代表摄政政府失效，不代表所有议员死亡。
  - Return 后 `councillor_fates` 清空，下一轮恢复为未结算。
- **现状**：`councillor_fates` 字典存在且默认空；没有初始化/校验所有议员，也没有尾声分支；Stage I 测试只注入 `{"hugh": "alive"}` 验证清空。需要实现时补完整状态枚举。

### CAP-05 结算不重问决定

- **Canon**：ND §8“Never ask all three again at the end”、§12 Capital branches。
- **前置**：三项决定已提交；进入结局卡/尾声。
- **操作**：检查结局卡与尾声 UI/接口；尝试重新提交任一决定。
- **期望**：不再出现 Crown/Oath/Day 选择菜单；重新提交被拒绝或无效；结局由已提交值计算；`settlement_committed` 只从 false 变 true 一次。
- **现状**：Stage I 已按顺序提交；通用防重入未实现完整测试。

---

## 8. 真结局与封档（ND §10、§12）

### TRUE-01 首次 E05–E08 后获得 K07

- **Canon**：ND §10.1、§12 Return after late ending、KNOW-07。
- **前置**：此前未亲历 E05–E08；`pact_release_known == false`。
- **操作**：完成 E05–E08 之一 → 结局卡 → Return → 据点对话。
- **期望**：结局卡阶段仍未解约；Return 后 `pact_release_known == true`；渡魂人解释自愿解约；不追溯改写刚记录的结局；K07 持久。
- **现状**：未实现。

### TRUE-02 最终候选出征与 Farewell 前置

- **Canon**：ND §10.2 步骤 1–4、§10.3。
- **前置**：K07 已解锁；Stage IV 开放；本轮已完成一个成功历史并记录 E01–E08 中一个。
- **操作**：在收潮前进入 Farewell。
- **期望**：
  - 若 `crown == "claim"`：必须提供合法继承人安排（通常 Eleanor 接受），`successor_settled == true` 才能继续；不能声称解约后永久执政。
  - 若 `oath == "keep"`：必须明确解除强制军誓，`final_oath_released == true`；记录“此前强制服役”和“后来解除”为两个事件。
  - 若 `crown == "recognise"` / `oath == "release"`：分别由女王安排告别、由自愿者护送；不另起继承危机、不暗扣。
  - 未满足条件时不能进入最后海岸；可以暂不继续。
- **现状**：未实现。

### TRUE-03 不可逆确认

- **Canon**：ND §10.2 步骤 5、§10.3 末段。
- **前置**：Farewell 条件满足；到达最后海岸。
- **操作**：触发“结束这段故事 / End this story”与“还不是时候 / Not yet”确认。
- **期望**：
  - 明确提示完结存档不能再发起新出征；这是剧情决定，不是第四个政治轴。
  - 只有明确确认“结束”后才写入 `closure_confirmed == true`；取消/关闭确认不写入。
  - 确认后渡魂人收下王冠信物/熄灭锚灯；不可逆。
- **现状**：未实现。

### TRUE-04 暂不解约走正常回溯

- **Canon**：ND §10.3 末段、§12 Decline closure。
- **前置**：已进入最终确认；K07 已解锁；本轮结局已记录。
- **操作**：选择“还不是时候 / Not yet”；播放尾声；Return。
- **期望**：
  - 走正常自动 Return；不进入 credits；不写 `COMPLETED`；`save_status` 保持 `ACTIVE`。
  - `closure_confirmed` / `credits_seen` 保持 false；`final_history_outcome` 为空或本轮未封档值。
  - 已记录的普通结局、K07、`endings_seen` 保留；本轮字段清空；以后仍可再次尝试真结局。
  - 不允许无限停留在开放历史中；选择后必须回正常回溯。
- **现状**：未实现；现有 `return_to_bay()` 是普通回溯的参考行为。

### TRUE-05 `COMPLETED` 原子写入与崩溃恢复

- **Canon**：ND §10.2 步骤 6、§12 判定段。
- **前置**：TRUE-03 已确认；当前结局与终章字段已确定；credits 尚未播放。
- **操作**：执行封档写入；在写入前/写入中/credits 播放中模拟中断，再重新载入。
- **期望**：
  - 先分别记录 `final_history_outcome` 与本轮普通结局，再写终章 coda；不允许把两者混成一个字段。
  - `save_status` 与终章字段在同一原子写入中变成 `COMPLETED`；要么旧 `ACTIVE` 完整保留，要么新 `COMPLETED` 完整可读，不能出现半写 JSON。
  - `COMPLETED` 写入必须发生在 credits 之前；credits 播放中崩溃后重新载入仍是 `COMPLETED`，不得恢复开放锚点。
  - 恢复后提供 credits 重播或完成档查看；不能发起新出征。
  - `credits_seen` 可以在 credits 完成时置 true；即使 false，`save_status == "COMPLETED"` 也不能回退为可出征。
- **现状**：`SaveState.write_to_disk` 已用 `.tmp` + rename 实现原子替换；但 `COMPLETED` 写入与 credits 流程未实现。

### TRUE-06 终章字段与历史变体

- **Canon**：ND §10.3 表、§12 终章字段。
- **前置**：K07 已解锁；任选 E01–E08 成功历史。
- **操作**：完成真结局，检查 `final_history_outcome`、`successor_settled`、`final_oath_released`、`closure_confirmed`、`credits_seen`。
- **期望**：
  - `final_history_outcome` 记录本次进入终章前的普通结局；不覆盖 `last_outcome` 的历史含义。
  - 真结局是单一 authored 结论，不增加组合维度；E08 是最直接路径但非唯一允许路径（除非未来明确修改 canon）。
  - Claim/Recognise 的继承处理、Keep/Release 的军誓处理、Continue/End 的制度后果均能在终章被承认；不能暗藏道德条件。
- **现状**：未实现。

### TRUE-07 最终确认不是第四政治轴

- **Canon**：ND §10.3“final confirmation is a story decision, not a disguised fourth bit”。
- **前置**：八种普通结局均可记录；K07 已解锁。
- **操作**：对 E01–E08 各跑一次，选择/拒绝真结局。
- **期望**：真结局入口只要求 K07、Stage IV 与已记录的普通成功；不因 Crown/Oath/Day 组合额外锁死（canon 若未来明确只允许 E08，须先改文档，不能由实现暗藏）。“结束/还不是时候”只控制终章，不改变普通结局 ID。
- **现状**：未实现。

---

## 9. 新存档（ND §12 New Game）

### NEW-01 新存档全部重置

- **Canon**：ND §12“A new save starts fresh”“A completed story is a completed save”。
- **前置**：已有完结档或旧档。
- **操作**：创建全新存档并启动。
- **期望**：
  - 所有持久字段回到初始值；`known_facts`/`known_routes`/`endings_seen`/`last_outcome`/`permanent_unlocks`/`pact_release_known` 为空或 false；`save_status == "ACTIVE"`。
  - 初始知识、基础部队、初始解锁按新档规则给予；不继承旧档的后期知识或结局。
  - `run_id == 1`；从沉钟湾开始。
- **现状**：`SaveState` 默认值与 `RunState.initialize` 新档路径已实现；若未来加入初始知识/解锁，需在测试中断言具体清单。

### NEW-02 完结档内不能正史重玩

- **Canon**：ND §12“no canonical replay within closed save”。
- **前置**：`save_status == "COMPLETED"`。
- **操作**：尝试开始新出征、进入航海图、可用 `available_next()`；另开新存档。
- **期望**：完结档不能发起新出征；只能查看完成档/重播 credits；新故事必须新存档，不能在同一存档内重玩正史。
- **现状**：`available_next()` 已对非 `ACTIVE` 返回空；完整 UI 待接。

---

## 10. 已知现状与待实现清单（只记录）

1. **阶段系统**：`scripts/campaign/run_state.gd` 的 `STAGE := 1` 是常量，`available_next()` 只开放 stage 1；没有由 `endings_seen`/知识推导的阶段状态。
2. **王都选择**：`advance_capital()` 固定 `claim`/`keep`/`continue`；第二阶段的双选项、第三阶段的 Day 决策、八组合映射均未实现。
3. **K02–K07**：`SaveState` 有 `pact_release_known` 字段，但没有 K02–K07 的学习路径；`known_facts` 生产路径目前只能获得 K01。
4. **终章字段**：ND §12 的 `final_history_outcome`、`successor_settled`、`final_oath_released`、`closure_confirmed`、`credits_seen` 未进入 `SaveState`。
5. **COMPLETED**：`save_status` 可读可校验，但没有写入 `COMPLETED` 的流程；`write_to_disk` 的 tmp+rename 可作为原子写入基础。
6. **议员状态**：`councillor_fates` 只是空字典；没有五名议员的默认状态、状态枚举或“未交战不默认死亡”的结算测试。
7. **路由/地点**：stage 2/3 地点和五条代表航路已在 canon 图中存在，但当前 `STAGE == 1` 会拒绝进入；本规格不要求现在改 `STAGE`。
8. **数据扩展**：`enemy_memory`、`echoes` 是项目在 ND §12 之外增加的持久字段，当前已纳入 `SaveState.FIELDS`；本规格按现状使用，不把它们当成 canon 新增字段。
