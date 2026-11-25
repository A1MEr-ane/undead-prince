extends RefCounted
## 只读历史记录。hurt 回调即时记录，避免高倍速下遗漏两次 refresh 之间的伤亡。
const DEFAULTS := "res://proto/siege/camera/map_camera.json"
const IDS := ["coast", "highland", "plaza", "keep"]
var world
var cfg: Dictionary
var mode := "zones"
var current := "coast"
var alerts: Array = []
var switches: Array = []
var latest := {}
var counts := {}
var seen := {}
var last_attack := {}
var decision_cursor := 0
var topology_cursor := 0
var saved := false
var view_usec: Array = []
var frame_msec: Array = []

func setup(main) -> void:
	world = main
	cfg = JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS)).map.camera
	if world.params.map.has("camera"):
		world.merge_params(cfg, world.params.map.camera)
	mode = world.args.get("camera_mode", cfg.mode)
	current = world.args.get("zone", cfg.initial_zone)
	if not IDS.has(current): current = "coast"
	for id in IDS:
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
	for id in IDS:
		counts[id] = [0, 0]
	for u in world.units:
		if u.alive and not u.escaped and u.cave_until < 0:
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
		if e.reason in ["gate_breached", "weak_wall_breached"]:
			var zone := "plaza" if e.reason == "gate_breached" else "highland"
			add_alert(zone, "breach", "城门被破" if e.reason == "gate_breached" else "薄弱城墙被破", e.time)
	for id in IDS:
		for field in ["captures", "losses"]:
			var history: Array = world.zones[id][field]
			while int(seen[id][field]) < history.size():
				add_alert(id, "capture" if field == "captures" else "loss", "战区已攻占" if field == "captures" else "战区已失守", history[int(seen[id][field])])
				seen[id][field] += 1

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"samples": 0}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for v in ordered: total += float(v)
	return {"samples": ordered.size(), "mean": total / ordered.size(), "p95": ordered[mini(ordered.size() - 1, floori(ordered.size() * 0.95))], "max": ordered.back()}

func save(directory: String) -> void:
	saved = true
	DirAccess.make_dir_recursive_absolute(directory)
	var report := {"mode": mode, "seed": world.seed_value, "strategy": world.strategy,
		"simulation_seconds": world.ended_at, "switches": switches, "switch_count": switches.size(),
		"alerts": alerts, "unacknowledged": alerts.filter(func(a): return float(a.acknowledged_at) < 0).size(),
		"view_update_usec": stats(view_usec), "frame_interval_msec": stats(frame_msec),
		"headless": world.headless, "note": "自动巡览切换量不代表玩家均值；未确认提醒不等于玩家漏看。帧间隔含模拟/渲染/限帧/截图。"}
	var stream := FileAccess.open(directory.path_join("camera_metrics.json"), FileAccess.WRITE)
	if stream != null: stream.store_string(JSON.stringify(report, "\t"))
	print("CAMERA_METRICS " + JSON.stringify({"mode": mode, "switches": switches.size(), "alerts": alerts.size(), "path": directory.path_join("camera_metrics.json")}))
