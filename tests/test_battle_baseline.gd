extends RefCounted
## T61 现有战斗系统基线测试（只测不改）。
## 覆盖：流场寻路 / 站位与碰撞 / 攻击判定 / 兵种行为状态切换 / 规格条款回归。
## 由 tests/run_tests.gd 在首帧后调用 run_all()；失败返回非零。
##
## 为了不依赖渲染与 main.gd 的场景搭建，这里用一个假 main（Terrain + Presence +
## 与 main._simulate 相同的每帧顺序）驱动真实的 Unit / Swordsman / Squad 代码。
## 所有断言都标注了 docs/badnorth-behavior-spec.md 的对应小节。

const DT := 1.0 / 60.0

var checks := 0
var failures := 0
var known_issues := 0
var known_issues_resolved := 0

var _current := ""
var _test_failed := false
var _known_issue := false
var _now := 0.0

var fm: FakeMain


class FakeMain:
	extends Node
	## main.gd 的最小替身：Unit / Squad 只用到这些字段和特效回调。

	var terrain: Terrain
	var units: Array = []
	var presence: Array = []
	var squads: Array = []
	var sprite_sets := {}
	var unit_quad: QuadMesh
	var shadow_mesh: PlaneMesh
	var ring_mesh: PlaneMesh
	var sim_rng := RandomNumberGenerator.new()
	var art_rng := RandomNumberGenerator.new()
	var notes := {}

	func note(key: String) -> void:
		notes[key] = notes.get(key, 0) + 1

	func spawn_dust(_pos: Vector3, _n: int, _strength: float) -> void:
		pass

	func spawn_splash(_pos: Vector3) -> void:
		pass

	func spawn_spark(_pos: Vector3) -> void:
		pass

	func spawn_blood(_pos: Vector3, _dir: Vector3) -> void:
		pass

	func spawn_blood_pool(_pos: Vector3) -> void:
		pass

	func shake(_amount: float) -> void:
		pass

	func cam_right() -> Vector3:
		return Vector3(1, 0, 0)

	func on_unit_removed(u) -> void:
		units.erase(u)


func run_all() -> int:
	print("战斗系统基线测试（T61，规格 4/5/7/8/9/11）")
	_run("流场能把单位从 A 带到 B（规格 4）", _test_flow_field_carries_unit)
	_run("流场遇水墙绕行（规格 4）", _test_flow_field_detours_around_water)
	_run("不可达目标不卡死（规格 4）", _test_unreachable_goal_does_not_hang)
	_run("小队到位后站位间距不小于规格值（规格 11.1）", _test_formation_spacing)
	_run("不能穿过悬崖（规格 5.4、move_ok）", _test_cliff_blocks_movement)
	_run("攻击在 0.333 秒命中帧结算且超出距离不命中（规格 7.7）", _test_attack_hit_frame_and_range)
	_run("招架窗口内正面攻击伤害归零（规格 7.9）", _test_parry_negates_frontal_hit)
	_run("拼刀需要双方都在攻击且动画进度差 < 0.4（规格 7.8）", _test_clash_zeroes_damage)
	_run("冲锋时高眩晕触发倒地并进入恢复流程（规格 8、7.1）", _test_knockdown_and_recovery)
	_run("落水只在高速度被推出水边时触发（规格 9）", _test_drown_when_pushed_off_edge)
	_run("待机在敌人进入 4 米后切到备战（规格 7.3）", _test_idle_to_ready)
	_run("冲锋会向邻居传播（规格 7.5）", _test_pursuit_propagation)
	_run("被威慑时备战后退（规格 7.4、7.10）", _test_intimidation_retreat)
	_run("近距离威慑随距离线性衰减（规格 7.10）", _test_proximity_intimidation)
	_run_known_issue(
		"人数不满的蛇形末行没有均分到两侧（规格 11.1）",
		_test_formation_partial_row_centered,
		"规格 11.1：编队蛇形排列、人数不满时空位均分到两侧。squad.gd:_layout 对末行先按 in_row 居中、再因偶数行反向把 c 映射到 sx-1-c，导致 5 人（3×2）时末行两个槽位整体偏向右侧（x 均值 12.242，目标 12.000）。"
	)
	_run_known_issue(
		"拼刀进度差没有取绝对值（规格 7.8）",
		_test_clash_norm_difference_is_signed,
		"规格 7.8 要求两人动画进度相差 < 0.4；swordsman.gd:335 用 a.u.anim_norm() - u.anim_norm() < 0.4，没有 absf()。当受击方比攻击方领先 >0.4 时仍会判拼刀。"
	)
	print("")
	var resolved_note := ""
	if known_issues_resolved > 0:
		resolved_note = "，%d 个已知问题已修复（待移除标记）" % known_issues_resolved
	print("=== Battles 基线结果：%d 个断言，%d 个失败用例，%d 个已知问题%s ===" % [checks, failures, known_issues, resolved_note])
	return failures


# ---------- 测试运行与断言 ----------

func _run(test_name: String, test: Callable) -> void:
	_current = test_name
	_test_failed = false
	_known_issue = false
	AgentState.now = 0.0
	var before := checks
	print("")
	print("-- " + test_name)
	test.call()
	if checks == before and not _test_failed:
		_fail("用例没有执行任何断言（脚本错误？）", "> 0", 0)
	_teardown()
	if _test_failed:
		failures += 1
		print("[FAIL] %s（%d 个断言）" % [test_name, checks - before])
	else:
		print("[PASS] %s（%d 个断言）" % [test_name, checks - before])


## 已知问题用例：失败只记录、不让 verify 变红；如果源码修好则报 XPASS 提醒移除标记。
func _run_known_issue(test_name: String, test: Callable, reason: String) -> void:
	_current = test_name
	_test_failed = false
	_known_issue = true
	AgentState.now = 0.0
	print("")
	print("-- " + test_name + "（已知问题）")
	var before := checks
	test.call()
	if checks == before and not _test_failed:
		_fail("用例没有执行任何断言（脚本错误？）", "> 0", 0)
	_teardown()
	if _test_failed:
		known_issues += 1
		print("[KNOWN ISSUE] %s：%s" % [test_name, reason])
	else:
		known_issues_resolved += 1
		print("[XPASS] %s：已知问题已不再复现，请移除 known issue 标记" % test_name)
	_known_issue = false


func _teardown() -> void:
	if fm != null:
		fm.free()
		fm = null


func _expect_true(actual: bool, label: String) -> void:
	_check(actual, true, label)


func _expect_false(actual: bool, label: String) -> void:
	_check(actual, false, label)


func _expect_eq(actual, expected, label: String) -> void:
	_check(actual, expected, label)


func _expect_lt(actual: float, limit: float, label: String) -> void:
	checks += 1
	if not (actual < limit):
		_fail(label, "< " + str(limit), actual)


func _expect_gt(actual: float, limit: float, label: String) -> void:
	checks += 1
	if not (actual > limit):
		_fail(label, "> " + str(limit), actual)


func _expect_between(actual: float, lo: float, hi: float, label: String) -> void:
	checks += 1
	if actual < lo or actual > hi:
		_fail(label, "[%s, %s]" % [lo, hi], actual)


func _check(actual, expected, label: String) -> void:
	checks += 1
	if actual != expected:
		_fail(label, expected, actual)


func _fail(label: String, expected, actual) -> void:
	_test_failed = true
	if _known_issue:
		print("  [KNOWN ISSUE] %s / %s: 期望=%s 实际=%s" % [_current, label, str(expected), str(actual)])
	else:
		print("  [FAIL] %s / %s: 期望=%s 实际=%s" % [_current, label, str(expected), str(actual)])


# ---------- 测试世界 ----------

func _new_world(level: int = 1) -> void:
	_teardown()
	_now = 0.0
	AgentState.now = 0.0
	AgentState.dt = DT
	fm = FakeMain.new()
	fm.sim_rng.seed = 7
	fm.art_rng.seed = 11
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(fm)

	var t := Terrain.new()
	t.levels.resize(Terrain.SIZE * Terrain.SIZE)
	t.levels.fill(level)
	t.blocked.resize(Terrain.SIZE * Terrain.SIZE)
	t.blocked.fill(0)
	fm.terrain = t
	fm.add_child(t)

	var quad := QuadMesh.new()
	quad.size = Vector2(Unit.QUAD, Unit.QUAD)
	fm.unit_quad = quad
	var shadow := PlaneMesh.new()
	shadow.size = Vector2(0.34, 0.23)
	fm.shadow_mesh = shadow
	var ring := PlaneMesh.new()
	ring.size = Vector2(0.55, 0.55)
	fm.ring_mesh = ring
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/unit.gdshader")
	var anims := {}
	for key in ["idle", "walk", "attack", "clash", "block", "down", "getup", "dead", "tumble", "hit"]:
		anims[key] = Vector2i(0, 4)
	fm.sprite_sets["proc"] = {"material": mat, "anims": anims, "lens": {}, "loops": {}, "direct": false}

	fm.presence = [Presence.new(), Presence.new()]
	fm.presence[0].setup(t, 0)
	fm.presence[1].setup(t, 1)


func _new_squad(faction: int) -> Squad:
	var sq := Squad.new()
	sq.main = fm
	sq.terrain = fm.terrain
	sq.faction = faction
	fm.add_child(sq)
	fm.squads.append(sq)
	return sq


func _new_unit(sq: Squad, pos: Vector3, stats: Dictionary = {}) -> Unit:
	var st := {"hp": 1.0, "damage": 1.0, "knockback": 1.0, "stun": 1.0}
	st.merge(stats, true)
	var u := Unit.new()
	fm.add_child(u)
	u.setup(fm, sq, sq.faction, 0, pos, st)
	sq.units.append(u)
	fm.units.append(u)
	u.slot = u.nav_pos
	return u


## 与 main._simulate 相同的顺序（规格 2.4）：势力场 → 清威慑 → 通知靠近 → 逐个 tick → 小队整队。
func _sim(steps: int) -> void:
	for _i in steps:
		_now += DT
		AgentState.now = _now
		AgentState.dt = DT
		for p in fm.presence:
			p.update(fm.units)
		for u in fm.units:
			u.soft_int = 0.0
			u.hard_int = 0.0
		for u in fm.units:
			if not u.alive_grounded.active:
				continue
			var e = u.enemy
			if e == null or not is_instance_valid(e) or e.removed or not e.alive_grounded.active:
				continue
			e.brain.on_proximity(u)
			if e.enemy != u:
				u.brain.on_proximity(e)
		for u in fm.units.duplicate():
			u.tick(DT)
		for sq in fm.squads:
			sq.tick()


## 只推进一个单位（攻击判定等单点用例，避免对方 AI 干扰）。
func _tick_unit(u: Unit) -> void:
	_now += DT
	AgentState.now = _now
	AgentState.dt = DT
	u.tick(DT)


func _tile_center(x: int, z: int) -> Vector3:
	return fm.terrain.tile_center(Vector2i(x, z))


# ---------- 寻路（规格 4） ----------

func _test_flow_field_carries_unit() -> void:
	_new_world(1)
	var goal := Vector2i(18, 18)
	var start := _tile_center(4, 4)
	var dir := fm.terrain.flow_dir(start, goal)
	_expect_gt(dir.length(), 0.9, "平坦地形起点能取到流场方向（规格 4）")

	var pos := start
	var reached := false
	for _i in 400:
		if fm.terrain.tile_of(pos) == goal:
			reached = true
			break
		var d := fm.terrain.flow_dir(pos, goal)
		_expect_true(d != Vector3.ZERO, "路径中途流场方向不为零（规格 4）")
		pos += d * 0.1
		_expect_true(fm.terrain.is_walkable_at(pos), "流场路径始终在可走格上（规格 4）")
	_expect_true(reached, "沿流场从 (4,4) 走到 (18,18)（规格 4）")

	# 真实单位走一遍
	_new_world(1)
	var sq := _new_squad(0)
	var u := _new_unit(sq, _tile_center(4, 4))
	sq.order_move(_tile_center(18, 18), Vector3(1, 0, 0))
	_sim(1200)
	var dist := Vector2(u.nav_pos.x - _tile_center(18, 18).x, u.nav_pos.z - _tile_center(18, 18).z).length()
	_expect_lt(dist, 0.5, "单位被小队命令带到目标附近（规格 4、5.1）")


func _test_flow_field_detours_around_water() -> void:
	_new_world(1)
	# x=12 的水墙从 z=0 到 z=16，只能从 z>=17 绕过去
	for z in 17:
		fm.terrain.levels[z * Terrain.SIZE + 12] = 0
	var start := _tile_center(5, 10)
	var goal := Vector2i(19, 10)
	var pos := start
	var reached := false
	var path_len := 0.0
	var entered_water := false
	for _i in 500:
		if fm.terrain.tile_of(pos) == goal:
			reached = true
			break
		var d := fm.terrain.flow_dir(pos, goal)
		_expect_true(d != Vector3.ZERO, "绕行时流场方向不为零（规格 4）")
		var next := pos + d * 0.1
		if not fm.terrain.is_walkable_at(next):
			entered_water = true
			break
		path_len += 0.1
		pos = next
	_expect_true(reached, "能绕过水墙到达目标（规格 4）")
	_expect_false(entered_water, "流场方向不会指进不可走格（规格 4）")
	_expect_gt(path_len, 16.0, "绕行路径长于直线距离约 14 米（规格 4）")

	# 真实单位绕行
	_new_world(1)
	for z in 17:
		fm.terrain.levels[z * Terrain.SIZE + 12] = 0
	var sq := _new_squad(0)
	var u := _new_unit(sq, _tile_center(5, 10))
	sq.order_move(_tile_center(19, 10), Vector3(1, 0, 0))
	var crossed_water := false
	for _i in 1500:
		_sim(1)
		var t := fm.terrain.tile_of(u.nav_pos)
		if not fm.terrain.is_walkable(t):
			crossed_water = true
			break
		if t == Vector2i(19, 10):
			break
	_expect_false(crossed_water, "单位绕行时不会走进水里（规格 4、5.1）")
	_expect_eq(fm.terrain.tile_of(u.nav_pos), Vector2i(19, 10), "单位绕水墙后到达目标格（规格 4、5.1）")


func _test_unreachable_goal_does_not_hang() -> void:
	_new_world(1)
	# 目标格 (20,20) 被一圈水包围
	var around := [Vector2i(19, 19), Vector2i(20, 19), Vector2i(21, 19),
		Vector2i(19, 20), Vector2i(21, 20), Vector2i(19, 21), Vector2i(20, 21), Vector2i(21, 21)]
	for t in around:
		fm.terrain.levels[t.y * Terrain.SIZE + t.x] = 0
	var start := _tile_center(4, 4)
	_expect_eq(fm.terrain.flow_dir(start, Vector2i(20, 20)), Vector3.ZERO, "不可达目标的流场方向为零（规格 4）")

	var sq := _new_squad(0)
	var u := _new_unit(sq, start)
	sq.order_move(_tile_center(20, 20), Vector3(1, 0, 0))
	var start_pos := u.nav_pos
	_sim(300)
	var moved := Vector2(u.nav_pos.x - start_pos.x, u.nav_pos.z - start_pos.z).length()
	_expect_lt(moved, 0.05, "不可达时单位原地不动而不是乱走（规格 4）")
	_expect_true(u.alive and is_instance_valid(u), "不可达时单位仍存活、没有崩溃（规格 4）")
	_expect_true(fm.terrain.is_walkable_at(u.nav_pos), "不可达时单位仍在可走格上（规格 4）")


# ---------- 站位与碰撞（规格 11.1、5.4） ----------

func _test_formation_spacing() -> void:
	_new_world(1)
	var sq := _new_squad(0)
	var units: Array = []
	for i in 9:
		var p := Vector3(8.0 + (i % 3) * 0.3, 0, 8.0 + (i / 3) * 0.3)
		units.append(_new_unit(sq, p))
	sq.order_move(Vector3(12, 0, 12), Vector3(0, 0, -1))
	_sim(600)

	var spec_spacing: float = units[0].radius * 2.0 * 1.01
	var min_pair := 1.0e9
	for i in units.size():
		for j in range(i + 1, units.size()):
			var d := Vector2(units[i].nav_pos.x - units[j].nav_pos.x, units[i].nav_pos.z - units[j].nav_pos.z).length()
			min_pair = minf(min_pair, d)
	print("  [data] spacing spec=%.4f min_pair=%.4f" % [spec_spacing, min_pair])
	_expect_gt(min_pair, spec_spacing - 0.002, "到位后任意两人间距 ≥ 2r×1.01（规格 11.1）")

	var max_slot_err := 0.0
	for u in units:
		max_slot_err = maxf(max_slot_err, u.order_dist)
	print("  [data] max_slot_err=%.4f" % max_slot_err)
	_expect_lt(max_slot_err, 0.12, "每个兵都靠近自己的槽位（规格 11.1、11.2）")

	# 规格 11.1 的蛇形排序在满行时和普通行优先位置相同，这里只验证间距/槽位收敛。


func _test_cliff_blocks_movement() -> void:
	_new_world(1)
	# x=12 一整列抬高 2 级：相邻格高差 2 > 1，不可一步跨上
	for z in Terrain.SIZE:
		fm.terrain.levels[z * Terrain.SIZE + 12] = 3
	var low := _tile_center(11, 12)
	var high := _tile_center(12, 12)
	_expect_false(fm.terrain.can_step(low, high), "高差 2 的悬崖不能一步跨上（规格 5.4/move_ok）")
	_expect_false(fm.terrain.move_ok(Vector2i(11, 12), Vector2i(12, 12)), "move_ok 拒绝跨越悬崖（规格 5.4/move_ok）")

	var sq := _new_squad(0)
	var u := _new_unit(sq, _tile_center(8, 12))
	sq.order_move(_tile_center(16, 12), Vector3(1, 0, 0))
	_sim(600)
	_expect_lt(u.nav_pos.x, 12.0, "被悬崖挡住时不会穿到对面（规格 5.4）")

	# 击退速度也不能把单位推过悬崖
	u.velocity = Vector3(6, 0, 0)
	_sim(120)
	_expect_lt(u.nav_pos.x, 12.0, "击退撞悬崖后反弹、不穿墙（规格 5.4）")
	_expect_true(u.alive and is_instance_valid(u), "撞悬崖不会掉出地图或崩溃（规格 5.4）")


# ---------- 攻击判定（规格 7.7、7.8、7.9） ----------

func _test_attack_hit_frame_and_range() -> void:
	_new_world(1)
	var sa := _new_squad(0)
	var sb := _new_squad(1)
	var a := _new_unit(sa, Vector3(10.5, 0, 10.5), {"hp": 10.0})
	var b := _new_unit(sb, Vector3(10.7, 0, 10.5), {"hp": 10.0, "stun_mult": 0.0})
	b.brain.idle.set_true()
	a.facing = Vector3(1, 0, 0)
	a.brain.attack.set_true()
	a.brain.target = b
	a.brain._hit_done = false
	a.play("attack")

	for _i in 20:
		_tick_unit(a)
	_expect_eq(b.hp, 10.0, "0.317 秒时还未到命中帧、不结算（规格 7.7）")
	_tick_unit(a)
	_expect_lt(b.hp, 10.0, "0.333 秒命中帧结算伤害（规格 7.7）")
	_expect_gt(float(fm.notes.get("hit", 0)), 0.0, "命中会记 hit（规格 7.7）")

	# 距离超出 reach：命中帧不结算
	_new_world(1)
	sa = _new_squad(0)
	sb = _new_squad(1)
	a = _new_unit(sa, Vector3(10.5, 0, 10.5), {"hp": 10.0})
	b = _new_unit(sb, Vector3(12.5, 0, 10.5), {"hp": 10.0, "stun_mult": 0.0})
	b.brain.idle.set_true()
	a.facing = Vector3(1, 0, 0)
	a.brain.attack.set_true()
	a.brain.target = b
	a.brain._hit_done = false
	a.play("attack")
	for _i in 24:
		_tick_unit(a)
	_expect_eq(b.hp, 10.0, "命中帧距离仍在 reach 外时不结算（规格 7.7）")


func _test_parry_negates_frontal_hit() -> void:
	_new_world(1)
	var sa := _new_squad(0)
	var sb := _new_squad(1)
	var a := _new_unit(sa, Vector3(10.5, 0, 10.5), {"hp": 10.0})
	var b := _new_unit(sb, Vector3(10.7, 0, 10.5), {"hp": 10.0, "stun_mult": 0.0})
	a.facing = Vector3(1, 0, 0)
	b.facing = Vector3(-1, 0, 0)
	b.play("parry")
	b.anim_t = 0.2
	b.brain.parry.set_true()
	a.brain.attack.set_true()
	a.brain.target = b
	a.brain._hit_done = false

	var atk := {"damage": 1.0, "knockback": 0.0, "stun": 0.0, "launch": 0.0,
		"dir": Vector3(1, 0, 0), "attacker": a.brain}
	b.deal_damage(atk)
	_expect_eq(b.hp, 10.0, "招架窗口内正面剑击伤害归零（规格 7.9）")
	_expect_gt(float(fm.notes.get("parry", 0)), 0.0, "招架会记 parry（规格 7.9）")

	# 窗口外：同一招架动画不再减伤（只改音效/特效）。注意每次攻击都要新建字典，
	# modify_attack 会就地改写 damage。
	b.anim_t = 0.5
	b.deal_damage({"damage": 1.0, "knockback": 0.0, "stun": 0.0, "launch": 0.0,
		"dir": Vector3(1, 0, 0), "attacker": a.brain})
	_expect_lt(b.hp, 10.0, "招架窗口外不减免伤害（规格 7.9）")


func _test_clash_zeroes_damage() -> void:
	_new_world(1)
	var sa := _new_squad(0)
	var sb := _new_squad(1)
	var a := _new_unit(sa, Vector3(10.5, 0, 10.5), {"hp": 10.0})
	var b := _new_unit(sb, Vector3(10.7, 0, 10.5), {"hp": 10.0, "stun_mult": 0.0})
	a.facing = Vector3(1, 0, 0)
	b.facing = Vector3(-1, 0, 0)
	a.brain.attack.set_true()
	a.brain.target = b
	a.play("attack")
	a.anim_t = 0.2
	b.brain.attack.set_true()
	b.brain.target = a
	b.play("attack")
	b.anim_t = 0.1

	var atk := {"damage": 1.0, "knockback": 1.0, "stun": 0.0, "launch": 0.0,
		"dir": Vector3(1, 0, 0), "attacker": a.brain}
	b.deal_damage(atk)
	_expect_eq(b.hp, 10.0, "拼刀这一刀伤害归零（规格 7.8）")
	_expect_true(b.brain.clash.active, "受击方进入拼刀（规格 7.8）")
	_expect_true(a.brain.clash.active, "攻击方也进入拼刀（规格 7.8）")
	_expect_gt(float(fm.notes.get("clash", 0)), 0.0, "拼刀会记 clash（规格 7.8）")

	# 进度差 >= 0.4 不拼刀
	_new_world(1)
	sa = _new_squad(0)
	sb = _new_squad(1)
	a = _new_unit(sa, Vector3(10.5, 0, 10.5), {"hp": 10.0})
	b = _new_unit(sb, Vector3(10.7, 0, 10.5), {"hp": 10.0, "stun_mult": 0.0})
	a.facing = Vector3(1, 0, 0)
	b.facing = Vector3(-1, 0, 0)
	a.brain.attack.set_true()
	a.brain.target = b
	a.play("attack")
	a.anim_t = 0.58
	b.brain.attack.set_true()
	b.brain.target = a
	b.play("attack")
	b.anim_t = 0.02
	b.deal_damage({"damage": 1.0, "knockback": 0.0, "stun": 0.0, "launch": 0.0,
		"dir": Vector3(1, 0, 0), "attacker": a.brain})
	_expect_lt(b.hp, 10.0, "动画进度差 >= 0.4 时不判拼刀（规格 7.8）")


## 规格 7.8：进度"相差"应取绝对值。现状差值带符号，受击方领先 >0.4 时仍拼刀。
func _test_clash_norm_difference_is_signed() -> void:
	_new_world(1)
	var sa := _new_squad(0)
	var sb := _new_squad(1)
	var a := _new_unit(sa, Vector3(10.5, 0, 10.5), {"hp": 10.0})
	var b := _new_unit(sb, Vector3(10.7, 0, 10.5), {"hp": 10.0, "stun_mult": 0.0})
	a.facing = Vector3(1, 0, 0)
	b.facing = Vector3(-1, 0, 0)
	a.brain.attack.set_true()
	a.brain.target = b
	a.play("attack")
	a.anim_t = 0.0          # 进度 0.00
	b.brain.attack.set_true()
	b.brain.target = a
	b.play("attack")
	b.anim_t = 0.58         # 进度 0.967，差 0.967 > 0.4
	var atk := {"damage": 1.0, "knockback": 0.0, "stun": 0.0, "launch": 0.0,
		"dir": Vector3(1, 0, 0), "attacker": a.brain}
	b.deal_damage(atk)
	_expect_lt(b.hp, 10.0, "受击方领先 >0.4 时应按规格不拼刀、正常结算伤害（规格 7.8）")
	_expect_false(a.brain.clash.active and b.brain.clash.active, "受击方领先 >0.4 时不应双双进入拼刀（规格 7.8）")


# ---------- 倒地、恢复、落水（规格 8、9、7.1） ----------

func _test_knockdown_and_recovery() -> void:
	_new_world(1)
	var sq := _new_squad(0)
	var u := _new_unit(sq, Vector3(10.5, 0, 10.5), {"hp": 10.0, "stun_mult": 1.0})
	var atk := {"damage": 0.1, "knockback": 0.1, "stun": 10.0, "launch": 0.0,
		"dir": Vector3(1, 0, 0), "attacker": null}
	u.deal_damage(atk)
	_expect_true(u.stun_fall.active, "累积冲击超过随机阈值时倒地（规格 8）")
	_expect_true(u.sliding.active, "倒地期间处于滑行（规格 8）")
	_expect_eq(u.fall_phase, 0, "倒地从倒下阶段开始（规格 8）")
	var lo: float = sqrt(10.0) * 0.5
	var hi: float = sqrt(10.0) * 1.0
	_expect_between(u.stun_timer, lo, hi, "倒地时长 = max(√累积,2) × rand(0.5,1)（规格 8）")

	var phases: Array = [u.fall_phase]
	var clips: Array = [u.anim_name]
	var last_phase := u.fall_phase
	for _i in 360:
		_tick_unit(u)
		if u.fall_phase != last_phase:
			last_phase = u.fall_phase
			phases.append(u.fall_phase)
		if clips.is_empty() or clips[-1] != u.anim_name:
			clips.append(u.anim_name)
		if not u.stun_fall.active:
			break
	_expect_eq(phases, [0, 1, 2, 3], "倒地流程：倒下 → 坐地 → 计时 → 爬起（规格 8）")
	_expect_true(clips.has("fall") and clips.has("sit") and clips.has("rise"), "倒地动画按 fall → sit → rise 播放（规格 8）")
	_expect_false(u.stun_fall.active, "倒地计时结束后退出倒地（规格 8）")
	_expect_eq(u.acc_stun, 0.0, "倒地结束清零累积冲击（规格 8）")
	_expect_true(u.alive and is_instance_valid(u), "倒地恢复后仍存活（规格 8）")


func _test_drown_when_pushed_off_edge() -> void:
	# 高速推出水边：掉进水里并移除
	_new_world(1)
	for z in Terrain.SIZE:
		fm.terrain.levels[z * Terrain.SIZE + 0] = 0
	var sq := _new_squad(0)
	var u := _new_unit(sq, Vector3(1.02, 0, 12.5), {"hp": 10.0})
	u.velocity = Vector3(-3, 0, 0)
	_sim(120)
	_expect_gt(float(fm.notes.get("drown", 0)), 0.0, "朝外速度 ≥ 2 被推出水边后落水（规格 9）")
	_expect_true(u.removed, "落水后从模拟中移除（规格 9）")

	# 低速推挤：沿边滑行，不会被推下水
	_new_world(1)
	for z in Terrain.SIZE:
		fm.terrain.levels[z * Terrain.SIZE + 0] = 0
	sq = _new_squad(0)
	u = _new_unit(sq, Vector3(1.02, 0, 12.5), {"hp": 10.0})
	u.velocity = Vector3(-1.5, 0, 0)
	_sim(120)
	_expect_eq(int(fm.notes.get("drown", 0)), 0, "朝外速度 < 2 只沿边滑、不落水（规格 9）")
	_expect_false(u.removed, "低速推挤后单位仍在模拟中（规格 9）")
	_expect_true(fm.terrain.is_land_at(u.nav_pos), "低速推挤后仍站在陆地上（规格 9）")


# ---------- 兵种行为状态切换（规格 7） ----------

func _test_idle_to_ready() -> void:
	_new_world(1)
	var s0 := _new_squad(0)
	var s1 := _new_squad(1)
	var u := _new_unit(s0, _tile_center(10, 10), {"hp": 10.0})
	var e := _new_unit(s1, _tile_center(10, 13), {"hp": 10.0})
	u.slot = u.nav_pos
	e.slot = e.nav_pos
	_expect_true(u.brain.idle.active, "出生后大脑回到待机（规格 7.1）")
	var became_ready := false
	for _i in 120:
		_sim(1)
		if u.brain.ready.active:
			became_ready = true
			break
	_expect_true(became_ready, "敌人进入 4 米后待机切到备战（规格 7.3、3 节拍）")
	_expect_true(u.enemy_dist < 4.0, "备战触发时敌人距离 < 4 米（规格 7.3）")


func _test_formation_partial_row_centered() -> void:
	_new_world(1)
	var sq := _new_squad(0)
	var units: Array = []
	for i in 5:
		units.append(_new_unit(sq, Vector3(8.0 + (i % 3) * 0.3, 0, 8.0 + (i / 3) * 0.3)))
	sq.order_move(Vector3(12, 0, 12), Vector3(0, 0, -1))
	_sim(600)
	var last_z := -1.0e9
	for u in units:
		last_z = maxf(last_z, u.slot.z)
	var xs: Array = []
	for u in units:
		if absf(u.slot.z - last_z) < 0.01:
			xs.append(u.slot.x)
	_expect_eq(xs.size(), 2, "3×2 编队 5 人时末行有 2 个槽位（规格 11.1）")
	if xs.size() == 2:
		var mean := (float(xs[0]) + float(xs[1])) * 0.5
		_expect_lt(absf(mean - 12.0), 0.01, "人数不满的末行空位均分到两侧、行中心对齐站点（规格 11.1）")


func _test_pursuit_propagation() -> void:
	_new_world(1)
	var sq := _new_squad(0)
	var ae := _new_squad(1)
	var e := _new_unit(ae, _tile_center(13, 10), {"hp": 10.0})
	var a := _new_unit(sq, _tile_center(10, 10), {"hp": 10.0})
	var b := _new_unit(sq, _tile_center(10, 11), {"hp": 10.0})
	var c := _new_unit(sq, _tile_center(10, 12), {"hp": 10.0})
	a.brain.adjacent = [b]
	b.brain.adjacent = [c]
	for u in [a, b, c]:
		u.enemy = e
		u.enemy_dir = Vector3(1, 0, 0)
		u.order_dir = Vector3(1, 0, 0)
		u.order_dist = 0.0
		u.brain.stamina = 1.0
		u.brain.ready.set_true()
	a.brain.pursue()
	_expect_true(a.brain.pursuing.active, "发起者进入冲锋（规格 7.5）")
	_expect_true(b.brain.pursuing.active, "邻居跟着冲锋（规格 7.5）")
	_expect_true(c.brain.pursuing.active, "冲锋继续向下一层传播（规格 7.5）")

	# 体力 < 0 的邻居不跟
	_new_world(1)
	sq = _new_squad(0)
	ae = _new_squad(1)
	e = _new_unit(ae, _tile_center(13, 10))
	a = _new_unit(sq, _tile_center(10, 10))
	b = _new_unit(sq, _tile_center(10, 11))
	a.brain.adjacent = [b]
	for u in [a, b]:
		u.enemy = e
		u.enemy_dir = Vector3(1, 0, 0)
		u.order_dir = Vector3(1, 0, 0)
		u.order_dist = 0.0
		u.brain.ready.set_true()
	b.brain.stamina = -0.1
	a.brain.pursue()
	_expect_false(b.brain.pursuing.active, "体力 < 0 的邻居不跟冲锋（规格 7.5）")

	# 敌人方向不一致的邻居不跟
	b.brain.stamina = 1.0
	b.enemy_dir = Vector3(-1, 0, 0)
	b.brain.ready.set_true()
	a.brain.pursue()
	_expect_false(b.brain.pursuing.active, "敌人方向点积 < 0.1 的邻居不跟冲锋（规格 7.5）")


func _test_intimidation_retreat() -> void:
	_new_world(1)
	var sq := _new_squad(0)
	var u := _new_unit(sq, _tile_center(10, 10), {"hp": 10.0})
	u.brain.ready.set_true()
	u.enemy_dir = Vector3(1, 0, 0)
	u.order_dir = Vector3(1, 0, 0)
	u.order_dist = 2.5
	u.brain.stamina = 1.0

	u.soft_int = 1.0
	u.hard_int = 0.0
	u.walk_dir = Vector3.ZERO
	u.brain._ready_update()
	_expect_lt(u.walk_dir.x, 0.0, "软威慑时备战朝远离敌人方向后退（规格 7.4）")
	var soft_x := u.walk_dir.x

	u.soft_int = 0.0
	u.hard_int = 1.0
	u.walk_dir = Vector3.ZERO
	u.brain._ready_update()
	_expect_lt(u.walk_dir.x, 0.0, "硬威慑时备战也后退（规格 7.4）")
	_expect_lt(u.walk_dir.x, soft_x, "硬威慑后退量大于软威慑（规格 7.4）")


func _test_proximity_intimidation() -> void:
	_new_world(1)
	var sa := _new_squad(0)
	var sb := _new_squad(1)
	var u := _new_unit(sa, Vector3(10.5, 0, 10.5), {"hp": 10.0})
	var e := _new_unit(sb, Vector3(11.0, 0, 10.5), {"hp": 10.0})
	e.brain.on_proximity(u)
	_expect_gt(u.soft_int, 0.0, "1 米内有人靠近时施加软威慑（规格 7.10）")
	_expect_lt(u.soft_int, 1.0, "软威慑在贴身到 1 米之间从 1 衰减到 0（规格 7.10）")
	_expect_eq(u.hard_int, 0.0, "软威慑不写硬威慑（规格 7.10）")

	# 超过 1 米不施加
	_new_world(1)
	sa = _new_squad(0)
	sb = _new_squad(1)
	u = _new_unit(sa, Vector3(10.5, 0, 10.5), {"hp": 10.0})
	e = _new_unit(sb, Vector3(12.0, 0, 10.5), {"hp": 10.0})
	e.brain.on_proximity(u)
	_expect_eq(u.soft_int, 0.0, "超过 1 米不施加威慑（规格 7.10）")
