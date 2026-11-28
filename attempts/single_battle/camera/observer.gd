extends RefCounted
## 只读历史记录。hurt 回调即时记录，避免高倍速下遗漏两次 refresh 之间的伤亡。
var ids: Array[String] = []
var world
var cfg: Dictionary
var current := "coast"
var alerts: Array = []
var switches: Array = []
var latest := {}
var counts := {}
var seen := {}
var last_attack := {}
var decision_cursor := 0
var topology_cursor := 0

func setup(main) -> void:
	world = main
	cfg = world.params.map.camera
	for zone in world.params.map.zones:
		ids.append(zone.id)
	current = world.args.get("zone", cfg.initial_zone)
	if not ids.has(current):
		current = ids[0]
	for id in ids:
		counts[id] = [0, 0]
		seen[id] = {"captures": 0, "losses": 0}
	world.hooks.subscribe("hurt", on_hurt)

func on_hurt(payload: Dictionary) -> void:
	var zone: String = world.terrain.zone_at(payload.unit.nav_pos)
	if world.time - float(last_attack.get(zone, -100.0)) < float(cfg.alert_cooldown):
		return
	last_attack[zone] = world.time
	add_alert(zone, "attack", "遭到攻击", world.time)

func add_alert(zone: String, kind: String, message: String, at: float) -> void:
	var offscreen := zone != current
	var item := {"zone": zone, "kind": kind, "message": message, "time": at,
		"offscreen": offscreen, "acknowledged_at": -1.0 if offscreen else at}
	alerts.append(item)
	if offscreen:
		var priority := {"attack": 0, "reinforcement": 1, "breach": 2, "capture": 3, "loss": 4}
		if not latest.has(zone) or int(priority[kind]) >= int(priority[latest[zone].kind]):
			latest[zone] = item

func visit(zone: String, source: String) -> void:
	if zone != current:
		switches.append({"time": world.time, "from": current, "to": zone, "source": source})
	current = zone
	for item in alerts:
		if item.zone == zone and float(item.acknowledged_at) < 0:
			item.acknowledged_at = world.time
	latest.erase(zone)

func poll() -> void:
	for id in ids:
		counts[id] = [0, 0]
	for u in world.units:
		if u.targetable() and not u.escaped:
			var zone: String = world.terrain.zone_at(u.nav_pos)
			counts[zone][u.faction] += 1
	while decision_cursor < world.director.decisions.size():
		var d: Dictionary = world.director.decisions[decision_cursor]
		decision_cursor += 1
		if d.event == "depart":
			# 同批同路线出发合为一条提醒；箭头仍按实际行军单位绘制。
			var key := "%s:%s:%s" % [d.time, d.from, d.to]
			if not seen.has(key):
				seen[key] = true
				var message := "%s增援出发 → %s" % [cfg.zones[d.from].label, cfg.zones[d.to].label]
				add_alert(d.from, "reinforcement", message, d.time)
				if d.to != d.from:
					add_alert(d.to, "reinforcement", message, d.time)
	while topology_cursor < world.terrain.topology_events.size():
		var e: Dictionary = world.terrain.topology_events[topology_cursor]
		topology_cursor += 1
		if e.reason.ends_with("_breached"):
			var id: String = e.reason.trim_suffix("_breached")
			var rect: Array = world.params.map.weak_rect
			if id == "gate":
				rect = world.params.map.gate_rect
			elif world.phase_b.walls.has(id):
				rect = world.phase_b.walls[id].rect
			var center := Vector3(float(rect[0]) + float(rect[2]) * 0.5, 0, float(rect[1]) + float(rect[3]) * 0.5)
			var zone: String = world.terrain.zone_at(center - Vector3.BACK * 0.75)
			add_alert(zone, "breach", "城门告破" if id == "gate" else "城墙告破", e.time)
	for id in ids:
		for field in ["captures", "losses"]:
			var history: Array = world.zones[id][field]
			while int(seen[id][field]) < history.size():
				add_alert(id, "capture" if field == "captures" else "loss", "战区已攻占" if field == "captures" else "战区已失守", history[int(seen[id][field])])
				seen[id][field] += 1

func zone_status(id: String) -> String:
	var state: Dictionary = world.zones[id]
	var count: Array = counts[id]
	if count[0] > 0 and count[1] > 0:
		return "交战中"
	if state.owner == "ghost":
		return "守军夺回中" if state.retake > 0.0 else "已攻占"
	return "亡灵攻占中" if state.progress > 0.0 else "守军驻防"
