extends RefCounted

const Ink := preload("res://attempts/single_battle/style_frame/ink_mesh.gd")
const GROUND := 0.48
const HEIGHT := 1.70
const WALL_FRONT := -3.76
const TOWER_WALK := 4.84
const SHORE_ORIGIN := Vector2(-20.0, -18.0)
const SHORE_SIZE := Vector2(40.0, 36.0)
const SHORE_REACH := 3.2
const COAST := [
	[-11.9, -12.6], [-8.3, -14.3], [-3.0, -14.0], [1.8, -13.2],
	[6.6, -14.0], [11.9, -13.2], [14.4, -11.4], [15.9, -7.2],
	[15.4, -4.1], [16.1, -1.7], [15.2, 2.5], [14.4, 3.2],
	[14.8, 6.1], [13.5, 8.9], [12.0, 10.6], [8.2, 11.6],
	[5.9, 10.5], [4.8, 8.6], [2.5, 7.9], [0.6, 7.9],
	[-1.0, 7.2], [-3.1, 7.1], [-5.0, 6.5], [-7.0, 6.8],
	[-8.9, 6.0], [-10.1, 5.5], [-10.9, 3.8], [-12.4, 2.9],
	[-13.6, 0.3], [-13.9, -2.6], [-12.8, -3.6], [-12.5, -6.9],
]
const LEDGE := [
	[3.9, -10.7], [5.9, -12.2], [10.0, -12.2], [13.3, -10.5],
	[14.7, -7.0], [14.2, -3.8], [14.9, -1.5], [13.8, 1.5],
	[12.4, 1.9], [12.7, 3.5], [12.0, 6.0], [10.1, 7.3],
	[8.3, 6.8], [8.1, 5.1], [6.5, 4.8], [5.7, 3.9],
	[5.3, 2.2], [4.7, 1.6], [4.8, -0.5], [6.0, -2.2],
	[5.2, -3.4], [4.4, -4.6], [4.8, -6.5],
]
const ROAD := [
	[-9.9, 5.7], [-8.0, 4.1], [-6.0, 3.6], [-4.0, 2.1],
	[-2.1, 0.5], [-0.9, -1.1], [-0.35, -3.8], [-0.24, -6.1],
	[0.8, -8.5], [1.0, -12.1],
]
const GRASS := Color("#484f43")
const CLIFF := Color("#3b484e")
const SAND := Color("#55514a")
const ROAD_COLOR := Color("#636055")
const STONE := Color("#636b70")
const MORTAR := Color("#222b32")
const WOOD := Color("#5d5149")
const DARK_WOOD := Color("#28262b")

var _ink := Ink.new()
var _rng := RandomNumberGenerator.new()


func build(parent: Node3D, material: ShaderMaterial) -> MeshInstance3D:
	_rng.seed = 84115
	var shore := _ring(COAST)
	_cliff(shore, -0.13, GROUND, GRASS, 0.26)
	_ink.sheet(_ring([
		[-12.3, 2.0], [-10.1, 2.5], [-8.2, 4.0], [-5.6, 3.7],
		[-2.8, 4.4], [-1.0, 3.7], [2.0, 4.3], [4.0, 6.2], [6.3, 7.3],
		[8.2, 10.7], [6.4, 10.0], [4.6, 8.3], [2.2, 7.7], [0.6, 7.7],
		[-1.1, 7.0], [-3.0, 6.8], [-5.1, 6.3], [-7.0, 6.55],
		[-9.95, 5.28], [-10.8, 3.65], [-12.05, 2.78],
	]), GROUND + 0.009, SAND)
	_dirt_road()
	_highland()
	_jetty()
	_fort()
	_village()
	_scenery()
	return _ink.instance(parent, "Painted coast and fort", material)


static func shore_field() -> ImageTexture:
	var shore := _ring(COAST)
	var image := Image.create_empty(160, 144, false, Image.FORMAT_R8)
	for y in image.get_height():
		for x in image.get_width():
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(image.get_size())
			var p := SHORE_ORIGIN + uv * SHORE_SIZE
			var nearest := SHORE_REACH * SHORE_REACH
			for i in shore.size():
				var edge := Geometry2D.get_closest_point_to_segment(p, shore[i], shore[(i + 1) % shore.size()])
				nearest = minf(nearest, p.distance_squared_to(edge))
			image.set_pixel(x, y, Color(sqrt(nearest) / SHORE_REACH, 0, 0))
	return ImageTexture.create_from_image(image)


func _cliff(rim: PackedVector2Array, low: float, top: float, cap: Color, flare: float) -> void:
	var foot := Ink.inset(rim, -flare)
	var inner := Ink.inset(rim, 0.085)
	var mids := PackedVector2Array()
	var heights := PackedFloat32Array()
	for i in rim.size():
		mids.append(rim[i].lerp(foot[i], _rng.randf_range(0.20, 0.62)))
		heights.append(lerpf(low, top, _rng.randf_range(0.26, 0.53)))
	for i in rim.size():
		var j := (i + 1) % rim.size()
		var a := Ink.point(rim[i], top)
		var b := Ink.point(rim[j], top)
		var mid_a := Ink.point(mids[i], heights[i])
		var mid_b := Ink.point(mids[j], heights[j])
		var shade := CLIFF.lightened(_rng.randf_range(0.0, 0.11))
		if rim[j].y > rim[i].y:
			shade = shade.darkened(0.14)
		_ink.quad(a, b, mid_b, mid_a, shade)
		_ink.quad(mid_a, mid_b, Ink.point(foot[j], low), Ink.point(foot[i], low), shade.darkened(0.30))
		var seam_a := a.lerp(mid_a, 0.86) + Vector3.UP * 0.002
		var seam_b := b.lerp(mid_b, 0.86) + Vector3.UP * 0.002
		_ink.quad(seam_a, seam_b, mid_b, mid_a, shade.darkened(0.24))
		var cut := a.lerp(b, 0.40)
		var split := mid_a.lerp(mid_b, 0.20)
		_ink.triangle(cut, a.lerp(b, 0.69), split, shade.lightened(0.095))
	_ink.sheet(rim, top, cap)
	_ink.ribbon(rim, inner, top + 0.003, Ink.INK)


func _dirt_road() -> void:
	var road := _ring(ROAD)
	var edge := _road_shape(road, 1.0, 0.0)
	_ink.sheet(edge, GROUND + 0.013, Color("#373a36"))
	_ink.sheet(_road_shape(road, 0.91, 0.0), GROUND + 0.015, ROAD_COLOR)
	_ink.sheet(_road_shape(road, 0.46, 0.27), GROUND + 0.017, Color("#6d6856"))
	for lane: float in [-0.61, 0.54]:
		for i in range(1, road.size()):
			var normal := (road[i] - road[i - 1]).normalized().orthogonal()
			var first := road[i - 1] + normal * lane
			var last := road[i] + normal * lane
			_ink.stroke(Ink.point(first.lerp(last, 0.05), GROUND + 0.019),
					Ink.point(first.lerp(last, 0.82), GROUND + 0.019), 0.10, Color("#50504a"))
	for i in 64:
		var x := _rng.randf_range(-2.3, 1.55)
		var z := _rng.randf_range(-5.3, -0.85)
		var footprint := Vector2(x, z)
		if not Geometry2D.is_point_in_polygon(footprint, edge):
			continue
		var size := _rng.randf_range(0.09, 0.25)
		_flat_chip(x, GROUND + 0.020, z, size, size * 0.46, Color("#797666").darkened(_rng.randf() * 0.3))


func _road_shape(center: PackedVector2Array, width: float, offset: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in center.size():
		var delta := center[mini(i + 1, center.size() - 1)] - center[maxi(i - 1, 0)]
		var across := delta.normalized().orthogonal()
		var broad := (1.26 + 0.65 * sin(float(i) * 0.37)) * width
		left.append(center[i] + across * (broad + offset))
		right.append(center[i] - across * (broad * 0.86 - offset))
	right.reverse()
	left.append_array(right)
	return left


func _highland() -> void:
	var ledge := _ring(LEDGE)
	_ink.ribbon(Ink.inset(ledge, -0.57), ledge, GROUND + 0.006, Color("#323c37"))
	_cliff(ledge, GROUND + 0.012, HEIGHT, Color("#505747"), 0.38)
	var step := _ring([[7.65, 6.9], [8.6, 7.5], [11.0, 7.9], [13.0, 6.4],
		[13.5, 4.0], [12.65, 3.4], [12.0, 5.65], [10.0, 7.05], [8.45, 6.6]])
	_cliff(step, GROUND + 0.014, 0.94, Color("#454f43"), 0.17)
	_ink.sheet(_ring([[5.7, 2.1], [6.5, 0.2], [9.25, -1.0], [10.65, -3.6],
		[11.85, -2.95], [10.8, -0.7], [9.5, 0.35], [7.1, 1.3], [6.15, 2.5]]),
		HEIGHT + 0.009, Color("#5e5b4d"))


func _jetty() -> void:
	var origin := Vector3(-9.15, GROUND + 0.10, 5.55)
	var along := Vector3(-0.44, 0, 0.898).normalized()
	var across := Vector3(along.z, 0, -along.x)
	var length := 6.7
	var half := 1.25
	var rim := PackedVector2Array()
	for p in [origin - across * half, origin + across * half,
			origin + along * length + across * half, origin + along * length - across * half]:
		rim.append(Vector2(p.x, p.z))
	_ink.sheet(rim, origin.y - 0.06, DARK_WOOD.lerp(WOOD, 0.48))
	var spacing := length / 18.0
	for i in 18:
		var at := origin + along * (i + 0.5) * spacing
		var a := at - across * (_rng.randf_range(1.16, 1.26))
		var b := at + across * (_rng.randf_range(1.16, 1.26))
		var edge := along * _rng.randf_range(0.165, 0.177)
		var color := WOOD.lightened(_rng.randf_range(0.01, 0.14))
		_ink.quad(a - edge, b - edge, b + edge, a + edge, color)
		_ink.stroke(a.lerp(b, 0.09 + _rng.randf() * 0.25) + Vector3.UP * 0.006,
				a.lerp(b, 0.66 + _rng.randf() * 0.23) + Vector3.UP * 0.006, 0.040, color.darkened(0.18))
	for i: float in [0.52, 2.48, 4.42, 6.48]:
		for side: float in [-1.0, 1.0]:
			var peg := origin + along * i + across * (1.17 * side)
			_ink.block(Vector3(peg.x, 0.41, peg.z), Vector3(0.25, 0.99, 0.25), DARK_WOOD)
			_ink.block(Vector3(peg.x, 0.76, peg.z), Vector3(0.20, 0.35, 0.20), WOOD)
			_ink.block(Vector3(peg.x, 0.82, peg.z), Vector3(0.265, 0.07, 0.265), Color("#7b7060"))
	for i in 3:
		var from := origin + along * (0.52 + i * 1.98) - across * 1.17 + Vector3.UP * 0.24
		var to := from + along * 1.98
		var droop := (from + to) * 0.5 - Vector3.UP * 0.24
		_ink.stroke(from, droop, 0.052, DARK_WOOD, across)
		_ink.stroke(to, droop, 0.046, DARK_WOOD, across)
	_crate(-8.7, GROUND, 4.22, 0.68)
	_crate(-9.43, GROUND, 4.42, 0.53)


func _fort() -> void:
	_shadow(-0.62, GROUND + 0.010, -2.55, 8.8, 2.05)
	_wall(-6.95, -1.86, WALL_FRONT, 2.0)
	_wall(1.88, 5.70, WALL_FRONT, 2.0)
	_gate()
	_tower(6.46, HEIGHT, -5.73)


func _wall(left: float, right: float, front: float, height: float) -> void:
	var width := right - left
	var basis := Vector3((left + right) * 0.5, GROUND, front - 0.38)
	_ink.block(basis + Vector3.UP * height * 0.5, Vector3(width, height, 0.78), MORTAR)
	var course := 0.32
	for row in 6:
		var x := left + 0.024
		while x < right - 0.07:
			var span := minf(_rng.randf_range(0.46, 0.86), right - x)
			var y := GROUND + (row + 0.5) * course
			_ink.block(Vector3(x + span * 0.5, y, front - 0.36),
					Vector3(span - 0.026, course - 0.022, 0.77),
					STONE.darkened(_rng.randf_range(0.07, 0.30)), 0.027)
			x += span
	_ink.block(basis + Vector3.UP * height, Vector3(width + 0.15, 0.16, 0.97), Ink.INK)
	_ink.block(basis + Vector3.UP * (height + 0.055), Vector3(width + 0.16, 0.12, 0.98), STONE)
	var x := left + 0.22
	while x < right - 0.1:
		_ink.block(Vector3(x, GROUND + height + 0.26, front - 0.20),
				Vector3(0.42, 0.39, 0.55), MORTAR)
		_ink.block(Vector3(x, GROUND + height + 0.42, front - 0.20),
				Vector3(0.45, 0.10, 0.61), STONE.lightened(0.07))
		x += 0.78


func _gate() -> void:
	var z := WALL_FRONT + 0.08
	_ink.block(Vector3(0, GROUND + 1.36, z - 0.46), Vector3(3.96, 2.72, 0.96), MORTAR)
	_ink.block(Vector3(0, GROUND + 2.63, z - 0.32), Vector3(4.04, 0.22, 1.15), STONE)
	var arch := []
	for i in 9:
		var angle := PI - PI * float(i) / 8.0
		arch.append(Vector2(cos(angle) * 1.38, GROUND + 1.32 + sin(angle) * 0.91))
	for i in 8:
		_ink.triangle(_front(arch[i], z + 0.034), _front(arch[i + 1], z + 0.034),
				Vector3(0.0, GROUND + 1.31, z + 0.034), DARK_WOOD)
	_ink.quad(Vector3(-1.38, GROUND, z + 0.034), Vector3(1.38, GROUND, z + 0.034),
			_front(arch[8], z + 0.034), _front(arch[0], z + 0.034), DARK_WOOD)
	for i in 12:
		var x := -1.30 + i * 0.218
		var height := 1.31 + sqrt(maxf(0.0, 1.0 - pow((absf(x) + 0.10) / 1.38, 2.0))) * 0.85
		var tint := WOOD.lightened(_rng.randf_range(0.0, 0.18))
		_ink.block(Vector3(x + 0.085, GROUND + height * 0.5, z + 0.056),
				Vector3(0.192, height - 0.04, 0.055), tint, 0.013)
		_ink.stroke(Vector3(x + 0.057, GROUND + 0.16, z + 0.091),
				Vector3(x + 0.095, GROUND + height * 0.77, z + 0.091),
				0.039, tint.darkened(0.36), Vector3.BACK)
	for sign_x in [-1.0, 1.0]:
		for row in 4:
			_ink.block(Vector3(sign_x * (1.65 + 0.026 * (row % 2)), GROUND + 0.17 + row * 0.33, z + 0.03),
					Vector3(0.54, 0.30, 0.26), STONE.lightened(0.13 - row * 0.026))
		for y in [0.48, 1.03]:
			_ink.block(Vector3(sign_x * 0.69, GROUND + y, z + 0.113),
					Vector3(1.26, 0.095, 0.075), Ink.INK, 0.016)
	for i in 8:
		var a: Vector2 = arch[i].lerp(arch[i + 1], 0.035)
		var b: Vector2 = arch[i].lerp(arch[i + 1], 0.965)
		var center := Vector2(0.0, GROUND + 1.32)
		_ink.quad(_front(a, z + 0.149), _front(b, z + 0.149),
				_front(center + (b - center) * 1.29, z + 0.149),
				_front(center + (a - center) * 1.29, z + 0.149),
				STONE.lightened(0.09 + 0.023 * (i % 3)))
	_ink.block(Vector3(0, GROUND + 1.08, z + 0.14), Vector3(0.10, 2.12, 0.055), DARK_WOOD)
	_ink.block(Vector3(0.0, GROUND + 1.12, z + 0.184), Vector3(0.37, 0.27, 0.075), Color("#524b41"))
	_ink.stroke(Vector3(-0.82, GROUND + 1.16, z + 0.19), Vector3(-0.32, GROUND + 0.90, z + 0.19),
			0.085, DARK_WOOD, Vector3.BACK)
	_banner(-1.53, GROUND + 2.53, z + 0.20, 0.53, 0.91)


func _tower(x: float, y: float, z: float) -> void:
	_shadow(x - 0.36, y + 0.006, z + 1.1, 3.5, 2.3)
	var ring := PackedVector2Array()
	for i in 8:
		var angle := TAU * (i + 0.5) / 8.0
		ring.append(Vector2(x + cos(angle) * 1.57, z + sin(angle) * 1.47))
	var ledge := Ink.inset(ring, -0.12)
	var platform := Ink.inset(ring, -0.19)
	var levels := [y, y + 0.22, TOWER_WALK - 0.35, TOWER_WALK - 0.18, TOWER_WALK]
	_ink.sheet(platform, TOWER_WALK, CLIFF.lightened(0.10))
	for i in 8:
		var j := (i + 1) % 8
		var a := ring[i]
		var b := ring[j]
		var tint := STONE.darkened(0.17 + (sin(i * 1.3) + 1.0) * 0.11)
		_ink.quad(Ink.point(ledge[i], levels[0]), Ink.point(ledge[j], levels[0]),
				Ink.point(ledge[j], levels[1]), Ink.point(ledge[i], levels[1]), MORTAR)
		_ink.quad(Ink.point(a, levels[1]), Ink.point(b, levels[1]),
				Ink.point(b, levels[2]), Ink.point(a, levels[2]), tint)
		_ink.quad(Ink.point(a, levels[2]), Ink.point(b, levels[2]),
				Ink.point(platform[j], levels[3]), Ink.point(platform[i], levels[3]), tint.darkened(0.14))
		_ink.quad(Ink.point(platform[i], levels[3]), Ink.point(platform[j], levels[3]),
				Ink.point(platform[j], levels[4]), Ink.point(platform[i], levels[4]), STONE)
		var outward := ((a + b) * 0.5 - Vector2(x, z)).normalized()
		var normal := Ink.point(outward, 0.0)
		for row in 8:
			var h := y + 0.30 + 0.32 * row
			var line_a := Ink.point(a + outward * 0.006, h)
			var line_b := Ink.point(b + outward * 0.006, h - 0.015)
			_ink.stroke(line_a, line_b, 0.038, tint.darkened(0.39), normal)
			var join := line_a.lerp(line_b, 0.35 + 0.23 * (row % 2))
			_ink.stroke(join, join + Vector3.UP * 0.28, 0.035, tint.darkened(0.35), normal)
		var crown := a.lerp(b, 0.26) + outward * 0.12
		_ink.block(Ink.point(crown, TOWER_WALK + 0.18), Vector3(0.42, 0.35, 0.38), MORTAR)
		_ink.block(Ink.point(crown, TOWER_WALK + 0.36), Vector3(0.49, 0.09, 0.45), STONE)
		if i == 1 or i == 2 or i == 3:
			var slit := Ink.point(a.lerp(b, 0.51) + outward * 0.011, y + 1.64)
			var tangent := normal.cross(Vector3.UP) * 0.12
			_ink.quad(slit - tangent, slit + tangent, slit + tangent * 0.8 + Vector3.UP * 0.65,
					slit - tangent * 0.8 + Vector3.UP * 0.65, Ink.INK)
	_banner(x - 0.26, TOWER_WALK - 0.22, z + 1.57, 0.65, 1.28)


func _banner(x: float, y: float, z: float, width: float, height: float) -> void:
	_ink.block(Vector3(x, y, z), Vector3(width + 0.2, 0.076, 0.074), DARK_WOOD)
	var a := Vector3(x - width * 0.5, y, z + 0.031)
	var b := a + Vector3.RIGHT * width
	var c := b - Vector3.UP * height
	var d := a - Vector3.UP * height
	var tip := (c + d) * 0.5 + Vector3.UP * 0.24
	for i in 2:
		var grow := 0.041 * (1 - i)
		var shift := Vector3.BACK * (0.004 * i)
		var left := Vector3.LEFT * grow + shift
		var right := Vector3.RIGHT * grow + shift
		var color := Ink.INK if i == 0 else Color("#716447")
		_ink.quad(a + left, b + right, c + right, tip + shift, color)
		_ink.triangle(a + left, tip + shift, d + left, color.darkened(0.15))
	var crest := Vector3(x, y - height * 0.44, z + 0.045)
	var gold := Color("#b09561")
	_ink.triangle(crest + Vector3.UP * 0.15, crest + Vector3.LEFT * 0.13,
			crest + Vector3.RIGHT * 0.13, gold)
	_ink.triangle(crest - Vector3.UP * 0.15, crest + Vector3.LEFT * 0.13,
			crest + Vector3.RIGHT * 0.13, gold.darkened(0.20))


func _village() -> void:
	_house(-7.7, GROUND, -5.9, 3.1, 2.45, Color("#66524e"))
	_house(3.15, GROUND, -8.15, 2.45, 2.0, Color("#4d5b64"))
	_house(10.95, HEIGHT, -5.05, 3.0, 2.28, Color("#69504e"))


func _house(x: float, y: float, z: float, width: float, depth: float, roof: Color) -> void:
	var eave := y + 1.51
	var ridge := eave + 1.04
	var front := z + depth * 0.5
	var right := x + width * 0.5
	var left := x - width * 0.5
	var plaster := Color("#77766c")
	_shadow(x - 0.45, y + 0.006, z + 0.77, width + 1.34, depth + 1.02)
	_ink.block(Vector3(x, y + 0.19, z), Vector3(width + 0.13, 0.38, depth + 0.12), MORTAR)
	_ink.block(Vector3(x, y + 0.91, z), Vector3(width, 1.23, depth), plaster)
	for side in [left + 0.095, right - 0.095, x + width * 0.17]:
		_ink.block(Vector3(side, y + 0.95, front + 0.021), Vector3(0.12, 1.21, 0.09), DARK_WOOD)
	_ink.stroke(Vector3(left + 0.12, y + 1.39, front + 0.055),
			Vector3(left + width * 0.36, y + 0.53, front + 0.055), 0.11, DARK_WOOD, Vector3.BACK)
	_ink.block(Vector3(x, y + 0.48, front + 0.026), Vector3(width + 0.06, 0.12, 0.11), DARK_WOOD)
	_ink.block(Vector3(x + width * 0.33, y + 0.57, front + 0.09),
			Vector3(0.57, 1.13, 0.15), DARK_WOOD)
	_ink.block(Vector3(x + width * 0.33, y + 0.49, front + 0.17),
			Vector3(0.40, 0.92, 0.09), WOOD.darkened(0.15))
	_window(x - width * 0.29, y + 0.99, front + 0.07)
	_window(x + width * 0.02, y + 0.99, front + 0.07)
	for face_x in [left, right]:
		_ink.triangle(Vector3(face_x, eave, z - depth * 0.5), Vector3(face_x, eave, front),
				Vector3(face_x, ridge, z), plaster.darkened(0.31))
	var ridge_a := Vector3(left - 0.20, ridge, z - 0.08)
	var ridge_b := Vector3(right + 0.22, ridge - 0.06, z + 0.08)
	for side: float in [-1.0, 1.0]:
		var edge_z := z + side * (depth * 0.5 + 0.23)
		var low_a := Vector3(ridge_a.x - 0.054, eave - 0.09, edge_z)
		var low_b := Vector3(ridge_b.x + 0.04, eave - 0.06, edge_z + 0.04)
		_ink.quad(ridge_a, ridge_b, low_b, low_a, roof.darkened(0.30 if side > 0 else 0.02))
		for row in 6:
			var t := (row + 1.0) / 6.5
			var a := ridge_a.lerp(low_a, t) + Vector3.UP * 0.012
			var b := ridge_b.lerp(low_b, t) + Vector3.UP * 0.012
			_ink.stroke(a, b, 0.054, roof.darkened(0.51))
			for tile in range(1, 8):
				var start := a.lerp(b, (tile + 0.5 * (row % 2)) / 8.0)
				var down := (low_a - ridge_a) * 0.145
				_ink.stroke(start, start - down, 0.028, roof.darkened(0.41))
				if _rng.randf() < 0.33:
					var tile_tint := roof.darkened(0.22 if side > 0 else 0.0).lightened(0.038)
					_ink.quad(start + Vector3.UP * 0.003, start - Vector3.RIGHT * 0.28,
							start - Vector3.RIGHT * 0.22 - down * 0.73,
							start - down * 0.55, tile_tint)
		_ink.stroke(low_a, low_b, 0.13, Ink.INK, Vector3.BACK)
		_ink.stroke(ridge_a, low_a, 0.11, Ink.INK, Vector3.RIGHT)
	_ink.stroke(ridge_a + Vector3.UP * 0.025, ridge_b + Vector3.UP * 0.025,
			0.14, roof.lightened(0.19))
	_ink.block(Vector3(x + width * 0.24, ridge - 0.12, z - depth * 0.30),
			Vector3(0.42, 0.81, 0.42), Color("#535458"))
	_ink.block(Vector3(x + width * 0.24, ridge + 0.30, z - depth * 0.30),
			Vector3(0.5, 0.13, 0.48), CLIFF.lightened(0.05))


func _window(x: float, y: float, z: float) -> void:
	_ink.block(Vector3(x, y, z), Vector3(0.38, 0.46, 0.096), DARK_WOOD)
	_ink.block(Vector3(x, y, z + 0.041), Vector3(0.24, 0.30, 0.06), Color("#8d754a"))
	_ink.block(Vector3(x, y, z + 0.075), Vector3(0.035, 0.34, 0.026), DARK_WOOD)
	_ink.block(Vector3(x, y - 0.21, z + 0.067), Vector3(0.45, 0.066, 0.17), WOOD)


func _scenery() -> void:
	for item in [[-12.4, 6.1, 0.24, 1.13], [-13.1, 5.4, 0.09, 0.57], [-11.4, -0.2, GROUND, 1.04],
			[-11.8, 1.1, GROUND, 0.51], [-13.9, -4.55, 0.15, 0.94], [-15.05, -3.45, 0.06, 1.20],
			[-14.2, -1.73, 0.15, 0.67], [3.9, 7.8, GROUND, 0.64], [5.35, 9.1, 0.08, 0.81],
			[9.25, 11.8, 0.10, 1.0], [11.2, 11.45, 0.15, 0.44], [7.8, 5.38, HEIGHT, 0.70],
			[13.55, 0.12, HEIGHT, 0.71], [2.75, -10.9, GROUND, 0.88], [-9.3, 0.6, GROUND, 0.51]]:
		_rock(item[0], item[2], item[1], item[3])
	for patch in [[-10.0, -4.2, GROUND, 1.86], [-11.0, -5.4, GROUND, 1.36],
			[-4.3, -9.4, GROUND, 1.52], [-7.6, -10.1, GROUND, 2.14], [11.5, -8.5, HEIGHT, 1.76],
			[13.0, -8.3, HEIGHT, 1.47], [12.0, -0.7, HEIGHT, 1.56], [13.1, 4.95, GROUND, 1.56]]:
		_tree(patch[0], patch[2], patch[1], patch[3])
	for patch in [[-10.3, 1.75, GROUND, 1.2], [-7.4, -1.72, GROUND, 1.6],
			[-8.7, 2.5, GROUND, 1.0], [-3.72, 4.7, GROUND, 1.2],
			[0.6, 6.0, GROUND, 1.78], [4.2, 4.85, GROUND, 1.1],
			[7.1, 8.6, GROUND, 0.92], [9.7, 9.13, GROUND, 1.1],
			[13.4, 7.64, GROUND, 0.73], [9.0, 3.95, HEIGHT, 1.2],
			[11.0, 4.4, HEIGHT, 0.89], [-4.4, -6.55, GROUND, 1.17],
			[-8.4, -3.18, GROUND, 0.73], [13.0, -5.0, HEIGHT, 0.85]]:
		_reeds(patch[0], patch[2], patch[1], patch[3])
	_crate(-6.65, GROUND, -4.35, 0.58)
	_crate(12.8, HEIGHT, -4.2, 0.56)


func _rock(x: float, y: float, z: float, scale: float) -> void:
	var footprint := PackedVector2Array()
	var crown := PackedVector2Array()
	for i in 7:
		var angle := TAU * i / 7.0
		var ray := Vector2(cos(angle), sin(angle) * 0.71) * scale * _rng.randf_range(0.60, 1.0)
		footprint.append(Vector2(x, z) + ray)
		crown.append(Vector2(x - 0.18 * scale, z - 0.09 * scale) + ray * 0.70)
	var top := y + scale * _rng.randf_range(0.33, 0.57)
	var base := maxf(y - scale * 0.27, 0.023)
	for i in footprint.size():
		var j := (i + 1) % footprint.size()
		_ink.quad(Ink.point(footprint[i], base), Ink.point(footprint[j], base),
				Ink.point(crown[j], top), Ink.point(crown[i], top),
				CLIFF.darkened(_rng.randf_range(0.12, 0.47)))
	_ink.sheet(crown, top, CLIFF.lightened(0.15))
	_ink.ribbon(crown, Ink.inset(crown, minf(0.052, scale * 0.1)), top + 0.003, Ink.INK)
	_ink.stroke(Ink.point(crown[5], top + 0.005), Ink.point(crown[2].lerp(crown[0], 0.48), top + 0.005),
			0.075 * scale, CLIFF.darkened(0.30))


func _tree(x: float, y: float, z: float, height: float) -> void:
	_shadow(x - 0.42, y + 0.008, z + 0.42, height * 1.44, height * 0.86)
	_ink.block(Vector3(x, y + height * 0.24, z), Vector3(0.21, height * 0.52, 0.20), DARK_WOOD)
	for layer in 3:
		var h := height * (0.43 + layer * 0.28)
		var size := height * (0.43 - layer * 0.081)
		var top := Vector3(x + height * 0.17, y + h + height * 0.63, z - 0.06)
		var center := Vector3(x + layer * 0.087, y + h, z)
		var tips := PackedVector3Array()
		for i in 12:
			var angle := TAU * (i + layer * 0.24) / 12.0
			var reach := size * _rng.randf_range(0.88, 1.15)
			var lift := -0.16 * height
			if i % 2 == 1:
				reach *= 0.66
				lift *= 0.52
			tips.append(center + Vector3(cos(angle) * reach, lift, sin(angle) * reach))
		for i in tips.size():
			var a := tips[i]
			var b := tips[(i + 1) % tips.size()]
			var low_tint := 0.08 + 0.07 * sin(i * 0.54)
			var leaf := Color("#344b46").lightened(low_tint - (0.02 if i % 2 == 0 else 0.0))
			var shoulder_a := a.lerp(top, 0.13)
			var shoulder_b := b.lerp(top, 0.13)
			_ink.triangle(shoulder_a, shoulder_b, top, leaf)
			_ink.quad(a, b, shoulder_b, shoulder_a, leaf.darkened(0.43))


func _reeds(x: float, y: float, z: float, radius: float) -> void:
	for i in int(7.0 * radius):
		var at := Vector3(x + _rng.randf_range(-radius, radius), y + 0.021,
				z + _rng.randf_range(-radius * 0.48, radius * 0.48))
		var h := _rng.randf_range(0.12, 0.31)
		var tint := Color("#303e39").lightened(_rng.randf() * 0.10)
		_flat_chip(at.x - 0.13, y + 0.022, at.z + 0.15, h * 0.9, h * 0.27, Color("#393f38"))
		for blade in 4:
			var off := (blade - 1.5) * 0.068
			var base := at + Vector3(off, 0.0, _rng.randf_range(-0.033, 0.033))
			_ink.triangle(base, base + Vector3(0.045, 0.0, 0.015),
					base + Vector3(off * 0.94 + 0.075, h * _rng.randf_range(0.55, 1.3), -0.025), tint)


func _crate(x: float, y: float, z: float, size: float) -> void:
	_shadow(x - 0.10, y + 0.025, z + 0.17, size * 1.5, size)
	_ink.block(Vector3(x, y + size * 0.5, z), Vector3.ONE * size, DARK_WOOD)
	for i in 4:
		var step := (i + 0.5) * size / 4.0
		_ink.block(Vector3(x, y + step, z + size * 0.5), Vector3(size * 0.9, size * 0.21, 0.032), WOOD)
	_ink.stroke(Vector3(x - size * 0.43, y + 0.08, z + size * 0.5 + 0.02),
			Vector3(x + size * 0.46, y + size * 0.89, z + size * 0.5 + 0.02), 0.11, DARK_WOOD, Vector3.BACK)


func _shadow(x: float, y: float, z: float, width: float, depth: float) -> void:
	_flat_chip(x, y, z, width * 0.5, depth * 0.5, Color("#303933"))


func _flat_chip(x: float, y: float, z: float, width: float, depth: float, tint: Color) -> void:
	_ink.sheet(_ring([[x - width, z + depth * 0.23], [x - width * 0.62, z - depth * 0.66],
		[x + width * 0.36, z - depth], [x + width, z - depth * 0.30],
		[x + width * 0.76, z + depth * 0.62], [x - width * 0.27, z + depth]]), y, tint)


static func _ring(coords: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for xy in coords:
		points.append(Vector2(xy[0], xy[1]))
	return points


static func _front(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)
