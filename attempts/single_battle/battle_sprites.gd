extends RefCounted

const SAMPLE := "res://attempts/single_battle/style_frame/silhouettes.svg"
const UNITS := "res://assets/sprites/units/"
const CELLS := ["ghost", "assassin", "giant", "lich", "shield", "archer", "cavalry",
	"bones", "fire", "dust", "stun", "clash"]
const FOLDERS := {"ghost": "skeleton", "assassin": "assassin", "giant": "giant", "lich": "lich",
	"shield": "shield", "archer": "archer", "cavalry": "cavalry"}
const ANIMATIONS := {"down": "fall", "shoot": "attack", "cast": "attack", "backstab": "attack",
	"slam": "attack", "sweep": "attack", "charge": "walk", "stealth": "walk",
	"reassemble": "rise", "retreat": "walk", "launch": "fall"}
var sample_tiles := {}
var atlases := {}

func setup() -> void:
	var image := Image.new()
	var error := image.load_svg_from_string(FileAccess.get_file_as_string(SAMPLE), 3.0)
	assert(error == OK and image.get_size() == Vector2i(960, 720), "无法读取局内样张侧影")
	for i in CELLS.size():
		var origin := Vector2i(i % 4, i / 4) * 240
		sample_tiles[CELLS[i]] = ImageTexture.create_from_image(image.get_region(Rect2i(origin, Vector2i(240, 240))))
	for kind in FOLDERS:
		var folder := UNITS.path_join(FOLDERS[kind])
		var path := folder.path_join("atlas.json")
		if kind == "ghost" and not FileAccess.file_exists(path):
			folder = UNITS.path_join("ghost")
			path = folder.path_join("atlas.json")
		if FileAccess.file_exists(path):
			var atlas := load_atlas(path)
			if atlas.is_empty():
				push_warning("单局精灵退回样张，无法读取 " + path)
			else:
				atlases[kind] = atlas

func load_atlas(path: String) -> Dictionary:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary or int(doc.get("schema", 0)) != 1 or not doc.get("animations") is Dictionary:
		return {}
	var image_path := path.get_base_dir().path_join(str(doc.get("image", "atlas.png")))
	var image := Image.load_from_file(image_path)
	if image == null or image.is_empty():
		return {}
	var texture := ImageTexture.create_from_image(image)
	var frames := {}
	for action in doc.animations:
		var entry = doc.animations[action]
		if not entry is Dictionary or not entry.get("frames") is Array or float(entry.get("fps", 0)) <= 0.0:
			return {}
		var regions: Array = []
		for tuple in entry.frames:
			if not tuple is Array or tuple.size() != 4:
				return {}
			var rect := Rect2i(int(tuple[0]), int(tuple[1]), int(tuple[2]), int(tuple[3]))
			if not Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect) or rect.size.x <= 0 or rect.size.y <= 0:
				return {}
			var tile := AtlasTexture.new()
			tile.atlas = texture
			tile.region = Rect2(rect)
			tile.filter_clip = true
			regions.append(tile)
		if regions.is_empty():
			return {}
		frames[action] = {"fps": float(entry.fps), "tiles": regions}
	var anchor = doc.get("foot", [])
	var art_height := float(doc.get("art_height", 0.0))
	if not frames.has("idle") or not anchor is Array or anchor.size() != 2 or art_height <= 0.0:
		return {}
	return {"foot": Vector2(float(anchor[0]), float(anchor[1])), "height": art_height,
		"animations": frames, "faces_right": bool(doc.get("faces_right", true))}

func appearance(kind: String, action: String, clock: float, looping: bool) -> Dictionary:
	if not atlases.has(kind):
		return {"texture": sample_tiles[kind], "foot": Vector2(120, 195), "height": 156.0, "faces_right": kind not in ["shield", "archer", "cavalry"]}
	var atlas: Dictionary = atlases[kind]
	var clips: Dictionary = atlas.animations
	var clip: Dictionary = clips.get(action, clips.get(ANIMATIONS.get(action, "idle"), clips.idle))
	var frame := floori(maxf(0.0, clock) * float(clip.fps))
	frame = frame % clip.tiles.size() if looping else mini(frame, clip.tiles.size() - 1)
	return {"texture": clip.tiles[frame], "foot": atlas.foot, "height": atlas.height, "faces_right": atlas.faces_right}
