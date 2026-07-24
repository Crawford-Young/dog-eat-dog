extends GutTest


func test_wake_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/wake.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({"mash_target": 10, "decay_per_sec": 0.0, "par_time": 4.0})
	assert_not_null(node)


func test_brush_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/brush.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({"strokes_required": 6, "amplitude": 40.0, "par_time": 5.0})
	assert_not_null(node)


func test_typing_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/typing.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({"tier": 4, "error_tolerance": 0.3})
	assert_not_null(node)


func test_listening_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/listening.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({"window": 1.2, "tier": 4})
	assert_not_null(node)


func test_freetime_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/freetime.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup({"pull_strength": 60.0})
	assert_not_null(node)


func test_dinner_scene_instantiates() -> void:
	var node = load("res://scenes/minigames/dinner.tscn").instantiate()
	add_child_autofree(node)
	assert_not_null(node)


func test_sleep_scene_instantiates() -> void:
	var node = load("res://scenes/minigames/sleep.tscn").instantiate()
	add_child_autofree(node)
	assert_not_null(node)
