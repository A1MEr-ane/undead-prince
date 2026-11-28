extends "res://attempts/single_battle/style_frame/coast.gd"
## Reuses the painted stone, timber, roofs and vegetation from the landing sample.

const ASH := Color("#766f62")
const SLATE := Color("#4c5c66")
const GOLD := Color("#ae8a53")
const STATES := {"gate": ["closed", "open", "broken"], "wall": ["intact", "breached"]}

var _ground: RefCounted
var _material: ShaderMaterial


func _init(ground: RefCounted, material: ShaderMaterial) -> void:
	_ground = ground
	_material = material
	_rng.seed = 85126


func build_static(parent: Node3D) -> void:
	_ink = Ink.new()
	for span in [[14.52, 26.0], [33.0, 48.10]]:
		var width: float = span[1] - span[0]
		_masonry(Vector3((span[0] + span[1]) * 0.5, 0.3, 28.52), width, 2.5, true)
	for span in [[14.18, 19.68, 0.3], [19.68, 20.0, 2.65], [22.0, 23.0, 2.65], [26.0, 29.0, 2.65]]:
		var width: float = span[1] - span[0]
		_masonry(Vector3(14.53, span[2], (span[0] + span[1]) * 0.5), width, 2.15, false)
	for item in [[16.25, -0.06, 29.35, 1.36, 3.45], [46.55, -0.06, 29.38, 1.28, 3.45],
			[14.5, 0.12, 14.55, 1.16, 3.25], [6.5, 2.65, 21.0, 1.04, 3.35]]:
		_turret(Vector3(item[0], item[1], item[2]), item[3], item[4])
	for item in [[19, 25.48, 3.23, 2.06, "#69514c"], [38, 25.55, 3.40, 2.04, "#545c62"],
			[39, 16.51, 3.32, 2.30, "#71554d"], [19, 16.50, 3.12, 2.16, "#51636b"],
			[7.51, 40.02, 2.42, 1.54, "#6c564e"]]:
		_house(item[0], 0.3, item[1], item[2], item[3], Color(item[4]))
	_keep()
	_dock(Vector3(24.63, 0.34, 45.10), Vector2(-0.20, 0.98), 5.5, 2.35, true)
	_dock(Vector3(15.45, 0.34, 45.36), Vector2(-0.12, 0.99), 3.6, 1.56, false)
	_harbor()
	_cave(Vector3(45.50, 0.3, 37.50), false)
	_cave(Vector3(21.50, 0.3, 20.50), true)
	_climb()
	_dressing()
	_ink.instance(parent, "Buildings, docks and scenery", _material)


func build_structure(parent: Node3D, id: String, rect: Array, kind: String) -> Dictionary:
	var assembly := Node3D.new()
	assembly.name = id
	var center := Vector3(float(rect[0]) + float(rect[2]) * 0.5, 0.3,
			float(rect[1]) + float(rect[3]) * 0.5)
	var across_x: bool = rect[2] >= rect[3]
	var width := float(rect[2] if across_x else rect[3])
	if not across_x:
		center.y = _ground.height_at(Vector2(center.x, center.z))
	assembly.position = center
	if not across_x:
		assembly.rotation_degrees.y = -90
	parent.add_child(assembly)
	var pieces := {}
	for state: String in STATES[kind]:
		_ink = Ink.new()
		_rng.seed = 85164 + int(rect[0]) * 19 + int(rect[1])
		if kind == "gate":
			_gate_variant(width, state)
		elif state == "intact":
			_masonry(Vector3.ZERO, width, 2.27, true)
			_fissures(width)
		else:
			_breach(width)
		var mesh := _ink.instance(assembly, state, _material)
		mesh.visible = state in ["intact", "closed"]
		pieces[state] = mesh
	return pieces


func build_boat(parent: Node3D, anchor: Vector3) -> MeshInstance3D:
	_ink = Ink.new()
	var hull := _ring([[-0.82,-2.20],[-1.12,-1.28],[-1.15,0.80],[-0.76,2.12],
		[-0.16,2.83],[0.09,2.88],[0.83,1.88],[1.11,0.81],[1.15,-1.19],[0.53,-2.30]])
	var upper := Ink.inset(hull, -0.045)
	var inner := Ink.inset(hull, 0.14)
	var keel := Ink.inset(hull, 0.41)
	for i in hull.size():
		var j := (i + 1) % hull.size()
		var a := Ink.point(upper[i], 0.65)
		var b := Ink.point(upper[j], 0.65)
		var c := Ink.point(hull[i], 0.39)
		var d := Ink.point(hull[j], 0.39)
		_ink.quad(a, b, d, c, WOOD.lightened(0.12))
		_ink.quad(c, d, Ink.point(keel[j], -0.10), Ink.point(keel[i], -0.10), DARK_WOOD)
		_ink.quad(a, b, Ink.point(inner[j], 0.61), Ink.point(inner[i], 0.61), ASH)
	_ink.sheet(inner, 0.58, WOOD)
	for i in range(-6, 8):
		var z := i * 0.24
		_ink.stroke(Vector3(-0.68, 0.585, z), Vector3(0.68, 0.585, z), 0.037, DARK_WOOD)
	for z in [-1.45, -0.70, 0.91, 1.38]:
		_ink.block(Vector3(0, 0.69, z), Vector3(1.64, 0.11, 0.25), WOOD.lightened(0.16))
	_ink.block(Vector3(0.04, 2.04, 0.20), Vector3(0.14, 2.91, 0.14), DARK_WOOD)
	var a := Vector3(0.09, 3.36, 0.91)
	var b := Vector3(0.09, 3.32, -1.55)
	var c := Vector3(0.38, 1.38, -1.31)
	var d := Vector3(0.39, 1.41, 0.83)
	var belly := Vector3(0.60, 2.16, -0.31)
	for edge in [[a,b], [b,c], [c,d], [d,a]]:
		_ink.triangle(edge[0], edge[1], belly, Color("#808070").darkened(_rng.randf_range(0.05, 0.20)))
	_ink.stroke(a, b, 0.12, DARK_WOOD, Vector3.RIGHT)
	_ink.stroke(d, c, 0.076, DARK_WOOD, Vector3.RIGHT)
	_ink.stroke(a, d, 0.037, DARK_WOOD, Vector3.RIGHT)
	_ink.stroke(Vector3(0.04, 3.34, 0.20), Vector3(-0.45, 0.70, 2.72), 0.036, DARK_WOOD, Vector3.RIGHT)
	_ink.quad(Vector3(0.04,3.48,0.20), Vector3(0.07,3.51,-0.57), Vector3(0.18,3.28,-0.39),
			Vector3(0.12,3.19,0.20), GOLD.darkened(0.20))
	var boat := _ink.instance(parent, "Garrison cutter", _material)
	boat.position = anchor
	return boat


func _masonry(at: Vector3, width: float, height: float, across_x: bool) -> void:
	_wall_brick(at, width, 0.0, (height - 0.4) * 0.5, across_x, MORTAR, 0.98, height + 0.4)
	var rows := maxi(1, roundi(height / 0.34))
	var course := height / rows
	for row in rows:
		var left := -width * 0.5
		var right := width * 0.5
		while left < right - 0.04:
			var brick := minf(right - left, _rng.randf_range(0.49, 0.84))
			var color := STONE.darkened(_rng.randf_range(0.05, 0.25))
			_wall_brick(at, brick - 0.031, left + brick * 0.5, (row + 0.5) * course,
					across_x, color, 0.99, course - 0.027)
			left += brick
	_wall_brick(at, width + 0.04, 0.0, height + 0.03, across_x, SLATE.lightened(0.16), 1.08, 0.16)
	var crenels := maxi(1, roundi(width / 0.86))
	for i in crenels:
		var x := width * ((i + 0.5) / crenels - 0.5)
		_wall_brick(at, minf(width * 0.72, 0.52), x, height + 0.25,
				across_x, STONE.lightened(0.04), 0.81, 0.30)


func _wall_brick(at: Vector3, width: float, along: float, elevation: float, across_x: bool,
		color: Color, depth: float, height: float) -> void:
	var center := at + (Vector3.RIGHT if across_x else Vector3.BACK) * along + Vector3.UP * elevation
	var size := Vector3(width, height, depth) if across_x else Vector3(depth, height, width)
	_ink.block(center, size, color, 0.025)


func _fissures(width: float) -> void:
	for side: float in [-1.0, 1.0]:
		var z := 0.499 * side
		var segments := [Vector3(-0.22, 2.15, z), Vector3(-0.08, 1.78, z),
			Vector3(-0.22, 1.49, z), Vector3(0.12, 1.15, z),
			Vector3(0.05, 0.78, z), Vector3(0.27, 0.34, z)]
		for i in range(1, segments.size()):
			var a: Vector3 = segments[i - 1]
			var b: Vector3 = segments[i]
			_ink.stroke(a, b, 0.057, MORTAR.darkened(0.24), Vector3.BACK)
			if i % 2 == 0:
				var branch := b + Vector3(width * 0.13 * side, -0.21, 0.0)
				_ink.stroke(b, branch, 0.035, MORTAR.darkened(0.16), Vector3.BACK)


func _breach(width: float) -> void:
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var x := side * (width * 0.5 - 0.11)
		for tier in 2:
			var span := minf(width * 0.20, 0.25) * (1.0 - tier * 0.28)
			_ink.block(Vector3(x, 0.12 + tier * 0.18, -0.23 * side),
					Vector3(span, 0.21, 0.41), STONE.darkened(0.10 + tier * 0.1))
	for i in roundi(width * 5.0):
		var x := _rng.randf_range(-0.44, 0.44) * width
		var z := _rng.randf_range(-0.38, 0.39)
		_rock(x, 0.025, z, _rng.randf_range(0.06, 0.15))
	_ink.sheet(_ring([[-width*0.46,0.22],[-width*0.30,-0.34],[width*0.32,-0.39],
		[width*0.47,0.30],[width*0.15,0.53],[-width*0.27,0.49]]), 0.012, ASH.darkened(0.27))


func _gate_variant(width: float, state: String) -> void:
	var opening := width * 0.455
	var peak := 2.73
	for side: float in [-1.0, 1.0]:
		for row in 6:
			_ink.block(Vector3(side * (opening + 0.104), (row + 0.5) * 0.32, 0),
					Vector3(0.26, 0.308, 0.99), STONE.darkened(0.03 + (row % 3) * 0.075))
		_banner(side * opening, 2.67, 0.565, 0.39, 0.81)
	var arch_center := Vector2(0, 1.74)
	var points := PackedVector2Array()
	for i in 13:
		var angle := PI - PI * i / 12.0
		points.append(arch_center + Vector2(cos(angle) * opening, sin(angle) * (peak - arch_center.y)))
	for i in 12:
		var a := points[i].lerp(points[i + 1], 0.021)
		var b := points[i].lerp(points[i + 1], 0.979)
		var top_a := a + (a - arch_center).normalized() * 0.26
		var top_b := b + (b - arch_center).normalized() * 0.26
		var color := STONE.lightened(0.05 + 0.021 * (i % 4))
		for z: float in [-0.47, 0.49]:
			_ink.quad(_front(a, z), _front(b, z), _front(top_b, z), _front(top_a, z), color)
		_ink.quad(_front(a, -0.47), _front(b, -0.47), _front(b, 0.49), _front(a, 0.49),
				color.darkened(0.43))
		_ink.quad(_front(top_a, -0.47), _front(top_b, -0.47), _front(top_b, 0.49), _front(top_a, 0.49),
				color.darkened(0.10))
	if state == "closed":
		var boards := 16
		var pitch := opening * 2 / boards
		for i in boards:
			var x := -opening + (i + 0.5) * pitch
			var h := 1.73 + (peak - 1.76) * sqrt(maxf(0.0, 1.0 - pow(x / opening, 2.0)))
			_ink.block(Vector3(x, h * 0.5, 0.27), Vector3(pitch - 0.015, h, 0.18),
					WOOD.lightened(_rng.randf_range(0.03, 0.22)))
		for side: float in [-1.0, 1.0]:
			for strap in [0.54, 1.19]:
				_ink.block(Vector3(side * opening * 0.5, strap, 0.39),
						Vector3(opening - 0.13, 0.11, 0.065), DARK_WOOD)
			_ink.block(Vector3(0.18 * side, 1.07, 0.43), Vector3(0.10, 0.17, 0.09), GOLD.darkened(0.28))
	elif state == "open":
		for side: float in [-1.0, 1.0]:
			for i in 8:
				var z := -0.43 - (i + 0.5) * opening / 8.0
				var h := 2.54 - 0.63 * pow(float(i) / 8.0, 3.0)
				_ink.block(Vector3(side * (opening + 0.045), h * 0.5, z),
						Vector3(0.16, h, opening / 8.0 - 0.013), WOOD.lightened(_rng.randf_range(0.03, 0.18)))
			_ink.block(Vector3(side * opening, 1.12, -1.35), Vector3(0.22, 0.10, 1.77), DARK_WOOD)
	else:
		_breach(width)
		for side: float in [-1.0, 1.0]:
			for i in 4:
				var x := side * (opening - 0.10 - i * 0.15)
				var h := _rng.randf_range(0.48, 1.34) * (1.0 - i * 0.12)
				var p := Vector3(x, 0.02, 0.39)
				_ink.quad(p, p + Vector3(0.13, 0.03, -0.04), p + Vector3(0.09, h * 0.75, -0.19),
						p + Vector3(-0.06, h, -0.23), WOOD.lightened(0.16))
		for i in 8:
			var p := Vector3(_rng.randf_range(-1.6, 1.6), 0.045, _rng.randf_range(0.5, 0.97))
			_ink.stroke(p, p + Vector3(0.18, 0.0, 0.18), 0.11, WOOD)


func _turret(at: Vector3, radius: float, height: float) -> void:
	var center := Vector2(at.x, at.z)
	var rim := PackedVector2Array()
	for i in 8:
		var angle := TAU * (i + 0.5) / 8.0
		rim.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var lip := Ink.inset(rim, -0.13)
	_ink.sheet(lip, at.y + height, SLATE.lightened(0.20))
	for i in rim.size():
		var j := (i + 1) % rim.size()
		var a := rim[i]
		var b := rim[j]
		var tint := STONE.darkened(0.12 + 0.11 * (sin(i * 1.35) + 1.0))
		_ink.quad(Ink.point(a, at.y), Ink.point(b, at.y),
				Ink.point(b, at.y + height - 0.24), Ink.point(a, at.y + height - 0.24), tint)
		_ink.quad(Ink.point(a, at.y + height - 0.24), Ink.point(b, at.y + height - 0.24),
				Ink.point(lip[j], at.y + height), Ink.point(lip[i], at.y + height), tint.lightened(0.15))
		var outward := ((a + b) * 0.5 - center).normalized()
		var normal := Ink.point(outward, 0)
		for row in range(1, ceili((height - 0.26) / 0.31)):
			var y := at.y + 0.31 * row
			var offset := outward * 0.007
			var left := Ink.point(a + offset, y)
			var right := Ink.point(b + offset, y - 0.011)
			_ink.stroke(left, right, 0.031, tint.darkened(0.38), normal)
			var join := left.lerp(right, 0.31 + 0.32 * (row % 2))
			_ink.stroke(join, join - Vector3.UP * 0.30, 0.029, tint.darkened(0.36), normal)
		var merlon := Ink.point(lip[i], at.y + height + 0.14)
		_ink.block(merlon, Vector3(0.43, 0.30, 0.43), STONE, 0.04)
		_ink.block(merlon + Vector3.UP * 0.16, Vector3(0.50, 0.08, 0.48), SLATE.lightened(0.18))
		if i % 2 == 0:
			var slit := Ink.point((a + b) * 0.5 + outward * 0.015, at.y + height * 0.48)
			var across := normal.cross(Vector3.UP) * 0.075
			_ink.quad(slit - across, slit + across, slit + across + Vector3.UP * 0.58,
					slit - across + Vector3.UP * 0.58, MORTAR.darkened(0.4))


func _keep() -> void:
	var y := 0.9
	_masonry(Vector3(32, y, 7.52), 8.38, 3.35, true)
	_ink.block(Vector3(32, y + 1.59, 6.23), Vector3(8.41, 3.38, 2.85), STONE.darkened(0.13))
	_ink.block(Vector3(32, y + 3.34, 6.17), Vector3(7.6, 0.19, 2.48), SLATE.darkened(0.15))
	_masonry(Vector3(32.0, y, 5.42), 6.27, 3.75, true)
	_turret(Vector3(27.33, y, 7.16), 1.32, 4.12)
	_turret(Vector3(36.58, y, 7.16), 1.32, 4.30)
	_ink.block(Vector3(32, y + 2.67, 5.79), Vector3(3.25, 4.99, 2.78), STONE.darkened(0.12))
	_ink.block(Vector3(32, y + 5.17, 5.79), Vector3(3.6, 0.27, 3.03), SLATE.lightened(0.12))
	for x in [-1.5, -0.5, 0.5, 1.5]:
		for z in [-1.21, 1.21]:
			_ink.block(Vector3(32 + x, y + 5.40, 5.79 + z), Vector3(0.44, 0.32, 0.44), STONE)
	for x in [29.27, 30.38, 33.58, 34.70]:
		_window(x, y + 2.30, 8.04)
	_ink.block(Vector3(32, y + 0.93, 8.05), Vector3(1.29, 1.88, 0.099), MORTAR)
	_ink.block(Vector3(32, y + 0.84, 8.11), Vector3(1.01, 1.70, 0.075), WOOD.darkened(0.17))
	_ink.block(Vector3(32, y + 1.83, 8.15), Vector3(1.44, 0.21, 0.32), STONE.lightened(0.12))
	_banner(32, y + 3.08, 8.14, 0.70, 1.08)
	_banner(36.68, y + 3.47, 8.48, 0.60, 1.24)
	_banner(27.34, y + 3.34, 8.48, 0.60, 1.24)
	for x in [26.98, 37.98]:
		_ink.block(Vector3(x, y + 0.18, 9.48), Vector3(1.40, 0.35, 2.52), SLATE)
		_crate(x, y + 0.35, 9.65, 0.46)
	_ink.block(Vector3(32, y + 0.025, 9.45), Vector3(2.34, 0.05, 1.81), ASH)
	var pole := Vector3(34.09, y, 9.95)
	_ink.block(pole + Vector3.UP * 1.23, Vector3(0.086, 2.46, 0.086), DARK_WOOD)
	_banner(pole.x + 0.31, pole.y + 2.42, pole.z, 0.57, 0.91)


func _dock(origin: Vector3, heading: Vector2, length: float, width: float, ropes: bool) -> void:
	var along := Ink.point(heading.normalized(), 0)
	var across := Vector3(along.z, 0, -along.x)
	var edge := across * width * 0.5
	var back := origin + along * length
	_ink.quad(origin - edge - Vector3.UP * 0.04, origin + edge - Vector3.UP * 0.04,
			back + edge - Vector3.UP * 0.04, back - edge - Vector3.UP * 0.04, DARK_WOOD)
	var boards := ceili(length / 0.26)
	var spacing := length / boards
	for i in boards:
		var p := origin + along * ((i + 0.5) * spacing)
		var a := p - edge * _rng.randf_range(0.96, 1.01)
		var b := p + edge * _rng.randf_range(0.96, 1.01)
		var span := along * (spacing * 0.47)
		var shade := WOOD.lightened(_rng.randf_range(0.04, 0.24))
		_ink.quad(a - span, b - span, b + span, a + span, shade)
		_ink.stroke(a.lerp(b, _rng.randf_range(0.10, 0.34)) + Vector3.UP * 0.006,
				a.lerp(b, _rng.randf_range(0.60, 0.93)) + Vector3.UP * 0.006, 0.029, shade.darkened(0.27))
	var posts := ceili(length / 1.5)
	for i in posts + 1:
		for side: float in [-1.0, 1.0]:
			var p := origin + along * lerpf(0.19, length - 0.17, float(i) / posts) + edge * (side * 0.93)
			_ink.block(p + Vector3.DOWN * 0.04, Vector3(0.19, 0.78, 0.19), DARK_WOOD)
			_ink.block(p + Vector3.UP * 0.25, Vector3(0.22, 0.09, 0.22), ASH)
			if ropes and side < 0 and i < posts:
				var a := p + Vector3.UP * 0.22
				var b := a + along * ((length - 0.36) / posts)
				var knot := (a + b) * 0.5 - Vector3.UP * 0.115
				_ink.stroke(a, knot, 0.038, ASH.darkened(0.42), across)
				_ink.stroke(knot, b, 0.038, ASH.darkened(0.43), across)


func _harbor() -> void:
	_dock(Vector3(46.12, 0.36, 19.50), Vector2.RIGHT, 4.42, 1.70, false)
	for side: float in [-1.0, 1.0]:
		var z := 19.5 + side * 1.56
		_ink.block(Vector3(47.90, 0.12, z), Vector3(4.40, 0.52, 0.53), SLATE)
		for i in 7:
			_ink.block(Vector3(45.89 + i * 0.66, 0.42, z), Vector3(0.64, 0.12, 0.57),
					STONE.darkened(_rng.randf_range(0.00, 0.15)))
	_crate(47.95, 0.41, 20.55, 0.45)
	_crate(48.57, 0.41, 20.59, 0.32)
	_ink.block(Vector3(49.26, 0.67, 20.42), Vector3(0.19, 0.65, 0.21), DARK_WOOD)
	_ink.block(Vector3(49.26, 1.11, 20.42), Vector3(0.24, 0.24, 0.24), GOLD, 0.04)
	_ink.block(Vector3(49.26, 1.25, 20.42), Vector3(0.30, 0.08, 0.29), DARK_WOOD)


func _cave(at: Vector3, inside_wall: bool) -> void:
	var mouth := PackedVector2Array([Vector2(-0.78, 0), Vector2(-0.74, 0.85), Vector2(-0.51, 1.19),
		Vector2(-0.16, 1.43), Vector2(0.41, 1.30), Vector2(0.69, 0.99), Vector2(0.78, 0.39),
		Vector2(0.72, 0)])
	var opening := Ink.inset(mouth, 0.065)
	var rim := Ink.inset(mouth, -0.46)
	var root := at + Vector3.FORWARD * 0.48
	var depth := 0.66 if inside_wall else 0.87
	var tint := SLATE.darkened(0.05 if inside_wall else 0.15)
	var sink := _front(Vector2(0, 0.57), -0.28)
	for i in mouth.size():
		var j := (i + 1) % mouth.size()
		var a := _front(mouth[i], 0.06)
		var b := _front(mouth[j], 0.06)
		var c := _front(rim[j], -0.28)
		var d := _front(rim[i], -0.28)
		var stone := tint.lightened(_rng.randf_range(0.0, 0.22))
		_ink.quad(root + a, root + b, root + c, root + d, stone)
		_ink.quad(root + d, root + c, root + c + Vector3(0.0, -0.18, -depth),
				root + d + Vector3(0.0, -0.16, -depth), stone.darkened(0.19))
		_ink.quad(root + a, root + b, root + _front(opening[j], -0.11),
				root + _front(opening[i], -0.11), tint.darkened(0.48))
		_ink.triangle(root + _front(opening[i], -0.11), root + _front(opening[j], -0.11), root + sink,
				Color("#10191f"))
	for side: float in [-1.0, 1.0]:
		_rock(at.x + side * 1.10, at.y, at.z - 0.79, _rng.randf_range(0.36, 0.57))
		var post := Vector3(at.x + side * 1.10, at.y + 0.38, at.z - 0.03)
		_ink.block(post, Vector3(0.12, 0.77, 0.12), DARK_WOOD)
		_ink.block(post + Vector3.UP * 0.28, Vector3(0.16, 0.10, 0.15), ASH)


func _climb() -> void:
	for item in [[12.53, 36.07, 0.02, 0.65], [12.72, 34.75, 0.04, 0.57], [12.91, 33.83, 0.23, 0.68],
			[12.99, 32.85, 0.44, 0.79], [13.15, 31.96, 0.79, 0.78],
			[13.35, 31.20, 1.05, 0.74], [13.41, 30.49, 1.32, 0.76],
			[13.24, 29.75, 1.68, 0.67], [13.16, 29.08, 2.09, 0.56]]:
		_rock(item[0], item[2], item[1], item[3])
	var rungs := [Vector3(13.02, 0.56, 34.67), Vector3(13.28, 0.91, 33.75),
			Vector3(13.46, 1.20, 32.78), Vector3(13.60, 1.59, 31.88),
			Vector3(13.79, 1.88, 31.10), Vector3(13.76, 2.14, 30.38),
			Vector3(13.59, 2.40, 29.69), Vector3(13.53, 2.68, 28.96)]
	for i in range(1, rungs.size()):
		var a: Vector3 = rungs[i - 1]
		var b: Vector3 = rungs[i]
		_ink.stroke(a, b, 0.045, Color("#8a808d"), Vector3.RIGHT)
		_ink.stroke(b - Vector3.RIGHT * 0.15, b + Vector3.RIGHT * 0.12, 0.065, Color("#706679"))
	for i in 9:
		var x := 12.6 + 0.21 * sin(i * 0.70)
		var z := 28.38 - i * 0.78
		_ink.stroke(Vector3(x, 2.662, z), Vector3(x - 0.17, 2.664, z - 0.21),
				0.055, Color("#696873"))


func _dressing() -> void:
	for item in [[4.55, 22.79, 1.64], [5.7, 25.19, 1.92], [7.11, 22.35, 1.31],
			[9.25, 19.75, 1.95], [11.95, 19.42, 1.38], [4.62, 28.09, 1.29],
			[5.68, 37.55, 1.51], [8.1, 37.12, 1.30], [11.45, 43.83, 1.03],
			[17.77, 36.97, 1.47], [20.72, 38.15, 1.28], [22.9, 37.01, 1.41],
			[42.25, 36.86, 1.29], [46.60, 37.64, 1.02], [49.30, 40.24, 1.42],
			[46.47, 15.01, 1.70], [42.29, 15.33, 1.07], [25.40, 15.20, 1.57],
			[23.12, 15.35, 1.42], [16.34, 17.91, 1.51], [26.0, 5.37, 1.48],
			[38.7, 5.02, 1.58], [39.26, 7.58, 1.08], [25.65, 10.65, 1.12]]:
		_tree(item[0], _ground.height_at(Vector2(item[0], item[1])), item[1], item[2])
	for item in [[2.6, 36.55, 0.74], [2.06, 38.4, 0.59], [3.50, 40.8, 0.48],
			[3.31, 45.3, 0.55], [5.00, 46.83, 0.84], [8.22, 47.12, 0.67],
			[12.90, 46.96, 0.79], [19.15, 46.96, 0.87], [21.60, 47.20, 0.54],
			[27.64, 46.66, 0.43], [32.48, 46.94, 0.64], [37.74, 47.17, 0.82],
			[40.22, 47.22, 0.39], [47.97, 46.92, 0.67], [52.44, 44.42, 0.71],
			[53.32, 42.32, 0.38], [52.72, 37.93, 0.52], [50.84, 34.98, 0.80],
			[43.48, 34.92, 0.60], [35.45, 34.12, 0.52], [34.18, 32.94, 0.81],
			[37.62, 30.22, 0.68], [42.18, 29.80, 0.63], [48.78, 25.12, 0.79],
			[51.05, 22.48, 0.55], [49.03, 16.83, 0.82], [48.71, 14.83, 0.54],
			[22.28, 12.72, 0.49], [24.04, 10.15, 0.76], [41.19, 7.52, 0.51],
			[23.79, 4.76, 0.60], [26.48, 3.06, 0.84], [35.69, 2.54, 0.61],
			[3.2, 19.07, 0.78], [2.63, 24.14, 0.72], [2.91, 28.37, 0.67],
			[17.80, 30.22, 0.63], [24.84, 31.57, 0.54], [22.02, 35.13, 0.40]]:
		_rock(item[0], 0.037, item[1], item[2])
	for item in [[6.53, 37.12, 0.95], [10.9, 39.92, 0.97], [13.61, 40.32, 1.16],
			[16.11, 41.68, 1.37], [19.8, 39.83, 1.28], [24.5, 42.87, 0.85],
			[31.54, 39.63, 1.42], [34.67, 43.56, 0.95], [38.42, 38.15, 1.10],
			[42.66, 42.37, 1.04], [49.3, 43.58, 1.26], [47.97, 39.48, 0.96],
			[22.32, 25.29, 1.11], [39.25, 22.75, 1.20], [45.08, 25.28, 0.93],
			[26.32, 16.23, 0.93], [5.5, 24.35, 0.77], [11.6, 26.28, 0.94],
			[10.96, 32.28, 0.52], [37.35, 11.25, 0.93]]:
		_reeds(item[0], _ground.height_at(Vector2(item[0], item[1])), item[1], item[2])
	for item in [[24.08, 44.91, 0.50], [23.67, 44.48, 0.37], [8.69, 40.67, 0.42],
			[18.08, 25.7, 0.55], [38.64, 26.51, 0.45], [41.48, 17.22, 0.48],
			[6.24, 22.47, 0.31], [45.46, 18.67, 0.37]]:
		_crate(item[0], _ground.height_at(Vector2(item[0], item[1])), item[1], item[2])
