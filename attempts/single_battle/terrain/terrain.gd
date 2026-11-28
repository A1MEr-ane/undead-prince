extends Node3D
## Terrain presentation for the siege simulation. The simulation owns all passability state.

const Ground := preload("res://attempts/single_battle/terrain/ground.gd")
const Kit := preload("res://attempts/single_battle/terrain/kit.gd")
const PAINT := preload("res://attempts/single_battle/terrain/paint.gdshader")
const TIDE := preload("res://attempts/single_battle/terrain/tide.gdshader")
const DATA := "res://attempts/single_battle/terrain/grey_tide.json"
const ZONES := ["coast", "highland", "plaza", "keep"]

var _layout := load_layout()
var _ground := Ground.new(_layout)
var _paint := ShaderMaterial.new()
var _tide := ShaderMaterial.new()
var _structures := {}
var _boat: Node3D
var _mooring: Vector3
var _time := 0.0
var _tide_clock := 0.0


static func load_layout() -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(DATA))
	assert(error == OK, "Invalid Grey Tide layout: " + parser.get_error_message())
	return parser.data


func _ready() -> void:
	_paint.shader = PAINT
	_tide.shader = TIDE
	_ground.build(self, _paint)
	var kit := Kit.new(_ground, _paint)
	kit.build_static(self)
	_structures.gate = kit.build_structure(self, "gate", _layout.map.gate_rect, "gate")
	_structures.weak_wall = kit.build_structure(self, "weak_wall", _layout.map.weak_rect, "wall")
	for wall: Dictionary in _layout.phase_b.breakable_walls:
		_structures[wall.id] = kit.build_structure(self, wall.id, wall.rect, "wall")
	var boat_cell: Array = _layout.map.boat
	_mooring = Vector3(boat_cell[0] + 1.55, 0, boat_cell[1] + 0.50)
	_boat = kit.build_boat(self, _mooring)
	_add_sea()
	set_time(_time)


func _process(delta: float) -> void:
	_tide_clock = fmod(_tide_clock + delta, 600.0)
	_tide.set_shader_parameter("clock", _tide_clock)


func height_at(point: Vector3) -> float:
	return _ground.height_at(Vector2(point.x, point.z))


func apply_camera(camera: Camera3D, zone_id: String) -> bool:
	if not _layout.cameras.has(zone_id):
		return false
	var view: Dictionary = _layout.cameras[zone_id]
	var local_focus := Vector3(view.focus[0], view.focus[1], view.focus[2])
	var pitch := deg_to_rad(view.pitch)
	var yaw := deg_to_rad(view.yaw)
	var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = view.size
	camera.far = 155.0
	camera.look_at_from_position(to_global(local_focus + direction * 75.0), to_global(local_focus))
	return true


func set_structure_state(structure_id: String, state: String) -> bool:
	if not _structures.has(structure_id):
		return false
	var meshes: Dictionary = _structures[structure_id]
	if not meshes.has(state):
		return false
	for key: String in meshes:
		meshes[key].visible = key == state
	return true


func set_boat_progress(progress: float) -> void:
	_boat.position = _mooring + Vector3.RIGHT * 10.0 * clampf(progress, 0.0, 1.0)


func set_time(elapsed_fraction: float) -> void:
	_time = clampf(elapsed_fraction, 0, 1)
	if _paint.shader == null:
		return
	var midnight := smoothstep(0.0, 0.34, _time)
	var dawn := smoothstep(0.42, 1.0, _time)
	var exposure := Vector3(0.47, 0.59, 0.75).lerp(Vector3(0.38, 0.50, 0.66), midnight)
	exposure = exposure.lerp(Vector3(1.04, 1.09, 1.08), dawn)
	_paint.set_shader_parameter("dawn", dawn)
	_paint.set_shader_parameter("exposure", exposure)
	_paint.set_shader_parameter("air", Vector3(0.021, 0.037, 0.057).lerp(Vector3(0.073, 0.080, 0.080), dawn))
	_tide.set_shader_parameter("dawn", dawn)
	_tide.set_shader_parameter("water", Color("#132837").lerp(Color("#4e6773"), dawn))
	_tide.set_shader_parameter("headland", Color("#233648").lerp(Color("#879797"), dawn))
	_tide.set_shader_parameter("horizon", Color("#3e4b60").lerp(Color("#d8cdb9"), dawn))
	_tide.set_shader_parameter("shallows", Color("#283a42").lerp(Color("#657d77"), dawn))
	_tide.set_shader_parameter("froth", Color("#617e83").lerp(Color("#bec8b6"), dawn))


func _add_sea() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(250, 250)
	var sea := MeshInstance3D.new()
	sea.name = "Tide and surf"
	sea.position = Vector3(28, 0, 24)
	sea.mesh = mesh
	sea.material_override = _tide
	add_child(sea)
	_tide.set_shader_parameter("shore_field", _ground.shore_field())
	_tide.set_shader_parameter("shore_origin", Ground.SHORE_ORIGIN)
	_tide.set_shader_parameter("shore_size", Ground.SHORE_SIZE)
	_tide.set_shader_parameter("shore_reach", Ground.SHORE_REACH)
