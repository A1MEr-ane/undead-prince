class_name Presence
extends RefCounted
## 阵营势力场（规格 4）：每个阵营一张格子场。每帧：
## 1. 存在量衰减 ×0.96，清空本帧距离
## 2. 把每个着地的活兵写进所在格（距离 = 到格心）
## 3. 从上一帧的结果沿可走边扩散一步（信息像波一样传开）
## 小兵采样得到最近敌人的距离、方向和对象，不做全图搜索。

const INF := 1.0e6

var terrain: Terrain
var faction := 0
var n := 0
var dist := PackedFloat32Array()
var new_dist := PackedFloat32Array()
var data: Array = []         # 每格最近的单位
var new_data: Array = []
var occupied := PackedByteArray()
var amount := PackedFloat32Array()
var nbr: Array[PackedInt32Array] = []    # 每格可走的邻格
var nbr_cost: Array[PackedFloat32Array] = []


func setup(p_terrain: Terrain, p_faction: int) -> void:
	terrain = p_terrain
	faction = p_faction
	var size := Terrain.SIZE
	n = size * size
	dist.resize(n)
	dist.fill(INF)
	new_dist.resize(n)
	occupied.resize(n)
	amount.resize(n)
	amount.fill(0.0)
	data.resize(n)
	new_data.resize(n)
	for i in n:
		var t := Vector2i(i % size, i / size)
		var ids := PackedInt32Array()
		var costs := PackedFloat32Array()
		if terrain.is_walkable(t):
			for d in Terrain.N8:
				var o := t + d
				if terrain.move_ok(o, t) and terrain.move_ok(t, o):
					ids.append(o.y * size + o.x)
					costs.append(1.414 if (d.x != 0 and d.y != 0) else 1.0)
		nbr.append(ids)
		nbr_cost.append(costs)


func update(units: Array) -> void:
	new_dist.fill(INF)
	occupied.fill(0)
	for i in n:
		amount[i] *= 0.96
		new_data[i] = null
	for u in units:
		if u.faction != faction or not u.alive_grounded.active:
			continue
		var t: Vector2i = terrain.tile_of(u.nav_pos)
		if not terrain.is_walkable(t):
			continue
		var i := t.y * Terrain.SIZE + t.x
		var c := Vector2(t.x + 0.5, t.y + 0.5)
		var d := Vector2(u.nav_pos.x, u.nav_pos.z).distance_to(c)
		occupied[i] = 1
		amount[i] = minf(1.0, amount[i] + 0.35)
		if d < new_dist[i]:
			new_dist[i] = d
			new_data[i] = u
	for i in n:
		if occupied[i] == 1:
			continue
		var ids := nbr[i]
		var costs := nbr_cost[i]
		var best := new_dist[i]
		var best_u = null
		for k in ids.size():
			var nd := dist[ids[k]] + costs[k]
			if nd < best:
				best = nd
				best_u = data[ids[k]]
		if best_u != null:
			new_dist[i] = best
			new_data[i] = best_u
	var tmp := dist
	dist = new_dist
	new_dist = tmp
	var tmp2 := data
	data = new_data
	new_data = tmp2


## 返回 [距离, 指向敌人的水平方向(长度≤1), 敌人(可能为 null)]
func sample(pos: Vector3) -> Array:
	var t := terrain.tile_of(pos)
	if not terrain.is_walkable(t):
		return [INF, Vector3.ZERO, null]
	var i := t.y * Terrain.SIZE + t.x
	var p2 := Vector2(pos.x, pos.z)
	var best_i := i
	var best := dist[i] + p2.distance_to(Vector2(t.x + 0.5, t.y + 0.5))
	for k in nbr[i]:
		var c := Vector2(k % Terrain.SIZE + 0.5, k / Terrain.SIZE + 0.5)
		var v := dist[k] + p2.distance_to(c)
		if v < best:
			best = v
			best_i = k
	var u = data[best_i]
	if u == null or best >= INF * 0.5:
		return [INF, Vector3.ZERO, null]
	if not is_instance_valid(u) or not u.alive_grounded.active:
		u = null
	# 敌人就在附近且直线可达：用精确的距离和方向
	if u != null:
		var v: Vector3 = u.nav_pos - pos
		v.y = 0.0
		var dl := v.length()
		if dl < 2.0 and terrain.line_clear(pos, u.nav_pos):
			return [dl, v.limit_length(1.0) if dl > 0.001 else Vector3.ZERO, u]
	var target := Vector3(best_i % Terrain.SIZE + 0.5, 0.0, best_i / Terrain.SIZE + 0.5)
	if best_i == i and u != null:
		target = u.nav_pos
	var dir := target - pos
	dir.y = 0.0
	return [best, dir.normalized() if dir.length() > 0.001 else Vector3.ZERO, u]


## 本阵营在该点的存在量（0–1），用来算友军占比
func amount_at(pos: Vector3) -> float:
	var t := terrain.tile_of(pos)
	if t.x < 0 or t.y < 0 or t.x >= Terrain.SIZE or t.y >= Terrain.SIZE:
		return 0.0
	return amount[t.y * Terrain.SIZE + t.x]
