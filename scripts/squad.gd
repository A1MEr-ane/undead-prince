class_name Squad
extends Node
## 小队协调器：持有目标点，在目标点周围生成站位并分配给个体；
## 决定个体的接敌半径和追击范围。个体只管自己的状态树。

var main
var terrain: Terrain
var faction := 0
var is_player := true
var title := ""
var units: Array = []
var target_point := Vector3.ZERO
var facing_dir := Vector3(0, 0, -1)
var post := Vector3.ZERO
var guard_radius := 3.5
var order_time := -100.0


func alive_units() -> Array:
	return units.filter(func(u): return u.alive)


func center() -> Vector3:
	var list := alive_units()
	if list.is_empty():
		return target_point
	var c := Vector3.ZERO
	for u in list:
		c += u.position
	return c / list.size()


func order_move(p: Vector3, face: Vector3 = Vector3.ZERO) -> void:
	var d := p - center()
	d.y = 0.0
	if face != Vector3.ZERO:
		facing_dir = face.normalized()
	elif d.length() > 0.3:
		facing_dir = d.normalized()
	target_point = p
	order_time = main.time
	if not is_player:
		post = p
	for u in alive_units():
		u.target = null
	_assign_slots()


func _assign_slots() -> void:
	var list := alive_units()
	var n := list.size()
	if n == 0:
		return
	var cols := mini(n, 3)
	var right := Vector3(-facing_dir.z, 0.0, facing_dir.x)
	var spacing := 0.42
	var slots: Array[Vector3] = []
	for i in n:
		var r := i / cols
		var c := i % cols
		var x := (c - (cols - 1) * 0.5) * spacing
		var p := target_point + right * x - facing_dir * (r * spacing)
		p += Vector3(randf_range(-0.05, 0.05), 0.0, randf_range(-0.05, 0.05))
		if not terrain.is_walkable_at(p):
			p = terrain.nearest_walkable(p)
		slots.append(p)
	var free := list.duplicate()
	for s in slots:
		var best = null
		var bd := 1e9
		for u in free:
			var d: float = u.position.distance_to(s)
			if d < bd:
				bd = d
				best = u
		best.slot = s
		free.erase(best)


func engage_radius(u) -> float:
	if is_player:
		# 刚下令或离站位远：只和挡路的敌人交手，优先执行移动
		if main.time - order_time < 0.8 or u.position.distance_to(u.slot) > 1.2:
			return 0.7
		return 2.4
	return 3.0


func can_chase(enemy) -> bool:
	if is_player:
		return true
	var d: Vector3 = enemy.position - post
	d.y = 0.0
	return d.length() < guard_radius + 1.0


func on_unit_died(_u) -> void:
	pass


func set_selected(on: bool) -> void:
	for u in units:
		u.set_selected(on)
