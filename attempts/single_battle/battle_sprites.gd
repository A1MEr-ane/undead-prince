extends RefCounted

const SAMPLE := "res://attempts/single_battle/style_frame/silhouettes.svg"
const UNITS := "res://assets/sprites/units/"
const CELLS := ["ghost", "assassin", "giant", "lich", "shield", "archer", "cavalry",
	"bones", "fire", "dust", "stun", "clash"]
const FOLDERS := {"ghost": "zombie", "assassin": "shadow_assassin", "giant": "stitched_giant", "lich": "lich",
	"shield": "shieldman", "archer": "archer", "cavalry": "cavalry"}
const CLIP_NAMES := {"down": "sit", "cast": "gravefire_cast", "slam": "wall_slam", "stealth": "sneak",
	"retreat": "retreat_run", "launch": "ragdoll", "hurt": "hit", "bone_pile": "downed", "reassemble": "rise_again"}
const FALLBACK_CLIPS := {"sit": "fall", "shoot": "attack", "gravefire_cast": "attack", "backstab": "attack",
	"wall_slam": "attack", "sweep": "attack", "charge": "walk", "charge_impact": "attack", "sneak": "walk",
	"rise_again": "rise", "retreat_run": "walk", "ragdoll": "fall", "downed": "death"}
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
		var id: String = FOLDERS[kind]
		var folder := UNITS.path_join(id)
		var path := folder.path_join(id + "_uv.json")
		if FileAccess.file_exists(path):
			var atlas := load_atlas(path, folder.path_join(id + "_ink.png"))
			if atlas.is_empty():
				push_warning("单局精灵退回样张，无法读取 " + path)
			else:
				atlases[kind] = atlas

func load_atlas(path: String, image_path: String) -> Dictionary:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
	if (not doc is Dictionary or doc.get("format") != "swordsman_uv_v1"
			or not doc.get("animations") is Dictionary or not doc.get("frames") is Array or not doc.get("coordinates") is Dictionary):
		return {}
	if not FileAccess.file_exists(image_path):
		return {}
	var image := Image.load_from_file(image_path)
	if image == null or image.is_empty():
		return {}
	var texture := ImageTexture.create_from_image(image)
	var clips := {}
	for action in doc.animations:
		var entry = doc.animations[action]
		if not entry is Dictionary:
			return {}
		var start := int(entry.get("start_frame", -1))
		var count := int(entry.get("frame_count", 0))
		var duration := float(entry.get("duration", 0.0))
		if start < 0 or count <= 0 or start + count > doc.frames.size() or duration <= 0.0:
			return {}
		var regions: Array = []
		for i in range(start, start + count):
			var frame = doc.frames[i]
			if not frame is Dictionary:
				return {}
			var tuple = frame.get("rect")
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
		clips[action] = {"duration": duration, "tiles": regions, "loop": bool(entry.get("loop", false)), "start": start}
	var anchor = doc.coordinates.get("standing_foot_anchor_pixels")
	if not clips.has("idle") or not anchor is Array or anchor.size() != 2:
		return {}
	var bounds = doc.frames[clips.idle.start].get("alpha_bbox")
	if not bounds is Array or bounds.size() != 4 or float(bounds[3]) <= float(bounds[1]):
		return {}
	return {"foot": Vector2(float(anchor[0]), float(anchor[1])), "height": float(bounds[3]) - float(bounds[1]), "animations": clips}

func clip_for(kind: String, action: String) -> Dictionary:
	if not atlases.has(kind):
		return {}
	var clips: Dictionary = atlases[kind].animations
	var name: String = CLIP_NAMES.get(action, action)
	return clips.get(name, clips.get(FALLBACK_CLIPS.get(name, "idle"), clips.idle))

func appearance(kind: String, action: String, clock: float) -> Dictionary:
	if not atlases.has(kind):
		var tile := "bones" if action == "bone_pile" else kind
		return {"texture": sample_tiles[tile], "foot": Vector2(120, 195), "height": 156.0, "faces_right": kind not in ["shield", "archer", "cavalry"]}
	var atlas: Dictionary = atlases[kind]
	var clip := clip_for(kind, action)
	var frame := floori(maxf(0.0, clock) * clip.tiles.size() / float(clip.duration))
	frame = frame % clip.tiles.size() if clip.loop else mini(frame, clip.tiles.size() - 1)
	return {"texture": clip.tiles[frame], "foot": atlas.foot, "height": atlas.height, "faces_right": true}
