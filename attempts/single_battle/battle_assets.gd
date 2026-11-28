extends RefCounted
## T85/T82 的磁盘入口。缺少正式资产时可以完整跑灰盒。
const NAVIGATION := "res://attempts/single_battle/terrain/navigation.json"
const TERRAIN_ROOT := "res://attempts/single_battle/terrain/"

static func apply_terrain(params: Dictionary, args: Dictionary) -> String:
	if args.has("graybox"):
		return ""
	var path := str(args.get("terrain", NAVIGATION))
	if not FileAccess.file_exists(path):
		return "找不到通行数据 " + path if args.has("terrain") else ""
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary or int(doc.get("schema", 0)) != 1 or not doc.get("map") is Dictionary:
		return "通行数据需要 schema=1 和 map 对象 " + path
	for key in ["width", "depth", "land_rects", "wall_rects", "zones", "gate_rect", "weak_rect", "deploy_rect", "routes", "camera", "port", "boat", "cave_a", "cave_b"]:
		if not doc.map.has(key):
			return "通行数据缺少 map." + key
	for key in ["map", "garrisons", "reinforcements", "strategies", "phase_b"]:
		if not doc.has(key):
			continue
		if params[key] is Dictionary and doc[key] is Dictionary:
			merge(params[key], doc[key])
		elif doc[key] is Array and params[key] is Array:
			params[key] = doc[key]
		else:
			return "通行数据 %s 类型不匹配" % key
	if doc.has("scene"):
		var scene := path.get_base_dir().path_join(str(doc.scene))
		if not ResourceLoader.exists(scene, "PackedScene"):
			return "通行数据引用的地形场景无法加载 " + scene
		params.view.terrain_scene = scene
	if not doc.map.zones is Array or not doc.map.camera is Dictionary or not doc.map.camera.get("zones") is Dictionary:
		return "通行数据的战区或机位结构无效"
	for zone in doc.map.zones:
		if not zone is Dictionary or not zone.has("id") or not doc.map.camera.zones.has(zone.id):
			return "每个通行数据战区需要对应的机位"
	return ""

static func merge(base: Dictionary, overlay: Dictionary) -> void:
	for key in overlay:
		if base.get(key) is Dictionary and overlay[key] is Dictionary:
			merge(base[key], overlay[key])
		else:
			base[key] = overlay[key]
