extends RefCounted
## 共享反向流场；开口只传播降低的距离，关门只修复依赖该门的路径子树。

const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var cfg: Dictionary
var width: int
var depth: int
var land := PackedByteArray()
var blocked := PackedByteArray()
var fields := {}
var cave_a: int
var cave_b: int
var cave_cost: float
var gate_open := false
var gate_broken := false
var weak_broken := false
var flow_repairs := 0
var repaired_cells := 0
var topology_events: Array = []

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
	var t := Vector2i(i % width, i / width)
	for delta in DIRS:
		var q: Vector2i = t + delta
		if walkable(q):
			out.append([index(q), 1.0])
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
	var count := 0
	while not heap.is_empty():
		var item := _pop(heap)
		var i: int = item[1]
		if item[0] != f.dist[i]:
			continue
		count += 1
		for edge in neighbors(i, f.cave):
			var j: int = edge[0]
			var d: float = item[0] + edge[1]
			if d < f.dist[j]:
				f.dist[j] = d
				f.next[j] = i
				_push(heap, [d, j])
	return count

func field(goal: Vector3, cave: bool) -> Dictionary:
	var g := index(tile(nearest(goal)))
	var key := "%d:%s" % [g, cave]
	if fields.has(key):
		return fields[key]
	if fields.size() >= int(cfg.flow_cache_limit):
		fields.erase(fields.keys()[0])
	var dist := PackedFloat64Array()
	dist.resize(land.size())
	dist.fill(float(cfg.flow_infinity))
	var next := PackedInt32Array()
	next.resize(land.size())
	next.fill(-1)
	dist[g] = 0
	var f := {"goal": g, "cave": cave, "dist": dist, "next": next}
	_propagate(f, [[0.0, g]])
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
	var visits := 0
	for f in fields.values():
		var heap: Array = []
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
