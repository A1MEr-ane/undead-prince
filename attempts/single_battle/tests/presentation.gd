extends SceneTree
## Builds the real view under the headless driver to verify camera, input and asset hookup.

const Battle := preload("res://attempts/single_battle/main.tscn")
const View := preload("res://attempts/single_battle/siege_view.gd")
const Assets := preload("res://attempts/single_battle/battle_assets.gd")
const Sprites := preload("res://attempts/single_battle/battle_sprites.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	root.size = Vector2i(1280, 720)
	var world = Battle.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.bot = null
	var view := View.new()
	world.add_child(view)
	view.setup(world)
	await process_frame
	check(view.clock_label.text.ends_with("05:00"), "the HUD starts at five minutes")
	check(view.unit_cards.size() == 4 and view.fire_bar.value == world.fire, "four cards and the fire gauge use the scene state")
	var coast: Transform3D = view.camera.transform
	var landing: Vector3 = world.terrain.vec(world.params.strategies.deploy_points.main)
	landing.y = world.terrain.height_at(landing)
	check(view.mouse_world(view.camera.unproject_position(landing)).distance_to(landing) < 0.02, "the landing in view is pickable")
	view.map_button.pressed.emit()
	await process_frame
	await process_frame
	check(view.expanded and view.overview.visible and view.overview.map_rect.has_area(), "the map button opens the drawn overview")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = view.overview.map_point(world.zone_point("highland"))
	view.overview.on_input(click)
	check(view.observer.current == "highland" and not view.expanded and view.camera.transform != coast,
		"clicking the highland on the map selects its fixed camera")
	check(world.pending_inputs.is_empty() and not world.manual_deploy_held, "map interaction cannot issue ground commands")
	view.zone_buttons.coast.pressed.emit()
	check(view.camera.transform.is_equal_approx(coast), "returning to the coast restores the same fixed camera")
	view.unit_cards.ghost.pressed.emit()
	click.position = view.camera.unproject_position(landing)
	view._unhandled_input(click)
	for step in 12:
		world.simulate()
	click.pressed = false
	view._input(click)
	var deployed: int = world.spawned[0]
	for step in 12:
		world.simulate()
	check(deployed >= 2 and world.spawned[0] == deployed, "the deployment card repeats while held and stops on release")
	var has_terrain := FileAccess.file_exists(Assets.NAVIGATION)
	check((view.field.imported != null) == has_terrain, "asset presence selects the matching terrain presentation")
	if has_terrain:
		var hill := Vector3(9.5, 0, 32.5)
		hill.y = world.terrain.height_at(hill)
		check(is_equal_approx(hill.y, view.field.imported.height_at(hill)) and hill.y > float(world.params.map.base_height),
			"simulation and T85 use the same ramp height")
		world.terrain.gate_open = true
		world.terrain.change(world.params.map.gate_rect, true, world.time, "defender_opened_gate")
		view.field.sync()
		check(view.field.imported.get_node("gate/open").visible, "T85 gate follows navigation state")
		var giant = world.spawn("giant", 0, Vector3(13.5, 0, 24.5), "highland")
		giant.objective = "weak"
		world.weak_hp = 0.01
		world.attack_structures(float(world.params.simulation.step))
		view.field.sync()
		check(view.field.imported.get_node("weak_wall/breached").visible, "T85 weak wall follows the simulation breach")
	for kind in Sprites.FOLDERS:
		var id: String = Sprites.FOLDERS[kind]
		var path := Sprites.UNITS.path_join(id).path_join(id)
		var exists := FileAccess.file_exists(path + "_uv.json") and FileAccess.file_exists(path + "_ink.png")
		check(view.sprites.atlases.has(kind) == exists, "atlas or sample is selected for " + id)
		check(view.sprites.appearance(kind, "walk", 0.2).texture != null, "a display frame exists for " + id)
	if view.sprites.atlases.has("ghost"):
		var pile := view.sprites.clip_for("ghost", "bone_pile")
		check(pile.tiles.size() == 2 and pile.loop, "the T82 skeleton uses its bone pile frames")
	world.time = 300.0
	world.resolve_outcome()
	view.refresh()
	check(view.clock_label.text.ends_with("00:00") and view.end_panel.visible and world.outcome == world.Outcome.LOST,
		"dawn stops deployment and displays the defeat result")
	print("T86 PRESENTATION: %d failures, terrain=%s, atlases=%d/%d" % [failures,
		"T85" if has_terrain else "graybox", view.sprites.atlases.size(), Sprites.FOLDERS.size()])
	world.free()
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
