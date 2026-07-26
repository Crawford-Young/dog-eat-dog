extends GutTest

## Scene glue only — smoke-level per games TDD scope; no coverage gate on
## scenes. Confirms the dev playtest lab instantiates and _ready() runs clean.
## _preset_state is pure logic (GameState in, GameState out) so it gets exact
## field-value assertions below, not just smoke coverage.


func test_lab_scene_instantiates() -> void:
	var node = load("res://scenes/dev/lab.tscn").instantiate()
	add_child_autofree(node)
	assert_not_null(node)


func _fresh_lab() -> Control:
	var node: Control = load("res://scenes/dev/lab.tscn").instantiate()
	add_child_autofree(node)
	return node


func test_flush_preset_launches_the_main_scene() -> void:
	var lab := _fresh_lab()
	lab._launch_day("flush")
	assert_eq(lab.get_node("%Host").get_child_count(), 1, "the day scene is hosted")
	assert_false(lab.get_node("%Menu").visible, "the menu steps aside")


func test_on_warning_preset_launches_the_main_scene() -> void:
	var lab := _fresh_lab()
	lab._launch_day("on_warning")
	assert_eq(lab.get_node("%Host").get_child_count(), 1, "the day scene is hosted")


func test_coffee_morning_preset_launches_the_main_scene() -> void:
	var lab := _fresh_lab()
	lab._launch_day("coffee_morning")
	assert_eq(lab.get_node("%Host").get_child_count(), 1, "the day scene is hosted")


func test_wreck_morning_preset_opens_on_the_sick_slot() -> void:
	var lab := _fresh_lab()
	lab._launch_day("wreck_morning")
	var day: Control = lab.get_node("%Host").get_child(0)
	assert_string_contains(
		(day.get_node("%DayLabel") as Label).text, "in bed", "8 energy is below the sick threshold"
	)


func test_cancel_after_a_day_preset_reshows_the_menu() -> void:
	var lab := _fresh_lab()
	lab._launch_day("flush")
	lab._cancel_run()
	assert_true(lab.get_node("%Menu").visible, "esc backs out of a day preset same as any activity")


func test_preset_state_flush_seeds_savings_one_margin_under_target() -> void:
	# QA ruling (issue #8): close_day nets the margin (salary - living cost),
	# not the raw salary, so the preset now seeds savings one margin short.
	var lab := _fresh_lab()
	var state: GameState = lab._preset_state("flush")
	assert_eq(
		state.wallet.savings,
		lab.cfg.retirement_target - (lab.cfg.salaries[state.rank] - lab.cfg.daily_living_cost),
		"one paid day's margin crosses the retirement target",
	)


func test_preset_state_on_warning_seeds_warning_and_low_performance() -> void:
	var lab := _fresh_lab()
	var state: GameState = lab._preset_state("on_warning")
	assert_true(state.warning)
	assert_eq(state.performance, 0.2)


func test_preset_state_wreck_morning_seeds_energy_below_the_sick_threshold() -> void:
	var lab := _fresh_lab()
	var state: GameState = lab._preset_state("wreck_morning")
	assert_eq(state.energy, 8.0)
	assert_lt(state.energy, lab.cfg.sick_energy_threshold)


func test_preset_state_coffee_morning_seeds_affordable_savings_and_energy() -> void:
	var lab := _fresh_lab()
	var state: GameState = lab._preset_state("coffee_morning")
	assert_eq(state.wallet.savings, 20)
	assert_eq(state.energy, 45.0)
