extends SceneTree
func _initialize() -> void:
	for path in ["res://proto/siege/siege_events.gd", "res://proto/siege/siege_metrics.gd"]:
		var file := FileAccess.open(path + ".uid", FileAccess.WRITE)
		file.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
	quit()
