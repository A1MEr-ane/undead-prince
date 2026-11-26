extends "res://proto/siege/test_siege.gd"
## 优化正确性：候选集合/顺序、顺序移动、洞内单位及流场全算对照。
const PerfState = preload("res://scripts/agent_state.gd")
const FineGrid = preload("res://proto/siege/siege_spatial.gd")

class HeapReference:
	extends "res://proto/siege/siege_map.gd"
	func _propagate(f: Dictionary, heap: Array) -> int:
		return _propagate_heap(f, heap)

func legacy_nearby(w, p: Vector3, radius: float, faction: int) -> Array:
	var out: Array = []
	var size := float(w.params.combat.spatial_cell_size)
	for z in range(floori((p.z - radius) / size), floori((p.z + radius) / size) + 1):
		for x in range(floori((p.x - radius) / size), floori((p.x + radius) / size) + 1):
			for u in w.spatial.get(Vector3i(x, faction, z), []):
				if u.alive and u.cave_until < 0 and Vector2(u.nav_pos.x - p.x, u.nav_pos.z - p.z).length_squared() <= radius * radius:
					out.append(u)
	return out

func legacy_separation(w, u) -> Vector3:
	var v := Vector3.ZERO
	for faction in 2:
		for other in legacy_nearby(w, u.nav_pos, float(w.params.combat.separation_radius), faction):
			if other == u:
				continue
			var delta: Vector3 = u.nav_pos - other.nav_pos
			delta.y = 0
			var d := delta.length()
			var desired: float = u.radius + other.radius + float(w.params.combat.contact_slack)
			if d < desired:
				v += (delta.normalized() if d > 0.000001 else Vector3.RIGHT * (1 if u.id > other.id else -1)) * (desired - d) * float(w.params.combat.separation_strength)
	return v.limit_length(float(w.params.combat.max_separation_speed))

func test_spatial_equivalence() -> void:
	var w = fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	for n in 160:
		w.spawn("ghost" if n % 2 == 0 else "shield", n % 2, Vector3(rng.randf_range(17, 40), 0, rng.randf_range(15, 27)), "plaza")
	w.units[0].cave_until = 10
	w.rebuild_spatial()
	var grid := FineGrid.new()
	grid.rebuild(w.units, 1, float(w.params.combat.spatial_cell_size), w.terrain.width)
	for n in 160:
		var moved = w.units[n]
		moved.nav_pos += Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		if n == 0:
			moved.cave_until = -1
		if n == 8:
			moved.deal_damage({"damage": 100.0, "knockback": 0.0, "stun": 0.0, "dir": Vector3.RIGHT})
		if n == 20:
			moved.cave_until = 10
		grid.moved(moved)
		check(w.separation(moved) == legacy_separation(w, moved), "融合分离力的结果与原求和逐位相等")
		for radius in [0.52, 1.0, 2.2, 10.0]:
			for faction in 2:
				check(grid.count(moved.nav_pos, radius, faction) == legacy_nearby(w, moved.nav_pos, radius, faction).size(), "计数查询与原查询相等")
				check(grid.query(moved.nav_pos, radius, faction) == legacy_nearby(w, moved.nav_pos, radius, faction), "细网格必须保留粗网格候选集合与次序: %d/%s/%d" % [n, radius, faction])
		var expected: Array = []
		for u in w.sides[moved.faction].units:
			if u.alive_grounded.active and Vector2(u.nav_pos.x - moved.nav_pos.x, u.nav_pos.z - moved.nav_pos.z).length_squared() <= 1:
				expected.append(u)
		var candidates: Array = grid.candidates(moved.nav_pos, 1, moved.faction, w.sides[moved.faction].units)
		var selected: Array = candidates.filter(func(u): return u.alive_grounded.active and Vector2(u.nav_pos.x - moved.nav_pos.x, u.nav_pos.z - moved.nav_pos.z).length_squared() <= 1)
		check(selected == expected, "宽相候选在稀疏/密集分支都必须覆盖原邻居并保持顺序")
		check(grid.query(moved.nav_pos, 1, moved.faction, false) == expected, "队友协同候选必须保持 id 顺序并包含洞内同伴")
	grid.clear()
	dispose(w)

func test_flow_equivalence() -> void:
	var params: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://proto/siege/siege_params.json"))
	var m = Map.new()
	m.setup(params)
	var heap_reference := HeapReference.new()
	heap_reference.setup(params)
	var goals: Array = []
	for z in range(5, 44, 7):
		for x in range(5, 51, 7):
			var p := Vector3(x + 0.5, 0, z + 0.5)
			if m.is_walkable_at(p):
				goals.append(p)
	for goal in goals:
		for cave in [false, true]:
			var initial: Dictionary = m.field(goal, cave)
			var heap_initial: Dictionary = heap_reference.field(goal, cave)
			check(initial.dist == heap_initial.dist and initial.next == heap_initial.next, "分层队列完整构建与堆的距离和 successor 逐格相等")
	var actions := [[params.map.gate_rect, true], [params.map.weak_rect, true], [params.map.gate_rect, false], [params.map.gate_rect, true], [params.map.weak_rect, false], [params.map.gate_rect, false]]
	var opened: Array = []
	for action in actions:
		m.change(action[0], action[1], 0, "test")
		heap_reference.change(action[0], action[1], 0, "test")
		opened.append(action)
		var full = Map.new()
		full.setup(params)
		for previous in opened:
			full.change(previous[0], previous[1], 0, "reference")
		for goal in goals:
			for cave in [false, true]:
				var actual: Dictionary = m.field(goal, cave)
				var reference: Dictionary = full.field(goal, cave)
				var heap_result: Dictionary = heap_reference.field(goal, cave)
				check(actual.dist == heap_result.dist and actual.next == heap_result.next, "增量分层队列与原堆的距离和 successor 逐格相等")
				check(actual.dist == reference.dist, "开关门/破墙/洞边的增量距离必须与全算逐格相等")
				for i in actual.next.size():
					var j: int = actual.next[i]
					if j < 0:
						continue
					var cost: float = m.cave_cost if cave and ((i == m.cave_a and j == m.cave_b) or (i == m.cave_b and j == m.cave_a)) else 1.0
					check(actual.dist[i] == actual.dist[j] + cost and m.blocked[j] == 0, "保留的等长路径 successor 必须满足最短路方程")
	check(m.fields.size() + m.prebuilt.size() <= int(params.map.flow_cache_limit), "流场缓存含预热项有界")
	var limited = Map.new()
	var small: Dictionary = params.duplicate(true)
	small.map.flow_cache_limit = 3
	limited.setup(small)
	for goal in goals:
		limited.prewarm(goal)
		check(limited.fields.size() + limited.prebuilt.size() <= 3, "预热不得超过流场上限")
	for goal in goals:
		limited.field(goal, false)
		check(limited.fields.size() + limited.prebuilt.size() <= 3, "正式场与预热场共同受限")

func test_adjacent_selection() -> void:
	var w = fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7302
	var hero = w.spawn("ghost", 0, Vector3(30.5, 0, 20.5), "plaza")
	for n in 80:
		w.spawn("ghost", 0, hero.nav_pos + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)), "plaza")
	for layout in 3:
		if layout > 0:
			for n in range(1, w.units.size()):
				w.units[n].nav_pos = hero.nav_pos + Vector3((n % 3 - 1) * 0.25, 0, (n % 5 - 2) * 0.25)
		if layout == 2:
			for friend in w.units:
				friend.nav_pos = hero.nav_pos
		w.rebuild_spatial()
		check(w.separation(hero) == legacy_separation(w, hero), "密集/对称/重叠布局的分离力保持逐位相等")
		for count in [0, 1, 3, 7]:
			hero.brain.cfg.adjacent_count = count
			var expected: Array = []
			for friend in hero.squad.units:
				if friend == hero or not hero.brain._valid(friend):
					continue
				var d: float = (friend.nav_pos - hero.nav_pos).length_squared()
				if d < hero.brain.cfg.adjacent_radius_sq:
					expected.append([d, friend])
			expected.sort_custom(func(a, b): return a[0] < b[0])
			var chosen: Array = []
			for n in mini(count, expected.size()):
				chosen.append(expected[n][1])
			PerfState.now = 0.125
			PerfState.dt = 1.0 / 30
			hero.beats.offset = 0
			hero.brain._update_adjacent()
			check(hero.brain.adjacent == chosen, "最近 K 人含等距回退必须与原完整排序一致")
	dispose(w)

func test_sense_steps() -> void:
	var w = fresh()
	var u = w.spawn("ghost", 0, w.zone_point("coast"), "coast")
	w.rebuild_spatial()
	for period in [1, 4, 7]:
		w.params.combat.sense_steps = period
		u.next_sense = 0
		var previous := -1
		for step in range(1, 100):
			w.step_number = step
			w.time = step * float(w.params.simulation.step)
			if w.time >= u.next_sense:
				if previous >= 0:
					check(step - previous == period, "索敌必须每 N 个固定步评估一次")
				previous = step
			u.sense()
	dispose(w)

func run() -> void:
	test_adjacent_selection()
	test_sense_steps()
	test_spatial_equivalence()
	test_flow_equivalence()
	if failures.is_empty():
		print("SIEGE_PERF_FEATURES PASS spatial_order/live_movement/cave/full_flow_reference/cache_bound")
		quit(0)
	else:
		printerr("SIEGE_PERF_FEATURES FAIL count=%d" % failures.size())
		quit(1)
