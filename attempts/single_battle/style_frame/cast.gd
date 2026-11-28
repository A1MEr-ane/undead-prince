extends Node3D

const Ink := preload("res://attempts/single_battle/style_frame/ink_mesh.gd")
const Coast := preload("res://attempts/single_battle/style_frame/coast.gd")
const ATLAS := "res://attempts/single_battle/style_frame/silhouettes.svg"
const CELL := 240
const SOLES := 195
const GROUND := Coast.GROUND
const HEIGHT := Coast.HEIGHT

enum Kind { SKELETON, ASSASSIN, GIANT, LICH, SHIELD, ARCHER, CAVALRY, BONES, FIRE, DUST, STUN, CLASH }
const SKELETONS := [
	Vector3(-7.05, GROUND, 4.94), Vector3(-5.55, GROUND, 3.1),
	Vector3(-3.72, GROUND, 3.87), Vector3(-3.38, GROUND, 2.35),
	Vector3(-1.69, GROUND, 2.38), Vector3(-2.93, GROUND, 0.80),
]
const CASTER := Vector3(-6.12, GROUND, 1.12)
const IMPACT := Vector3(1.46, GROUND, 1.48)
const GATE := Vector3(-0.17, GROUND, Coast.WALL_FRONT + 0.46)

class Actor:
	var pivot: Node3D
	var sprite: Sprite3D
	var anchor: Vector3
	var kind: int
	var phase: float


var actors: Array[Actor] = []
var _tiles: Array[Texture2D] = []
var _view_basis: Basis
var _sprite_light := Color.WHITE
var _flame: Sprite3D
var _embers: Array[MeshInstance3D] = []
var _stun: Sprite3D
var _dust: Array[Sprite3D] = []
var _clash: Sprite3D
var _stone: Array[MeshInstance3D] = []
var _bone_piles: Array[Sprite3D] = []
var _gate_shadow: MeshInstance3D


func build(camera: Camera3D, material: ShaderMaterial) -> void:
	_view_basis = camera.basis
	var image := Image.new()
	var error := image.load_svg_from_string(FileAccess.get_file_as_string(ATLAS), 3.0)
	assert(error == OK and image.get_size() == Vector2i(CELL * 4, CELL * 3), "Unreadable T84 sprite artwork.")
	for i in 12:
		var cell := Vector2i(i % 4, floori(float(i) / 4.0)) * CELL
		_tiles.append(ImageTexture.create_from_image(image.get_region(Rect2i(cell, Vector2i.ONE * CELL))))
	var shadows := Ink.new()
	for position in SKELETONS:
		_actor(Kind.SKELETON, position, 1.23, shadows)
	_actor(Kind.ASSASSIN, Vector3(5.9, GROUND, 5.88), 1.17, shadows)
	_actor(Kind.ASSASSIN, Vector3(8.55, HEIGHT, 5.23), 1.20, shadows)
	var slam_shadow := Ink.new()
	_actor(Kind.GIANT, Vector3(-0.99, GROUND, -2.21), 1.90, slam_shadow)
	_gate_shadow = slam_shadow.instance(self, "Gate giant shadow", material)
	_actor(Kind.GIANT, Vector3(-4.75, GROUND, -1.04), 1.98, shadows)
	_actor(Kind.LICH, CASTER, 1.18, shadows)
	_actor(Kind.LICH, Vector3(-8.64, GROUND, 3.03), 1.15, shadows)
	_actor(Kind.SHIELD, Vector3(0.18, GROUND, 2.49), 1.23, shadows)
	_actor(Kind.SHIELD, IMPACT, 1.23, shadows)
	_actor(Kind.SHIELD, Vector3(2.85, GROUND, 0.50), 1.23, shadows)
	_actor(Kind.SHIELD, Vector3(2.43, GROUND, 3.75), 1.23, shadows)
	_actor(Kind.ARCHER, Vector3(6.42, HEIGHT, 2.60), 1.18, shadows)
	_actor(Kind.ARCHER, Vector3(8.42, HEIGHT, 3.45), 1.20, shadows)
	_actor(Kind.ARCHER, Vector3(6.52, Coast.TOWER_WALK, -5.81), 1.19, shadows)
	_actor(Kind.CAVALRY, Vector3(2.05, GROUND, -1.36), 1.46, shadows)
	_actor(Kind.CAVALRY, Vector3(3.91, GROUND, -0.90), 1.49, shadows)
	for pos in [Vector3(-2.78, GROUND, 4.57), Vector3(-7.43, GROUND, 5.75),
			Vector3(0.09, GROUND, 4.38)]:
		var bones := _sprite(self, Kind.BONES, 1.26)
		bones.basis = _view_basis
		bones.position = pos + _view_basis.y * _sprite_offset(bones)
		_bone_piles.append(bones)
		_shadow(shadows, pos, 0.46, 0.20)
	shadows.instance(self, "Contact shadows", material)

	_flame = _effect(Kind.FIRE, 1.54)
	_stun = _effect(Kind.STUN, 1.48)
	_clash = _effect(Kind.CLASH, 0.96)
	for i in 3:
		_dust.append(_effect(Kind.DUST, [1.16, 0.98, 0.86][i]))
	for i in 9:
		_embers.append(_chip(Color("#61edc6") if i % 2 == 0 else Color("#25a88d")))
	for i in 7:
		_stone.append(_chip(Color("#a08c70") if i % 2 == 0 else Color("#5d5651")))


func light(exposure: float) -> void:
	_sprite_light = Color("#d5d7eb").lerp(Color("#fff1d5"), exposure)
	for bones in _bone_piles:
		bones.modulate = _sprite_light.darkened(0.12)


func pose(clock: float) -> void:
	var punch := fposmod(clock, 4.2)
	var bolt := fposmod(clock + 0.32, 3.5)
	for actor in actors:
		var wave := sin(clock * 3.9 + actor.phase)
		var move := Vector3(0, wave * 0.028, 0)
		var tilt := 0.032 * wave
		var squash := 1.0
		actor.sprite.modulate = _sprite_light
		match actor.kind:
			Kind.GIANT:
				if actor.anchor.z < -2.0:
					var lead := smoothstep(1.38, 1.99, punch)
					var settle := 1.0 - smoothstep(2.03, 2.76, punch)
					var slam := lead * settle
					move += Vector3(0.11, 0.0, -0.78) * slam
					tilt -= 0.30 * slam - 0.11 * smoothstep(0.55, 1.38, punch) * (1.0 - lead)
					squash = 1.0 - 0.09 * slam
					_gate_shadow.position = Vector3(move.x, 0.0, move.z)
			Kind.ASSASSIN:
				move.x += sin(clock * 1.6 + actor.phase) * 0.29
				move.z += sin(clock * 1.1) * 0.18
				actor.sprite.modulate.a = 0.49 + sin(clock * 2.2 + actor.phase) * 0.17
			Kind.SKELETON, Kind.SHIELD:
				var step := sin(clock * 5.2 + actor.phase)
				move.x += step * (0.15 if actor.kind == Kind.SKELETON else 0.09)
				move.y += maxf(0.0, step) * 0.07
				if actor.kind == Kind.SHIELD and actor.anchor == IMPACT:
					var knock := smoothstep(2.52, 2.63, bolt) * (1.0 - smoothstep(2.70, 3.24, bolt))
					tilt += 0.29 * knock
					move.z -= 0.20 * knock
			Kind.CAVALRY:
				move.x += wave * 0.19
				move.y += maxf(wave, 0.0) * 0.078
		actor.pivot.position = actor.anchor + move
		actor.pivot.basis = _view_basis.rotated(_view_basis.z, tilt)
		actor.pivot.scale.y = squash

	_gravefire(bolt)
	_gate_dust(punch)
	var clash_phase := fposmod(clock - 0.06, 1.09)
	_clash.visible = clash_phase < 0.14
	if _clash.visible:
		_clash.position = Vector3(-0.66, GROUND + 0.76, 2.44)
		_clash.scale = Vector3.ONE * (0.70 + clash_phase * 2.6)


func _gravefire(cycle: float) -> void:
	var from := CASTER + Vector3(0.57, 1.09, 0.0)
	var to := IMPACT + Vector3(-0.15, 0.79, 0.10)
	var travel := clampf((cycle - 1.20) / 1.32, 0.0, 1.0)
	_flame.visible = cycle >= 0.92 and cycle < 2.69
	var world := from.lerp(to, travel) + Vector3.UP * sin(travel * PI) * 0.60
	_flame.position = world
	var contact := smoothstep(2.52, 2.69, cycle)
	_flame.scale = Vector3.ONE * ((0.87 if cycle >= 1.20 else 0.56) + 0.06 * sin(cycle * 21.0))
	_flame.modulate.a = 1.0 - contact
	for i in _embers.size():
		var ember := _embers[i]
		var delayed := travel - (i + 1) * 0.039
		ember.visible = _flame.visible and cycle < 2.53 and delayed > 0.0
		if not ember.visible:
			continue
		ember.position = from.lerp(to, delayed) + Vector3.UP * (sin(delayed * PI) * 0.62 +
				sin(i * 5.7 + cycle * 6.0) * 0.13) + Vector3.BACK * cos(i * 2.1) * 0.14
		ember.scale = Vector3.ONE * lerpf(1.05, 0.34, i / 9.0)
	_stun.visible = cycle >= 2.51 and cycle < 3.37
	if _stun.visible:
		_stun.position = IMPACT + Vector3(0.0, 1.23 + 0.12 * sin(cycle * 14.0), 0.24)
		_stun.modulate.a = 1.0 - smoothstep(3.05, 3.37, cycle)


func _gate_dust(cycle: float) -> void:
	for i in _dust.size():
		var puff := _dust[i]
		var age := cycle - 1.99 - i * 0.06
		puff.visible = age > 0.0 and age < 0.77
		if puff.visible:
			puff.position = GATE + Vector3((i - 1) * (0.34 + 0.40 * age),
					0.43 + (i % 2) * 0.41 + age * 1.04, 0.34 + i * 0.22 + age * 0.89)
			puff.scale = Vector3.ONE * (0.56 + age * 1.6)
			puff.modulate = _sprite_light
			puff.modulate.a = (1.0 - smoothstep(0.33, 0.77, age)) * 0.84
	for i in _stone.size():
		var chip := _stone[i]
		var age := cycle - 1.98 - 0.016 * i
		chip.visible = age > 0.0 and age < 0.57
		if chip.visible:
			chip.position = GATE + Vector3(age * (i - 3) * 0.50,
					0.95 + (1.6 + (i % 3) * 0.43) * age - 4.7 * age * age,
					0.30 + age * (2.1 + i * 0.16))
			chip.rotation = Vector3(age * (i + 1), i * 0.23, age * 3.0)


func _actor(kind: Kind, at: Vector3, height: float, shadows: RefCounted) -> void:
	var actor := Actor.new()
	actor.kind = kind
	actor.anchor = at
	actor.phase = actors.size() * 2.36
	actor.pivot = Node3D.new()
	actor.pivot.name = "%s %02d" % [Kind.keys()[kind].capitalize(), actors.size() + 1]
	add_child(actor.pivot)
	actor.sprite = _sprite(actor.pivot, kind, height)
	actor.sprite.position.y = _sprite_offset(actor.sprite)
	actor.sprite.flip_h = kind >= Kind.SHIELD
	_shadow(shadows, at, height * (0.57 if kind == Kind.CAVALRY else 0.40), height * 0.25)
	actors.append(actor)


func _sprite(parent: Node3D, kind: Kind, height: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = _tiles[kind]
	sprite.pixel_size = height / 156.0
	sprite.shaded = false
	sprite.double_sided = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	parent.add_child(sprite)
	return sprite


func _effect(kind: Kind, size: float) -> Sprite3D:
	var sprite := _sprite(self, kind, size)
	sprite.basis = _view_basis
	sprite.visible = false
	return sprite


func _chip(color: Color) -> MeshInstance3D:
	var chip := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.105, 0.048, 0.078)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	chip.mesh = mesh
	chip.material_override = material
	chip.visible = false
	add_child(chip)
	return chip


func _shadow(shadows: RefCounted, at: Vector3, width: float, depth: float) -> void:
	var ring := PackedVector2Array()
	var center := Vector2(at.x - width * 0.38, at.z + depth * 0.40)
	for i in 8:
		var a := TAU * i / 8.0
		ring.append(center + Vector2(cos(a) * width, sin(a) * depth * (0.9 + 0.1 * (i % 3))))
	shadows.sheet(ring, at.y + 0.032, Color("#242d30"))


static func _sprite_offset(sprite: Sprite3D) -> float:
	return (SOLES - CELL * 0.5) * sprite.pixel_size
