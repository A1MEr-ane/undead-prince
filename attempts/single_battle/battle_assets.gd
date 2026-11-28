extends RefCounted
## T85/T82 的磁盘入口。缺少正式资产时可以完整跑灰盒。
const TERRAIN_ROOT := "res://attempts/single_battle/terrain/"
const NAVIGATION := TERRAIN_ROOT + "grey_tide.json"
const TERRAIN_SCENE := TERRAIN_ROOT + "grey_tide.tscn"

static func apply_terrain(params: Dictionary, args: Dictionary) -> String:
	if args.has("graybox"):
		return ""
	var path := str(args.get("terrain", NAVIGATION))
	if not FileAccess.file_exists(path):
		return "找不到通行数据 " + path if args.has("terrain") else ""
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary or int(doc.get("schema_version", 0)) != 1 or not doc.get("map") is Dictionary:
		return "通行数据需要 schema_version=1 和 map 对象 " + path
	for key in ["width", "depth", "land_rects", "wall_rects", "zones", "gate_rect", "weak_rect", "deploy_rect", "routes", "port", "boat", "cave_a", "cave_b"]:
		if not doc.map.has(key):
			return "通行数据缺少 map." + key
	if not doc.map.zones is Array or doc.map.zones.is_empty() or not doc.get("cameras") is Dictionary:
		return "通行数据的战区或机位结构无效"
	var cameras := {}
	for zone in doc.map.zones:
		if not zone is Dictionary or not zone.has("id") or not doc.cameras.get(zone.id) is Dictionary:
			return "每个通行数据战区需要对应的机位"
		var pose: Dictionary = doc.cameras[zone.id]
		if not pose.get("focus") is Array or pose.focus.size() != 3 or not pose.has("yaw") or not pose.has("pitch") or float(pose.get("size", 0)) <= 0.0:
			return "通行数据的机位无效 " + str(zone.id)
		cameras[zone.id] = pose.merged({"distance": 75.0, "label": zone.label})
	if not doc.get("phase_b") is Dictionary or not doc.get("deploy_points") is Dictionary or not doc.get("surfaces") is Array:
		return "通行数据缺少 phase_b、deploy_points 或 surfaces"
	if path == NAVIGATION and not ResourceLoader.exists(TERRAIN_SCENE, "PackedScene"):
		return "通行数据缺少地形场景 " + TERRAIN_SCENE
	merge(params.map, doc.map)
	merge(params.phase_b, doc.phase_b)
	merge(params.strategies.deploy_points, doc.deploy_points)
	params.map.camera.zones = cameras
	params.map.surfaces = doc.surfaces
	if path == NAVIGATION:
		params.view.terrain_scene = TERRAIN_SCENE
	return ""

static func merge(base: Dictionary, overlay: Dictionary) -> void:
	for key in overlay:
		if base.get(key) is Dictionary and overlay[key] is Dictionary:
			merge(base[key], overlay[key])
		else:
			base[key] = overlay[key]
