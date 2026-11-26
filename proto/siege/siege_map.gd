extends RefCounted
## 共享反向流场；开口只传播降低的距离，关门只修复依赖该门的路径子树。

const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var cfg: Dictionary
var width: int
var depth: int
var land := PackedByteArray()
var blocked := PackedByteArray()
var fields := {}
var prebuilt := {}
var adjacency: Array = []
var cave_a: int
var cave_b: int
var cave_cost: float
var gate_open := false
var gate_broken := false
var weak_broken := false
var flow_repairs := 0
var repaired_cells := 0
var topology_events: Array = []
var battle_cells := {}

func setup(params: Dictionary) -> void:
	cfg = params.map
	width = int(cfg.width)
	depth = int(cfg.depth)
	land.resize(width * depth)
	blocked.resize(width * depth)
	for r in cfg.land_rects:
		for t in rect_cells(r):
			land[index(t)] = 1
	for r in cfg.wall_rects:
		for t in rect_cells(r):
			blocked[index(t)] = 1
	cave_a = index(tile(vec(cfg.cave_a)))
	cave_b = index(tile(vec(cfg.cave_b)))
	cave_cost = float(cfg.cave_travel_seconds) * float(params.units.ghost.speed)
	adjacency.resize(land.size())
	for i in land.size():
		var edges := PackedInt32Array()
		var t := Vector2i(i % width, i / width)
		for delta in DIRS:
			var q: Vector2i = t + delta
			if q.x >= 0 and q.y >= 0 and q.x < width and q.y < depth and land[index(q)] != 0:
				edges.append(index(q))
		adjacency[i] = edges
	# 关卡可战斗区域允许经过可破门/薄弱墙；普通墙仍阻断。
	var frontier: Array = []
	var openings := rect_cells(cfg.gate_rect) + rect_cells(cfg.weak_rect)
	for t in rect_cells(cfg.deploy_rect):
		if walkable(t):
			battle_cells[index(t)] = true
			frontier.append(index(t))
	var cursor := 0
	while cursor < frontier.size():
		var i: int = frontier[cursor]
		cursor += 1
		var t := Vector2i(i % width, i / width)
		var adjacent: Array = []
		for delta in DIRS:
			adjacent.append(t + delta)
		if cfg.cave_enabled and i in [cave_a, cave_b]:
			adjacent.append(tile(point(cave_b if i == cave_a else cave_a)))
		for q in adjacent:
			if q.x < 0 or q.y < 0 or q.x >= width or q.y >= depth:
				continue
			var j := index(q)
			if land[j] != 0 and (blocked[j] == 0 or openings.has(q)) and not battle_cells.has(j):
				battle_cells[j] = true
				frontier.append(j)

func battle_reachable(p: Vector3) -> bool:
	return is_walkable_at(p) and battle_cells.has(index(tile(p)))

static func vec(a: Array) -> Vector3:
	return Vector3(float(a[0]) + 0.5, 0, float(a[1]) + 0.5)

static func in_rect(p: Vector3, r: Array) -> bool:
	return p.x >= r[0] and p.z >= r[1] and p.x < r[0] + r[2] and p.z < r[1] + r[3]

func rect_cells(r: Array) -> Array:
	var out: Array = []
	for z in range(int(r[1]), int(r[1] + r[3])):
		for x in range(int(r[0]), int(r[0] + r[2])):
			if x >= 0 and z >= 0 and x < width and z < depth:
				out.append(Vector2i(x, z))
	return out

func index(t: Vector2i) -> int:
	return t.y * width + t.x

func tile(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))

func point(i: int) -> Vector3:
	return Vector3(i % width + 0.5, 0, i / width + 0.5)

func walkable(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < width and t.y < depth and land[index(t)] != 0 and blocked[index(t)] == 0

func is_walkable_at(p: Vector3) -> bool:
	return walkable(tile(p))

func height_at(p: Vector3) -> float:
	if in_rect(p, cfg.highland_rect):
		return float(cfg.highland_height)
	if in_rect(p, cfg.keep_rect):
		return float(cfg.keep_height)
	return float(cfg.base_height)

func zone_at(p: Vector3) -> String:
	for z in cfg.zones:
		for r in z.rects:
			if in_rect(p, r):
				return z.id
	return "coast"

func line_clear(a: Vector3, b: Vector3) -> bool:
	var delta := Vector3(b.x - a.x, 0, b.z - a.z)
	var count := maxi(1, ceili(delta.length() / float(cfg.line_sample_step)))
	for n in range(count + 1):
		if not is_walkable_at(a + delta * float(n) / count):
			return false
	return true

func nearest(p: Vector3) -> Vector3:
	if is_walkable_at(p):
		return p
	var best := Vector3.ZERO
	var distance := INF
	for i in land.size():
		if land[i] == 0 or blocked[i] != 0:
			continue
		var q := point(i)
		var d := Vector2(q.x - p.x, q.z - p.z).length_squared()
		if d < distance:
			distance = d
			best = q
	return best

func neighbors(i: int, cave: bool) -> Array:
	var out: Array = []
	for j in adjacency[i]:
		if blocked[j] == 0:
			out.append([j, 1.0])
	if cave and cfg.cave_enabled:
		if i == cave_a:
			out.append([cave_b, cave_cost])
		elif i == cave_b:
			out.append([cave_a, cave_cost])
	return out

func _push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var child := heap.size() - 1
	while child > 0:
		var parent := (child - 1) / 2
		if heap[parent][0] < entry[0] or (heap[parent][0] == entry[0] and heap[parent][1] <= entry[1]):
			break
		heap[child] = heap[parent]
		child = parent
	heap[child] = entry

func _pop(heap: Array) -> Array:
	var first: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return first
	var parent := 0
	while parent * 2 + 1 < heap.size():
		var child := parent * 2 + 1
		if child + 1 < heap.size() and (heap[child + 1][0] < heap[child][0] or (heap[child + 1][0] == heap[child][0] and heap[child + 1][1] < heap[child][1])):
			child += 1
		if last[0] < heap[child][0] or (last[0] == heap[child][0] and last[1] <= heap[child][1]):
			break
		heap[parent] = heap[child]
		parent = child
	heap[parent] = last
	return first

func _propagate(f: Dictionary, heap: Array) -> int:
	if not (f.cave and cfg.cave_enabled):
		var integer_seeds := true
		for item in heap:
			if item[0] < float(cfg.flow_infinity) and item[0] != floorf(item[0]):
				integer_seeds = false
				break
		if integer_seeds:
			return _propagate_unit_edges(f, heap)
	return _propagate_heap(f, heap)

func _propagate_unit_edges(f: Dictionary, seeds: Array) -> int:
	# 普通地面边权均为 1。按距离分层、层内按格号排序，与堆的 (距离, 格号) 次序一致。
	var buckets := {}
	var first := -1
	var last := 0
	for item in seeds:
		if item[0] >= float(cfg.flow_infinity):
			continue
		var distance := int(item[0])
		if not buckets.has(distance):
			buckets[distance] = []
		buckets[distance].append(item[1])
		first = distance if first < 0 else mini(first, distance)
		last = maxi(last, distance)
	if first < 0:
		return 0
	var dist: PackedFloat64Array = f.dist
	var next: PackedInt32Array = f.next
	var count := 0
	var cursor := first
	while cursor <= last:
		if not buckets.has(cursor):
			cursor += 1
			continue
		var layer: Array = buckets[cursor]
		buckets.erase(cursor)
		layer.sort()
		var d: float = cursor + 1.0
		for i in layer:
			if dist[i] != cursor:
				continue
			count += 1
			for j in adjacency[i]:
				if blocked[j] == 0 and d < dist[j]:
					dist[j] = d
					next[j] = i
					if not buckets.has(cursor + 1):
						buckets[cursor + 1] = []
					buckets[cursor + 1].append(j)
					last = maxi(last, cursor + 1)
		cursor += 1
	f.dist = dist
	f.next = next
	return count

func _propagate_heap(f: Dictionary, heap: Array) -> int:
	# PackedArray 放在局部变量中更新，避免每条边反复经 Dictionary 取写。
	var dist: PackedFloat64Array = f.dist
	var next: PackedInt32Array = f.next
	var cave: bool = f.cave and cfg.cave_enabled
	var count := 0
	while not heap.is_empty():
		var item := _pop(heap)
		var i: int = item[1]
		if item[0] != dist[i]:
			continue
		count += 1
		var d: float = item[0] + 1.0
		for j in adjacency[i]:
			if blocked[j] == 0 and d < dist[j]:
				dist[j] = d
				next[j] = i
				_push(heap, [d, j])
		if cave and (i == cave_a or i == cave_b):
			var j := cave_b if i == cave_a else cave_a
			var cd: float = item[0] + cave_cost
			if cd < dist[j]:
				dist[j] = cd
				next[j] = i
				_push(heap, [cd, j])
	f.dist = dist
	f.next = next
	return count

func _build_field(g: int, cave: bool) -> Dictionary:
	var dist := PackedFloat64Array()
	dist.resize(land.size())
	dist.fill(float(cfg.flow_infinity))
	var next := PackedInt32Array()
	next.resize(land.size())
	next.fill(-1)
	dist[g] = 0
	var f := {"goal": g, "cave": cave, "dist": dist, "next": next}
	_propagate(f, [[0.0, g]])
	return f

func prewarm(goal: Vector3, cave: bool = false) -> void:
	var g := index(tile(nearest(goal)))
	var key := "%d:%s" % [g, cave]
	if fields.has(key) or prebuilt.has(key) or fields.size() + prebuilt.size() >= int(cfg.flow_cache_limit):
		return
	prebuilt[key] = _build_field(g, cave)

func field(goal: Vector3, cave: bool) -> Dictionary:
	var g := index(tile(nearest(goal)))
	var key := "%d:%s" % [g, cave]
	if fields.has(key):
		return fields[key]
	if fields.size() >= int(cfg.flow_cache_limit):
		fields.erase(fields.keys()[0])
	var f: Dictionary
	if prebuilt.has(key):
		f = prebuilt[key]
		prebuilt.erase(key)
	else:
		# 预热项不占用正式 FIFO 插入位置，也不能挤掉已经使用的流场。
		if fields.size() + prebuilt.size() >= int(cfg.flow_cache_limit):
			prebuilt.erase(prebuilt.keys()[0])
		f = _build_field(g, cave)
	fields[key] = f
	return f

func distance(a: Vector3, b: Vector3, cave: bool = false) -> float:
	if not cave and line_clear(a, b):
		return Vector2(b.x - a.x, b.z - a.z).length()
	return field(b, cave).dist[index(tile(a))] if is_walkable_at(a) else float(cfg.flow_infinity)

func direction(a: Vector3, b: Vector3, cave: bool = false) -> Vector3:
	if Vector2(a.x - b.x, a.z - b.z).length_squared() <= float(cfg.direct_path_radius) ** 2 and line_clear(a, b):
		return Vector3(b.x - a.x, 0, b.z - a.z).limit_length(1.0)
	var f := field(b, cave)
	var i := index(tile(a))
	var j: int = f.next[i]
	if j < 0:
		return Vector3.ZERO
	return (point(j) - Vector3(a.x, 0, a.z)).limit_length(1.0)

func change(rect: Array, open: bool, at: float, reason: String) -> void:
	var changed: Array = []
	for t in rect_cells(rect):
		var i := index(t)
		if blocked[i] != int(not open):
			blocked[i] = int(not open)
			changed.append(i)
	if changed.is_empty():
		return
	# 拓扑改变后丢弃未使用的预热场，首次使用仍等价于当时完整构建。
	prebuilt.clear()
	var visits := 0
	for f in fields.values():
		var heap: Array = []
		var affected := false
		for i in changed:
			if f.dist[i] < float(cfg.flow_infinity):
				affected = true
			if open:
				for edge in neighbors(i, f.cave):
					if f.dist[edge[0]] < float(cfg.flow_infinity):
						affected = true
		if not affected:
			continue
		if not open:
			# 只失效穿过关门格的 successor 子树；其他距离保留。
			var invalid := {}
			var queue: Array = changed.duplicate()
			var cursor := 0
			while cursor < queue.size():
				var i: int = queue[cursor]
				cursor += 1
				if invalid.has(i):
					continue
				invalid[i] = true
				for edge in neighbors(i, f.cave):
					var j: int = edge[0]
					if f.next[j] == i:
						queue.append(j)
			for i in invalid:
				f.dist[i] = float(cfg.flow_infinity)
				f.next[i] = -1
			for i in invalid:
				if blocked[i] != 0:
					continue
				if i == f.goal:
					f.dist[i] = 0.0
					_push(heap, [0.0, i])
				for edge in neighbors(i, f.cave):
					if not invalid.has(edge[0]) and f.dist[edge[0]] < float(cfg.flow_infinity):
						_push(heap, [f.dist[edge[0]], edge[0]])
		else:
			for i in changed:
				if i == f.goal:
					f.dist[i] = 0.0
					_push(heap, [0.0, i])
				for edge in neighbors(i, f.cave):
					_push(heap, [f.dist[edge[0]], edge[0]])
		visits += _propagate(f, heap)
	flow_repairs += 1
	repaired_cells += visits
	topology_events.append({"time": snappedf(at, 0.001), "reason": reason, "changed_cells": changed.size(), "relaxed_cells": visits})
