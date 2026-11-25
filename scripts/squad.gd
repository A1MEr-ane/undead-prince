class_name Squad
extends Node
## 小队协调器（规格 11）：只管整队的事——站位、换位、到位转身。
## 剑兵之间的战斗协同不在这里，靠个体的邻居网络（冲锋传播、体力分摊）。

var main
var terrain: Terrain
var faction := 0
var is_player := true
var title := ""
var units: Array = []
var target_point := Vector3.ZERO
var final_look := Vector3(0, 0, -1)

var _swap_i := 0
var _arriving := false
var _arrive_start := -1.0
var _turns: Array = []   # [时刻, 单位]：到位后逐个转身

# 守方联动：被下令增援后保持环形站位，直到本队自己接敌。
const ENEMY_CONTACT := 4.0
const RING_RADIUS := 1.8
var reinforcing := false
var _ring_center := Vector3.ZERO
var _ring_radius := 0.0


func alive_units() -> Array:
	return units.filter(func(u): return is_instance_valid(u) and not u.removed and u.alive)


func center() -> Vector3:
	var list := alive_units()
	if list.is_empty():
		return target_point
	var c := Vector3.ZERO
	for u in list:
		c += u.nav_pos
	return c / list.size()


## 本队任一存活成员 4 米内是否有敌人。用精确距离而不是势力场采样，
## 让 0.5 秒一次的联动判断不受信息扩散延迟影响。
func has_enemy_within(radius: float) -> bool:
	for u in alive_units():
		for e in main.units:
			if e == null or not is_instance_valid(e) or e.removed or not e.alive:
				continue
			if e.faction == faction:
				continue
			var dx: float = e.nav_pos.x - u.nav_pos.x
			var dz: float = e.nav_pos.z - u.nav_pos.z
			if dx * dx + dz * dz < radius * radius:
				return true
	return false


func flat_distance_to(p: Vector3) -> float:
	var c := center()
	return Vector2(c.x - p.x, c.z - p.z).length()


## 守方增援：在旗点周围按环形分配站位。face 是整队的最终朝向。
func order_reinforce(flag: Vector3, face: Vector3 = Vector3.ZERO) -> void:
	var list := alive_units()
	if list.is_empty():
		return
	target_point = flag
	if face.length_squared() > 1e-6:
		final_look = Vector3(face.x, 0.0, face.z).normalized()
	_ring_center = flag
	_ring_radius = RING_RADIUS
	_layout_ring()
	var far := flat_distance_to(flag) > 1.5
	for u in list:
		u.slot_look = final_look
	_arriving = far
	_arrive_start = -1.0
	_turns.clear()
	reinforcing = true


## 环形站位：n 个兵均匀落在旗点周围，间距不足时把半径撑大。
func _layout_ring() -> void:
	var list := alive_units()
	var n := list.size()
	if n == 0:
		return
	var circumference := maxf(TAU * _ring_radius, float(n) * list[0].radius * 2.0 * 2.2)
	var r := circumference / TAU
	var slots: Array[Vector3] = []
	for i in n:
		var ang := TAU * float(i) / float(n)
		var p := _ring_center + Vector3(cos(ang), 0.0, sin(ang)) * r
		if not terrain.is_walkable_at(p):
			p = terrain.nearest_walkable(p)
		slots.append(Vector3(p.x, terrain.height_at(p), p.z))
	var free := list.duplicate()
	for s in slots:
		var best = null
		var bd := 1e9
		for u in free:
			var d: float = u.nav_pos.distance_to(s)
			if d < bd:
				bd = d
				best = u
		best.slot = s
		free.erase(best)


## 下令移动。face 为空时按行进方向决定最终朝向。
func order_move(p: Vector3, face: Vector3 = Vector3.ZERO) -> void:
	var travel := p - center()
	travel.y = 0.0
	if face != Vector3.ZERO:
		final_look = Vector3(face.x, 0, face.z).normalized()
	elif travel.length() > 0.3:
		final_look = travel.normalized()
	target_point = p
	reinforcing = false
	_ring_radius = 0.0
	_layout()
	# 行进途中先面朝来时方向，到位后再统一转身
	var far := travel.length() > 1.5
	for u in alive_units():
		u.slot_look = travel.normalized() if far else final_look
	_arriving = far
	_arrive_start = -1.0
	_turns.clear()


## 蛇形方阵：边长 ceil(√n)，偶数行反向，间距 2r × 1.01
func _layout() -> void:
	var list := alive_units()
	var n := list.size()
	if n == 0:
		return
	var sx := ceili(sqrt(float(n)))
	var sy := ceili(float(n) / sx)
	var right := Vector3(-final_look.z, 0.0, final_look.x)
	var spacing: float = list[0].radius * 2.0 * 1.01
	var slots: Array[Vector3] = []
	for i in n:
		var r := i / sx
		var c := i % sx
		if r % 2 == 1:
			c = sx - 1 - c
		var in_row := sx if r < sy - 1 else n - r * sx
		var x := (c - (in_row - 1) * 0.5) * spacing if r == sy - 1 else (c - (sx - 1) * 0.5) * spacing
		var y := (r - (sy - 1) * 0.5) * spacing
		var p := target_point + right * x - final_look * y
		if not terrain.is_walkable_at(p):
			p = terrain.nearest_walkable(p)
		slots.append(p)
	# 先贪心分配，之后靠每帧换槽慢慢优化
	var free := list.duplicate()
	for s in slots:
		var best = null
		var bd := 1e9
		for u in free:
			var d: float = u.nav_pos.distance_to(s)
			if d < bd:
				bd = d
				best = u
		best.slot = Vector3(s.x, terrain.height_at(s), s.z)
		free.erase(best)


func tick() -> void:
	var list := alive_units()
	if list.size() >= 2:
		_slot_swap(list)
	_update_arrival(list)


## 每帧轮询一个兵，和其他兵比较：交换后"最大距离 + 两人距离之和"降低 1% 以上就交换
func _slot_swap(list: Array) -> void:
	_swap_i = (_swap_i + 1) % list.size()
	var a = list[_swap_i]
	var da: float = a.order_dist_to(a.nav_pos)
	for b in list:
		if b == a:
			continue
		var db: float = b.order_dist_to(b.nav_pos)
		if da + db < 0.1:
			continue
		var da2: float = b.order_dist_to(a.nav_pos)
		var db2: float = a.order_dist_to(b.nav_pos)
		if maxf(da2, db2) + da2 + db2 < (maxf(da, db) + da + db) * 0.99:
			var s: Vector3 = a.slot
			a.slot = b.slot
			b.slot = s
			return


## 第一个兵到位后 0.5 秒内陆续标记到位，然后间隔 0.2/n 秒逐个转向最终朝向
func _update_arrival(list: Array) -> void:
	var now := AgentState.now
	if _arriving and not list.is_empty():
		if _arrive_start < 0.0:
			for u in list:
				if u.order_dist < 0.1:
					_arrive_start = now
					break
		else:
			var all_in := true
			for u in list:
				if u.order_dist > 0.2:
					all_in = false
					break
			if all_in or now - _arrive_start > 0.5:
				_arriving = false
				var gap := 0.2 / list.size()
				for i in list.size():
					_turns.append([now + i * gap, list[i]])
	while not _turns.is_empty() and _turns[0][0] <= now:
		var u = _turns.pop_front()[1]
		if is_instance_valid(u):
			u.slot_look = final_look


func report_dead(_u) -> void:
	# 有人倒下：剩下的人重新排阵（不重置到位状态）
	if reinforcing:
		_layout_ring()
	else:
		_layout()


func set_selected(on: bool) -> void:
	for u in units:
		if is_instance_valid(u):
			u.set_selected(on)
