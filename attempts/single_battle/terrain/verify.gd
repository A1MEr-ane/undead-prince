extends SceneTree

const Layout := preload("res://attempts/single_battle/terrain/terrain.gd")
const Ground := preload("res://attempts/single_battle/terrain/ground.gd")
const BattleMap := preload("res://proto/siege/siege_map.gd")
const Metrics := preload("res://proto/siege/siege_metrics.gd")
const TERRAIN := preload("res://attempts/single_battle/terrain/grey_tide.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var layout := Layout.load_layout()
	var map: Dictionary = layout.map
	var battle := BattleMap.new()
	const SPEED := 2.0
	battle.setup({"map": map, "units": {"ghost": {"speed": SPEED}}})
	var terrain := TERRAIN.instantiate() as Layout
	root.size = Vector2i(1280, 720)
	root.add_child(terrain)
	var camera := Camera3D.new()
	root.add_child(camera)
	var keep := BattleMap.vec(map.zones[3].center)
	var port := BattleMap.vec(map.port)
	var main := BattleMap.vec(layout.deploy_points.main)
	var side := BattleMap.vec(layout.deploy_points.side)
	var cave := BattleMap.vec(layout.deploy_points.cave)
	var infinity: float = map.flow_infinity
	_check(battle.distance(main, keep) >= infinity, "The entrance wall must hold when all gates are closed.")
	_check(battle.distance(side, keep) >= infinity, "The closed weak wall must hold at the highland.")
	_check(battle.distance(cave, keep, true) < infinity and battle.distance(cave, keep) >= infinity,
			"The cave must bypass the wall only when the caller allows its link.")
	_check(battle.distance(keep, port) < infinity, "Keep defenders need access to the boarding point.")
	for wall: Dictionary in layout.phase_b.breakable_walls:
		var r: Array = wall.rect
		var approach := side if wall.id == "wall_highland" else main
		battle.change(r, true, 0.0, wall.id)
		_check(battle.distance(approach, keep) < infinity, wall.id + " must open its own route.")
		battle.change(r, false, 0.0, wall.id)
		_check(battle.distance(approach, keep) >= infinity, wall.id + " must close again.")
	var times := {"cave": _travel(battle, layout, "cave", SPEED)}
	battle.change(map.gate_rect, true, 0.0, "gate")
	times.main = _travel(battle, layout, "main", SPEED)
	battle.change(map.gate_rect, false, 0.0, "gate")
	battle.change(map.weak_rect, true, 0.0, "weak_wall")
	times.side = _travel(battle, layout, "side", SPEED)
	_check(times.cave >= 0 and times.cave < times.main and times.main < times.side, "The three route travel times must stay staggered.")
	_check(battle.is_walkable_at(BattleMap.vec(layout.phase_b.cliff_entry))
			and battle.is_walkable_at(BattleMap.vec(layout.phase_b.cliff_exit)), "Climb endpoints must be on walkable tiles.")
	_check(terrain.height_at(BattleMap.vec(layout.phase_b.cliff_exit)) >
			terrain.height_at(BattleMap.vec(layout.phase_b.cliff_entry)) + 1.0, "The climb must lead up to the highland.")
	var contour := Ground.ring(Ground.COAST)
	var lagoon := Ground.ring(Ground.LAGOON)
	for rect: Array in map.land_rects:
		for tile: Vector2i in battle.rect_cells(rect):
			var anchor := Vector2(tile) + Vector2.ONE * 0.5
			_check(Geometry2D.is_point_in_polygon(anchor, contour)
					and not Geometry2D.is_point_in_polygon(anchor, lagoon),
					"Land tile %s must have a dry center." % tile)

	for id: String in ["gate", "weak_wall", "wall_west", "wall_east", "wall_highland"]:
		var states := ["closed", "open", "broken"] if id == "gate" else ["intact", "breached"]
		for state: String in states:
			_check(terrain.set_structure_state(id, state), "Missing visual state %s/%s." % [id, state])
			for child in terrain.get_node(id).get_children():
				_check(child.visible == (child.name == state), "Visual state %s/%s is inconsistent." % [id, state])
	_check(not terrain.set_structure_state("gate", "intact"), "Reject invalid gate state.")
	_check(not terrain.set_structure_state("unknown", "intact"), "Reject unknown structure.")
	var landmarks := {
		"coast": [[24, 45], [28, 39], [45, 37], [29, 28]],
		"highland": [[9, 31], [9, 24], [14, 24], layout.phase_b.cliff_entry, layout.phase_b.cliff_exit],
		"plaza": [[29, 28], map.cave_b, map.zones[2].center],
		"keep": [map.zones[3].center, map.port, map.boat],
		"overview": [map.zones[0].center, map.zones[1].center, map.zones[2].center, map.zones[3].center, map.port]
	}
	var landmark_tops := {
		"coast": [Vector3(29, 3.4, 28.5), Vector3(45.5, 2.3, 37.5)],
		"highland": [Vector3(6.5, 6.3, 21)],
		"plaza": [Vector3(29, 3.4, 28.5), Vector3(21.5, 2.3, 20.5)],
		"keep": [Vector3(32, 6.46, 4.58), Vector3(51.55, 3.51, 18.93), Vector3(51.55, 0.65, 22.38)],
	}
	for id: String in landmarks:
		_check(terrain.apply_camera(camera, id), "Missing camera " + id)
		for tile: Array in landmarks[id]:
			var point := BattleMap.vec(tile)
			point.y = terrain.height_at(point)
			_check(camera.is_position_in_frustum(point), "%s camera lost landmark %s." % [id, tile])
		for point: Vector3 in landmark_tops.get(id, []):
			_check(camera.is_position_in_frustum(point), "%s camera clips the landmark at %s." % [id, point])
	for time: float in [0.0, 0.28, 0.7, 1.0]:
		terrain.set_time(time)
	var cutter: MeshInstance3D = terrain.get_node("Garrison cutter")
	var mooring := cutter.position
	terrain.set_boat_progress(1.0)
	_check(cutter.position.is_equal_approx(mooring + Vector3.RIGHT * 10.0), "The boat must sail seaward.")
	print("T85 terrain: %d failures; unobstructed seconds %s." % [_failures, JSON.stringify(times)])
	quit(0 if _failures == 0 else 1)


func _travel(battle: BattleMap, layout: Dictionary, route: String, speed: float) -> float:
	var points: Array = [layout.deploy_points[route]] + layout.map.routes[route]
	var seconds := 0.0
	for i in range(1, points.size()):
		if route == "cave" and i == 2:
			seconds += float(layout.map.cave_travel_seconds)
			continue
		var path := Metrics.path_points(battle, BattleMap.vec(points[i - 1]), BattleMap.vec(points[i]))
		if path.is_empty():
			return -1
		for step in range(1, path.size()):
			seconds += path[step - 1].distance_to(path[step]) / speed
	return seconds


func _check(passed: bool, message: String) -> void:
	if not passed:
		_failures += 1
		push_error(message)
