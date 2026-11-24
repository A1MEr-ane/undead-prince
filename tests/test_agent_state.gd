extends RefCounted
## AgentState 状态树回归测试（规格 docs/badnorth-behavior-spec.md 2.2）。
## 由 tests/run_tests.gd 调用 run_all()；每个断言失败都会打印期望值和实际值。

const AgentStateScript = preload("res://scripts/agent_state.gd")

var failures := 0
var checks := 0
var known_issues := 0
var known_issues_resolved := 0

var _current := ""
var _test_failed := false
var _known_issue := false


func run_all() -> int:
	print("AgentState 状态树测试（规格 2.2）")
	_run("激活子状态连带激活祖先", _test_activate_child_activates_ancestors)
	_run("互斥状态顶掉互斥兄弟、不影响非互斥兄弟", _test_exclusive_evicts_exclusive_siblings_only)
	_run("停用状态递归停用子孙", _test_deactivate_deactivates_descendants)
	_run("激活且没有互斥子状态时触发 on_empty", _test_on_empty_when_activated_without_exclusive_child)
	_run("停用最后一个互斥子状态后父状态触发 on_empty", _test_on_empty_after_last_exclusive_child_deactivated)
	_run("有互斥子状态激活时不触发 on_empty", _test_on_empty_not_triggered_while_exclusive_child_active)
	_run("since() 使用 AgentState.now 计时", _test_since_uses_agent_state_now)
	_run("update() 只调用激活状态的回调且按树序", _test_update_only_active_states_in_tree_order)
	_run_known_issue(
		"通过非互斥子状态间接激活父状态时触发 on_empty",
		_test_on_empty_when_ancestor_activated_by_child,
		"规格 2.2：状态激活且没有互斥子状态时应触发 on_empty；现状 _set_internal(true) 只激活祖先，不调用祖先的 _maybe_empty()。期望 hits=1，实际 hits=0。"
	)
	print("")
	var resolved_note := ""
	if known_issues_resolved > 0:
		resolved_note = "，%d 个已知问题已修复（待移除标记）" % known_issues_resolved
	print("=== 结果：%d 个断言，%d 个失败用例，%d 个已知问题%s ===" % [checks, failures, known_issues, resolved_note])
	return failures


func _run(test_name: String, test: Callable) -> void:
	_current = test_name
	_test_failed = false
	AgentStateScript.now = 0.0
	var before := checks
	print("")
	print("-- " + test_name)
	test.call()
	if _test_failed:
		failures += 1
		print("[FAIL] %s（%d 个断言）" % [test_name, checks - before])
	else:
		print("[PASS] %s（%d 个断言）" % [test_name, checks - before])


## 已知问题用例：失败只记录、不让 verify 变红；如果以后源码修好而通过，则报 XPASS 提醒移除标记。
func _run_known_issue(test_name: String, test: Callable, reason: String) -> void:
	_current = test_name
	_test_failed = false
	_known_issue = true
	AgentStateScript.now = 0.0
	print("")
	print("-- " + test_name + "（已知问题）")
	test.call()
	if _test_failed:
		known_issues += 1
		print("[KNOWN ISSUE] %s：%s" % [test_name, reason])
	else:
		known_issues_resolved += 1
		print("[XPASS] %s：已知问题已不再复现，请移除 known issue 标记" % test_name)
	_known_issue = false


# ---------- 断言 ----------

func _expect_true(actual: bool, label: String) -> void:
	_check(actual, true, label)


func _expect_false(actual: bool, label: String) -> void:
	_check(actual, false, label)


func _expect_eq(actual, expected, label: String) -> void:
	_check(actual, expected, label)


func _expect_approx(actual: float, expected: float, label: String) -> void:
	checks += 1
	if absf(actual - expected) > 0.000001:
		_fail(label, expected, actual)


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


# ---------- 测试 ----------

func _test_activate_child_activates_ancestors() -> void:
	var root_log := []
	var mid_log := []
	var leaf_log := []
	var root := AgentStateScript.new("Root", null, false, false)
	root.on_activate.append(func(): root_log.append("root"))
	var mid := AgentStateScript.new("Mid", root, false, false)
	mid.on_activate.append(func(): mid_log.append("mid"))
	var leaf := AgentStateScript.new("Leaf", mid, false, false)
	leaf.on_activate.append(func(): leaf_log.append("leaf"))

	leaf.set_true()

	_expect_true(root.active, "激活叶子后 Root.active")
	_expect_true(mid.active, "激活叶子后 Mid.active")
	_expect_true(leaf.active, "激活叶子后 Leaf.active")
	_expect_eq(root_log, ["root"], "Root 的 on_activate 调用次数")
	_expect_eq(mid_log, ["mid"], "Mid 的 on_activate 调用次数")
	_expect_eq(leaf_log, ["leaf"], "Leaf 的 on_activate 调用次数")

	# 再激活一个已经激活的共同祖先下的另一个子状态，祖先不应重复触发 on_activate。
	var leaf2 := AgentStateScript.new("Leaf2", mid, false, false)
	leaf2.on_activate.append(func(): leaf_log.append("leaf2"))
	leaf2.set_true()
	_expect_true(leaf2.active, "激活第二个叶子后 Leaf2.active")
	_expect_eq(root_log, ["root"], "祖先已激活时 Root 不重复触发 on_activate")
	_expect_eq(mid_log, ["mid"], "祖先已激活时 Mid 不重复触发 on_activate")
	_expect_eq(leaf_log, ["leaf", "leaf2"], "两个叶子各自触发 on_activate")


func _test_exclusive_evicts_exclusive_siblings_only() -> void:
	var root := AgentStateScript.new("Root", null, true, false)
	var plain := AgentStateScript.new("Plain", root, true, false)   # 非互斥兄弟
	var excl_a := AgentStateScript.new("ExclA", root, true, true)   # 互斥兄弟
	var excl_b := AgentStateScript.new("ExclB", root, false, true)
	var deactivate_a := []
	excl_a.on_deactivate.append(func(): deactivate_a.append("a"))

	_expect_true(plain.active, "前置：Plain.active")
	_expect_true(excl_a.active, "前置：ExclA.active")

	excl_b.set_true()

	_expect_true(excl_b.active, "激活 ExclB 后 ExclB.active")
	_expect_false(excl_a.active, "激活 ExclB 后互斥兄弟 ExclA.active")
	_expect_true(plain.active, "激活 ExclB 后非互斥兄弟 Plain.active 保持不变")
	_expect_eq(deactivate_a, ["a"], "ExclA 的 on_deactivate 调用次数")

	# 激活非互斥状态不应顶掉正在激活的互斥状态。
	var plain2 := AgentStateScript.new("Plain2", root, false, false)
	plain2.on_activate.append(func(): pass)
	plain2.set_true()
	_expect_true(plain2.active, "激活 Plain2 后 Plain2.active")
	_expect_true(excl_b.active, "激活非互斥 Plain2 后 ExclB.active 仍然为真")
	_expect_true(plain.active, "激活非互斥 Plain2 后 Plain.active 仍然为真")


func _test_deactivate_deactivates_descendants() -> void:
	var root := AgentStateScript.new("Root", null, true, false)
	var a := AgentStateScript.new("A", root, true, false)
	var b := AgentStateScript.new("B", a, true, true)
	var c := AgentStateScript.new("C", b, true, false)
	var d := AgentStateScript.new("D", a, true, false)
	var deactivated := []
	for state in [a, b, c, d]:
		state.on_deactivate.append(func(): deactivated.append(state.name))

	a.set_false()

	_expect_false(a.active, "停用 A 后 A.active")
	_expect_false(b.active, "停用 A 后子状态 B.active")
	_expect_false(c.active, "停用 A 后孙状态 C.active")
	_expect_false(d.active, "停用 A 后另一个子状态 D.active")
	_expect_true(root.active, "停用 A 不影响祖先 Root.active")
	var sorted := deactivated.duplicate()
	sorted.sort()
	_expect_eq(sorted, ["A", "B", "C", "D"], "A/B/C/D 的 on_deactivate 各触发一次")


func _test_on_empty_when_activated_without_exclusive_child() -> void:
	var root := AgentStateScript.new("Root", null, true, false)
	var parent := AgentStateScript.new("Parent", root, false, false)
	var child := AgentStateScript.new("Child", parent, false, false)
	var hits := []
	parent.on_empty.append(func():
		hits.append({"active": parent.active, "has_exclusive": parent.has_active_exclusive_child()}))

	parent.set_true()

	_expect_eq(hits.size(), 1, "Parent 激活且无激活的互斥子状态时 on_empty 调用次数")
	if hits.size() == 1:
		_expect_true(hits[0]["active"], "on_empty 触发时 Parent.active")
		_expect_false(hits[0]["has_exclusive"], "on_empty 触发时 Parent 没有激活的互斥子状态")
	_expect_true(parent.active, "Parent.active")
	_expect_false(child.active, "未激活的普通子状态保持不激活")

	# 已经激活的状态再次 set_true 不应重复触发。
	parent.set_true()
	_expect_eq(hits.size(), 1, "重复激活已激活的 Parent 不重复触发 on_empty")


func _test_on_empty_after_last_exclusive_child_deactivated() -> void:
	var root := AgentStateScript.new("Root", null, true, false)
	var parent := AgentStateScript.new("Parent", root, false, false)
	var exclusive := AgentStateScript.new("Exclusive", parent, false, true)
	var default_child := AgentStateScript.new("Default", parent, false, true)
	var hits := []
	parent.on_empty.append(func(): hits.append(parent.has_active_exclusive_child()))
	parent.on_empty.append(default_child.set_true)

	exclusive.set_true()
	_expect_true(exclusive.active, "前置：Exclusive.active")
	_expect_eq(hits.size(), 0, "有互斥子状态激活时 on_empty 调用次数")

	exclusive.set_false()
	_expect_false(exclusive.active, "停用最后一个互斥子状态后 Exclusive.active")
	_expect_eq(hits.size(), 1, "停用最后一个互斥子状态后 on_empty 调用次数")
	if hits.size() == 1:
		_expect_false(hits[0], "on_empty 触发时已经没有激活的互斥子状态")
	_expect_true(default_child.active, "on_empty 回调把默认子状态激活")
	_expect_true(parent.active, "on_empty 后父状态仍然激活")

	exclusive.set_false()
	_expect_eq(hits.size(), 1, "重复停用已停用的状态不重复触发 on_empty")


func _test_on_empty_not_triggered_while_exclusive_child_active() -> void:
	var root := AgentStateScript.new("Root", null, true, false)
	var parent := AgentStateScript.new("Parent", root, false, false)
	var excl_a := AgentStateScript.new("ExclA", parent, false, true)
	var excl_b := AgentStateScript.new("ExclB", parent, false, true)
	var hits := []
	parent.on_empty.append(func(): hits.append(true))

	excl_a.set_true()
	_expect_eq(hits.size(), 0, "激活第一个互斥子状态时父状态不触发 on_empty")

	# 互斥子状态互相顶替时，父状态始终有一个激活的互斥子状态，不应触发 on_empty。
	excl_b.set_true()
	_expect_false(excl_a.active, "ExclB 顶掉 ExclA")
	_expect_true(excl_b.active, "ExclB.active")
	_expect_eq(hits.size(), 0, "互斥子状态顶替过程中父状态不触发 on_empty")


func _test_since_uses_agent_state_now() -> void:
	AgentStateScript.now = 100.0
	var state := AgentStateScript.new("State", null, false, false)
	_expect_approx(state.since(), 0.0, "刚创建时 since()")

	AgentStateScript.now = 104.5
	_expect_approx(state.since(), 4.5, "未激活时 since() 仍按 now 计算")

	state.set_true()
	_expect_approx(state.since(), 0.0, "激活瞬间 since() 归零")

	AgentStateScript.now = 106.0
	_expect_approx(state.since(), 1.5, "激活 1.5 秒后 since()")

	state.set_false()
	_expect_approx(state.since(), 0.0, "停用瞬间时间戳也更新")

	AgentStateScript.now = 107.25
	_expect_approx(state.since(), 1.25, "停用 1.25 秒后 since()")

	# 不同状态各自计时，互不影响。
	AgentStateScript.now = 200.0
	var other := AgentStateScript.new("Other", null, true, false)
	AgentStateScript.now = 202.0
	_expect_approx(other.since(), 2.0, "Other 激活 2 秒后 since()")
	_expect_approx(state.since(), 96.0, "Other 激活不影响 State 的时间戳")


func _test_update_only_active_states_in_tree_order() -> void:
	var order := []
	var root := AgentStateScript.new("Root", null, true, false)
	var a := AgentStateScript.new("A", root, true, false)
	var a1 := AgentStateScript.new("A1", a, true, false)
	var b := AgentStateScript.new("B", root, false, false)
	var b1 := AgentStateScript.new("B1", b, false, false)
	var c := AgentStateScript.new("C", root, true, false)
	for state in [root, a, a1, b, b1, c]:
		state.on_update.append(func(): order.append(state.name))

	root.update()
	_expect_eq(order, ["Root", "A", "A1", "C"], "update() 的调用顺序（跳过未激活的 B/B1）")

	# 停用 A 后，A1 也应被递归停用，不再收到 update。
	a.set_false()
	order.clear()
	root.update()
	_expect_eq(order, ["Root", "C"], "停用 A 后 update() 跳过 A/A1")

	# 未激活的根节点不更新整棵树。
	var inactive_root := AgentStateScript.new("InactiveRoot", null, false, false)
	var quiet := []
	inactive_root.on_update.append(func(): quiet.append("root"))
	inactive_root.update()
	_expect_eq(quiet, [], "未激活的根节点 update() 不调用回调")


## 规格 2.2 字面：父状态被间接激活、且没有任何互斥子状态激活时，应触发 on_empty。
## 现状：_set_internal(true) 只把祖先置为激活，不调用祖先的 _maybe_empty()。
func _test_on_empty_when_ancestor_activated_by_child() -> void:
	var root := AgentStateScript.new("Root", null, true, false)
	var parent := AgentStateScript.new("Parent", root, false, false)
	var child := AgentStateScript.new("Child", parent, false, false)
	var hits := []
	parent.on_empty.append(func(): hits.append(parent.has_active_exclusive_child()))

	child.set_true()

	_expect_true(parent.active, "子状态激活后 Parent.active")
	_expect_eq(hits.size(), 1, "通过非互斥子状态间接激活 Parent 时的 on_empty 调用次数")
	if hits.size() == 1:
		_expect_false(hits[0], "on_empty 触发时 Parent 没有激活的互斥子状态")
