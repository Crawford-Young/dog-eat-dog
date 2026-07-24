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
