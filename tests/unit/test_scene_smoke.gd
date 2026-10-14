extends GutTest

## Full-screen panels, not HUD: they cover the host and take clicks.
const OVERLAYS := [&"Summary", &"Ending"]

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


func test_triage_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/minigames/triage.tscn")
	var node := scene.instantiate()
	add_child_autofree(node)
	node.setup(Difficulty.triage_params(50.0, BalanceConfig.new()))
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
	var node: Minigame = load("res://scenes/minigames/dinner.tscn").instantiate()
	add_child_autofree(node)
	node.setup(Difficulty.dinner_params(50.0, BalanceConfig.new()))
	assert_true(node.is_running())


## A/D walk the dog, but every Control still lets the mouse through: the
## shell's clicks and any later pointer input must never be eaten here.
func test_dinner_lets_the_mouse_reach_the_game() -> void:
	var node: Minigame = load("res://scenes/minigames/dinner.tscn").instantiate()
	add_child_autofree(node)
	node.setup(Difficulty.dinner_params(50.0, BalanceConfig.new()))
	var blockers: Array = _mouse_blockers(node)
	assert_eq(blockers.size(), 0, "these nodes eat the click: %s" % str(blockers))


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


## A ChoiceCard greys out exactly the choices named in disabled_choices; the
## rest stay clickable. The coffee cart is the card that uses it (#18).
func test_a_choice_card_greys_out_only_the_disabled_choices() -> void:
	var node: Minigame = load("res://scenes/minigames/coffee.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"text_speed": 30.0, "disabled_choices": ["both", "coffee"]})
	var choices: Node = node.get_node("%Choices")
	assert_true((choices.get_node("Both") as Button).disabled)
	assert_true((choices.get_node("Coffee") as Button).disabled)
	assert_false((choices.get_node("Snack") as Button).disabled)
	assert_false((choices.get_node("Water") as Button).disabled)


func test_a_choice_card_with_no_disabled_choices_greys_out_nothing() -> void:
	var node: Minigame = load("res://scenes/minigames/coffee.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"text_speed": 30.0})
	for button in node.get_node("%Choices").get_children():
		assert_false((button as Button).disabled, String(button.name))


## A choice card's buttons are exempt; everything else in the click path must
## let the mouse through (wave-3a rule), so a click lands on the button.
func test_the_coffee_card_lets_the_mouse_reach_its_buttons() -> void:
	var node: Minigame = load("res://scenes/minigames/coffee.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"text_speed": 30.0})
	var blockers: Array = _mouse_blockers(node)
	assert_eq(blockers.size(), 0, "these nodes eat the click: %s" % str(blockers))


func test_the_retire_offer_lets_the_mouse_reach_its_buttons() -> void:
	var node: Minigame = load("res://scenes/minigames/retire_offer.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"text_speed": 30.0})
	var blockers: Array = _mouse_blockers(node)
	assert_eq(blockers.size(), 0, "these nodes eat the click: %s" % str(blockers))


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


func test_breakfast_lets_the_mouse_reach_the_game() -> void:
	var node: Minigame = load("res://scenes/minigames/breakfast.tscn").instantiate()
	add_child_autofree(node)
	var blockers: Array = _mouse_blockers(node)
	assert_eq(blockers.size(), 0, "these nodes eat the click: %s" % str(blockers))


func test_the_breakfast_scene_has_visible_props() -> void:
	var node: Minigame = load("res://scenes/minigames/breakfast.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"window": 0.3, "speed": 1.6, "beats": 3})
	for unique_name in ["%Toast", "%Egg", "%Cakes"]:
		assert_not_null(node.get_node(unique_name), "%s is missing" % unique_name)


## The prop-parity pass only ever exercised beat 1 (setup() calls _start_beat()
## once) — nothing drove the cakes beat, the one whose prop is a Control
## container rather than a ColorRect. Same absence class as the draw-order
## lesson: a correct-looking suite that never reaches the third beat at all.
func test_breakfast_survives_all_three_beats() -> void:
	var node: Minigame = load("res://scenes/minigames/breakfast.tscn").instantiate()
	add_child_autofree(node)
	node.setup({"window": 0.3, "speed": 1.6, "beats": 3})
	watch_signals(node)
	node._press()
	node._press()
	node._press()
	assert_signal_emitted(node, "finished")


## Each beat starts the marker at a phase drawn from the game's own rng, not
## always at the left end: a fixed start made the first centre crossing land on
## the same instant every time, so a ramp that moved it past a reaction time
## flipped sharp from never missing to missing (the step-2 cliff, #18).
func _breakfast_beat_starts(seed_value: int) -> Array:
	var node: Minigame = load("res://scenes/minigames/breakfast.tscn").instantiate()
	add_child_autofree(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	node.setup({"window": 0.3, "speed": 1.6, "beats": 3, "rng": rng})
	var starts: Array = []
	for i in 3:
		starts.append([node._beat.position, node._beat.get("_dir")])
		node._press()
	return starts


func test_breakfast_beats_start_at_a_random_phase() -> void:
	var seen := {}
	for seed_value in 10:
		for start in _breakfast_beat_starts(seed_value):
			assert_between(start[0], 0.0, 1.0)
			seen[start] = true
	assert_gt(seen.size(), 20, "30 beats do not all start in the same place")
	var rising := 0
	for start in seen:
		rising += 1 if start[1] > 0.0 else 0
	assert_between(rising, 1, seen.size() - 1, "and not all the same way")


func test_breakfast_beat_starts_replay_from_the_same_seed() -> void:
	assert_eq(_breakfast_beat_starts(7), _breakfast_beat_starts(7))
	assert_ne(_breakfast_beat_starts(7), _breakfast_beat_starts(8))


## Breakfast takes a click OR space, so the prompt copy states every accepted
## input rather than naming only one. (issue #8)
func test_breakfast_prompt_names_both_of_its_inputs() -> void:
	var node: Minigame = load("res://scenes/minigames/breakfast.tscn").instantiate()
	add_child_autofree(node)
	var prompt: String = (node.get_node("Prompt") as Label).text.to_upper()
	assert_true(prompt.contains("SPACE"), "prompt names SPACE: %s" % prompt)
	assert_true(prompt.contains("CLICK"), "prompt names CLICK: %s" % prompt)


## The blocker can also sit ABOVE the minigame: the shell hosts every scene, and a
## full-rect Control there eats the click before the minigame's `_unhandled_input`
## ever runs. Fixing the leaf scene alone is not enough — the whole chain from the
## shell root down to the item has to be transparent. (issue #6)
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
		"car_min_gap": 20.0, "car_count": 4,
		"day_speed_min": 0.2, "day_speed_max": 0.6, "wave_speed_jitter": 0.25,
		"car_speed_jitter": 0.12, "blocked_wave_chance": 0.25,
		"route_miles": 9.0, "display_top_mph": 60.0,
	})
	assert_not_null(node)


## The commute is the only slot whose cost is legible WHILE it happens: a pin
## has to read as a pin. Miles and mph are display-only — the sim is untouched
## by both — but without them a bad traffic roll is invisible until the clock
## has already eaten the morning.
func test_drive_shows_how_far_is_left_and_how_fast_the_dog_is_going() -> void:
	var node: Minigame = load("res://scenes/minigames/drive.tscn").instantiate()
	add_child_autofree(node)
	node.setup({
		"length": 100.0, "top_speed": 50.0, "accel": 40.0,
		"pin_gap": 30.0, "block_margin": 25.0, "switch_lag": 0.0,
		"car_min_gap": 20.0, "car_count": 0,
		"day_speed_min": 0.2, "day_speed_max": 0.6, "wave_speed_jitter": 0.25,
		"car_speed_jitter": 0.12, "blocked_wave_chance": 0.25,
		"route_miles": 9.0, "display_top_mph": 60.0,
	})
	node._process(0.0)
	assert_string_contains(node.get_node("%Miles").text, "9.0")
	assert_string_contains(node.get_node("%Miles").text, "mi")
	assert_string_contains(node.get_node("%Speedo").text, "0 mph")
	node._process(1.0)  # empty road: one second of accel
	assert_string_contains(node.get_node("%Speedo").text, "48 mph")
	assert_false(node.get_node("%Miles").text.contains("9.0"), "the miles never counted down")


func test_drive_readouts_come_from_the_route_before_the_first_frame() -> void:
	# The scene's design-time label text must never flash: setup() writes the
	# route's own miles and a standing speedo before anything is drawn.
	var node: Minigame = load("res://scenes/minigames/drive.tscn").instantiate()
	add_child_autofree(node)
	node.setup({
		"length": 100.0, "top_speed": 50.0, "accel": 40.0,
		"pin_gap": 30.0, "block_margin": 25.0, "switch_lag": 0.0,
		"car_min_gap": 20.0, "car_count": 0,
		"day_speed_min": 0.2, "day_speed_max": 0.6, "wave_speed_jitter": 0.25,
		"car_speed_jitter": 0.12, "blocked_wave_chance": 0.25,
		"route_miles": 4.2, "display_top_mph": 60.0,
	})
	assert_eq(node.get_node("%Miles").text, "4.2 mi to go")
	assert_eq(node.get_node("%Speedo").text, "0 mph")
	assert_eq(node.sim().route_length(), 100.0, "the sim it hosts is public, for the bot")


func test_the_sleep_beat_states_the_real_bed_time_and_the_ledger() -> void:
	# The band copy must not hardcode "10pm" / "midnight" / "3am": the bed
	# minute is real, so fixed stamps would contradict the clock the player just
	# watched. The beat takes the time as a param instead of asserting one.
	var node: Minigame = load("res://scenes/minigames/sleep.tscn").instantiate()
	add_child_autofree(node)
	node.setup({
		"bedtime": "late",
		"bed_clock": "23:41",
		"ledger": "7h19 tonight. running short.",
		"text_speed": 99999.0,
		"hold": 0.01,
	})
	await wait_physics_frames(2)
	var text: String = node.get_node("%Line").text
	assert_string_contains(text, "23:41")
	assert_string_contains(text, "running short")


func test_no_band_copy_hardcodes_a_wall_clock_hour() -> void:
	for band in BalanceConfig.BANDS:
		var line: String = load("res://scripts/minigames/sleep_beat.gd").LINES[band]
		for stamp in ["pm", "am", "midnight", "noon"]:
			assert_false(
				line.to_lower().contains(stamp),
				"the '%s' line hardcodes '%s' — the clock states the time" % [band, stamp],
			)


## issue #11 round 4, user ruling: "space should be the button. click should be
## everywhere. similar to breakfast" — the gesture contract is click-anywhere/SPACE
## press, with no per-gesture recognizers.
## issue #11 round 5, user ruling: "stirring a pot should not be rhythm."
## Chop/transfer stay press-graded (BeatTimer); stir/pour become hold-graded
## (HoldMeter) — press starts the hold, release commits. window: 1.0 makes
## every beat/band accept, same simplification test_the_cooking_scene_
## walks_its_recipe_and_finishes already uses via tolerance: 1.0 — this test
## is about the input chain reaching finished, not grading precision.
func test_the_cooking_scene_completes_the_diegetic_walk() -> void:
	var node: Minigame = load("res://scenes/minigames/cooking.tscn").instantiate()
	add_child_autofree(node)
	var got: Array = []
	node.finished.connect(func(r: Dictionary) -> void: got.append(r))
	node.setup({"tolerance": 1.0, "window": 1.0, "text_speed": 300.0})
	await wait_physics_frames(2)
	var space := InputEventKey.new()
	space.pressed = true
	space.echo = false
	space.physical_keycode = KEY_SPACE
	var release := InputEventKey.new()
	release.pressed = false
	release.physical_keycode = KEY_SPACE
	var mouse_press := InputEventMouseButton.new()
	mouse_press.pressed = true
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	var mouse_release := InputEventMouseButton.new()
	mouse_release.pressed = false
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	# chop: 3 presses
	for _i in range(3):
		node._unhandled_input(space)
	# transfer: 1 press
	node._unhandled_input(space)
	# stir (issue #11 round 6: mouse-only) — press starts the hold, circle
	# the pan three full turns (well past STIR_MIN_RADIUS) to feed the
	# tracker, mouse release commits.
	node._unhandled_input(mouse_press)
	var pan_center: Vector2 = node.get_node("%Pan").get_global_rect().get_center()
	var steps := 24
	var turns := 3
	for i in range(steps * turns + 1):
		var angle := TAU * float(i) / float(steps)
		var motion := InputEventMouseMotion.new()
		motion.position = pan_center + Vector2.RIGHT.rotated(angle) * 40.0
		node._unhandled_input(motion)
	node._unhandled_input(mouse_release)
	# pour: same hold/release shape, SPACE still fine
	node._unhandled_input(space)
	for _i in range(10):
		node._process(0.1)
	node._unhandled_input(release)
	await wait_physics_frames(2)
	assert_eq(got.size(), 1, "the pan finished exactly once")


func test_the_cooking_scene_walks_its_recipe_and_finishes() -> void:
	var node: Minigame = load("res://scenes/minigames/cooking.tscn").instantiate()
	add_child_autofree(node)
	var got: Array = []
	node.finished.connect(func(r: Dictionary) -> void: got.append(r))
	node.setup({"tolerance": 1.0, "text_speed": 300.0})
	await wait_physics_frames(2)
	for verb in CookingSession.VERBS:
		node._commit(verb, 1.0)
	await wait_physics_frames(2)
	assert_eq(got.size(), 1, "the pan finished exactly once")
	assert_eq(got[0].score, 1.0)


func test_the_cooking_progress_bar_reads_a_zero_to_one_fraction() -> void:
	# Range nodes default to 0..100, and this scene writes a 0..1 fraction into
	# it. The default would render 4% for a finished pan and no test would
	# notice — the bar is display-only.
	var node: Minigame = load("res://scenes/minigames/cooking.tscn").instantiate()
	add_child_autofree(node)
	assert_eq(node.get_node("%Progress").max_value, 1.0)


func test_cooking_lets_the_mouse_reach_the_game() -> void:
	var node: Minigame = load("res://scenes/minigames/cooking.tscn").instantiate()
	add_child_autofree(node)
	var blockers: Array = _mouse_blockers(node)
	assert_eq(blockers.size(), 0, "these nodes eat the click: %s" % str(blockers))


## issue #11: every gesture target has a visible node — pin that they exist,
## on top of the generic mouse-filter scan above.
func test_the_cooking_scene_has_visible_gesture_targets() -> void:
	var node: Minigame = load("res://scenes/minigames/cooking.tscn").instantiate()
	add_child_autofree(node)
	for unique_name in ["%Pan", "%PanFill", "%Board", "%Carrots", "%Ladle", "%LadleFill",
			"%GestureBar", "%StirSpot", "%PanGlow", "%Knife", "%FillLine"]:
		assert_not_null(node.get_node(unique_name), "%s is missing" % unique_name)


## The wave-3a reflect's closing lesson: a correct node drawn BEHIND an
## opaque one passes every test the suite can express. Visibility is not draw
## order, so every HUD node is held after the host here (issue #17).
func test_every_hud_node_draws_over_the_minigame_host() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	var host: Node = main.get_node("%MinigameHost")
	var huds := 0
	for node in main.get_children():
		# Non-Control children (the typewriter helpers) draw nothing.
		if not node is Control or node == host or node.name in OVERLAYS:
			continue
		huds += 1
		assert_gt(
			node.get_index(),
			host.get_index(),
			"%s must be declared after MinigameHost or minigames paint over it" % node.name,
		)
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"%s never eats a click" % node.name)
	assert_gt(huds, 0, "no HUD nodes found")
