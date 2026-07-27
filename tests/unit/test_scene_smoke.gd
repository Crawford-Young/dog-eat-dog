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


## `_unhandled_input` never sees an event a Control has already eaten, and every
## Control defaults to MOUSE_FILTER_STOP. So a minigame that routes CLICKS through
## `_unhandled_input` must leave its decorative Controls transparent to the mouse,
## or it renders perfectly, instantiates clean, and is unplayable in a real window.
## Buttons are exempt — they are supposed to eat their own clicks. (issue #6)
func _mouse_blockers(root: Node) -> Array:
	var blockers: Array = []
	var controls: Array = root.find_children("*", "Control", true, false)
	controls.push_back(root)
	for node in controls:
		if node is Button or not node is Control:
			continue
		if (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blockers.append(String(node.name))
	return blockers


func test_clothes_lets_the_mouse_reach_the_game() -> void:
	var node: Minigame = load("res://scenes/minigames/clothes.tscn").instantiate()
	add_child_autofree(node)
	var blockers: Array = _mouse_blockers(node)
	assert_eq(blockers.size(), 0, "these nodes eat the drag: %s" % str(blockers))


func test_breakfast_lets_the_mouse_reach_the_game() -> void:
	var node: Minigame = load("res://scenes/minigames/breakfast.tscn").instantiate()
	add_child_autofree(node)
	var blockers: Array = _mouse_blockers(node)
	assert_eq(blockers.size(), 0, "these nodes eat the click: %s" % str(blockers))


## The blocker can also sit ABOVE the minigame: the shell hosts every scene, and a
## full-rect Control there eats the click before the minigame's `_unhandled_input`
## ever runs. Fixing the leaf scene alone is not enough — the whole chain from the
## shell root down to the item has to be transparent. (issue #6)
## Breakfast takes a click OR space, but advertised only the click — and the click
## was the affordance issue #6 had broken, so the prompt named the one input that
## did not work. Copy states every accepted input. (issue #8)
func test_breakfast_prompt_names_both_of_its_inputs() -> void:
	var node: Minigame = load("res://scenes/minigames/breakfast.tscn").instantiate()
	add_child_autofree(node)
	var prompt: String = (node.get_node("Prompt") as Label).text.to_upper()
	assert_true(prompt.contains("SPACE"), "prompt names SPACE: %s" % prompt)
	assert_true(prompt.contains("CLICK"), "prompt names CLICK: %s" % prompt)


func test_the_shell_never_eats_a_minigames_clicks() -> void:
	var node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(node)
	assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "Main root")
	var host: Control = node.get_node("%MinigameHost")
	assert_eq(host.mouse_filter, Control.MOUSE_FILTER_IGNORE, "MinigameHost")


func test_drive_scene_instantiates() -> void:
	var node: Minigame = load("res://scenes/minigames/drive.tscn").instantiate()
	add_child_autofree(node)
	node.setup({
		"length": 100.0, "top_speed": 50.0, "accel": 40.0,
		"pin_gap": 30.0, "block_margin": 25.0, "switch_lag": 0.0,
		"car_count": 4,
	})
	assert_not_null(node)
