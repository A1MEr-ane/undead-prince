extends RefCounted
## Original, procedural sword-and-shield soldier. RG = part-sheet UV,
## B = baked volume light (0.5 neutral), A = 4x4 sample coverage.
## Never interpolate RG across part boundaries; only coverage is filtered.

const FW := 64
const FH := 64
const COLS := 8
const SS := 4
const SCALE := 1.9
const HIP := Vector2(32, 43)
const PART_GRID := 4
const PART_PX := 64
const LOOK_PX := PART_GRID * PART_PX
const LOOK_GRID := Vector2i(2, 2)
const PART_PAD := 3.0

const SKIN := 1
const TUNIC := 2
const PANTS := 3
const HELM := 4
const BLADE := 5
const HILT := 6
const SHIELD := 7
const RIM := 8
const EYE := 9
const BELT := 10
const FAR := 0.76

# Advisory seconds; playback remains owned by Unit. Keep its fixed frame counts.
# Attack: 0..2 anticipation, 3 contact, 4 follow-through, 5 recovery.
const ANIM_DURATIONS := {
	"idle": 0.8, "walk": 0.52, "attack": 0.72, "block": 0.3,
	"clash": 0.4, "hit": 0.3, "tumble": 0.5, "down": 1.0,
	"getup": 0.56, "dead": 0.5,
}
const ATTACK_HIT_TIME := 0.333

var draw_shield := true
var anchors := PackedVector2Array()

var _owners := PackedByteArray()
var _uvs := PackedVector2Array()
var _lights := PackedFloat32Array()
var _rot := 0.0
var _off := Vector2.ZERO


static func build(with_shield: bool = true) -> Dictionary:
	var factory = load("res://sprite_factory.gd").new()
	factory.draw_shield = with_shield
	return factory._build()


static func part_uv(code: int, uv: Vector2) -> Vector2:
	var slot := Vector2((code - 1) % PART_GRID, (code - 1) / PART_GRID)
	return (slot * PART_PX + Vector2.ONE * (PART_PAD + 0.5)
		+ uv.clamp(Vector2.ZERO, Vector2.ONE) * (PART_PX - PART_PAD * 2.0 - 1.0)) / LOOK_PX


static func light_decode(b: float) -> float:
	return 0.6 + b * 0.8 if b <= 0.5 else 0.7 + b * 0.6


func _build() -> Dictionary:
	var poses: Array[Dictionary] = []
	var anims := {}
	_add(anims, poses, "idle", _idle())
	_add(anims, poses, "walk", _walk())
	_add(anims, poses, "attack", _attack())
	_add(anims, poses, "block", _block())
	_add(anims, poses, "clash", _clash())
	_add(anims, poses, "hit", _hit())
	_add(anims, poses, "tumble", _tumble())
	_add(anims, poses, "down", [_down_pose()])
	_add(anims, poses, "getup", _getup())
	_add(anims, poses, "dead", _dead())
	var rows := ceili(poses.size() / float(COLS))
	var img := Image.create(COLS * FW, rows * FH, false, Image.FORMAT_RGBA8)
	for i in poses.size():
		_render(poses[i])
		img.blit_rect(_resolve(), Rect2i(0, 0, FW, FH), Vector2i(i % COLS, i / COLS) * FW)
	return {"image": img, "anims": anims, "grid": Vector2(COLS, rows), "count": poses.size(), "anchors": anchors}


func _add(anims: Dictionary, poses: Array[Dictionary], anim_name: String, list: Array) -> void:
	anims[anim_name] = Vector2i(poses.size(), list.size())
	for p in list:
		poses.append(p)


# ---------- 姿势 ----------
# 角度约定：0 = 竖直向下，正值 = 向前（朝右）。躯干 lean 正值前倾。
# 腿：大腿 t、小腿相对 s；臂：上臂 u、前臂相对 l。near = 持盾的近侧，far = 持剑的远侧。

func _p(over: Dictionary) -> Dictionary:
	var p := {
		"lean": 0.0, "ft": 0.12, "fs": 0.0, "bt": -0.12, "bs": 0.0,
		"nu": 0.3, "nl": 0.6, "fu": 0.35, "fl": -0.9, "sw": 2.7, "sh": 0.0,
		"rot": 0.0, "ox": 0.0, "oy": 0.0, "dy": 0.0,
	}
	p.merge(over, true)
	return p


func _idle() -> Array:
	return [
		_p({}),
		_p({"sw": 2.72}),
		_p({"dy": 0.35, "sw": 2.78, "nl": 0.7}),
		_p({"dy": 0.35, "sw": 2.74, "nl": 0.7}),
	]


func _walk() -> Array:
	var out := []
	for i in 6:
		var ph := (i + 0.5) / 6.0 * TAU
		var s := sin(ph)
		out.append(_p({
			"lean": 0.1,
			"ft": 0.6 * s, "bt": -0.6 * s,
			"fs": -0.7 * max(0.0, -s), "bs": -0.7 * max(0.0, s),
			"nu": 0.3 - 0.3 * s, "fu": 0.35 + 0.35 * s,
			"dy": -0.35 * abs(cos(ph)),
		}))
	return out


func _attack() -> Array:
	return [
		_p({"lean": -0.1, "fu": PI - 0.5, "fl": -0.5, "sw": PI + 0.7, "ft": 0.3, "bt": -0.3}),
		_p({"lean": -0.2, "fu": PI - 0.25, "fl": -0.4, "sw": PI + 1.15, "ft": 0.35, "bt": -0.35}),
		_p({"lean": -0.22, "fu": PI - 0.2, "fl": -0.4, "sw": PI + 1.25, "ft": 0.35, "bt": -0.35, "dy": 0.35}),
		_p({"lean": 0.28, "fu": 1.9, "fl": -0.2, "sw": 1.75, "ft": 0.75, "fs": -0.2, "bt": -0.5, "nu": 0.0}),
		_p({"lean": 0.35, "fu": 1.3, "fl": 0.0, "sw": 1.0, "ft": 0.85, "fs": -0.3, "bt": -0.6, "dy": 0.35, "nu": -0.1}),
		_p({"lean": 0.12, "fu": 0.8, "fl": -0.4, "sw": 2.0, "ft": 0.4, "bt": -0.3}),
	]


func _block() -> Array:
	return [
		_p({"lean": -0.12, "nu": 1.45, "nl": 0.1, "ft": 0.35, "bt": -0.35, "sw": 2.5}),
		_p({"lean": -0.22, "nu": 1.35, "nl": 0.15, "ft": 0.4, "bt": -0.4, "sw": 2.6, "dy": 0.35}),
	]


func _clash() -> Array:
	return [
		_p({"lean": 0.22, "fu": 1.7, "fl": -0.7, "sw": 2.25, "ft": 0.55, "bt": -0.5, "nu": 0.9}),
		_p({"lean": 0.05, "fu": 1.4, "fl": -0.9, "sw": 2.65, "ft": 0.45, "bt": -0.45, "nu": 0.7, "dy": 0.35}),
	]


func _hit() -> Array:
	return [
		_p({"lean": -0.45, "nu": -0.5, "nl": 0.3, "fu": -0.4, "fl": -0.5, "sw": 3.7, "ft": 0.45, "bt": 0.1, "dy": 0.35}),
		_p({"lean": -0.25, "nu": -0.2, "fu": -0.1, "fl": -0.6, "sw": 3.3, "ft": 0.35, "bt": 0.0}),
	]


func _tumble() -> Array:
	var out := []
	for i in 6:
		out.append(_p({
			"lean": 0.5, "ft": 1.7, "fs": -2.4, "bt": 1.4, "bs": -2.2,
			"nu": 1.3, "nl": 1.0, "fu": 0.9, "fl": 1.25, "sw": 3.5,
			"rot": i * TAU / 6.0, "oy": -5.0,
		}))
	return out


func _down_pose() -> Dictionary:
	return _p({"rot": -PI / 2.0, "ox": 2.0, "oy": 5.2, "ft": 0.05, "bt": -0.08, "nu": 0.4, "nl": 0.2, "fu": 0.8, "fl": 0.3, "sw": 1.6})


func _getup() -> Array:
	return [
		_down_pose(),
		_p({"rot": -1.0, "ox": 1.0, "oy": 5.2, "ft": 0.6, "bt": 0.5, "nu": 0.9, "fu": 0.6, "sw": 2.0}),
		_p({"lean": 0.3, "ft": 1.5, "fs": -1.5, "bt": 0.9, "bs": -2.4, "oy": 5.0, "nu": 0.6, "sw": 2.3}),
		_p({"lean": 0.15, "ft": 0.6, "fs": -0.9, "bt": -0.3, "bs": -0.6, "oy": 1.0, "sw": 2.5}),
	]


func _dead() -> Array:
	return [
		_p({"lean": 0.75, "ft": 1.5, "fs": -1.5, "bt": 0.9, "bs": -2.4, "oy": 3.5, "nu": 0.1, "fu": 0.2, "fl": 0.0, "sw": 1.35}),
		_p({"rot": PI / 2.0, "ox": -3.0, "oy": 2.0, "ft": 0.1, "bt": -0.1, "nu": 2.8, "nl": 0.0, "fu": 2.5, "fl": 0.2, "sw": 2.6}),
	]


# ---------- Supersampled, local-UV geometry ----------

func _dir(a: float) -> Vector2:
	return Vector2(sin(a), cos(a))


func _tx(v: Vector2) -> Vector2:
	return (v.rotated(_rot) + _off) * SCALE + HIP


## Ellipse: local Y follows the part, so patterns rotate with it.
func _ellipse(c: Vector2, radii: Vector2, axis: Vector2, code: int,
		shade: float = 1.0, cap: float = 1.0) -> void:
	_raster(c, axis, radii, code, shade, 0, cap)


## Rounded, tapered cylinders; ends are real hemispheres, not thick lines.
func _capsule(a: Vector2, b: Vector2, r0: float, r1: float, code: int,
		shade: float = 1.0) -> void:
	var delta := b - a
	_raster(a, delta.normalized(), Vector2(r0, r1), code, shade, 1, delta.length())


## kind 0 ellipse, 1 tapered capsule, 2 fitted tunic, 3 pointed blade.
func _raster(c: Vector2, axis: Vector2, size: Vector2, code: int,
		shade: float, kind: int, extent: float) -> void:
	var center := _tx(c)
	var along := axis.rotated(_rot)
	var across := Vector2(along.y, -along.x)
	var reach := maxf(size.x, size.y)
	if kind == 1:
		reach += extent
	var lo := Vector2i((center - Vector2.ONE * (reach * SCALE + 1.0)) * SS)
	var hi := Vector2i((center + Vector2.ONE * (reach * SCALE + 1.0)) * SS)
	for y in range(maxi(0, lo.y), mini(FH * SS, hi.y + 1)):
		for x in range(maxi(0, lo.x), mini(FW * SS, hi.x + 1)):
			var d := (Vector2(x + 0.5, y + 0.5) / SS - center) / SCALE
			var q := Vector2(d.dot(across), d.dot(along))
			var uv := Vector2.ZERO
			var round_x := 0.0
			var edge := 0.0
			if kind == 0:
				var n := q / size
				if n.length_squared() > 1.0 or n.y > extent:
					continue
				uv = n * 0.5 + Vector2.ONE * 0.5
				round_x = n.x
				edge = n.length()
			elif kind == 1:
				var t := clampf(q.y / extent, 0.0, 1.0)
				var radius := lerpf(size.x, size.y, t)
				var dist := Vector2(q.x, q.y - t * extent).length() / radius
				if dist > 1.0:
					continue
				uv = Vector2(q.x / radius * 0.5 + 0.5,
					(q.y + size.x) / (extent + size.x + size.y))
				round_x = q.x / radius
				edge = dist
			else:
				var t := q.y / size.y * 0.5 + 0.5
				if t < 0.0 or t > 1.0:
					continue
				var width := size.x
				if kind == 2:
					# Shoulders, cinched waist, flared hem, rounded shoulder corners.
					width *= (0.76 + 0.24 * cos(t * TAU))
					width *= sqrt(clampf(t / 0.055, 0.0, 1.0))
				else:
					width *= minf(1.0, (1.0 - t) * 5.0)
				if absf(q.x) > width:
					continue
				round_x = q.x / maxf(width, 0.001)
				uv = Vector2(round_x * 0.5 + 0.5, t)
				edge = absf(round_x)
			# Broad curved highlight on the left, narrow shaded right silhouette.
			var light := shade * (0.79 + 0.27 * sqrt(maxf(0.0, 1.0 - round_x * round_x))
				- round_x * 0.10 - 0.035 * (uv.y - 0.5))
			light *= lerpf(1.0, 0.84, smoothstep(0.83, 1.0, edge))
			var idx := y * FW * SS + x
			_owners[idx] = code
			_uvs[idx] = uv
			_lights[idx] = clampf(light, 0.6, 1.3)


func _resolve() -> Image:
	var img := Image.create(FW, FH, false, Image.FORMAT_RGBA8)
	for y in FH:
		for x in FW:
			var votes := PackedInt32Array()
			votes.resize(BELT + 1)
			var covered := 0
			for sy in SS:
				for sx in SS:
					var code := _owners[(y * SS + sy) * FW * SS + x * SS + sx]
					votes[code] += 1
					if code > 0:
						covered += 1
			if covered == 0:
				continue
			var winner := 1
			for code in range(2, BELT + 1):
				if votes[code] > votes[winner]:
					winner = code
			var uv := Vector2.ZERO
			var light := 0.0
			for sy in SS:
				for sx in SS:
					var idx := (y * SS + sy) * FW * SS + x * SS + sx
					if _owners[idx] == winner:
						uv += _uvs[idx]
						light += _lights[idx]
			uv = part_uv(winner, uv / votes[winner])
			light /= votes[winner]
			var b := (light - 0.6) / 0.8 if light <= 1.0 else 0.5 + (light - 1.0) / 0.6
			img.set_pixel(x, y, Color(uv.x, uv.y, b, covered / float(SS * SS)))
	# Extrude UV/light into transparent texels for the coverage filter's fringe.
	# Never bleed into another frame or average unrelated part UVs.
	var src: Image = img.duplicate()
	for y in FH:
		for x in FW:
			if src.get_pixel(x, y).a > 0.0:
				continue
			var best := 0.0
			var value := Color(0, 0, 0, 0)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var p := Vector2i(x + dx, y + dy)
					if p.x < 0 or p.y < 0 or p.x >= FW or p.y >= FH:
						continue
					var c := src.get_pixelv(p)
					if c.a > best:
						best = c.a
						value = Color(c.r, c.g, c.b, 0)
			img.set_pixel(x, y, value)
	return img


func _render(p: Dictionary) -> void:
	_owners.resize(FW * FH * SS * SS)
	_owners.fill(0)
	_uvs.resize(_owners.size())
	_lights.resize(_owners.size())
	_rot = p.rot
	_off = Vector2(p.ox, p.oy)
	var hip := Vector2(0, p.dy)
	var up := _dir(PI - p.lean)
	var fwd := Vector2(-up.y, up.x)
	var neck := hip + up * 7.0
	var head := neck + up * 3.0
	var shoulder := neck - up * 1.1

	_leg(hip - fwd * 0.85, p.bt, p.bs, FAR)
	var elbow := shoulder + _dir(p.fu) * 3.2
	var hand := elbow + _dir(p.fu + p.fl) * 3.2
	_capsule(shoulder, elbow, 1.25, 1.0, TUNIC, FAR)
	_capsule(elbow, hand, 0.85, 0.7, TUNIC, FAR)
	# Sword is drawn above the far arm so windup and contact remain legible.
	var sw := _dir(p.sw)
	_capsule(hand - sw * 1.25, hand + sw * 0.8, 0.45, 0.4, HILT, 0.92)
	_raster(hand + sw * 4.65, sw, Vector2(0.58, 3.65), BLADE, 1.16, 3, 1.0)
	_capsule(hand + sw * 0.9 - sw.orthogonal() * 1.4,
		hand + sw * 0.9 + sw.orthogonal() * 1.4, 0.32, 0.32, HILT, 1.1)
	_ellipse(hand - sw * 1.35, Vector2(0.58, 0.58), sw, RIM)
	_ellipse(hand, Vector2(0.8, 0.95), _dir(p.fu + p.fl), SKIN, FAR)

	_leg(hip + fwd * 0.8, p.ft, p.fs, 1.0)
	_raster(hip + up * 3.3, -up, Vector2(2.85, 4.2), TUNIC, 1.0, 2, 1.0)
	var belt := hip + up * 1.25
	_capsule(belt - fwd * 2.1, belt + fwd * 2.1, 0.38, 0.38, BELT)
	_ellipse(belt + fwd * 0.6, Vector2(0.45, 0.45), -up, RIM, 1.1)
	_capsule(neck - up * 0.5, neck + up * 1.5, 1.0, 1.0, SKIN)
	_ellipse(head, Vector2(3.0, 3.25), -up, SKIN)
	_ellipse(head + fwd * 2.75 - up * 0.6, Vector2(0.68, 0.75), -up, SKIN)
	_ellipse(head, Vector2(3.25, 3.4), -up, HELM, 1.03, 0.0)
	_capsule(head - fwd * 2.9, head + fwd * 2.8, 0.27, 0.27, HELM, 0.85)
	_ellipse(head + fwd * 1.9 - up * 0.65, Vector2(0.38, 0.35), -up, EYE, 1.2)

	elbow = shoulder + _dir(p.nu) * 3.25
	hand = elbow + _dir(p.nu + p.nl) * 3.0
	_capsule(shoulder, elbow, 1.25, 1.0, TUNIC)
	_ellipse(shoulder, Vector2(1.55, 1.25), -up, HELM)
	_capsule(elbow, hand, 0.88, 0.7, TUNIC)
	_ellipse(hand, Vector2(0.8, 0.9), _dir(p.nu + p.nl), SKIN)
	var shield_axis := (-up).rotated(p.sh)
	var sc := hand + fwd * 0.75
	anchors.append(_tx(sc))
	if draw_shield:
		_ellipse(sc, Vector2(2.85, 4.2), shield_axis, RIM, 0.96)
		_ellipse(sc, Vector2(2.36, 3.65), shield_axis, SHIELD, 1.03)
		_ellipse(sc, Vector2(0.6, 0.68), shield_axis, RIM, 1.15)


func _leg(h: Vector2, thigh: float, shin: float, shade: float) -> void:
	var knee := h + _dir(thigh) * 4.5
	var foot := knee + _dir(thigh + shin) * 4.0
	_capsule(h, knee, 1.22, 1.0, PANTS, shade)
	_capsule(knee, foot, 0.93, 0.75, PANTS, shade)
	var toe := Vector2(cos(thigh + shin), -sin(thigh + shin))
	_capsule(foot - _dir(thigh + shin) * 0.55, foot + toe * 1.1, 0.8, 0.75, BELT, shade)


# ---------- Part sheet: four original looks, 4x4 material slots per look ----------

static func make_parts(palettes: Array) -> Image:
	var img := Image.create(LOOK_PX * LOOK_GRID.x, LOOK_PX * LOOK_GRID.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.18, 0.23, 1))
	for look in palettes.size():
		var origin := Vector2i(look % LOOK_GRID.x, look / LOOK_GRID.x) * LOOK_PX
		var colors: Dictionary = palettes[look]
		for code in range(SKIN, BELT + 1):
			var slot := Vector2i((code - 1) % PART_GRID, (code - 1) / PART_GRID) * PART_PX
			for y in PART_PX:
				for x in PART_PX:
					# Replicated 3px gutters keep linear filtering inside a material.
					var uv := (Vector2(x, y) - Vector2.ONE * PART_PAD) / (PART_PX - PART_PAD * 2.0 - 1.0)
					uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
					var col := _part_color(look, code, uv, colors)
					# Alpha is DATA here, not opacity: smooth deterministic blood field.
					var n := (sin(uv.x * 11.0 + sin(uv.y * 9.0) * 1.6 + code * 1.7)
						+ sin(uv.y * 13.0 - uv.x * 7.0 + code)
						+ sin(uv.x * 27.0 + uv.y * 19.0) * 0.22) / 2.22
					col.a = clampf(0.5 + n * 0.46, 0.04, 0.96)
					img.set_pixelv(origin + slot + Vector2i(x, y), col)
	return img


static func _part_color(look: int, code: int, uv: Vector2, colors: Dictionary) -> Color:
	var col: Color = colors[code]
	var u := uv.x
	var v := uv.y
	var metal := code == HELM or code == BLADE or code == RIM
	var grain := sin(u * 143.0 + v * 79.0) * sin(v * 177.0 - u * 47.0)
	var light := 1.0 + grain * (0.014 if metal else 0.025)
	if code == SKIN:
		light *= 1.05 - v * 0.12 + 0.035 * sin(u * PI)
		col = col.lerp(Color(0.45, 0.52, 0.53) if look >= 2 else Color(0.7, 0.39, 0.3), smoothstep(0.7, 1.0, v) * 0.13)
	elif code == TUNIC:
		light *= 0.92 + sin(u * 25.0 + sin(v * 6.0) * 1.8) * 0.075 + sin(u * 43.0 + v * 7.0) * 0.025
		# Light collar and hem; veteran gold seams, spectral elite teal trim.
		var trim: Color = colors[RIM] if look % 2 == 1 else colors[SHIELD].lightened(0.15)
		if v < 0.1 or v > 0.88 or absf(u - 0.5) < 0.025:
			col = col.lerp(trim, 0.85)
		if look == 0 and u < 0.28:
			col = col.lerp(Color(0.86, 0.85, 0.78), 0.9)
	elif code == PANTS:
		light *= 0.88 + 0.12 * sin(u * PI) + 0.04 * sin(u * 23.0 + v * 9.0)
		if u > 0.83:
			light *= 0.8
	elif metal:
		light *= 0.72 + 0.24 * sin(u * PI) + 0.3 * exp(-pow((u - 0.29) / 0.12, 2.0))
		if code == BLADE:
			light *= 1.05
			if absf(u - 0.48) < 0.055 or u < 0.1:
				col = col.lerp(Color(0.96, 0.99, 1.0), 0.75)
			if u > 0.58:
				light *= 0.78
		elif code == HELM:
			if v > 0.4 and v < 0.47:
				col = col.lerp(colors[RIM], 0.65)
			if absf(u - 0.5) < 0.025:
				light *= 0.74
		else:
			light += 0.09 * sin(v * 18.0)
	elif code == HILT or code == BELT:
		light *= 0.86 + 0.1 * sin(v * 52.0) + 0.1 * sin(u * PI)
		if code == BELT and (u < 0.12 or u > 0.9):
			light *= 0.76
	elif code == SHIELD:
		light *= 0.92 + 0.045 * sin(u * 47.0) + 0.025 * sin(u * 93.0 + v * 4.0)
		var d := uv - Vector2(0.5, 0.5)
		var emblem := false
		if look == 0:
			# A broad ivory chevron and small bar on a blue field.
			col = colors[TUNIC].lerp(colors[SHIELD], 0.1)
			emblem = absf(v - (0.29 + absf(d.x) * 0.7)) < 0.06 and absf(d.x) < 0.34
			emblem = emblem or (absf(v - 0.72) < 0.045 and absf(d.x) < 0.2)
		elif look == 1:
			# Gold stepped tower with two crenels on a crimson field.
			emblem = absf(d.x) < 0.12 and v > 0.29 and v < 0.76
			emblem = emblem or (absf(d.x) < 0.24 and v > 0.24 and v < 0.37 and absf(d.x) > 0.055)
			emblem = emblem or (absf(d.x) < 0.22 and v > 0.72 and v < 0.78)
		elif look == 2:
			# Bone-white forked sigil, split by a small irregular crack.
			emblem = absf(d.x) < 0.04 and absf(d.y) < 0.31
			emblem = emblem or (absf(absf(d.x) - (0.28 - v) * 0.7 - 0.10) < 0.036 and v < 0.4 and v > 0.19)
			emblem = emblem or (absf(d.y - 0.12) + absf(d.x) * 0.6 < 0.055)
		else:
			# An open angular lozenge with an inner spectral bar.
			emblem = absf(absf(d.x) * 1.1 + absf(d.y) * 0.72 - 0.24) < 0.035
			emblem = emblem or (absf(d.x) < 0.035 and absf(d.y) < 0.13)
		if emblem:
			col = Color(0.84, 0.86, 0.74) if look == 2 else colors[RIM].lightened(0.25)
			if look == 0:
				col = Color(0.94, 0.91, 0.77)
		if look >= 2 and absf(u - (0.72 + sin(v * 21.0) * 0.035)) < 0.012:
			light *= 0.45
	elif code == EYE:
		col = colors[EYE]
		light = 1.0
	return Color(clampf(col.r * light, 0.0, 1.0), clampf(col.g * light, 0.0, 1.0), clampf(col.b * light, 0.0, 1.0))
