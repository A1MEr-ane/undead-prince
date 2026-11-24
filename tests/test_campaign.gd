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
	_test_difficulty_and_overrides()
	_test_enemy_memory()
	_test_echoes()
	_test_route_knowledge()
	_test_legacy_save()
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
	_expect(state.save.enemy_memory.get("sunhold", 0) == 1 and state.site_difficulty("sunhold") == 5, "宫城首胜计入首领记忆，但尚不降档")
	_expect(state.echo_settlement == {"captured_sites": 5, "bosses": 1, "new_facts": 1, "earned": 18}, "宫城首领纳入残响，剧情调查不冒充攻城")
	_expect(not state.save.enemy_memory.has("kings"), "剧情地点不记录守军胜利")
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


func _test_difficulty_and_overrides() -> void:
	var state = _new_run()
	var canon: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunState.CHART_PATH))
	var originals: Dictionary = {}
	for site in canon.nodes:
		originals[site.id] = site
	_expect(originals.saltmarket.type == "battle" and state.sites.saltmarket.type == "boss", "盐市港先读取 canon，再覆盖为首领")
	_expect(originals.sunhold.type == "capital" and state.sites.sunhold.type == "boss", "宫城首领覆盖不改 canon")
	_expect(state.sites.saltmarket.boss == "CHAR_EARL" and state.sites.sunhold.boss == "CHAR_CHANCELLOR", "新增首领使用 canon 角色 id")
	_expect(state.boss_name("saltmarket") == "罗德里克" and state.boss_name("sunhold") == "沃尔特", "面板从角色索引解析首领中文名")
	_expect(state.sites.oar.display_offset != [0, 0] and state.sites.light.display_offset != [0, 0], "易重叠区域读入显示偏移")
	_expect(state.sites.saltmarket.reward == originals.saltmarket.reward and state.sites.sunhold.scene == originals.sunhold.scene, "局部覆盖保留 canon 的奖励和王都流程")
	_expect(state.difficulty.depth.yard == state.difficulty.depth.lantern, "比较同深度的军道和长航路地点")
	_expect(state.difficulty.describe("yard").full_route_steps == 6 and state.difficulty.describe("lantern").full_route_steps == 8, "捷径分使用经过该点的最短全程")
	_expect(state.site_difficulty("yard") > state.site_difficulty("lantern"), "同深度短路线比长路线难")
	var visible_tiers: Array = []
	for id in state.sites:
		if int(state.sites[id].stage) <= state.STAGE and state.sites[id].type != "hub" and not visible_tiers.has(state.site_difficulty(id)):
			visible_tiers.append(state.site_difficulty(id))
		var detail: Dictionary = state.difficulty.describe(id)
		_expect(detail.depth_score >= 0 and detail.depth_score <= 2 and detail.shortcut_score >= 0 and detail.shortcut_score <= 2, "深度和捷径分边界：" + id)
		_expect(state.site_difficulty(id) >= 1 and state.site_difficulty(id) <= 5, "最终难度限制在 1–5：" + id)
		if state.sites[id].type == "boss":
			_expect(state.site_difficulty(id) == 5, "无记忆首领固定紫档：" + id)
	visible_tiers.sort()
	_expect(visible_tiers == [1, 2, 3, 4, 5], "首局开放地点覆盖五档颜色")
	state.sites.yard.difficulty_adjustment = 100
	_expect(state.site_difficulty("yard") == 5, "正手调上限")
	_expect(state.difficulty.tier("yard", {"yard": 1}) == 5, "手调减记忆之后才限制最终档次")
	state.sites.yard.difficulty_adjustment = -100
	_expect(state.site_difficulty("yard") == 1, "负手调下限")
	state.sites.yard.difficulty_adjustment = 0.49
	_expect(state.site_difficulty("yard") == 3, "小数难度向最近整数取整")
	state.sites.yard.difficulty_adjustment = 0.5
	_expect(state.site_difficulty("yard") == 4, "半档向上取整")
	state.sites.yard.erase("difficulty_adjustment")
	state.sites.gate.difficulty_adjustment = -100
	_expect(state.site_difficulty("gate") == 5, "首领固定档不受普通地点手调影响")
	var low: Dictionary = state.reward_offer("saltmarket", 1)
	var high: Dictionary = state.reward_offer("saltmarket", 5)
	_expect(high.soulfire > low.soulfire and high.rarity == "史诗" and low.rarity == "普通", "高难度提升魂火数量和奖励稀有度")
	_expect(not state.reward_offer("sunhold").grants_reward and state.reward_offer("sunhold").soulfire == 0, "首领覆盖不凭空增加王都构筑奖励")
	_expect(state.difficulty.win_chance(1, 0) > state.difficulty.win_chance(5, 0), "战斗桩受地点难度影响")
	_expect(state.difficulty.win_chance(4, 0) < 0.2 and state.difficulty.win_chance(4, 8) >= 0.5 and state.difficulty.win_chance(4, 8) <= 0.7, "红档符合开局与长路中段胜率目标")
	_expect(state.difficulty.win_chance(5, 8) > state.difficulty.win_chance(5, 0) and state.difficulty.win_chance(1, 100) <= 0.96, "本轮奖励提升胜率且存在上限")
	state.free()


func _test_enemy_memory() -> void:
	var state = _new_run()
	var before: int = state.site_difficulty("light")
	_to_light(state)
	_expect(state.save.enemy_memory.light == 1 and state.site_difficulty("light") == before - 1, "普通地点首胜降一档")
	state.travel_to("oar")
	state.attack()
	state.resolve_battle(false)
	_expect(not state.save.enemy_memory.has("oar"), "败北地点不增加敌情胜利计数")
	state.return_to_bay()
	_expect(state.site_difficulty("light") == before - 1, "敌情记忆跨回溯保留")
	for victory in range(2):
		_to_light(state)
		for id in ["oar", "saltmarket"]:
			_expect(state.travel_to(id) and state.attack() and state.resolve_battle(true), "到达并打赢沿岸据点：" + id)
		_expect(state.save.enemy_memory.saltmarket == victory + 1, "首领每胜一轮只计一次")
		_expect(state.site_difficulty("saltmarket") == (5 if victory == 0 else 4), "首领两胜后降一档")
		_expect(not state.resolve_battle(true), "重复结算不叠加首领记忆")
		state.travel_to("kings")
		state.investigate()
		state.travel_to("roads")
		state.attack()
		state.resolve_battle(false)
		state.return_to_bay()
	_expect(state.site_difficulty("saltmarket") == 4 and state.site_difficulty("wreck") >= 1, "首领记忆跨回溯，所有地点不低于一档")
	_expect(state.difficulty.tier("saltmarket", {"saltmarket": 100}) == 4, "第一版敌情记忆最多降低一档")
	state.free()


func _test_echoes() -> void:
	var state = _new_run()
	_to_light(state)
	state.travel_to("oar")
	state.attack()
	state.resolve_battle(false)
	_expect(state.outcome == "E00" and state.save.echoes == 7, "失败按两处攻城和一条新知识发放 7 残响")
	_expect(state.echo_settlement.captured_sites == 2 and state.echo_settlement.new_facts == 1, "失败也展示结算明细")
	state.resolve_battle(false)
	_expect(state.save.echoes == 7, "结局不能重复领取残响")
	state.return_to_bay()
	_expect(state.save.echoes == 7 and state.echo_settlement.is_empty(), "回溯保留累计残响，清空本轮结算")
	_to_light(state)
	state.travel_to("oar")
	state.attack()
	state.resolve_battle(false)
	_expect(state.save.echoes == 11 and state.echo_settlement.new_facts == 0, "多轮累计，旧知识不会重复给新知识残响")
	state.free()


func _test_route_knowledge() -> void:
	var state = _new_run()
	_expect(state.reward_previews() == {"wreck": 1}, "初次开局只显示下一站奖励")
	state.travel_to("wreck")
	state.attack()
	state.resolve_battle(true)
	_expect(not state.reward_previews().has("oar"), "未走过的边不预览第二层")
	state.travel_to("light")
	state.attack()
	state.resolve_battle(false)
	state.return_to_bay()
	var previews: Dictionary = state.reward_previews()
	_expect(previews.wreck == 1 and previews.light == 2 and previews.pilot == 2 and previews.northrelief == 2, "已知 bay→wreck 边显示 wreck 之后一层奖励")
	_expect(not previews.has("oar"), "连续已知边不会无限向前显示奖励")
	state.travel_to("wreck")
	state.attack()
	state.resolve_battle(true)
	previews = state.reward_previews()
	_expect(previews.oar == 2 and previews.kings == 2 and not previews.has("gate"), "只对已知的出边预览下一站之后一层")
	state.travel_to("light")
	state.attack()
	state.resolve_battle(true)
	_expect(state.reward_previews().get("lantern") == 2, "灯塔本轮侦察仍能多看一层")
	state.free()


func _test_legacy_save() -> void:
	var path := OS.get_environment("TMPDIR").path_join("t29_legacy_%d.json" % OS.get_process_id())
	if not path.is_absolute_path():
		path = "/tmp/" + path
	var legacy: Dictionary = SaveState.new().to_dict()
	legacy.erase("enemy_memory")
	legacy.erase("echoes")
	legacy.known_routes = ["bay>wreck"]
	legacy.known_facts = ["K01"]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var loaded := SaveState.new()
	loaded.enemy_memory = {"light": 3}
	loaded.echoes = 99
	_expect(loaded.read_from_disk(path) == OK, "T28 旧存档无需新字段也能读取")
	_expect(loaded.enemy_memory.is_empty() and loaded.echoes == 0 and loaded.known_facts == ["K01"], "旧档的新字段补默认值，保留原知识")
	var state := RunState.new()
	_expect(state.initialize(true, 1, path) == OK and state.reward_previews().get("light") == 2, "旧存档的已知航路直接获得预览机制")
	loaded.enemy_memory = {"saltmarket": 2}
	loaded.echoes = 18
	_expect(loaded.write_to_disk(path) == OK, "可兼容地写出扩展存档")
	var restored := SaveState.new()
	_expect(restored.read_from_disk(path) == OK and restored.to_dict() == loaded.to_dict(), "新增数值跨磁盘保存，兼容 JSON 浮点数字")
	for invalid in [{"echoes": -1}, {"echoes": 1.5}, {"enemy_memory": {"light": -1}}, {"enemy_memory": {"light": true}}]:
		var bad: Dictionary = loaded.to_dict()
		bad.merge(invalid, true)
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		_expect(restored.read_from_disk(path) == ERR_FILE_CORRUPT and restored.to_dict() == loaded.to_dict(), "非法新字段报错且不覆盖已读入记忆：" + str(invalid))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	state.free()
