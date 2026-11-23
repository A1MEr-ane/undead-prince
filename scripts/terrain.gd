class_name Terrain
extends Node3D
## 方块地形：高度分层的格子岛。负责网格生成、高度查询、可走判定和流场寻路。

const SIZE := 24
const LEVEL_H := 0.6
const BASE_Y := -0.35
const WATER_Y := 0.08
const SEABED_Y := -1.4
const INF := 1 << 30
const N8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var levels := PackedInt32Array()
var blocked := PackedByteArray()
var flow_cache := {}
var rng := RandomNumberGenerator.new()


func generate(seed_value: int) -> void:
	rng.seed = seed_value
	levels.resize(SIZE * SIZE)
	blocked.resize(SIZE * SIZE)
	blocked.fill(0)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.08
	var c := Vector2((SIZE - 1) * 0.5, (SIZE - 1) * 0.5)
	for z in SIZE:
		for x in SIZE:
			var d := Vector2(x, z).distance_to(c) / (SIZE * 0.5)
			var n := noise.get_noise_2d(x, z)
			var v := 1.0 - d * 1.25 + n * 0.45
			var h := 0
			if v > 0.12:
				h = 1
			if v > 0.42:
				h = 2
			if v > 0.68:
				h = 3
			levels[z * SIZE + x] = h
	_smooth()
	_build_mesh()


## 相邻格最多差一级，保证每块陆地都能一步一跳走上去。
func _smooth() -> void:
	for _pass in 4:
		for z in SIZE:
			for x in SIZE:
				var t := Vector2i(x, z)
				var h := level(t)
				var m := 0
				for d in N4:
					m = maxi(m, level(t + d))
				if h > m + 1:
					levels[_i(t)] = m + 1


# ---------- 查询 ----------

func _in(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < SIZE and t.y < SIZE


func _i(t: Vector2i) -> int:
	return t.y * SIZE + t.x


func level(t: Vector2i) -> int:
	return levels[_i(t)] if _in(t) else 0


func level_y(h: int) -> float:
	return BASE_Y + h * LEVEL_H


func tile_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


func is_walkable(t: Vector2i) -> bool:
	return _in(t) and levels[_i(t)] > 0 and blocked[_i(t)] == 0


func height_at(p: Vector3) -> float:
	var h := level(tile_of(p))
	return level_y(h) if h > 0 else WATER_Y


func is_land_at(p: Vector3) -> bool:
	return level(tile_of(p)) > 0


func is_walkable_at(p: Vector3) -> bool:
	return is_walkable(tile_of(p))


func tile_center(t: Vector2i) -> Vector3:
	var h := level(t)
	return Vector3(t.x + 0.5, level_y(h) if h > 0 else WATER_Y, t.y + 0.5)


func move_ok(a: Vector2i, b: Vector2i) -> bool:
	if not is_walkable(b):
		return false
	if abs(level(a) - level(b)) > 1:
		return false
	var dx := b.x - a.x
	var dz := b.y - a.y
	if abs(dx) > 1 or abs(dz) > 1:
		return false
	if dx != 0 and dz != 0:
		var o1 := Vector2i(a.x + dx, a.y)
		var o2 := Vector2i(a.x, a.y + dz)
		if not (is_walkable(o1) and is_walkable(o2)):
			return false
		if abs(level(o1) - level(a)) > 1 or abs(level(o2) - level(a)) > 1:
			return false
	return true


func can_step(from: Vector3, to: Vector3) -> bool:
	var ta := tile_of(from)
	var tb := tile_of(to)
	if ta == tb:
		return true
	if not is_walkable(ta):
		return is_walkable(tb)
	return move_ok(ta, tb)


func line_clear(a: Vector3, b: Vector3) -> bool:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var n := int(ceil(flat.length() / 0.25))
	var prev := tile_of(a)
	for i in range(1, n + 1):
		var t := tile_of(a + flat * (float(i) / n))
		if t != prev:
			if not move_ok(prev, t):
				return false
			prev = t
	return true


func nearest_walkable(p: Vector3) -> Vector3:
	var t0 := tile_of(p)
	if is_walkable(t0):
		return p
	for r in range(1, 8):
		var best := Vector3.ZERO
		var bd := 1e9
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := t0 + Vector2i(dx, dz)
				if not is_walkable(t):
					continue
				var c := tile_center(t)
				var d := Vector2(c.x - p.x, c.z - p.z).length()
				if d < bd:
					bd = d
					best = c
		if bd < 1e8:
			return best
	return p


func raycast(origin: Vector3, dir: Vector3) -> Variant:
	var t := 0.0
	while t < 150.0:
		var p := origin + dir * t
		if p.y <= height_at(p):
			var lo := t - 0.05
			var hi := t
			for _k in 10:
				var mid := (lo + hi) * 0.5
				var q := origin + dir * mid
				if q.y <= height_at(q):
					hi = mid
				else:
					lo = mid
			return origin + dir * hi
		t += 0.05
	return null


func peak_tile() -> Vector2i:
	var best := Vector2i(SIZE / 2, SIZE / 2)
	var score := -1e9
	for z in SIZE:
		for x in SIZE:
			var t := Vector2i(x, z)
			if not is_walkable(t):
				continue
			var s := level(t) * 100.0 - z * 2.0 - absf(x - SIZE * 0.5)
			if s > score:
				score = s
				best = t
	return best


func beach_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in SIZE:
		for x in SIZE:
			var t := Vector2i(x, z)
			if level(t) != 1 or not is_walkable(t):
				continue
			for d in N4:
				if level(t + d) == 0:
					out.append(t)
					break
	return out


# ---------- 流场寻路 ----------

func _field(goal: Vector2i) -> PackedInt32Array:
	if flow_cache.has(goal):
		return flow_cache[goal]
	var dist := PackedInt32Array()
	dist.resize(SIZE * SIZE)
	dist.fill(INF)
	if is_walkable(goal):
		dist[_i(goal)] = 0
		var open: Array[Vector3i] = [Vector3i(goal.x, goal.y, 0)]
		while not open.is_empty():
			var bi := 0
			for k in range(1, open.size()):
				if open[k].z < open[bi].z:
					bi = k
			var cur := open[bi]
			open[bi] = open[open.size() - 1]
			open.pop_back()
			var ct := Vector2i(cur.x, cur.y)
			if cur.z > dist[_i(ct)]:
				continue
			for d in N8:
				var nt := ct + d
				if not _in(nt) or not move_ok(nt, ct):
					continue
				var cost := 14 if (d.x != 0 and d.y != 0) else 10
				if level(nt) != level(ct):
					cost += 4
				var nd := cur.z + cost
				if nd < dist[_i(nt)]:
					dist[_i(nt)] = nd
					open.append(Vector3i(nt.x, nt.y, nd))
	flow_cache[goal] = dist
	return dist


## 返回从 pos 朝 goal 前进的水平方向；不可达时返回零向量。
func flow_dir(pos: Vector3, goal: Vector2i) -> Vector3:
	var t := tile_of(pos)
	if t == goal:
		var c := tile_center(goal) - pos
		c.y = 0.0
		return c.normalized()
	var field := _field(goal)
	if not _in(t) or field[_i(t)] >= INF:
		return Vector3.ZERO
	var best := t
	var bd := field[_i(t)]
	for d in N8:
		var nt := t + d
		if _in(nt) and move_ok(t, nt) and field[_i(nt)] < bd:
			bd = field[_i(nt)]
			best = nt
	if best == t:
		return Vector3.ZERO
	var v := tile_center(best) - pos
	v.y = 0.0
	return v.normalized()


# ---------- 网格 ----------

func _top_color(t: Vector2i, h: int) -> Color:
	var jitter := (rng.randf() - 0.5) * 0.05
	var sandy := false
	if h == 1:
		for d in N8:
			if level(t + d) == 0:
				sandy = true
				break
	var c: Color
	if sandy:
		c = Color(0.86, 0.79, 0.58)
	elif h == 1:
		c = Color(0.55, 0.67, 0.34)
	elif h == 2:
		c = Color(0.47, 0.62, 0.31)
	else:
		c = Color(0.41, 0.56, 0.29)
	return Color(c.r + jitter, c.g + jitter, c.b + jitter * 0.5)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, c_top: Color, c_bot: Color) -> void:
	var verts := [a, b, c, d]
	var cols := [c_top, c_top, c_bot, c_bot]
	# Godot 以顺时针为正面：叉积与法线同向时说明是逆时针，要翻转。
	if (b - a).cross(c - a).dot(n) > 0.0:
		verts = [a, d, c, b]
		cols = [c_top, c_bot, c_bot, c_top]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_color(cols[idx])
		st.add_vertex(verts[idx])


func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in SIZE:
		for x in SIZE:
			var t := Vector2i(x, z)
			var h := level(t)
			if h == 0:
				continue
			var y := level_y(h)
			var col := _top_color(t, h)
			_quad(st, Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1), Vector3.UP, col, col)
			var lip := col.darkened(0.25)
			for dir in N4:
				var nh := level(t + dir)
				if nh >= h:
					continue
				var y2 := level_y(nh) if nh > 0 else SEABED_Y
				var a: Vector3
				var b: Vector3
				if dir == Vector2i(1, 0):
					a = Vector3(x + 1, 0, z); b = Vector3(x + 1, 0, z + 1)
				elif dir == Vector2i(-1, 0):
					a = Vector3(x, 0, z + 1); b = Vector3(x, 0, z)
				elif dir == Vector2i(0, 1):
					a = Vector3(x + 1, 0, z + 1); b = Vector3(x, 0, z + 1)
				else:
					a = Vector3(x, 0, z); b = Vector3(x + 1, 0, z)
				var n := Vector3(dir.x, 0, dir.y)
				var ylip := y - 0.07
				_quad(st, Vector3(a.x, y, a.z), Vector3(b.x, y, b.z), Vector3(b.x, ylip, b.z), Vector3(a.x, ylip, a.z), n, lip, lip)
				var rock_top := Color(0.56, 0.53, 0.49) + Color(1, 1, 1) * ((rng.randf() - 0.5) * 0.04)
				var rock_bot := Color(0.30, 0.30, 0.33)
				_quad(st, Vector3(a.x, ylip, a.z), Vector3(b.x, ylip, b.z), Vector3(b.x, y2, b.z), Vector3(a.x, y2, a.z), n, rock_top, rock_bot)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## 在高处放几棵树；树所在的格子不可走。
func add_trees(count: int, avoid: Array[Vector3], avoid_r: float) -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.36, 0.25, 0.17)
	trunk_mat.roughness = 1.0
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.22, 0.38, 0.22)
	leaf_mat.roughness = 1.0
	var placed := 0
	var tries := 0
	while placed < count and tries < 400:
		tries += 1
		var t := Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
		if not is_walkable(t) or level(t) < 2:
			continue
		var c := tile_center(t)
		var ok := true
		for p in avoid:
			if Vector2(p.x - c.x, p.z - c.z).length() < avoid_r:
				ok = false
				break
		if not ok:
			continue
		blocked[_i(t)] = 1
		placed += 1
		var tree := Node3D.new()
		tree.position = c + Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
		var s := rng.randf_range(0.8, 1.2)
		tree.scale = Vector3(s, s * rng.randf_range(0.9, 1.15), s)
		add_child(tree)
		var trunk := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.05; tm.bottom_radius = 0.07; tm.height = 0.35; tm.radial_segments = 6
		trunk.mesh = tm
		trunk.material_override = trunk_mat
		trunk.position.y = 0.17
		tree.add_child(trunk)
		for k in 2:
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.34 - k * 0.1
			cm.height = 0.6 - k * 0.12
			cm.radial_segments = 7
			cone.mesh = cm
			cone.material_override = leaf_mat
			cone.position.y = 0.55 + k * 0.32
			cone.rotation.y = rng.randf() * TAU
			tree.add_child(cone)
	flow_cache.clear()
