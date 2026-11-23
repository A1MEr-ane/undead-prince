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
var tree_tiles: Array[Vector2i] = []

# 光照：所有地形和道具共用一组参数，烘焙结果是一张三维天光贴图
const VOL_DY := 0.3
const LIT_SHADER := preload("res://shaders/terrain.gdshader")
var lit_materials: Array[ShaderMaterial] = []
var light_params := {}
var sky_volume: ImageTexture3D


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
		c = Color(0.80, 0.74, 0.57)
	elif h == 1:
		c = Color(0.50, 0.60, 0.33)
	elif h == 2:
		c = Color(0.45, 0.56, 0.31)
	else:
		c = Color(0.40, 0.52, 0.29)
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
				# alpha = 0 标记岩壁，着色器按高度画岩层
				var rock_top := Color(0.56, 0.53, 0.49, 0.0)
				var rock_bot := Color(0.30, 0.30, 0.33, 0.0)
				_quad(st, Vector3(a.x, ylip, a.z), Vector3(b.x, ylip, b.z), Vector3(b.x, y2, b.z), Vector3(a.x, y2, a.z), n, rock_top, rock_bot)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = make_lit_material(Color.WHITE, true, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## 在高处放几棵树；树所在的格子不可走。
func add_trees(count: int, avoid: Array[Vector3], avoid_r: float) -> void:
	var trunk_mat := make_lit_material(Color(0.36, 0.25, 0.17), false, false)
	var leaf_mat := make_lit_material(Color(0.24, 0.40, 0.24), false, false)
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
	print("BAKE %d ms, %d layers, %d traced points, %d dirs" % [Time.get_ticks_msec() - t0, layers, traced, dirs.size()])


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
