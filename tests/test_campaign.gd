extends RefCounted

const RunState = preload("res://scripts/campaign/run_state.gd")
const SaveState = preload("res://scripts/campaign/save_state.gd")
const CATEGORIES := ["旧部增益", "招募", "魂火", "缝补", "休整", "遗物", "航海", "知识"]

var checks := 0
var failures := 0


func run_all() -> int:
	print("Campaign 第一阶段闭环测试")
	_test_graph_and_rewards()
	_test_failure_and_return()
	_test_first_success()
	_test_failed_capital()
	_test_save_round_trip()
	print("=== Campaign 结果：%d 个断言，%d 个失败 ===" % [checks, failures])
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


func _test_graph_and_rewards() -> void:
	var state = _new_run()
	_expect(state.sites.size() == 39 and state.edges.size() == 75, "保留全部 39 地点、75 条 canon 有向边")
	var queue: Array = ["bay"]
	var visited: Array = []
	while not queue.is_empty():
		var id: String = str(queue.pop_front())
		if visited.has(id):
			continue
		visited.append(id)
		var outgoing := 0
		for edge in state.edges:
			if edge[0] == id and int(state.sites[edge[1]].stage) <= 1:
				outgoing += 1
				queue.append(edge[1])
		_expect(id == "sunhold" or outgoing > 0, "第一阶段可达地点无死路：" + id)
	_expect(visited.has("sunhold"), "stage 1：bay 可达 sunhold")
	for id in state.sites:
		var site: Dictionary = state.sites[id]
		_expect(state.rewards.has(id), "逐地点列出奖励：" + id)
		var reward: Dictionary = state.rewards[id]
		_expect(reward.reward == site.reward and CATEGORIES.has(reward.category), "奖励原文与八分类一致：" + id)
		if int(site.stage) > 1:
			_expect(not visited.has(id), "后期地点不可进入：" + id)
	_expect(state.available_next() == ["wreck"], "固定登陆战，不允许开局绕行")
	_expect(not state.travel_to("sunhold"), "拒绝跳过有向边")
	_expect(state.travel_to("wreck"), "可以沿 bay→wreck 前进")
	_expect(not state.travel_to("pilot"), "本站未结算不能继续航行")
	_expect(state.attack() and state.resolve_battle(true), "战斗胜利结算")
	_expect(not state.travel_to("bay"), "拒绝逆向航行")
	_expect(state.travel_to("pilot") and state.attack() and state.resolve_battle(true), "引航岛路径可用")
	_expect(not state.available_next().has("old"), "stage 2 的旧王堡未开放")
	_expect(not state.travel_to("old"), "模型层拒绝进入后期节点")
	state.free()


func _to_light(state) -> void:
	for id in ["wreck", "light"]:
		_expect(state.travel_to(id), "进入 " + id)
		_expect(state.attack() and state.resolve_battle(true), "结算 " + id)


func _test_failure_and_return() -> void:
	var state = _new_run()
	_to_light(state)
	_expect(state.save.known_facts.has("K01"), "地方禁救令提供 K01")
	_expect(state.travel_to("oar") and state.attack(), "前往折桨港战斗")
	state.allegiance = {"witness": "present"}
	state.councillor_fates = {"hugh": "alive"}
	state.civilian_harm = 1
	state.crown = "claim"
	state.oath = "keep"
	state.day = "continue"
	_expect(state.resolve_battle(false), "败北可结算")
	_expect(state.outcome == "E00" and not state.settlement_committed, "部分决定不构成成功，失败记 E00")
	_expect(not state.resolve_battle(true), "失败后不能覆盖结局")
	_expect(state.save.endings_seen == ["E00"], "一轮只记录一个结局")
	var memory: Dictionary = state.save.to_dict()
	_expect(state.return_to_bay(), "E00 可以回溯")
	_assert_cleared(state)
	_expect(state.save.known_facts == memory.known_facts, "回溯后知识保留")
	_expect(state.save.known_routes == memory.known_routes, "已知航路保留")
	_expect(state.save.last_outcome == "E00" and state.save.ferryman_recognised, "保留上轮结果，确认渡魂人知情")
	_expect(not state.save.pact_release_known and state.save.permanent_unlocks.is_empty(), "失败次数不解锁后期")
	_expect(not state.return_to_bay(), "不能重复回溯")
	state.free()


func _assert_cleared(state) -> void:
	var fresh = _new_run()
	var expected: Dictionary = fresh.current_data()
	expected.run_id = 2
	_expect(state.current_data() == expected, "§12 全部本轮字段清空，只有 run_id 进入下一轮")
	_expect(state.current_site == "bay" and state.route == ["bay"] and state.phase == "map", "导航回到沉钟湾")
	_expect(state.outcome.is_empty() and state.capital_step.is_empty(), "清除本轮结局及王都进程")
	fresh.free()


func _to_capital(state) -> void:
	_to_light(state)
	_expect(state.travel_to("kings"), "前往沉王群像")
	_expect(not state.attack(), "剧情点无强制战斗")
	_expect(state.investigate(), "剧情点调查结算")
	for id in ["roads", "merchant"]:
		_expect(state.travel_to(id) and state.attack() and state.resolve_battle(true), "通往王都：" + id)
	_expect(state.stores.rewards.size() == 4, "入口不凭空给予构筑奖励")
	_expect(state.travel_to("sunhold") and state.phase == "capital", "抵达王都章节")
	_expect(state.capital_entry == "merchant", "记录本轮王都入口")


func _test_first_success() -> void:
	var state = _new_run()
	_to_capital(state)
	_expect(not state.resolve_battle(true), "未初始化王权决定时不能提前结算")
	_expect(state.advance_capital() and state.crown == "claim", "第一阶段王权固定 claim")
	_expect(not state.advance_capital(), "宫城战未获胜不能跳过")
	_expect(state.resolve_battle(true) and state.save.known_facts.has("K01"), "宫廷档案补全知识")
	_expect(state.advance_capital() and state.oath == "keep", "第一阶段军誓固定 keep")
	_expect(state.advance_capital() and state.advance_capital(), "冬政会议与永昼政策依次执行")
	_expect(state.day == "continue" and state.settlement_committed, "提交完整三项决定")
	_expect(state.outcome == "E01" and state.save.endings_seen == ["E01"], "首胜只能 E01")
	_expect(not state.advance_capital() and not state.resolve_battle(false), "提交成功后不得改记 E00")
	_expect(not state.save.known_facts.has("K07"), "E01 不解锁解约知识")
	_expect(state.return_to_bay(), "成功后正常回溯")
	_assert_cleared(state)
	_expect(state.save.last_outcome == "E01" and state.save.endings_seen == ["E01"], "成功记录跨轮保存")
	_expect(state.STAGE == 1 and not state.available_next().has("old"), "本交付保持第一阶段范围")
	state.free()


func _test_failed_capital() -> void:
	var state = _new_run()
	_to_capital(state)
	_expect(state.advance_capital() and state.resolve_battle(false), "王都内也可失败")
	_expect(state.outcome == "E00", "王都部分决定后失败记 E00")
	_expect(state.return_to_bay(), "王都失败可回溯")
	_assert_cleared(state)
	_expect(state.save.known_facts.has("K01"), "王都失败保留已知事实")
	state.free()


func _test_save_round_trip() -> void:
	# 测试注入临时路径，既不碰玩家档案，也可在禁止写用户 Library 的沙箱运行。
	var path := OS.get_environment("TMPDIR").path_join("t28_round_trip_%d.json" % OS.get_process_id())
	if not path.is_absolute_path():
		path = "/tmp/" + path
	var state = _new_run()
	_to_light(state)
	state.attack() # 已结算地点不可重打。
	_expect(state.travel_to("oar") and state.attack() and state.resolve_battle(false), "持久化前记录败北")
	state.return_to_bay()
	state.save.permanent_unlocks = ["learned_navigation"]
	_expect(state.save.write_to_disk(path) == OK, "写入 JSON 存档成功")
	var loaded := SaveState.new()
	_expect(loaded.read_from_disk(path) == OK, "重新读取 JSON 存档成功")
	_expect(loaded.to_dict() == state.save.to_dict(), "全部持久字段往返一致")
	var resumed := RunState.new()
	_expect(resumed.initialize(true, 7, path) == OK, "重新启动可载入存档")
	_expect(resumed.save.to_dict() == state.save.to_dict() and resumed.current_site == "bay", "重启保留记忆，从锚点开始")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(raw.size() == SaveState.FIELDS.size(), "存档只含持久字段，不写入本轮资产")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_expect(loaded.read_from_disk(path) == ERR_FILE_CORRUPT, "损坏存档明确报错，不静默重置")
	_expect(loaded.to_dict() == state.save.to_dict(), "坏档不覆盖已读入的记忆")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	state.free()
	resumed.free()
