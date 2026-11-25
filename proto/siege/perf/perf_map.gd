extends "res://proto/siege/siege_map.gd"
## 测量用地图子类：只加计时，不改寻路/流场逻辑。
## 由 perf_siege.gd 在父类 _ready() 前注入；普通运行不加载。

var stat := {
	"distance_calls": 0,
	"distance_us": 0,
	"direction_calls": 0,
	"direction_us": 0,
	"field_calls": 0,
	"field_hits": 0,
	"field_builds": 0,
	"field_us": 0,
	"field_build_us": 0,
	"field_hit_us": 0,
	"change_calls": 0,
	"change_us": 0,
	"change_max_us": 0,
}

func distance(a: Vector3, b: Vector3, cave: bool = false) -> float:
	var t := Time.get_ticks_usec()
	var out := super.distance(a, b, cave)
	stat.distance_us += Time.get_ticks_usec() - t
	stat.distance_calls += 1
	return out

func direction(a: Vector3, b: Vector3, cave: bool = false) -> Vector3:
	var t := Time.get_ticks_usec()
	var out := super.direction(a, b, cave)
	stat.direction_us += Time.get_ticks_usec() - t
	stat.direction_calls += 1
	return out

func field(goal: Vector3, cave: bool) -> Dictionary:
	var before := fields.size()
	var t := Time.get_ticks_usec()
	var out := super.field(goal, cave)
	var elapsed := Time.get_ticks_usec() - t
	stat.field_us += elapsed
	stat.field_calls += 1
	if fields.size() > before:
		stat.field_builds += 1
		stat.field_build_us += elapsed
	else:
		stat.field_hits += 1
		stat.field_hit_us += elapsed
	return out

func change(rect: Array, open: bool, at: float, reason: String) -> void:
	var t := Time.get_ticks_usec()
	super.change(rect, open, at, reason)
	var elapsed := Time.get_ticks_usec() - t
	stat.change_us += elapsed
	stat.change_calls += 1
	stat.change_max_us = maxi(int(stat.change_max_us), elapsed)
