class_name Terrain
extends Node3D
## 格子玩法与视觉网格分离：查询保持分层平面，视觉使用共享轮廓的倒角岩岛。

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
var tree_tiles: Array[Vector2i] = []

# 光照：所有地形和道具共用一组参数，烘焙结果是一张三维天光贴图
const VOL_DY := 0.3
const LIT_SHADER := preload("res://shaders/terrain.gdshader")
var lit_materials: Array[ShaderMaterial] = []
var light_params := {}
var sky_volume: ImageTexture3D
var art_rng := RandomNumberGenerator.new()
var art_noise := FastNoiseLite.new()
var shore_field: ImageTexture
var generation_ms := 0
var decoration_ms := 0
const SHORE_RES := SIZE * 4
const CORNERS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
const EDGES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


func generate(seed_value: int) -> void:
	var started := Time.get_ticks_msec()
	rng.seed = seed_value
	art_rng.seed = seed_value + 7493
	art_noise.seed = seed_value + 1021
	art_noise.frequency = 0.24
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
	_build_shore_field()
	_build_mesh()
	generation_ms = Time.get_ticks_msec() - started
	print("TERRAIN geometry + shore %d ms" % generation_ms)


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

# 海岸有符号距离场：四像素/格，两趟 chamfer，陆地为正。与玩法数据只读共享。
func _build_shore_field() -> void:
	var dist := PackedFloat32Array()
	var land := PackedByteArray()
	dist.resize(SHORE_RES * SHORE_RES)
	land.resize(dist.size())
	dist.fill(1000.0)
	for z in SHORE_RES:
		for x in SHORE_RES:
			land[z * SHORE_RES + x] = int(level(Vector2i(x / 4, z / 4)) > 0)
	for z in SHORE_RES:
		for x in SHORE_RES:
			var i := z * SHORE_RES + x
			for d in N4:
				var q := Vector2i(x, z) + d
				if q.x >= 0 and q.y >= 0 and q.x < SHORE_RES and q.y < SHORE_RES:
					if land[i] != land[q.y * SHORE_RES + q.x]:
						dist[i] = 0.5
	for forward in [true, false]:
		for zi in SHORE_RES:
			var z: int = zi if forward else SHORE_RES - 1 - zi
			for xi in SHORE_RES:
				var x: int = xi if forward else SHORE_RES - 1 - xi
				var i := z * SHORE_RES + x
				for d in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]:
					var q: Vector2i = Vector2i(x, z) + (d if forward else -d)
					if q.x >= 0 and q.y >= 0 and q.x < SHORE_RES and q.y < SHORE_RES:
						dist[i] = minf(dist[i], dist[q.y * SHORE_RES + q.x] + (1.4142 if d.x != 0 and d.y != 0 else 1.0))
	var image := Image.create(SHORE_RES, SHORE_RES, false, Image.FORMAT_RF)
	for z in SHORE_RES:
		for x in SHORE_RES:
			var i := z * SHORE_RES + x
			var signed_d := dist[i] * 0.25 * (1.0 if land[i] == 1 else -1.0)
			image.set_pixel(x, z, Color(clampf(0.5 + signed_d / 16.0, 0.0, 1.0), 0, 0))
	shore_field = ImageTexture.create_from_image(image)
	set_light_param("shore_field", shore_field)
	set_light_param("island_size", float(SIZE))
	# main 已先创建雾海：自动绑定已有材质；其它场景也可显式调用 bind_sea_material。
	if get_parent():
		for child in get_parent().get_children():
			if child is MeshInstance3D and child.material_override is ShaderMaterial:
				var mat: ShaderMaterial = child.material_override
				if mat.shader and mat.shader.resource_path == "res://shaders/fog_sea.gdshader":
					bind_sea_material(mat)


func bind_sea_material(material: ShaderMaterial) -> void:
	material.set_shader_parameter("shore_field", shore_field)
	material.set_shader_parameter("island_size", float(SIZE))
	material.set_shader_parameter("shore_enabled", true)


func _top_color(p: Vector3, h: int) -> Color:
	var patch := art_noise.get_noise_2d(p.x, p.z)
	return Color(0.47, 0.57, 0.32).lerp(Color(0.57, 0.63, 0.38), patch * 0.5 + 0.5).darkened((h - 1) * 0.025)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, outward: Vector3, wind: Vector3 = Vector3.ZERO) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 0.00000001:
		return
	var flip := n.dot(outward) < 0.0
	n = -n.normalized() if flip else n.normalized()
	var vertices := [a, c, b] if flip else [a, b, c]
	var colors := [ca, cc, cb] if flip else [ca, cb, cc]
	var weights := [wind.x, wind.z, wind.y] if flip else [wind.x, wind.y, wind.z]
	for i in 3:
		st.set_normal(n)
		st.set_color(colors[i])
		st.set_uv(Vector2(weights[i], 0.0))
		st.add_vertex(vertices[i])


func _panel(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, top: Color, bottom: Color, outward: Vector3) -> void:
	_tri(st, a, b, c, top, top, bottom, outward)
	_tri(st, a, c, d, top, bottom, bottom, outward)


func _mesh_node(st: SurfaceTool, material: ShaderMaterial, label: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 摆动最大约 0.05，扩展包围盒防止屏幕边缘被提前裁掉。
	mi.extra_cull_margin = 0.08
	add_child(mi)


# 一个角由四格共同决定。凹角共用一个斜接点，凸角拆成两点；对角接触各自圆角。
# 参数只看世界角点/高度，连续边上的不同模块会得到完全相同的位置。
func _corner_pair(t: Vector2i, h: int, k: int, inset: float, cut: float, y: float) -> PackedVector3Array:
	var g: Vector2i = t + CORNERS[k]
	var count := 0
	var sum := Vector2.ZERO
	var contact := 0.0
	for dz in [-1, 0]:
		for dx in [-1, 0]:
			var neighbor := level(g + Vector2i(dx, dz))
			if neighbor >= h:
				count += 1
				sum += Vector2(dx * 2 + 1, dz * 2 + 1)
			elif neighbor > 0:
				contact = maxf(contact, 1.0 - smoothstep(0.025, 0.13, absf(y - level_y(neighbor))))
	var origin := Vector3(g.x, y, g.y)
	var jitter := art_noise.get_noise_2d(g.x * 2.7 + h * 3, g.y * 2.7) * 0.018
	# 崖脚展开到下层顶面之内；角点的四格共同决定接触，避免腰线内收露出底缝。
	var width := lerpf(inset + jitter, -0.03, contact)
	var corner_cut := lerpf(cut, -0.03, contact)
	if count == 1 or (count == 2 and sum == Vector2.ZERO):
		var prev: Vector2i = CORNERS[(k + 3) % 4] - CORNERS[k]
		var next: Vector2i = CORNERS[(k + 1) % 4] - CORNERS[k]
		var pv := Vector3(prev.x, 0, prev.y)
		var nv := Vector3(next.x, 0, next.y)
		return PackedVector3Array([origin + pv * corner_cut + nv * width, origin + pv * width + nv * corner_cut])
	var offset := sum * width / (2.0 if count == 2 else 1.0)
	var p := origin + Vector3(offset.x, 0, offset.y)
	return PackedVector3Array([p, p])


# 每边分两段，腰线轻微内外错动，端点仍由共享角决定。
func _outline(t: Vector2i, h: int, y: float, inset: float, cut: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for k in 4:
		var pair := _corner_pair(t, h, k, inset, cut, y)
		points.append(pair[0])
		points.append(pair[1])
		var mid: Vector2 = Vector2(t) + (Vector2(CORNERS[k]) + Vector2(CORNERS[(k + 1) % 4])) * 0.5
		var shift := 0.0
		var neighbor := level(t + EDGES[k])
		if neighbor < h:
			shift = inset + art_noise.get_noise_2d(mid.x * 3.7 + y * 2.0, mid.y * 3.7) * 0.045
			if neighbor > 0:
				var contact := 1.0 - smoothstep(0.025, 0.13, absf(y - level_y(neighbor)))
				shift = lerpf(shift, -0.03, contact)
		points.append(Vector3(mid.x - EDGES[k].x * shift, y, mid.y - EDGES[k].y * shift))
	return points


func _wall_ring(t: Vector2i, h: int, y: float) -> PackedVector3Array:
	var depth := level_y(h) - y
	var waist := sin(depth * 17.0 + h) * 0.028
	# 草皮下的第一圈略外展，保证站到逻辑格边缘时脚下仍有窄斜面承托。
	waist = lerpf(-0.025, waist, smoothstep(0.09, 0.27, depth))
	# 水下内收；水上扩张不超过约 0.05 格。
	var inset := waist + maxf(WATER_Y - y, 0.0) * 0.11
	return _outline(t, h, y, inset, 0.12 + maxf(WATER_Y - y, 0.0) * 0.06)


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
			var ring := _outline(t, h, y, 0.065, 0.18)
			var center := tile_center(t)
			var col := _top_color(center, h)
			for k in ring.size():
				var a := ring[k]
				var b := ring[(k + 1) % ring.size()]
				_tri(st, center, a, b, col, _top_color(a, h), _top_color(b, h), Vector3.UP)
			for k in 4:
				var nh := level(t + EDGES[k])
				var ph := level(t + EDGES[(k + 3) % 4])
				# 凸角的切面归当前模块；平/凹角两点重合，无需额外面。
				if nh < h and ph < h:
					_build_wall(st, t, h, mini(nh, ph), k * 3, k * 3 + 1, ring)
				if nh < h:
					_build_wall(st, t, h, nh, k * 3 + 1, k * 3 + 2, ring)
					_build_wall(st, t, h, nh, k * 3 + 2, ((k + 1) * 3) % 12, ring)
	var mat := make_lit_material(Color.WHITE, true, true)
	mat.set_shader_parameter("ground_surface", true)
	_mesh_node(st, mat, "IslandRockAndTurf")


func _build_wall(st: SurfaceTool, t: Vector2i, h: int, nh: int, a: int, b: int, top: PackedVector3Array) -> void:
	var y := level_y(h)
	var bottom := level_y(nh) - 0.015 if nh > 0 else SEABED_Y
	var outward := Vector3.UP.cross(top[b] - top[a]).normalized()
	var rim := _wall_ring(t, h, y - 0.09)
	_panel(st, top[a], top[b], rim[b], rim[a], _top_color(top[a], h), _top_color(top[a], h).darkened(0.11), outward + Vector3.UP)
	var upper := rim
	var upper_y := y - 0.09
	var band := 0
	while upper_y > bottom + 0.001:
		var lower_y := maxf(bottom, y - 0.27 - band * 0.20)
		var lower := _wall_ring(t, h, lower_y)
		var shade := 0.9 + art_noise.get_noise_2d(t.x * 1.9 + band, t.y * 1.9) * 0.1
		var ct := Color(shade, shade, shade, 0.0)
		var cb := Color(shade * 0.94, shade * 0.94, shade * 0.94, 0.0)
		_panel(st, upper[a], upper[b], lower[b], lower[a], ct, cb, outward)
		upper = lower
		upper_y = lower_y
		band += 1


## 树仍只占原来的 blocked 格；装饰使用独立随机流，不干扰树位/玩法随机数。
func add_trees(count: int, avoid: Array[Vector3], avoid_r: float) -> void:
	var started := Time.get_ticks_msec()
	var wood := SurfaceTool.new()
	var leaves := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
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
		tree_tiles.append(t)
		placed += 1
		var base := c + Vector3(art_rng.randf_range(-0.10, 0.10), 0, art_rng.randf_range(-0.10, 0.10))
		_build_pine(wood, leaves, base)
	if placed > 0:
		_mesh_node(wood, make_lit_material(Color.WHITE, true, false), "TreeTrunks")
		var leaf_mat := make_lit_material(Color.WHITE, true, false)
		leaf_mat.set_shader_parameter("wind_enabled", true)
		leaf_mat.set_shader_parameter("wind_strength", 0.045)
		_mesh_node(leaves, leaf_mat, "PineCrowns")
	_add_ground_details(avoid, avoid_r)
	flow_cache.clear()
	decoration_ms += Time.get_ticks_msec() - started
	print("TERRAIN decorations %d ms, %d trees" % [decoration_ms, placed])


# 多层偏心针叶冠：裙边 -> 肩部 -> 错位尖端，面色/高度/偏航各有小变化。
func _build_pine(wood: SurfaceTool, leaves: SurfaceTool, base: Vector3) -> void:
	var size := art_rng.randf_range(0.88, 1.20)
	var lean := Vector3(art_rng.randf_range(-0.09, 0.09), 0, art_rng.randf_range(-0.09, 0.09))
	_taper(wood, base, base + Vector3.UP * size * 0.83 + lean * 0.5, 0.065 * size, 0.033 * size, 6, Color(0.40, 0.30, 0.21), Color(0.34, 0.27, 0.20))
	var green := Color(0.28, 0.43, 0.28).lerp(Color(0.40, 0.50, 0.30), art_rng.randf() * 0.65)
	for k in 4:
		var y := (0.32 + k * 0.26) * size
		var radius := (0.40 - k * 0.078) * size
		var height := (0.58 - k * 0.055) * size
		var center := base + Vector3.UP * y + lean * (float(k) / 3.0)
		var offset := Vector3(art_rng.randf_range(-0.035, 0.035), 0, art_rng.randf_range(-0.035, 0.035))
		var shoulder := center + Vector3.UP * height * 0.25 + offset
		var tip := center + Vector3.UP * height + lean * 0.4
		var color := green.lightened(k * 0.025)
		var phase := art_rng.randf() * TAU
		_taper(leaves, center, shoulder, radius, radius * 0.72, 7, color.darkened(0.10), color, 0.18 + k * 0.16, 0.28 + k * 0.16, phase)
		_taper(leaves, shoulder, tip, radius * 0.72, 0.0, 7, color, color.lightened(0.06), 0.28 + k * 0.16, 0.42 + k * 0.16, phase)


func _taper(st: SurfaceTool, base: Vector3, tip: Vector3, r0: float, r1: float, sides: int, c0: Color, c1: Color, w0: float = 0.0, w1: float = 0.0, phase: float = 0.0) -> void:
	for i in sides:
		var a := phase + i * TAU / sides
		var b := phase + (i + 1) * TAU / sides
		var va := Vector3(cos(a), 0, sin(a))
		var vb := Vector3(cos(b), 0, sin(b))
		var pa := base + va * r0
		var pb := base + vb * r0
		var pc := tip + vb * r1
		var pd := tip + va * r1
		var tint := 0.96 + 0.04 * sin(i * 2.4 + phase)
		_tri(st, pa, pb, pc, c0 * Color(tint, tint, tint), c0 * Color(tint, tint, tint), c1, va + vb, Vector3(w0, w0, w1))
		_tri(st, pa, pc, pd, c0, c1, c1, va + vb, Vector3(w0, w1, w1))
		_tri(st, base, pb, pa, c0.darkened(0.15), c0.darkened(0.15), c0.darkened(0.15), Vector3.DOWN, Vector3(w0, w0, w0))


func _add_ground_details(avoid: Array[Vector3], avoid_r: float) -> void:
	var grass := SurfaceTool.new()
	var rocks := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	rocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_count := 0
	var rock_count := 0
	for z in SIZE:
		for x in SIZE:
			var t := Vector2i(x, z)
			var h := level(t)
			if h == 0:
				continue
			var center := tile_center(t)
			var traffic := false
			for p in avoid:
				if Vector2(p.x - center.x, p.z - center.z).length() < avoid_r * 0.65:
					traffic = true
			var cliff := false
			for d in N4:
				cliff = cliff or level(t + d) > h
			if grass_at(center) > 0.5 and (blocked[_i(t)] == 1 or (not traffic and art_rng.randf() < 0.48)):
				for clump in art_rng.randi_range(1, 3):
					# 留出格子中心，矮草只在内部边缘，避免伸到倒角/低台阶外。
					var angle := art_rng.randf() * TAU
					var radius := art_rng.randf_range(0.20, 0.30)
					var p := center + Vector3(cos(angle) * radius, 0.004, sin(angle) * radius)
					_build_grass(grass, p)
					grass_count += 1
			if (h == 1 or cliff) and art_rng.randf() < (0.45 if cliff else 0.19):
				var p := center + Vector3(art_rng.randf_range(-0.28, 0.28), -0.015, art_rng.randf_range(-0.28, 0.28))
				if cliff:
					for d in N4:
						if level(t + d) > h:
							p = center + Vector3(d.x, 0, d.y) * 0.40
							break
				var scale := Vector3(art_rng.randf_range(0.10, 0.22), art_rng.randf_range(0.06, 0.14), art_rng.randf_range(0.09, 0.18))
				_build_boulder(rocks, p, scale)
				rock_count += 1
	if grass_count > 0:
		var mat := make_lit_material(Color.WHITE, true, false)
		mat.set_shader_parameter("wind_enabled", true)
		mat.set_shader_parameter("wind_strength", 0.035)
		_mesh_node(grass, mat, "GrassClumps")
	if rock_count > 0:
		_mesh_node(rocks, make_lit_material(Color.WHITE, true, false), "BeachAndCliffStones")
	print("DETAIL %d grass clumps, %d stones (2 batches, no extra bake rays)" % [grass_count, rock_count])


func _build_grass(st: SurfaceTool, base: Vector3) -> void:
	var color := Color(0.45, 0.55, 0.30).lerp(Color(0.62, 0.65, 0.39), art_rng.randf() * 0.6)
	for blade in art_rng.randi_range(4, 6):
		var angle := art_rng.randf() * TAU
		var right := Vector3(cos(angle), 0, sin(angle)) * art_rng.randf_range(0.018, 0.030)
		var root := base + Vector3(art_rng.randf_range(-0.055, 0.055), 0, art_rng.randf_range(-0.055, 0.055))
		var tip := root + Vector3(art_rng.randf_range(-0.05, 0.05), art_rng.randf_range(0.09, 0.19), art_rng.randf_range(-0.05, 0.05))
		var n := (tip - root).cross(right).normalized()
		_tri(st, root - right, root + right, tip, color.darkened(0.14), color.darkened(0.14), color.lightened(0.08), n, Vector3(0, 0, 1))
		_tri(st, root + right, root - right, tip, color.darkened(0.14), color.darkened(0.14), color.lightened(0.08), -n, Vector3(0, 0, 1))


func _build_boulder(st: SurfaceTool, base: Vector3, scale: Vector3) -> void:
	var sides := 7
	var phase := art_rng.randf() * TAU
	var ring := PackedVector3Array()
	for i in sides:
		var a := phase + i * TAU / sides
		var radial := art_rng.randf_range(0.80, 1.15)
		ring.append(base + Vector3(cos(a) * scale.x * radial, scale.y * art_rng.randf_range(0.35, 0.65), sin(a) * scale.z * radial))
	var top := base + Vector3(scale.x * 0.12, scale.y, -scale.z * 0.15)
	var color := Color(0.58, 0.57, 0.52).lerp(Color(0.70, 0.66, 0.55), art_rng.randf())
	for i in sides:
		var a := ring[i]
		var b := ring[(i + 1) % sides]
		var va := a - base
		var vb := b - base
		var pa := Vector3(a.x, base.y, a.z)
		var pb := Vector3(b.x, base.y, b.z)
		_tri(st, top, a, b, color.lightened(0.04), color, color, Vector3.UP)
		_panel(st, a, b, pb, pa, color, color.darkened(0.13), Vector3(va.x + vb.x, 0, va.z + vb.z))


# ---------- 光照 ----------

## 地形与道具共用的不受光照着色器材质。albedo 只在不用顶点色时生效。
func make_lit_material(albedo: Color, use_vertex_color: bool, cliff_bands: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LIT_SHADER
	m.set_shader_parameter("albedo_color", Vector3(albedo.r, albedo.g, albedo.b))
	m.set_shader_parameter("use_vertex_color", use_vertex_color)
	m.set_shader_parameter("cliff_bands", cliff_bands)
	for k in light_params:
		m.set_shader_parameter(k, light_params[k])
	lit_materials.append(m)
	return m


func set_light_param(key: String, value: Variant) -> void:
	light_params[key] = value
	for m in lit_materials:
		m.set_shader_parameter(key, value)


## 三光瓣天光体积：每个格点向外发射线，统计从 +X 侧、正上方、−X 侧来的天光有多少没被挡住。
## 太阳只在 X-Y 平面里转，着色器按太阳方向给三个通道加权。
func bake_light() -> void:
	var t0 := Time.get_ticks_msec()
	var tops := PackedFloat32Array()
	tops.resize(SIZE * SIZE)
	var max_top := WATER_Y
	for i in SIZE * SIZE:
		var h := levels[i]
		tops[i] = level_y(h) if h > 0 else -100.0
		max_top = maxf(max_top, tops[i])

	var lobe_r := Vector3(1, 0.2, 0).normalized()
	var lobe_b := Vector3(-1, 0.2, 0).normalized()
	var dirs: Array[Vector3] = []
	var wts: Array[Vector3] = []
	var sums := Vector3.ZERO
	var n := 96
	for i in n:
		# 黄金角螺旋均匀取方向
		var y := 1.0 - (i + 0.5) / n * 2.0
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var a := i * 2.39996323
		var d := Vector3(cos(a) * r, y, sin(a) * r)
		var w := Vector3(pow(maxf(d.dot(lobe_r), 0.0), 5.0), pow(maxf(d.y, 0.0), 5.0), pow(maxf(d.dot(lobe_b), 0.0), 5.0))
		if w.x + w.y + w.z < 1e-4:
			continue
		dirs.append(d)
		wts.append(w)
		sums += w

	var w_px := SIZE + 1
	var layers := int(ceil((max_top + 1.6 - BASE_Y) / VOL_DY)) + 1
	var images: Array[Image] = []
	var traced := 0
	for k in layers:
		var y := BASE_Y + k * VOL_DY
		var img := Image.create(w_px, w_px, false, Image.FORMAT_RGB8)
		for z in w_px:
			for x in w_px:
				var c := Vector3.ONE
				if y < max_top + 1.3:
					var cover := 0.0
					for dz in [-1, 0]:
						for dx in [-1, 0]:
							var tx: int = x + dx
							var tz: int = z + dz
							if tx >= 0 and tz >= 0 and tx < SIZE and tz < SIZE and tops[tz * SIZE + tx] > y:
								cover += 0.25
					if cover >= 1.0:
						c = Vector3.ZERO
					else:
						traced += 1
						var acc := Vector3.ZERO
						var p := Vector3(x, y, z)
						for i in dirs.size():
							acc += wts[i] * _trace(p, dirs[i], tops, max_top)
						c = Vector3(acc.x / sums.x, acc.y / sums.y, acc.z / sums.z) * (1.0 - cover)
				# 存伽马后的值，暗部精度更高，过渡也更柔和
				img.set_pixel(x, z, Color(pow(c.x, 0.6), pow(c.y, 0.6), pow(c.z, 0.6)))
		images.append(img)
	sky_volume = ImageTexture3D.new()
	sky_volume.create(Image.FORMAT_RGB8, w_px, w_px, layers, false, images)
	set_light_param("sky_volume", sky_volume)
	set_light_param("vol_size", Vector3(w_px, w_px, layers))
	set_light_param("vol_base_y", BASE_Y)
	set_light_param("vol_dy", VOL_DY)
	var bake_ms := Time.get_ticks_msec() - t0
	print("BAKE %d ms, %d layers, %d traced points, %d dirs" % [bake_ms, layers, traced, dirs.size()])
	print("TERRAIN TOTAL generation + decoration + bake = %d ms (%d + %d + %d)" % [generation_ms + decoration_ms + bake_ms, generation_ms, decoration_ms, bake_ms])


func _trace(p: Vector3, d: Vector3, tops: PackedFloat32Array, max_top: float) -> float:
	var trans := 1.0
	var t := 0.2
	while t < 5.0:
		var q := p + d * t
		if q.y > max_top + 1.3:
			return trans
		var tx := floori(q.x)
		var tz := floori(q.z)
		if tx >= 0 and tz >= 0 and tx < SIZE and tz < SIZE:
			var i := tz * SIZE + tx
			if q.y < tops[i]:
				return 0.0
			# 树冠只挡一部分光
			if blocked[i] == 1 and q.y < tops[i] + 1.2:
				trans *= 0.7
		t += 0.3
	return trans


## 草量：草地 1，沙滩 0.3，水 0。小兵脚下按这个值陷进草里。
func grass_at(p: Vector3) -> float:
	var t := tile_of(p)
	var h := level(t)
	if h == 0:
		return 0.0
	if h == 1:
		for d in N8:
			if level(t + d) == 0:
				return 0.3
	return 1.0
