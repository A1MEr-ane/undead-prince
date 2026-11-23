class_name SpriteFactory
extends RefCounted
## 程序化生成剑盾兵的部位编码帧图集。
## 每个像素：R = 部位编号/15，G = 明暗系数，A = 是否不透明。
## 着色器按 (部位, 调色板行) 查颜色，所以阵营、等级、亡魂版本共用同一套帧。

const FW := 32
const FH := 32
const COLS := 8
const HIP := Vector2(16, 21)

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
const OUTLINE := 15

const FAR := 0.68  # 远侧肢体压暗

var codes := PackedByteArray()
var shades := PackedFloat32Array()
var _rot := 0.0
var _off := Vector2.ZERO


static func build() -> Dictionary:
	var f := SpriteFactory.new()
	return f._build()


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
	var rows := int(ceil(poses.size() / float(COLS)))
	var img := Image.create(COLS * FW, rows * FH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in poses.size():
		_render(poses[i])
		_outline()
		var ox := (i % COLS) * FW
		var oy := (i / COLS) * FH
		for y in FH:
			for x in FW:
				var c := codes[y * FW + x]
				if c > 0:
					img.set_pixel(ox + x, oy + y, Color(c / 15.0, shades[y * FW + x], 0.0, 1.0))
	return {"image": img, "anims": anims, "grid": Vector2(COLS, rows), "count": poses.size()}


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
		_p({"dy": 1.0, "sw": 2.78, "nl": 0.7}),
		_p({"dy": 1.0, "sw": 2.74, "nl": 0.7}),
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
			"dy": round(-1.0 * abs(cos(ph))),
		}))
	return out


func _attack() -> Array:
	return [
		_p({"lean": -0.1, "fu": PI - 0.5, "fl": -0.5, "sw": PI + 0.7, "ft": 0.3, "bt": -0.3}),
		_p({"lean": -0.2, "fu": PI - 0.25, "fl": -0.4, "sw": PI + 1.15, "ft": 0.35, "bt": -0.35}),
		_p({"lean": -0.22, "fu": PI - 0.2, "fl": -0.4, "sw": PI + 1.25, "ft": 0.35, "bt": -0.35, "dy": 1.0}),
		_p({"lean": 0.28, "fu": 1.9, "fl": -0.2, "sw": 1.75, "ft": 0.75, "fs": -0.2, "bt": -0.5, "nu": 0.0}),
		_p({"lean": 0.35, "fu": 1.3, "fl": 0.0, "sw": 1.0, "ft": 0.85, "fs": -0.3, "bt": -0.6, "dy": 1.0, "nu": -0.1}),
		_p({"lean": 0.12, "fu": 0.8, "fl": -0.4, "sw": 2.0, "ft": 0.4, "bt": -0.3}),
	]


func _block() -> Array:
	return [
		_p({"lean": -0.12, "nu": 1.45, "nl": 0.1, "ft": 0.35, "bt": -0.35, "sw": 2.5}),
		_p({"lean": -0.22, "nu": 1.35, "nl": 0.15, "ft": 0.4, "bt": -0.4, "sw": 2.6, "dy": 1.0}),
	]


func _clash() -> Array:
	return [
		_p({"lean": 0.22, "fu": 1.7, "fl": -0.7, "sw": 2.25, "ft": 0.55, "bt": -0.5, "nu": 0.9}),
		_p({"lean": 0.05, "fu": 1.4, "fl": -0.9, "sw": 2.65, "ft": 0.45, "bt": -0.45, "nu": 0.7, "dy": 1.0}),
	]


func _hit() -> Array:
	return [
		_p({"lean": -0.45, "nu": -0.5, "nl": 0.3, "fu": -0.4, "fl": -0.5, "sw": 3.7, "ft": 0.45, "bt": 0.1, "dy": 1.0}),
		_p({"lean": -0.25, "nu": -0.2, "fu": -0.1, "fl": -0.6, "sw": 3.3, "ft": 0.35, "bt": 0.0}),
	]


func _tumble() -> Array:
	var out := []
	for i in 6:
		out.append(_p({
			"lean": 0.5, "ft": 1.7, "fs": -2.4, "bt": 1.4, "bs": -2.2,
			"nu": 1.3, "nl": 1.0, "fu": 1.0, "fl": 1.2, "sw": 1.2,
			"rot": i * TAU / 6.0, "oy": -5.0,
		}))
	return out


func _down_pose() -> Dictionary:
	return _p({"rot": -PI / 2.0, "ox": 2.0, "oy": 8.0, "ft": 0.05, "bt": -0.08, "nu": 0.4, "nl": 0.2, "fu": 0.8, "fl": 0.3, "sw": 1.6})


func _getup() -> Array:
	return [
		_down_pose(),
		_p({"rot": -1.0, "ox": 1.0, "oy": 8.0, "ft": 0.6, "bt": 0.5, "nu": 0.9, "fu": 0.6, "sw": 2.0}),
		_p({"lean": 0.3, "ft": 1.5, "fs": -1.5, "bt": 0.9, "bs": -2.4, "oy": 5.0, "nu": 0.6, "sw": 2.3}),
		_p({"lean": 0.15, "ft": 0.6, "fs": -0.9, "bt": -0.3, "bs": -0.6, "oy": 2.0, "sw": 2.5}),
	]


func _dead() -> Array:
	return [
		_p({"lean": 0.75, "ft": 1.5, "fs": -1.5, "bt": 0.9, "bs": -2.4, "oy": 5.0, "nu": 0.1, "fu": 0.2, "fl": 0.0, "sw": 0.4}),
		_p({"rot": PI / 2.0, "ox": -2.0, "oy": 8.0, "ft": 0.1, "bt": -0.1, "nu": 2.8, "nl": 0.0, "fu": 2.5, "fl": 0.2, "sw": 2.6}),
	]


# ---------- 光栅化 ----------

func _dir(a: float) -> Vector2:
	return Vector2(sin(a), cos(a))


func _tx(v: Vector2) -> Vector2:
	return v.rotated(_rot) + HIP + _off


func _stamp(c: Vector2, r: float, code: int, shade: float) -> void:
	for y in range(floori(c.y - r - 1), ceili(c.y + r + 1)):
		for x in range(floori(c.x - r - 1), ceili(c.x + r + 1)):
			if x < 0 or y < 0 or x >= FW or y >= FH:
				continue
			if (Vector2(x + 0.5, y + 0.5) - c).length() <= r + 0.2:
				codes[y * FW + x] = code
				shades[y * FW + x] = shade


func _line(a: Vector2, b: Vector2, w: float, code: int, shade: float) -> void:
	var ta := _tx(a)
	var tb := _tx(b)
	var steps := maxi(1, ceili(ta.distance_to(tb) * 2.0))
	for i in steps + 1:
		_stamp(ta.lerp(tb, float(i) / steps), w * 0.5, code, shade)


func _disc(c: Vector2, r: float, code: int, shade: float) -> void:
	_stamp(_tx(c), r, code, shade)


## 只覆盖圆的一侧（头盔）。
func _cap(c: Vector2, r: float, axis: Vector2, code: int) -> void:
	var tc := _tx(c)
	var ta := axis.rotated(_rot)
	for y in range(floori(tc.y - r - 1), ceili(tc.y + r + 1)):
		for x in range(floori(tc.x - r - 1), ceili(tc.x + r + 1)):
			if x < 0 or y < 0 or x >= FW or y >= FH:
				continue
			var d := Vector2(x + 0.5, y + 0.5) - tc
			if d.length() <= r + 0.2 and d.dot(ta) > 0.2:
				codes[y * FW + x] = code


func _render(p: Dictionary) -> void:
	codes.resize(FW * FH)
	codes.fill(0)
	shades.resize(FW * FH)
	shades.fill(1.0)
	_rot = p.rot
	_off = Vector2(p.ox, p.oy)
	var hip := Vector2(0, p.dy)
	var tdir := _dir(PI - p.lean)          # 躯干朝上方向
	var fwd := Vector2(-tdir.y, tdir.x)     # 躯干朝前方向
	var neck := hip + tdir * 7.0
	var head := neck + tdir * 3.0
	var shoulder := neck - tdir * 1.0

	# 远侧：持剑手臂 + 剑
	var f_el := shoulder + _dir(p.fu) * 3.5
	var f_hand := f_el + _dir(p.fu + p.fl) * 3.5
	var sw := _dir(p.sw)
	_line(f_hand + sw * 1.0, f_hand + sw * 9.0, 1.2, BLADE, 1.0)
	_line(f_hand - sw * 1.5, f_hand + sw * 1.0, 1.4, HILT, FAR)
	var guard := f_hand + sw
	_line(guard + sw.orthogonal() * 1.4, guard - sw.orthogonal() * 1.4, 1.0, HILT, FAR)
	_line(shoulder, f_el, 2.0, TUNIC, FAR)
	_line(f_el, f_hand, 1.8, TUNIC, FAR)
	_disc(f_hand, 1.0, SKIN, FAR)

	# 远侧腿
	_leg(hip + Vector2(-0.8, 0), p.bt, p.bs, FAR)

	# 躯干
	_line(hip, neck, 4.6, TUNIC, 1.0)
	_disc(hip + tdir * 0.3, 2.6, TUNIC, 1.0)
	var belt := hip + tdir * 1.4
	_line(belt - fwd * 2.2, belt + fwd * 2.2, 1.0, BELT, 1.0)

	# 头
	_disc(head, 3.0, SKIN, 1.0)
	_cap(head, 3.0, tdir, HELM)
	_disc(head + fwd * 1.6 - tdir * 0.2, 0.45, EYE, 1.0)
	_disc(head + fwd * 3.0 - tdir * 0.6, 0.4, SKIN, 1.0)

	# 近侧腿
	_leg(hip + Vector2(0.8, 0), p.ft, p.fs, 1.0)

	# 近侧：持盾手臂 + 盾
	var n_el := shoulder + _dir(p.nu) * 3.5
	var n_hand := n_el + _dir(p.nu + p.nl) * 3.3
	_line(shoulder, n_el, 2.0, TUNIC, 1.0)
	_disc(shoulder, 1.6, HELM, 1.0)
	var axis := _dir(PI - p.lean + p.sh)
	var sc := n_hand + fwd * 0.6
	_line(sc - axis * 3.8, sc + axis * 3.8, 4.4, RIM, 1.0)
	_line(sc - axis * 3.0, sc + axis * 3.0, 2.6, SHIELD, 1.0)
	_disc(sc, 0.7, RIM, 1.0)


func _leg(h: Vector2, thigh: float, shin: float, shade: float) -> void:
	var knee := h + _dir(thigh) * 5.0
	var foot := knee + _dir(thigh + shin) * 4.6
	_line(h, knee, 2.3, PANTS, shade)
	_line(knee, foot, 2.0, PANTS, shade)
	var a := thigh + shin
	_line(foot, foot + Vector2(cos(a), -sin(a)) * 1.6, 1.6, BELT, shade)


func _outline() -> void:
	var src := codes.duplicate()
	for y in FH:
		for x in FW:
			if src[y * FW + x] != 0:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < FW and ny < FH and src[ny * FW + nx] != 0:
					near = true
					break
			if near:
				codes[y * FW + x] = OUTLINE
				shades[y * FW + x] = 1.0
