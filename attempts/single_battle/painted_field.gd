extends Node3D
## 灰盒沿用原型的通行格，使用样张的地面与海面材质。
const Ink = preload("res://attempts/single_battle/style_frame/ink_mesh.gd")
const INK_SHADER = preload("res://attempts/single_battle/style_frame/ink.gdshader")
const SEA_SHADER = preload("res://attempts/single_battle/style_frame/sea.gdshader")
const SHORE_REACH := 3.0

var world
var ink := ShaderMaterial.new()
var sea := ShaderMaterial.new()
var imported: Node3D
var structures := {}
var banners := {}
var ship: Node3D
var ship_origin := Vector3.ZERO
var last_topology := {}
var sprite_light := Color.WHITE

func setup(main) -> void:
	world = main
	ink.shader = INK_SHADER
	sea.shader = SEA_SHADER
	var scene_path: String = world.params.view.get("terrain_scene", "")
	if not scene_path.is_empty():
		var packed := load(scene_path) as PackedScene
		imported = packed.instantiate() as Node3D
		add_child(imported)
		if imported.has_method("set_battle_state"):
			return
	build_fallback()

func build_fallback() -> void:
	var map = world.terrain
	var cfg: Dictionary = world.params.map
	build_water()
	var land := Ink.new()
	var paths := Ink.new()
	for z in map.depth:
		for x in map.width:
			var t := Vector2i(x, z)
			if map.land[map.index(t)] == 0:
				continue
			var p := Vector3(x + 0.5, 0, z + 0.5)
			var y: float = map.height_at(p)
			var variation := 0.035 * sin(x * 1.81 + z * 0.713)
			var color := Color("#636853")
			if map.in_rect(p, cfg.highland_rect):
				color = Color("#555f58")
			elif map.in_rect(p, cfg.keep_rect):
				color = Color("#79736a")
			elif z >= 40:
				color = Color("#72695a")
			land.quad(Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1), color.lightened(variation))
			for direction in map.DIRS:
				var q: Vector2i = t + direction
				var valid: bool = q.x >= 0 and q.y >= 0 and q.x < map.width and q.y < map.depth
				var neighbor_height := -0.36
				if valid and map.land[map.index(q)] != 0:
					neighbor_height = map.height_at(p + Vector3(direction.x, 0, direction.y))
				if neighbor_height >= y:
					continue
				var edge := p + Vector3(direction.x, 0, direction.y) * 0.5
				edge.y = y
				var side := Vector3(direction.y, 0, -direction.x) * 0.5
				var drop := Vector3.DOWN * (y - neighbor_height)
				land.quad(edge - side, edge + side, edge + side + drop, edge - side + drop, color.darkened(0.23 + variation))
			if map.in_rect(p, cfg.deploy_rect):
				land.quad(Vector3(x + 0.025, y + 0.01, z + 0.025), Vector3(x + 0.975, y + 0.01, z + 0.025),
					Vector3(x + 0.975, y + 0.01, z + 0.975), Vector3(x + 0.025, y + 0.01, z + 0.975), color.lerp(Color("#527266"), 0.6))
	for route in cfg.routes:
		var points: Array = cfg.routes[route]
		for i in range(1, points.size()):
			var from: Vector3 = map.vec(points[i - 1])
			var to: Vector3 = map.vec(points[i])
			var length := ceili(from.distance_to(to) * 2.0)
			for n in length:
				var p := from.lerp(to, float(n) / maxf(1.0, length))
				if map.is_walkable_at(p):
					p.y = map.height_at(p) + 0.014
					paths.stroke(p, p.move_toward(to + Vector3.UP * p.y, 0.6), 0.72, Color("#938473"))
	land.instance(self, "海岸与坡地", ink)
	paths.instance(self, "道路", ink)
	for id in ["gate", "weak"]:
		var rect: Array = cfg.gate_rect if id == "gate" else cfg.weak_rect
		structures[id] = wall(rect, Color("#665347") if id == "gate" else Color("#776c62"), id)
	for id in world.phase_b.walls:
		structures[id] = wall(world.phase_b.walls[id].rect, Color("#75716b"), id)
	var wall_body := Ink.new()
	for rect in cfg.wall_rects:
		for t in map.rect_cells(rect):
			var p := Vector3(t.x + 0.5, 0, t.y + 0.5)
			if not map.land[map.index(t)] or structures_at(p):
				continue
			p.y = map.height_at(p) + 0.85
			wall_body.block(p, Vector3(1, 1.7, 1), Color("#6d6b67"))
			wall_body.block(p + Vector3.UP * 0.87, Vector3(0.9, 0.17, 1.06), Color("#9a9080"))
	wall_body.instance(self, "完整城墙", ink)
	var props := Ink.new()
	for z in cfg.zones:
		var p: Vector3 = world.zone_point(z.id)
		p.y = map.height_at(p)
		props.block(p + Vector3.UP * 0.94, Vector3(0.09, 1.88, 0.09), Color("#9b8970"))
		var node := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.96, 0.50)
		node.mesh = mesh
		node.material_override = solid(Color("#bc9873"))
		node.position = p + Vector3(0.46, 1.61, 0)
		banners[z.id] = node
		add_child(node)
	for key in ["port", "cave_a", "cave_b"]:
		if key != "port" and not cfg.cave_enabled:
			continue
		var p: Vector3 = map.vec(cfg[key])
		p.y = map.height_at(p)
		if key == "port":
			props.block(p + Vector3(1.45, -0.04, 0), Vector3(3.68, 0.19, 2.2), Color("#776553"))
		else:
			props.block(p + Vector3(0.49, 0.31, 0), Vector3(0.35, 0.62, 0.74), Color("#232b31"))
	props.instance(self, "旗杆与码头", ink)
	ship = Node3D.new()
	ship_origin = map.vec(cfg.boat)
	ship.position = ship_origin
	add_child(ship)
	var hull := Ink.new()
	hull.block(Vector3(0, 0.12, 0), Vector3(1.24, 0.44, 3.05), Color("#635149"), 0.42)
	hull.block(Vector3(0, 0.97, 0), Vector3(0.095, 1.60, 0.095), Color("#917d63"))
	hull.quad(Vector3(0, 0.66, -0.95), Vector3(0, 0.63, 0.87),
		Vector3(0, 1.57, 0.50), Vector3(0, 1.65, -0.28), Color("#9e9985"))
	hull.instance(ship, "撤离船", ink)

func structures_at(p: Vector3) -> bool:
	var map = world.terrain
	var cfg: Dictionary = world.params.map
	if map.in_rect(p, cfg.gate_rect) or map.in_rect(p, cfg.weak_rect):
		return true
	for info in world.phase_b.walls.values():
		if map.in_rect(p, info.rect):
			return true
	return false

func wall(rect: Array, color: Color, id: String) -> Node3D:
	var map = world.terrain
	var p := Vector3(float(rect[0]) + float(rect[2]) * 0.5, 0, float(rect[1]) + float(rect[3]) * 0.5)
	p.y = map.height_at(p)
	var mesh := Ink.new()
	var width := float(rect[2])
	var depth := float(rect[3])
	mesh.block(p + Vector3.UP * 0.86, Vector3(width, 1.72, depth), color)
	var count := int(maxf(width, depth) * 2.0)
	for i in count:
		var offset := (float(i) + 0.5) / count - 0.5
		var direction := Vector3.RIGHT * width if width >= depth else Vector3.BACK * depth
		mesh.block(p + direction * offset + Vector3.UP * 1.72,
			Vector3(0.22 if width >= depth else width, 0.29, depth if width >= depth else 0.22), color.lightened(0.13))
	return mesh.instance(self, id, ink)

func build_water() -> void:
	var map = world.terrain
	var size := Vector2i(map.width, map.depth)
	var image := Image.create_empty(size.x + 2, size.y + 2, false, Image.FORMAT_R8)
	for z in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			var distance := SHORE_REACH
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var q := Vector2i(x + dx, z + dy)
					if q.x >= 0 and q.y >= 0 and q.x < size.x and q.y < size.y and map.land[map.index(q)] != 0:
						distance = minf(distance, maxf(0.0, Vector2(dx, dy).length() - 0.48))
			image.set_pixel(x + 1, z + 1, Color(distance / SHORE_REACH, 0, 0))
	sea.set_shader_parameter("shore_field", ImageTexture.create_from_image(image))
	sea.set_shader_parameter("shore_origin", -Vector2.ONE)
	sea.set_shader_parameter("shore_size", Vector2(size + Vector2i(2, 2)))
	sea.set_shader_parameter("shore_reach", SHORE_REACH)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(240, 240)
	plane.mesh = mesh
	plane.material_override = sea
	plane.position = Vector3(size.x * 0.5, -0.034, size.y * 0.5)
	add_child(plane)

func sync() -> void:
	var hour := clampf(world.time / float(world.params.simulation.night_seconds), 0.0, 1.0)
	var dawn := smoothstep(0.30, 1.0, hour)
	var midnight := smoothstep(0.0, 0.27, hour) * (1.0 - dawn)
	sprite_light = Color("#c6ccdb").lerp(Color("#fff1d5"), dawn)
	if imported != null and imported.has_method("set_night_progress"):
		imported.set_night_progress(hour)
	if imported != null and imported.has_method("set_battle_state"):
		var state := {"gate": "broken" if world.terrain.gate_broken else "open" if world.terrain.gate_open else "closed",
			"breaches": {"weak": world.terrain.weak_broken}, "owners": {}, "boat_seconds": 0.0}
		for id in world.phase_b.walls:
			state.breaches[id] = world.phase_b.walls[id].broken
		for id in world.zones:
			state.owners[id] = world.zones[id].owner
		if world.retreat_started:
			state.boat_seconds = clampf(world.time - world.boat_depart_at, 0.0, float(world.params.retreat.boat_sail_seconds))
		if state != last_topology:
			imported.set_battle_state(state)
			last_topology = state
		return
	var exposure := Vector3(0.74, 0.84, 0.98).lerp(Vector3(0.61, 0.74, 0.90), midnight)
	exposure = exposure.lerp(Vector3(1.17, 1.16, 1.11), dawn)
	ink.set_shader_parameter("exposure", exposure)
	ink.set_shader_parameter("air", Vector3(0.027, 0.046, 0.066).lerp(Vector3(0.071, 0.074, 0.076), dawn))
	sea.set_shader_parameter("clock", world.time)
	sea.set_shader_parameter("dawn", dawn)
	sea.set_shader_parameter("water", Color("#283e4b").lerp(Color("#203647"), midnight).lerp(Color("#526974"), dawn))
	sea.set_shader_parameter("headland", Color("#465767").lerp(Color("#798b94"), dawn))
	sea.set_shader_parameter("horizon", Color("#637081").lerp(Color("#f9f4e9"), dawn))
	sea.set_shader_parameter("shallows", Color("#455958").lerp(Color("#78887b"), dawn))
	sea.set_shader_parameter("froth", Color("#869f98").lerp(Color("#b7bfa9"), dawn))
	structures.gate.visible = not world.terrain.gate_open
	structures.weak.visible = not world.terrain.weak_broken
	for id in world.phase_b.walls:
		structures[id].visible = not world.phase_b.walls[id].broken
	for id in banners:
		banners[id].material_override.albedo_color = Color("#65b6a0") if world.zones[id].owner == "ghost" else Color("#bd9974")
	if world.retreat_started:
		ship.position.x = ship_origin.x + clampf(world.time - world.boat_depart_at, 0.0, float(world.params.retreat.boat_sail_seconds)) * 2.5

static func solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
