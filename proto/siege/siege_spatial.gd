extends RefCounted
## 细网格随单位移动更新；保留粗网格快照的候选边界与遍历次序。
## 队友协同查询按 id 返回，等价于原来的 squad.units 顺序。

var bins := {}
var members: Array = []
var keys: Array = []
var snapshot: Array = []
var ranks := PackedInt64Array()
var cell_size := 1.0
var coarse_size := 3.0
var rank_stride := 1

func key(p: Vector3, faction: int) -> Vector3i:
	return Vector3i(floori(p.x / cell_size), faction, floori(p.z / cell_size))

func rebuild(units: Array, fine_size: float, legacy_size: float, map_width: int) -> void:
	cell_size = fine_size
	coarse_size = legacy_size
	bins.clear()
	members = units
	keys.resize(units.size())
	snapshot.resize(units.size())
	ranks.resize(units.size())
	rank_stride = units.size() + 1
	var columns := ceili(map_width / coarse_size) + 1
	for u in units:
		keys[u.id] = null
		snapshot[u.id] = null
		if not u.alive:
			continue
		var k := key(u.nav_pos, u.faction)
		keys[u.id] = k
		if not bins.has(k):
			bins[k] = []
		bins[k].append(u.id)
		if u.cave_until < 0:
			var coarse := Vector2i(floori(u.nav_pos.x / coarse_size), floori(u.nav_pos.z / coarse_size))
			snapshot[u.id] = coarse
			ranks[u.id] = (coarse.y * columns + coarse.x) * rank_stride + u.id

func moved(u) -> void:
	# 伤害和洞内状态仍在查询时检查；这里仅维护位置。
	if not u.alive or u.id >= keys.size():
		return
	var k := key(u.nav_pos, u.faction)
	var old = keys[u.id]
	if old == k:
		return
	if old != null:
		bins[old].erase(u.id)
		if bins[old].is_empty():
			bins.erase(old)
	if not bins.has(k):
		bins[k] = []
	bins[k].append(u.id)
	keys[u.id] = k

func _collect(p: Vector3, radius: float, faction: int, legacy: bool) -> Array:
	var ids: Array = []
	var low := Vector2i(floori((p.x - radius) / coarse_size), floori((p.z - radius) / coarse_size))
	var high := Vector2i(floori((p.x + radius) / coarse_size), floori((p.z + radius) / coarse_size))
	var radius_sq := radius * radius
	for z in range(floori((p.z - radius) / cell_size), floori((p.z + radius) / cell_size) + 1):
		for x in range(floori((p.x - radius) / cell_size), floori((p.x + radius) / cell_size) + 1):
			for id in bins.get(Vector3i(x, faction, z), []):
				var u = members[id]
				if legacy:
					var coarse = snapshot[id]
					if coarse == null or coarse.x < low.x or coarse.x > high.x or coarse.y < low.y or coarse.y > high.y or not u.alive or u.cave_until >= 0:
						continue
				elif not u.alive_grounded.active:
					continue
				if Vector2(u.nav_pos.x - p.x, u.nav_pos.z - p.z).length_squared() <= radius_sq:
					ids.append(ranks[id] if legacy else id)
	return ids

func count(p: Vector3, radius: float, faction: int) -> int:
	return _collect(p, radius, faction, true).size()

func query(p: Vector3, radius: float, faction: int, legacy: bool = true) -> Array:
	var ids := _collect(p, radius, faction, legacy)
	# 整数原生排序避免每次比较回调 GDScript；解码后仍是原粗格次序。
	ids.sort()
	var out: Array = []
	for id in ids:
		out.append(members[id % rank_stride if legacy else id])
	return out

func candidates(p: Vector3, radius: float, faction: int, fallback: Array) -> Array:
	# Brain 仍执行原三维距离/存活判断。宽相候选只需保证不漏人、保持 id 次序。
	var ids: Array = []
	for z in range(floori((p.z - radius) / cell_size), floori((p.z + radius) / cell_size) + 1):
		for x in range(floori((p.x - radius) / cell_size), floori((p.x + radius) / cell_size) + 1):
			ids.append_array(bins.get(Vector3i(x, faction, z), []))
	if ids.size() * 2 >= fallback.size():
		return fallback
	ids.sort()
	var out: Array = []
	for id in ids:
		out.append(members[id])
	return out

func clear() -> void:
	bins.clear()
	members = []
	keys.clear()
	snapshot.clear()
	ranks.clear()
