extends SceneTree
## 独立计时首次真实调度；显式开启全图感知，确保 T69 后仍有实际派兵决定。

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var baseline := OS.get_cmdline_user_args().has("--baseline")
	var path := "res://proto/siege/perf/perf_runner.tscn"
	if baseline:
		path = "res://proto/siege/perf/results/t73/baseline_source/perf/perf_runner.tscn"
	var scene = load(path)
	var rows: Array = []
	for repeat in 3:
		var started := Time.get_ticks_usec()
		var probe = scene.instantiate()
		root.add_child(probe)
		probe.set_process(false)
		var world = probe.main
		world.params.director.global_perception = true
		world.rebuild_spatial()
		var setup_us := Time.get_ticks_usec() - started
		var t := Time.get_ticks_usec()
		world.director.tick()
		var elapsed := Time.get_ticks_usec() - t
		var decisions: Array = world.director.decisions.duplicate(true)
		var ordered := 0
		for event in decisions:
			if event.event == "ordered":
				ordered += event.units.size()
		rows.append({"setup_ms": float(setup_us) / 1000.0, "director_ms": float(elapsed) / 1000.0,
			"units": world.units.size(), "ordered": ordered, "decisions": decisions})
		probe.free()
		if ordered == 0:
			printerr("DIRECTOR_BENCH FAIL no actual orders")
			quit(1)
			return
	print("DIRECTOR_BENCH " + JSON.stringify({"baseline": baseline, "global_perception": true, "repeats": rows}))
	quit(0)
