extends RefCounted
## T62：战役流程、跨周目持久字段、E00 失败覆盖与五条走廊首领覆盖。
## 只补 test_campaign.gd / test_campaign_data.gd 没有覆盖的部分；第二至第四阶段、
## E02–E08、K07 与真结局封档只写在 docs/test-specs/campaign-endings.md。

const RunState = preload("res://scripts/campaign/run_state.gd")
const SaveState = preload("res://scripts/campaign/save_state.gd")

const COASTAL := ["bay", "wreck", "light", "oar", "saltmarket", "kings", "roads",
	"merchant", "sunhold"]
const NAVAL := ["bay", "wreck", "pilot", "watchskerry", "gate", "foundry", "yard",
	"lion", "sunhold"]
const GRAIN := ["bay", "wreck", "light", "oar", "lantern", "mill", "titheford",
	"harvest", "granary", "lock", "provision", "sunhold"]
const MARSH := ["bay", "wreck", "light", "oar", "lantern", "harvest", "silent",
	"graves", "hospice", "abbey", "provision", "sunhold"]
const OLD_COURT := ["bay", "wreck", "pilot", "old", "winterpalace", "orchard",
	"abbey", "funeral", "sealquay", "procession", "sunhold"]
const CORRIDORS := {
	"coastal": COASTAL,
	"naval": NAVAL,
	"grain": GRAIN,
	"marsh": MARSH,
	"old_court": OLD_COURT,
}
## roguelike.md 第 9 节：五条走廊各一个中段首领。葬海与旧王庭共用苍白圣堂。
const CORRIDOR_BOSS := {
	"coastal": "saltmarket",
	"naval": "gate",
	"grain": "granary",
	"marsh": "abbey",
	"old_court": "abbey",
}

var checks := 0
var failures := 0


func run_all() -> int:
	print("Campaign 流程与跨周目测试")
	_test_multi_return_accumulation()
	_test_all_stage_one_failure_points()
	_test_corrupt_and_legacy_save()
	_test_corridor_boss_coverage()
	print("=== Campaign 流程结果：%d 个断言，%d 个失败 ===" % [checks, failures])
	return failures


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("[FAIL] " + message)


func _new_run():
	var state := RunState.new()
	_expect(state.initialize(false, 7) == OK, "只读 canon 与奖励数据可读取")
	return state


func _travel_and_win(state, path: Array) -> void:
	for index in range(1, path.size()):
		var id := str(path[index])
		_expect(state.travel_to(id), "沿航路前往：" + id)
		if id == "sunhold":
			_expect(state.phase == "capital", "抵达王都后进入王都章节")
			return
		var site: Dictionary = state.sites[id]
		if site.type == "lore":
			_expect(state.investigate(), "调查剧情点：" + id)
		else:
			_expect(state.attack(), "进入战斗：" + id)
			_expect(state.resolve_battle(true), "胜利结算：" + id)


func _finish_capital_e01(state) -> void:
	_expect(state.advance_capital(), "王室会面提交王权")
	_expect(state.crown == "claim", "第一阶段王权固定 claim")
	_expect(state.resolve_battle(true), "宫城对质获胜")
	_expect(state.advance_capital(), "最后的集结提交军誓")
	_expect(state.oath == "keep", "第一阶段军誓固定 keep")
	_expect(state.advance_capital(), "冬政会议继续")
	_expect(state.advance_capital(), "永昼政策提交")
	_expect(state.outcome == "E01" and state.settlement_committed, "首胜只记录 E01 并提交结算")


func _assert_cleared_against(state, blank: Dictionary, expected_run_id: int) -> void:
	var expected := blank.duplicate(true)
	expected.run_id = expected_run_id
	_expect(state.current_data() == expected, "第 %d 轮回溯清空全部本轮字段" % expected_run_id)
	_expect(state.current_site == "bay" and state.route == ["bay"] and state.phase == "map",
		"第 %d 轮回到沉钟湾地图" % expected_run_id)
	_expect(state.outcome.is_empty() and state.capital_step.is_empty(),
		"第 %d 轮清除结局与王都进程" % expected_run_id)
	_expect(state.route_difficulties.is_empty() and state.echo_settlement.is_empty(),
		"第 %d 轮清除本轮路线难度与残响明细" % expected_run_id)


func _test_multi_return_accumulation() -> void:
	var state = _new_run()
	var blank = _new_run()

	# 第 1 轮：沿岸。首次成功必须得到 E01 与 K01。
	_travel_and_win(state, COASTAL)
	_finish_capital_e01(state)
	_expect(state.echo_settlement == {"captured_sites": 7, "bosses": 2, "new_facts": 1, "earned": 27},
		"沿岸首胜结算 7 处攻城、2 个首领、1 条新知识")
	var echoes_1 := int(state.save.echoes)
	var facts_1: Array = state.save.known_facts.duplicate()
	var routes_1: Array = state.save.known_routes.duplicate()
	var memory_1: Dictionary = state.save.enemy_memory.duplicate(true)
	_expect(facts_1 == ["K01"], "沿岸首胜只永久记录 K01")
	_expect(routes_1.size() == 8, "沿岸首胜累计 8 条已知航路")
	_expect(memory_1.size() == 7, "沿岸首胜累计 7 处敌情记忆")
	_expect(echoes_1 == int(state.echo_settlement.earned), "本轮残响等于结算值")
	_expect(state.save.endings_seen == ["E01"] and state.save.last_outcome == "E01",
		"首胜结局写入 endings_seen 与 last_outcome")
	# K02 是当前未实现阶段的知识桩；在回溯前注入，验证下一轮的 _starting_facts 正确衔接。
	state.save.learn("K02")
	var facts_after_seed: Array = state.save.known_facts.duplicate()

	_expect(state.return_to_bay(), "首胜后可正常回溯")
	_assert_cleared_against(state, blank.current_data(), 2)
	_expect(state.save.known_facts == facts_after_seed and state.save.known_routes == routes_1,
		"回溯保留已知事实与航路")
	_expect(state.save.enemy_memory == memory_1 and state.save.echoes == echoes_1,
		"回溯保留敌情记忆与残响")
	_expect(state.save.last_outcome == "E01" and state.save.ferryman_recognised,
		"回溯保留上轮结局并确认渡魂人知情")

	# 第 2 轮：军道。K02 已在上一轮回溯前注入，应进入本轮起点知识。
	var echoes_2_before := int(state.save.echoes)
	var facts_2_before: Array = state.save.known_facts.duplicate()
	var routes_2_before: Array = state.save.known_routes.duplicate()
	var memory_2_before: Dictionary = state.save.enemy_memory.duplicate(true)
	_travel_and_win(state, NAVAL)
	_finish_capital_e01(state)
	var echoes_2 := int(state.save.echoes)
	_expect(echoes_2 > echoes_2_before, "第二局残响在上一局基础上累加")
	_expect(state.echo_settlement.new_facts == 0, "旧知识不重复计入新知识残响")
	_expect(state.save.endings_seen == ["E01"], "重复达成 E01 不重复写入结局")
	_expect(state.save.known_facts == facts_2_before, "旧知识跨局不重复、不丢失")
	_expect(state.save.known_routes.size() > routes_2_before.size(), "新航路继续追加")
	_expect(state.save.enemy_memory.size() > memory_2_before.size(), "新敌情继续追加")
	_expect(state.return_to_bay(), "第二局后可正常回溯")
	_assert_cleared_against(state, blank.current_data(), 3)
	_expect(state.save.known_facts == facts_2_before and state.save.echoes == echoes_2,
		"第二局回溯保留知识桩与累计残响")

	# 第 3 轮：粮运。再次成功，确认多轮累计仍只记录一个结局。
	var echoes_3_before := int(state.save.echoes)
	_travel_and_win(state, GRAIN)
	_finish_capital_e01(state)
	var echoes_3 := int(state.save.echoes)
	_expect(echoes_3 > echoes_3_before, "第三局残响继续累加")
	_expect(state.save.endings_seen == ["E01"] and state.save.last_outcome == "E01",
		"第三局成功后仍不重复记录 E01")
	_expect(state.return_to_bay(), "第三局后可正常回溯")
	_assert_cleared_against(state, blank.current_data(), 4)

	# 第 4 轮：立刻失败。失败只在 endings_seen 追加一次 E00，不清空跨轮数据。
	var facts_4: Array = state.save.known_facts.duplicate()
	var routes_4: Array = state.save.known_routes.duplicate()
	var memory_4: Dictionary = state.save.enemy_memory.duplicate(true)
	var echoes_4_before := int(state.save.echoes)
	_expect(state.travel_to("wreck"), "失败轮前往断桅滩")
	_expect(state.attack() and state.resolve_battle(false), "断桅滩失败结算")
	_expect(state.outcome == "E00" and not state.settlement_committed, "失败记 E00")
	_expect(state.save.endings_seen == ["E01", "E00"], "E00 只追加一次")
	_expect(state.return_to_bay(), "失败轮可正常回溯")
	_assert_cleared_against(state, blank.current_data(), 5)
	_expect(state.save.echoes == echoes_4_before and state.save.last_outcome == "E00",
		"无攻城无新知识的失败不增加残响，但仍更新上轮结局")
	_expect(state.save.known_facts == facts_4 and state.save.known_routes == routes_4,
		"失败轮不丢知识或航路")
	_expect(state.save.enemy_memory == memory_4, "失败轮不增加敌情记忆")

	state.free()
	blank.free()


func _test_all_stage_one_failure_points() -> void:
	var blank = _new_run()
	var probe = _new_run()
	var targets: Array = []
	for id in probe.sites:
		var site: Dictionary = probe.sites[id]
		if int(site.stage) == int(probe.STAGE) and site.type in ["battle", "boss", "entry", "capital"]:
			targets.append(str(id))
	targets.sort()
	_expect(targets.size() == 23, "第一阶段有 23 个可失败的战斗/首领/入口/王都节点")
	probe.free()

	for target in targets:
		var state = _new_run()
		var path := _shortest_stage_one_path(state, str(target))
		_expect(not path.is_empty(), "可找到通往失败点的第一阶段航路：" + str(target))
		if path.is_empty():
			state.free()
			continue
		_travel_and_win(state, path.slice(0, path.size() - 1))
		_expect(state.travel_to(str(target)), "抵达失败点：" + str(target))
		if str(target) == "sunhold":
			_expect(state.phase == "capital", "抵达王都即进入章节")
			_expect(state.advance_capital(), "王都失败前先提交王权")
		else:
			_expect(state.attack(), "失败前进入战斗：" + str(target))
		# 人为制造“半个成功”：三项决定都已填写但未提交结算。
		state.crown = "claim"
		state.oath = "keep"
		state.day = "continue"
		state.settlement_committed = false
		state.allegiance = {"witness": "present"}
		state.councillor_fates = {"hugh": "alive"}
		state.civilian_harm = 1
		state.evidence = ["partial:evidence"]
		state.stores = {"rewards": [{"site": "partial"}]}
		_expect(state.resolve_battle(false), "失败点可结算：" + str(target))
		_expect(state.outcome == "E00" and not state.settlement_committed,
			"任意失败点都只记 E00，不出现半个成功：" + str(target))
		_expect(not state.save.endings_seen.has("E01") and state.save.endings_seen == ["E00"],
			"失败点不能顺带记录 E01：" + str(target))
		_expect(state.phase == "ending" and state.aftermath_seen,
			"失败进入结局并标记亲历尾声：" + str(target))
		var facts_before: Array = state.save.known_facts.duplicate()
		var routes_before: Array = state.save.known_routes.duplicate()
		var memory_before: Dictionary = state.save.enemy_memory.duplicate(true)
		var echoes_before := int(state.save.echoes)
		_expect(state.return_to_bay(), "每个失败点都可回溯：" + str(target))
		_assert_cleared_against(state, blank.current_data(), 2)
		_expect(state.save.known_facts == facts_before and state.save.known_routes == routes_before,
			"失败回溯保留实际获得的知识和航路：" + str(target))
		_expect(state.save.enemy_memory == memory_before and state.save.echoes == echoes_before,
			"失败回溯保留敌情与残响：" + str(target))
		_expect(state.save.last_outcome == "E00" and state.save.ferryman_recognised,
			"失败点保留 E00 并确认渡魂人知情：" + str(target))
		_expect(not state.save.pact_release_known and state.save.permanent_unlocks.is_empty(),
			"失败不解锁 K07 或永久解锁：" + str(target))
		state.free()

	blank.free()


func _shortest_stage_one_path(state, target: String) -> Array:
	var queue: Array = [["bay"]]
	var seen := {"bay": true}
	while not queue.is_empty():
		var path: Array = queue.pop_front()
		var current := str(path[path.size() - 1])
		if current == target:
			return path
		for edge in state.edges:
			if str(edge[0]) != current:
				continue
			var next := str(edge[1])
			if int(state.sites[next].stage) > int(state.STAGE) or seen.has(next):
				continue
			seen[next] = true
			var extended: Array = path.duplicate()
			extended.append(next)
			queue.append(extended)
	return []


func _temp_path(tag: String) -> String:
	var path := OS.get_environment("TMPDIR").path_join("t62_%s_%d.json" % [tag, OS.get_process_id()])
	return path if path.is_absolute_path() else "/tmp/" + path


func _test_corrupt_and_legacy_save() -> void:
	var path := _temp_path("save")
	var source := SaveState.new()
	source.known_facts = ["K01", "K05"]
	source.known_routes = ["bay>wreck", "wreck>light"]
	source.endings_seen = ["E00", "E01"]
	source.last_outcome = "E01"
	source.permanent_unlocks = ["learned_navigation"]
	source.ferryman_recognised = true
	source.pact_release_known = true
	source.save_status = "ACTIVE"
	source.enemy_memory = {"light": 2, "sunhold": 1}
	source.echoes = 42
	_expect(source.write_to_disk(path) == OK, "写入完整存档成功")

	var loaded := SaveState.new()
	_expect(loaded.read_from_disk(path) == OK, "读取完整存档成功")
	var snapshot: Dictionary = loaded.to_dict()
	_expect(snapshot == source.to_dict(), "完整存档字段往返一致")

	# 合法 JSON 但一个旧字段非法：必须整体拒绝，不能把前面读到的字段半写入内存。
	var bad: Dictionary = snapshot.duplicate(true)
	bad.save_status = "ARCHIVED"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	_expect(loaded.read_from_disk(path) == ERR_FILE_CORRUPT, "合法 JSON 中的非法旧字段明确报错")
	_expect(loaded.to_dict() == snapshot, "坏档不覆盖已读入的持久字段")

	# 真正启动时读坏档也不能静默重置或覆盖磁盘上的原始数据。
	var corrupt_state = RunState.new()
	_expect(corrupt_state.initialize(true, 7, path) == ERR_FILE_CORRUPT, "坏档启动返回明确错误")
	_expect(corrupt_state.last_error == ERR_FILE_CORRUPT, "坏档启动保留错误码")
	_expect(corrupt_state.save.to_dict() == SaveState.new().to_dict() and corrupt_state.run_id == 1,
		"坏档不把部分字段带进新一轮")
	_expect(JSON.parse_string(FileAccess.get_file_as_string(path)).save_status == "ARCHIVED",
		"启动失败不覆盖磁盘上的坏档")
	corrupt_state.free()

	# 旧八字段存档：缺少 T29 新增字段，仍读入全部旧数据并补默认值。
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.erase("enemy_memory")
	legacy.erase("echoes")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var old := SaveState.new()
	_expect(old.read_from_disk(path) == OK, "旧八字段存档可直接读取")
	for field in SaveState.LEGACY_FIELDS:
		_expect(old.get(field) == snapshot[field], "旧档字段不丢失：" + str(field))
	_expect(old.enemy_memory.is_empty() and old.echoes == 0, "旧档缺少的新字段补默认值")

	var old_state = RunState.new()
	_expect(old_state.initialize(true, 7, path) == OK, "旧档可经正式入口载入")
	_expect(old_state.save.known_facts == snapshot.known_facts, "旧档载入保留知识")
	_expect(old_state.save.known_routes == snapshot.known_routes, "旧档载入保留已知航路")
	_expect(old_state.save.endings_seen == snapshot.endings_seen, "旧档载入保留结局记忆")
	_expect(old_state.save.ferryman_recognised and old_state.save.pact_release_known,
		"旧档载入保留渡魂人与解约知识")
	_expect(old_state.current_site == "bay" and old_state.run_id == 1,
		"旧档载入后从新一轮锚点开始")
	old_state.free()

	# 覆盖写成新格式后仍能完整读回，确认旧档迁移不会丢字段。
	_expect(source.write_to_disk(path) == OK, "迁移后可写回扩展存档")
	var restored := SaveState.new()
	_expect(restored.read_from_disk(path) == OK and restored.to_dict() == source.to_dict(),
		"扩展存档完整往返")
	var restored_state = RunState.new()
	_expect(restored_state.initialize(true, 7, path) == OK, "扩展存档可经正式入口载入")
	_expect(restored_state.save.to_dict() == source.to_dict(), "正式入口载入全部持久字段")
	restored_state.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_corridor_boss_coverage() -> void:
	var state = _new_run()
	var edge_set := {}
	for edge in state.edges:
		edge_set[str(edge[0]) + ">" + str(edge[1])] = true

	for corridor in CORRIDORS:
		var path: Array = CORRIDORS[corridor]
		_expect(str(path[0]) == "bay", "走廊从沉钟湾开始：" + str(corridor))
		_expect(str(path[path.size() - 1]) == "sunhold", "走廊以王都结束：" + str(corridor))
		for index in range(path.size() - 1):
			var from := str(path[index])
			var to := str(path[index + 1])
			_expect(edge_set.has(from + ">" + to), "走廊边存在于 canon 图：%s→%s" % [from, to])
		for index in range(1, path.size()):
			var id := str(path[index])
			_expect(state.sites.has(id), "走廊节点存在于正式加载表：" + id)
			_expect(_can_reach(state, id, "sunhold"), "走廊节点可到王都：" + str(corridor) + "/" + id)
		var mid_bosses: Array = []
		for index in range(1, path.size() - 1):
			var id := str(path[index])
			if state.sites[id].type == "boss":
				mid_bosses.append(id)
		var expected_boss := str(CORRIDOR_BOSS[corridor])
		_expect(mid_bosses == [expected_boss],
			"每条走廊恰有一个指定中段首领：%s=%s（实际 %s）" % [str(corridor), expected_boss, str(mid_bosses)])
		_expect(not state.boss_name(expected_boss).is_empty(),
			"中段首领可解析角色名：" + expected_boss)
		_expect(state.sites[str(path[path.size() - 2])].type == "entry",
			"王都前最后节点是入口：" + str(corridor))
		_expect(state.sites.sunhold.type == "boss" and not state.boss_name("sunhold").is_empty(),
			"每条走廊终点的宫城都是可解析的首领：" + str(corridor))

	# 盐市港与宫城的 override 首领覆盖都必须实际参与走廊判定。
	_expect(state.sites.saltmarket.type == "boss" and state.boss_name("saltmarket") == "罗德里克",
		"沿岸走廊的盐市港首领覆盖生效")
	_expect(state.sites.sunhold.boss_step == "council",
		"宫城首领战发生在王都 council 步骤")
	_expect(COASTAL.has("saltmarket"), "盐市港位于沿岸走廊")
	# 盐市港只在地理上属于沿岸走廊；其余走廊通过各自中段首领 + 宫城覆盖。
	for corridor in CORRIDORS:
		_expect(CORRIDORS[corridor].has("sunhold"),
			"每条走廊都覆盖宫城首领：" + str(corridor))
	state.free()


func _can_reach(state, start: String, target: String) -> bool:
	var queue: Array = [start]
	var seen := {start: true}
	while not queue.is_empty():
		var current := str(queue.pop_front())
		if current == target:
			return true
		for edge in state.edges:
			if str(edge[0]) == current and not seen.has(str(edge[1])):
				seen[str(edge[1])] = true
				queue.append(str(edge[1]))
	return false
