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


## The lab is a SHELL that hosts minigames exactly like main.tscn does, and it had
## the identical click-eating root — a full-rect STOP Control over a Host that was
## already IGNORE. Fixing one shell and reporting the bug closed left clothes dead
## on the surface the playtester actually uses. (issue #6 addendum)
func test_the_lab_shell_never_eats_a_minigames_clicks() -> void:
	var lab := _fresh_lab()
	assert_eq(lab.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Lab root")
	var host: Control = lab.get_node("%Host")
	assert_eq(host.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Host")


## The menu gains a row or two every wave. A fixed rect just stops drawing the
## newest ones — no error, no test, the row is simply gone. (issue #9)
func test_the_lab_menu_absorbs_new_rows_instead_of_hiding_them() -> void:
	var lab := _fresh_lab()
	var menu: Control = lab.get_node("%Menu")
	assert_true(menu is ScrollContainer, "the menu scrolls, so rows can't fall off")
	var bottom: float = menu.position.y + menu.size.y
	var viewport_height: float = lab.get_viewport_rect().size.y
	assert_true(bottom <= viewport_height,
			"menu bottom %s must stay inside the %s-tall viewport" % [bottom, viewport_height])


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


func test_shower_activity_launches_and_sets_up() -> void:
	var lab := _fresh_lab()
	lab._launch("shower")
	assert_eq(lab.get_node("%Host").get_child_count(), 1, "shower minigame is hosted")


func test_clothes_activity_launches_and_sets_up() -> void:
	var lab := _fresh_lab()
	lab._launch("clothes")
	assert_eq(lab.get_node("%Host").get_child_count(), 1, "clothes minigame is hosted")


func test_breakfast_activity_launches_and_sets_up() -> void:
	var lab := _fresh_lab()
	lab._launch("breakfast")
	assert_eq(lab.get_node("%Host").get_child_count(), 1, "breakfast minigame is hosted")


func test_drive_activity_launches_and_sets_up() -> void:
	var lab := _fresh_lab()
	lab._launch("drive")
	assert_eq(lab.get_node("%Host").get_child_count(), 1, "drive minigame is hosted")


func test_typing_params_uses_the_selected_rank() -> void:
	var lab := _fresh_lab()
	lab.get_node("%RankOption").selected = 2
	var params: Dictionary = lab._params_for("typing")
	assert_eq(
		params["par_units"], lab.cfg.typing_par_units[2], "rank selector feeds typing_params"
	)


func test_late_morning_preset_launches_the_main_scene() -> void:
	var lab := _fresh_lab()
	lab._launch_day("late_morning")
	assert_eq(lab.get_node("%Host").get_child_count(), 1, "the day scene is hosted")


func test_preset_cfg_late_morning_duplicates_with_a_tiny_budget() -> void:
	var lab := _fresh_lab()
	var day_cfg: BalanceConfig = lab._preset_cfg("late_morning")
	assert_eq(day_cfg.morning_budget(), 20.0, "the duplicate carries the tight morning")
	assert_eq(lab.cfg.morning_budget(), 90.0, "the shared cfg resource is untouched")


func test_preset_cfg_other_presets_return_cfg_unchanged() -> void:
	var lab := _fresh_lab()
	var day_cfg: BalanceConfig = lab._preset_cfg("flush")
	assert_eq(
		day_cfg.morning_budget(), 90.0, "non-late-morning presets pass cfg through untouched"
	)
