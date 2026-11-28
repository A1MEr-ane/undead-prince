extends RefCounted
## A single opaque batch for the painted faces and ink marks of the set.

const INK := Color("#151d26")

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()


func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	_vertices.append(a)
	_vertices.append(b)
	_vertices.append(c)
	for i in 3:
		_normals.append(normal)
		_colors.append(color)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	triangle(a, b, c, color)
	triangle(a, c, d, color)


func sheet(outline: PackedVector2Array, y: float, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(outline)
	assert(not indices.is_empty(), "The set piece needs a simple polygon.")
	for i in range(0, indices.size(), 3):
		triangle(point(outline[indices[i]], y), point(outline[indices[i + 1]], y),
				point(outline[indices[i + 2]], y), color)


func ribbon(outline: PackedVector2Array, inner: PackedVector2Array, y: float, color: Color) -> void:
	for i in outline.size():
		var j := (i + 1) % outline.size()
		quad(point(outline[i], y), point(outline[j], y), point(inner[j], y),
				point(inner[i], y), color)


func stroke(from: Vector3, to: Vector3, width: float, color: Color, normal := Vector3.UP) -> void:
	var side := (to - from).normalized().cross(normal) * width
	quad(from - side * 0.56, from + side * 0.44, to + side * 0.18, to - side * 0.30, color)


func block(center: Vector3, size: Vector3, color: Color, bevel := 0.045) -> void:
	var half := size * 0.5
	var b := minf(bevel, minf(half.x, half.z) * 0.4)
	var ring := PackedVector2Array([
		Vector2(-half.x + b, -half.z), Vector2(half.x - b, -half.z),
		Vector2(half.x, -half.z + b), Vector2(half.x, half.z - b),
		Vector2(half.x - b, half.z), Vector2(-half.x + b, half.z),
		Vector2(-half.x, half.z - b), Vector2(-half.x, -half.z + b),
	])
	var top := center.y + half.y
	var bottom := center.y - half.y
	for i in ring.size():
		ring[i] += Vector2(center.x, center.z)
	sheet(ring, top, color.lightened(0.12))
	var side_tints := [0.23, 0.16, 0.19, 0.12, 0.29, 0.34, 0.25, 0.22]
	for i in ring.size():
		var j := (i + 1) % ring.size()
		var a := ring[i]
		var end := ring[j]
		quad(point(a, bottom), point(end, bottom), point(end, top), point(a, top),
				color.darkened(side_tints[i]))


func instance(parent: Node3D, node_name: String, material: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var result := MeshInstance3D.new()
	result.name = node_name
	result.mesh = mesh
	result.material_override = material
	parent.add_child(result)
	return result


static func point(value: Vector2, y: float) -> Vector3:
	return Vector3(value.x, y, value.y)


static func inset(ring: PackedVector2Array, width: float) -> PackedVector2Array:
	var winding := 1.0 if Geometry2D.is_polygon_clockwise(ring) else -1.0
	var edge := PackedVector2Array()
	for i in ring.size():
		var previous := (ring[i] - ring[posmod(i - 1, ring.size())]).normalized().orthogonal()
		var next := (ring[(i + 1) % ring.size()] - ring[i]).normalized().orthogonal()
		var bisector := (previous + next).normalized()
		edge.append(ring[i] + bisector * width * winding / maxf(bisector.dot(next), 0.42))
	return edge
