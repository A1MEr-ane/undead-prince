extends RefCounted
## World-space mesh for the coastline, grade changes and road markings.

const Ink := preload("res://attempts/single_battle/style_frame/ink_mesh.gd")
const GRASS := Color("#565d4e")
const SAND := Color("#71695b")
const STONE := Color("#50616a")
const ROAD := Color("#767061")
const SHORE_ORIGIN := Vector2(-2.0, -2.0)
const SHORE_SIZE := Vector2(60.0, 53.0)
const SHORE_REACH := 3.4
const COAST := [
	[3.55,36.1],[5.7,35.55],[7.76,35.66],[7.6,33.72],[7.81,31.69],[7.68,29.36],
	[5.7,29.56],[3.66,29.42],[3.20,26.3],[3.59,23.64],[3.44,20.98],[3.72,18.64],
	[5.51,18.1],[8.12,18.25],[10.42,17.96],[13.36,18.16],[14.45,18.66],
	[14.69,15.87],[14.53,13.83],[17.35,13.57],[20.22,13.78],[22.15,13.45],
	[24.61,13.56],[24.48,10.95],[24.62,7.54],[24.21,4.04],[26.17,3.51],
	[29.88,3.14],[33.92,3.40],[37.17,3.20],[40.65,3.97],[40.73,6.76],
	[40.48,9.98],[40.64,13.63],[43.12,13.53],[46.44,13.75],[48.32,13.81],
	[48.56,15.66],[48.44,17.90],[50.21,17.96],[50.50,19.2],[50.27,21.22],
	[48.42,21.37],[48.50,23.62],[48.40,26.14],[48.29,29.10],
	[46.06,29.35],[43.88,29.58],[40.29,29.41],[37.93,30.06],[35.97,29.72],
	[34.06,30.14],[33.46,31.35],[33.81,32.69],[34.04,33.58],[35.78,34.73],
	[36.97,35.43],[38.52,35.69],[40.36,35.12],[42.39,35.48],[44.61,34.94],[45.72,35.46],
	[47.77,35.60],[50.11,35.48],[52.25,36.02],[52.49,38.37],[52.26,40.15],
	[52.65,42.53],[52.21,44.54],[51.60,45.88],[49.71,46.34],[47.4,46.44],
	[44.8,46.15],[41.97,46.32],[40.23,46.53],[37.41,46.37],[34.4,46.06],
	[31.64,46.26],[28.23,46.47],[25.86,46.22],[22.74,46.41],[19.87,46.25],
	[16.47,46.04],[13.14,46.35],[10.44,46.30],[7.89,46.16],[5.21,46.35],
	[3.54,45.56],[3.18,43.10],[3.48,40.43],[3.13,38.39]
]
const LAGOON := [
	[12.40,35.70],[12.47,34.12],[12.58,32.4],[12.39,30.85],[12.50,29.37],
	[14.36,29.54],[15.68,28.94],[17.34,28.55],[19.58,28.83],[21.99,28.63],
	[24.14,29.41],[25.00,30.29],[25.55,31.39],[25.23,33.0],[24.29,34.50],[23.44,34.56],
	[21.85,35.41],[20.12,35.75],[17.92,35.27],[16.43,35.46],[14.28,35.82]
]
const ROADS := [
	{"width":2.75, "path":[[24.8,45.7],[26.3,43.7],[28.4,41.1],[29.1,37.6],[29.35,35.4],
		[29.5,30.4],[29.03,27.45],[29.8,24.3],[31.5,20.5],[32.05,17.65],[33.05,13.5],[32.5,9.5]]},
	{"width":1.32, "path":[[15.1,44.95],[12.2,42.9],[10.25,39.0],[9.65,35.7],[9.7,32.15],
		[9.94,29.08],[9.62,26.55],[10.7,24.65],[13.3,24.45],[15.2,24.5],[16.6,24.25],[17.7,23.35],
		[20.6,22.85],[24.9,21.35],[31.5,20.5]]},
	{"width":1.8, "path":[[31.5,20.5],[35.6,20.86],[40.45,20.47],[43.4,19.5],[46.5,19.5],[50.98,19.5]]},
	{"width":1.0, "path":[[32.7,42.75],[36.6,42.2],[40.0,40.9],[43.3,39.15],[45.5,37.5]]},
	{"width":1.0, "path":[[21.5,20.5],[23.6,20.3],[27.9,20.55],[31.5,20.5]]}
]

var _ink := Ink.new()
var _rng := RandomNumberGenerator.new()
var _surfaces: Array[Dictionary] = []
var _base: float
var _shorelines: Array[PackedVector2Array] = []


func _init(layout: Dictionary) -> void:
	_base = float(layout.map.base_height)
	for surface: Dictionary in layout.surfaces:
		var region := surface.duplicate()
		region.rim = ring(surface.rim)
		_surfaces.append(region)
	_rng.seed = 85101


func build(parent: Node3D, material: ShaderMaterial) -> void:
	var edge := ring(COAST)
	var lagoon := ring(LAGOON)
	_shorelines = [Ink.inset(edge, -0.48), Ink.inset(lagoon, 0.25)]
	_island_cap(edge, lagoon)
	_tidal_edge(edge, -1.0, _shorelines[0])
	_tidal_edge(lagoon, 1.0, _shorelines[1])
	_landing_sand()
	for region in _surfaces:
		_terrace(region)
	_brushwork(edge, lagoon)
	_plaza()
	for i in ROADS.size():
		var road: Dictionary = ROADS[i]
		_road(ring(road.path), road.width, 0.022 + i * 0.012)
	_ink.instance(parent, "Coast, slopes and roads", material)


func height_at(xz: Vector2) -> float:
	for region in _surfaces:
		if Geometry2D.is_point_in_polygon(xz, region.rim):
			return _grade(region, xz)
	return _base


func shore_field() -> ImageTexture:
	var image := Image.create_empty(226, 200, false, Image.FORMAT_R8)
	var dims := Vector2(image.get_size())
	image.fill(Color.WHITE)
	for shore in _shorelines:
		_trace_shore(image, dims, shore)
	return ImageTexture.create_from_image(image)


func _trace_shore(image: Image, dims: Vector2, shore: PackedVector2Array) -> void:
	for i in shore.size():
		var a := shore[i]
		var b := shore[(i + 1) % shore.size()]
		var span := Vector2.ONE * SHORE_REACH
		var low := Vector2i(((a.min(b) - span - SHORE_ORIGIN) / SHORE_SIZE * dims).floor()).max(Vector2i.ZERO)
		var high := Vector2i(((a.max(b) + span - SHORE_ORIGIN) / SHORE_SIZE * dims).ceil()).min(image.get_size())
		for z in range(low.y, high.y):
			for x in range(low.x, high.x):
				var p := SHORE_ORIGIN + (Vector2(x, z) + Vector2(0.5, 0.5)) / dims * SHORE_SIZE
				var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
				var distance := p.distance_to(closest) / SHORE_REACH
				if distance < image.get_pixel(x, z).r:
					image.set_pixel(x, z, Color(distance, 0, 0))


func _island_cap(edge: PackedVector2Array, lagoon: PackedVector2Array) -> void:
	# Cut through the lagoon first so all the resulting land polygons have simple outlines.
	var left := ring([[-90,-90],[19,-90],[19,90],[-90,90]])
	var right := ring([[19,-90],[90,-90],[90,90],[19,90]])
	for half in [left, right]:
		for coast in Geometry2D.intersect_polygons(edge, half):
			for cap in Geometry2D.clip_polygons(coast, lagoon):
				_ink.sheet(cap, _base, GRASS)


func _tidal_edge(edge: PackedVector2Array, direction: float, shoreline: PackedVector2Array) -> void:
	var shoulder := Ink.inset(edge, direction * 0.14)
	var seabed := Ink.inset(edge, direction * 0.72)
	var wave_height := 0.012
	for i in edge.size():
		var j := (i + 1) % edge.size()
		var a := Ink.point(edge[i], _base)
		var b := Ink.point(edge[j], _base)
		var toe_a := shoulder[i].lerp(shoreline[i], 0.17 + 0.17 * sin(i * 2.9))
		var toe_b := shoulder[j].lerp(shoreline[j], 0.17 + 0.17 * sin(j * 2.9))
		var shelf_a := Ink.point(toe_a, 0.15 + 0.055 * sin(i * 1.68))
		var shelf_b := Ink.point(toe_b, 0.15 + 0.055 * sin(j * 1.68))
		var tide_a := Ink.point(shoreline[i], wave_height)
		var tide_b := Ink.point(shoreline[j], wave_height)
		var tint := SAND.lerp(STONE, 0.34 + 0.31 * sin(i * 0.71))
		_ink.quad(a, b, shelf_b, shelf_a, GRASS.lerp(tint, _rng.randf_range(0.61, 0.92)))
		_ink.quad(shelf_a, shelf_b, tide_b, tide_a, tint.darkened(0.13))
		_ink.quad(tide_a, tide_b, Ink.point(seabed[j], -0.20),
				Ink.point(seabed[i], -0.20), tint.darkened(0.25))
		if i % 4 == 0:
			_ink.stroke(a.lerp(b, 0.12) + Vector3.UP * 0.004,
					a.lerp(b, 0.85) + Vector3.UP * 0.004, 0.030, tint.darkened(0.30))


func _landing_sand() -> void:
	_ink.sheet(ring([[4.4,42.8],[7.8,42.2],[11.7,43.4],[17.0,42.9],[21.6,44.0],
		[26.4,43.35],[31.8,43.9],[36.4,42.65],[40.9,43.45],[45.0,42.2],[47.1,40.6],[51.9,41.2],
		[51.55,44.8],[50.0,46.09],[45.7,45.99],[40.3,46.24],[36.9,46.18],[31.64,46.05],
		[28.23,46.30],[22.74,46.24],[17.2,45.85],[13.14,46.2],[7.9,45.98],[5.3,46.18],[3.75,45.42]]),
		_base + 0.005, SAND)


func _terrace(region: Dictionary) -> void:
	var rim: PackedVector2Array = region.rim
	var h := PackedFloat32Array()
	var mid := PackedVector2Array()
	var foot := Ink.inset(rim, -0.21)
	for i in rim.size():
		h.append(_grade(region, rim[i]))
		mid.append(rim[i].lerp(foot[i], _rng.randf_range(0.23, 0.75)))
	var indices := Geometry2D.triangulate_polygon(rim)
	assert(not indices.is_empty(), "Invalid terrain polygon: " + region.id)
	var grass := GRASS.lightened(0.06 if region.id.begins_with("keep") else 0.035)
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		_ink.triangle(Ink.point(rim[a], h[a]), Ink.point(rim[b], h[b]), Ink.point(rim[c], h[c]), grass)
	for i in rim.size():
		var j := (i + 1) % rim.size()
		if h[i] <= _base and h[j] <= _base:
			continue
		var midpoint := (rim[i] + rim[j]) * 0.5
		var outward := ((foot[i] + foot[j]) * 0.5 - midpoint).normalized()
		var outside := height_at(midpoint + outward * 0.04)
		if outside >= (h[i] + h[j]) * 0.5 - 0.06:
			continue
		var a := Ink.point(rim[i], h[i])
		var b := Ink.point(rim[j], h[j])
		var a_mid := Ink.point(mid[i], lerpf(_base, h[i], 0.47 + 0.10 * sin(i * 1.5)))
		var b_mid := Ink.point(mid[j], lerpf(_base, h[j], 0.47 + 0.10 * sin(j * 1.5)))
		var tint := STONE.darkened(_rng.randf_range(0.03, 0.20))
		_ink.quad(a, b, b_mid, a_mid, tint)
		_ink.quad(a_mid, b_mid, Ink.point(foot[j], 0.02), Ink.point(foot[i], 0.02), tint.darkened(0.23))
		_ink.triangle(a.lerp(b, 0.17), a.lerp(b, 0.63), a_mid.lerp(b_mid, 0.40), tint.lightened(0.12))
		_ink.stroke(a.lerp(a_mid, 0.73), b.lerp(b_mid, 0.72), 0.048, tint.darkened(0.24),
				Vector3(outward.x, 0, outward.y))
		_ink.stroke(a + Vector3.UP * 0.004, b + Vector3.UP * 0.004, 0.035, grass.darkened(0.46))


func _grade(region: Dictionary, xz: Vector2) -> float:
	if not region.has("grade"):
		return float(region.height)
	var grade: Dictionary = region.grade
	var coordinate := xz.x if grade.axis == "x" else xz.y
	var t := inverse_lerp(float(grade.from[0]), float(grade.to[0]), coordinate)
	return lerpf(float(grade.from[1]), float(grade.to[1]), clampf(t, 0.0, 1.0))


func _brushwork(edge: PackedVector2Array, lagoon: PackedVector2Array) -> void:
	for i in 560:
		var p := Vector2(_rng.randf_range(3.6, 52.2), _rng.randf_range(4.0, 46.0))
		var width := _rng.randf_range(0.16, 1.20)
		var depth := _rng.randf_range(0.12, 0.48)
		var q := p + Vector2(width, depth)
		if not Geometry2D.is_point_in_polygon(p, edge) or not Geometry2D.is_point_in_polygon(q, edge):
			continue
		if Geometry2D.is_point_in_polygon(p, lagoon) or Geometry2D.is_point_in_polygon(q, lagoon):
			continue
		var height := height_at(p)
		if absf(height - height_at(q)) > 0.15:
			continue
		var color := GRASS.lerp(SAND, 0.31 + 0.22 * sin(i * 1.15))
		if i % 3 == 0:
			color = color.darkened(0.15)
		var offset := 0.008 if p.y > 43.0 else 0.004
		_ink.quad(_lift(p, offset), _lift(p + Vector2(width * 0.64, -0.04), offset),
				_lift(q, offset), _lift(p + Vector2(width * 0.22, depth * 0.84), offset), color)


func _plaza() -> void:
	var rim := ring([[25.8,18.08],[29.4,17.4],[34.94,17.6],[36.4,19.0],[36.18,21.54],
		[35.1,23.7],[31.2,24.25],[27.5,23.74],[25.1,22.19],[24.9,19.6]])
	_ink.sheet(rim, _base + 0.009, Color("#64635c"))
	var inset := Ink.inset(rim, 0.35)
	for i in 170:
		var p := Vector2(_rng.randf_range(25.2, 36.0), _rng.randf_range(17.8, 24.0))
		if Geometry2D.is_point_in_polygon(p, inset):
			var y := _base + 0.013
			var width := _rng.randf_range(0.20, 0.64)
			var depth := _rng.randf_range(0.11, 0.38)
			var color := Color("#757469").darkened(_rng.randf_range(0.0, 0.22))
			_ink.quad(Ink.point(p, y), Ink.point(p + Vector2(width, 0.03), y),
					Ink.point(p + Vector2(width * 0.84, depth), y), Ink.point(p + Vector2(0.04, depth), y), color)


func _road(points: PackedVector2Array, width: float, height: float) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in points.size():
		var normal := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized().orthogonal()
		left.append(points[i] + normal * width * (0.55 + 0.043 * sin(i * 2.8)))
		right.append(points[i] - normal * width * (0.49 + 0.037 * cos(i * 1.6)))
	for i in range(1, points.size()):
		var steps := ceili(points[i - 1].distance_to(points[i]) * 4.0)
		for step in steps:
			var t0 := float(step) / steps
			var t1 := float(step + 1) / steps
			var a := left[i - 1].lerp(left[i], t0)
			var b := right[i - 1].lerp(right[i], t0)
			var c := right[i - 1].lerp(right[i], t1)
			var d := left[i - 1].lerp(left[i], t1)
			var la := a.lerp(b, 0.12)
			var lb := a.lerp(b, 0.88)
			var lc := d.lerp(c, 0.88)
			var ld := d.lerp(c, 0.12)
			_ink.quad(_lift(a, height), _lift(la, height), _lift(ld, height), _lift(d, height), ROAD.darkened(0.18))
			_ink.quad(_lift(la, height), _lift(lb, height), _lift(lc, height), _lift(ld, height), ROAD)
			_ink.quad(_lift(lb, height), _lift(b, height), _lift(c, height), _lift(lc, height), ROAD.darkened(0.16))
			if step % 4 != 3 and width >= 2:
				for t: float in [0.28, 0.72]:
					_ink.stroke(_lift(a.lerp(b, t), height + 0.005), _lift(d.lerp(c, t), height + 0.005), 0.038, ROAD.darkened(0.25))


func _lift(p: Vector2, offset := 0.021) -> Vector3:
	return Ink.point(p, height_at(p) + offset)


static func ring(coords: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in coords:
		result.append(Vector2(float(p[0]), float(p[1])))
	return result
