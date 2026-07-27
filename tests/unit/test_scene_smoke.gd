extends GutTest

## Smoke level only — scenes depend on the frame loop and node lifecycle, so
## these assert "it instantiates and setup() runs clean", nothing finer.
## (Games domain rule: no coverage gate on visual scenes.)


func test_main_scene_instantiates() -> void:
	var node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(node)
	assert_not_null(node)


func test_wake_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/wake.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({"mash_target": 10, "decay_per_sec": 0.0})
	assert_not_null(node)


func test_brush_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/brush.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({"strokes_required": 6, "amplitude": 40.0})
	assert_not_null(node)


func test_typing_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/typing.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({"tier": 4, "wrong_cap": 5, "shift_time": 100.0, "par_units": 3})
	assert_not_null(node)


func test_listening_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/listening.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({"window": 1.2, "tier": 4, "text_speed": 30.0})
	assert_not_null(node)


func test_freetime_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/freetime.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({
		"pull_strength": 60.0,
		"dwell_time": 0.25,
		"pull_growth": 90.0,
		"pull_ceiling": 600.0,
	})
	assert_not_null(node)


func test_dinner_scene_instantiates() -> void:
	var node = load("res://scenes/minigames/dinner.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"text_speed": 30.0})
	assert_not_null(node)


func test_sleep_scene_instantiates() -> void:
	var node = load("res://scenes/minigames/sleep.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"bedtime": "late", "text_speed": 30.0, "hold": 1.4})
	assert_not_null(node)


func test_coffee_scene_instantiates() -> void:
	var node = load("res://scenes/minigames/coffee.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"text_speed": 30.0})
	assert_not_null(node)


func test_retire_offer_scene_instantiates() -> void:
	var node = load("res://scenes/minigames/retire_offer.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"text_speed": 30.0})
	assert_not_null(node)


func test_warning_scene_instantiates() -> void:
	var node = load("res://scenes/minigames/warning.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"text": "x", "text_speed": 30.0, "hold": 0.0})
	assert_not_null(node)


func test_sick_scene_instantiates() -> void:
	var node = load("res://scenes/minigames/sick.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"burrow_target": 4, "burrow_time": 0.5, "text_speed": 0.0})
	assert_not_null(node)


func test_shower_scene_instantiates() -> void:
	var node: Minigame = load("res://scenes/minigames/shower.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"spots": 2, "revolutions": 2.0, "min_radius": 12.0})
	assert_not_null(node)


func test_clothes_scene_instantiates() -> void:
	var node: Minigame = load("res://scenes/minigames/clothes.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"fumble_chance": 0.0})
	assert_not_null(node)


func test_breakfast_scene_instantiates() -> void:
	var node: Minigame = load("res://scenes/minigames/breakfast.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"window": 0.3, "speed": 1.6, "beats": 3})
	assert_not_null(node)


func test_drive_scene_instantiates() -> void:
	var node: Minigame = load("res://scenes/minigames/drive.tscn").instantiate()
	add_child_autofree(node)
	node.setup({
		"length": 100.0, "top_speed": 50.0, "accel": 40.0,
		"pin_gap": 30.0, "block_margin": 25.0, "switch_lag": 0.0,
		"car_count": 4,
	})
	assert_not_null(node)
