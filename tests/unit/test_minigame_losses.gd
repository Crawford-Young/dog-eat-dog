extends GutTest

## Each playable game's loss rule (issue #17, the #11 loss table): what makes
## it a MISS, what does not, and that a score-based MISS keeps the real score.
## Countdowns run on tiny limits with a 0.05 s gag so a timeout lands inside
## one short wait; the non-MISS cases use an absurd limit so only the game's
## own rule can end them.

const WAKE := "res://scenes/minigames/wake.tscn"
const BRUSH := "res://scenes/minigames/brush.tscn"
const SHOWER := "res://scenes/minigames/shower.tscn"
const CLOTHES := "res://scenes/minigames/clothes.tscn"
const BREAKFAST := "res://scenes/minigames/breakfast.tscn"
const COOKING := "res://scenes/minigames/cooking.tscn"
const TYPING := "res://scenes/minigames/typing.tscn"
const LISTENING := "res://scenes/minigames/listening.tscn"

const QUICK := {"time_limit": 0.1, "fail_gag_seconds": 0.05}
const LONG := {"time_limit": 100.0, "fail_gag_seconds": 0.05}
const WAIT := 0.5
## Holds no art, so PropArt always draws the emoji placeholder.
const NO_ART_ROOT := "res://tests/fixtures/props/none"

const TIMED := [
	[WAKE, {"mash_target": 50, "decay_per_sec": 0.0}],
	[BRUSH, {"strokes_required": 6, "amplitude": 40.0}],
	[SHOWER, {"spots": 2, "revolutions": 2.0, "min_radius": 12.0}],
	[CLOTHES, {"fumble_chance": 0.0}],
	[BREAKFAST, {"window": 0.3, "speed": 1.6, "beats": 3}],
	[COOKING, {"tolerance": 0.3, "text_speed": 300.0}],
]
const SKIPPABLE_CHORES := [
	[BRUSH, {"strokes_required": 6, "amplitude": 40.0}],
	[SHOWER, {"spots": 2, "revolutions": 2.0, "min_radius": 12.0}],
]


func _host(path: String, params: Dictionary, extra: Dictionary = {}) -> Minigame:
	var node: Minigame = load(path).instantiate()
	# The loss rule is under test, not the art: an empty root keeps every gag
	# its emoji whatever lands in assets/props (issue #24).
	node.props_root = NO_ART_ROOT
	add_child_autofree(node)
	var merged := params.duplicate()
	merged.merge(extra, true)
	watch_signals(node)
	node.setup(merged)
	return node


func _result(node: Minigame) -> Dictionary:
	return get_signal_parameters(node, "finished")[0]


func _gag_shown(node: Minigame) -> bool:
	for child in node.get_children():
		if child is Label and (child as Label).text == node.FAIL_GAG:
			return true
	return false


func _space() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_SPACE
	return event


func _type_char(node: Node, c: String) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.unicode = c.unicode_at(0)
	node._unhandled_key_input(event)


# --- timeouts ---------------------------------------------------------------


func test_running_out_of_time_is_a_miss_with_its_gag(p = use_parameters(TIMED)) -> void:
	var node := _host(p[0], p[1], QUICK)
	assert_true(node.has_countdown(), "the time_limit param starts the countdown")
	await wait_seconds(WAIT)
	assert_signal_emit_count(node, "finished", 1)
	assert_true(_result(node).failed, "a timeout is a MISS")
	assert_false(_result(node).skipped)
	assert_true(_gag_shown(node), "the MISS pops the game's own gag")


func test_every_game_has_a_short_gag(p = use_parameters(TIMED)) -> void:
	var node := _host(p[0], p[1], LONG)
	var gag: String = node.FAIL_GAG
	assert_between(gag.length(), 1, 4, "one or two emoji, not copy")


func test_no_time_limit_means_no_countdown(p = use_parameters(TIMED)) -> void:
	var node := _host(p[0], p[1])
	assert_false(node.has_countdown(), "a host that passes no limit gets an untimed game")


func test_a_skip_is_never_a_miss(p = use_parameters(SKIPPABLE_CHORES)) -> void:
	var node := _host(p[0], p[1], QUICK)
	(node.get_node("SkipButton") as Button).pressed.emit()
	await wait_seconds(WAIT)
	assert_signal_emit_count(node, "finished", 1, "the countdown dies with the skip")
	assert_eq(_result(node), {"score": 0.0, "skipped": true, "failed": false})


# --- finishing in time ------------------------------------------------------


func test_a_wake_up_in_time_is_not_a_miss() -> void:
	var node := _host(WAKE, {"mash_target": 2, "decay_per_sec": 0.0}, LONG)
	node._unhandled_input(_space())
	node._unhandled_input(_space())
	node._process(0.016)
	assert_eq(_result(node), {"score": 1.0, "skipped": false, "failed": false})


func test_a_full_wake_bar_at_the_timeout_is_not_a_miss() -> void:
	var node := _host(WAKE, {"mash_target": 1, "decay_per_sec": 0.0}, LONG)
	node._logic.press()
	node._on_timeout()
	assert_eq(_result(node).failed, false, "the rule is the bar, not the clock")


func test_a_brush_in_time_is_not_a_miss() -> void:
	var node := _host(BRUSH, {"strokes_required": 1, "amplitude": 40.0}, LONG)
	node._tracker.stroke_count = 1
	node._process(0.016)
	assert_eq(_result(node), {"score": 1.0, "skipped": false, "failed": false})


func test_a_shower_in_time_is_not_a_miss() -> void:
	var node := _host(SHOWER, {"spots": 1, "revolutions": 2.0, "min_radius": 12.0}, LONG)
	node._tracker.revolutions = 2.0
	node._process(0.016)
	assert_eq(_result(node), {"score": 1.0, "skipped": false, "failed": false})


func test_dressing_in_time_is_not_a_miss() -> void:
	var node := _host(CLOTHES, {"fumble_chance": 0.0}, LONG)
	var dog: Control = node.get_node("%DogZone")
	for item_name in ["Shirt", "Pants", "Shoes", "Collar"]:
		var item: Control = node.get_node("%Items").get_node(item_name)
		node._held = item
		item.global_position = dog.global_position
		node._try_wear()
	assert_eq(_result(node), {"score": 1.0, "skipped": false, "failed": false})


func test_dressed_at_the_timeout_is_not_a_miss() -> void:
	var node := _host(CLOTHES, {"fumble_chance": 0.0}, LONG)
	for item in DressLogic.ITEMS:
		node._logic.wear(item)
	node._on_timeout()
	assert_eq(_result(node).failed, false, "the rule is being dressed, not the clock")


# --- breakfast --------------------------------------------------------------


func _breakfast_presses(node: Minigame, hits: Array[bool]) -> void:
	for hit in hits:
		node._beat.position = 0.5 if hit else 0.0
		node._unhandled_input(_space())


func test_breakfast_with_no_hits_is_a_miss() -> void:
	var node := _host(BREAKFAST, {"window": 0.3, "speed": 1.6, "beats": 3, "fail_hits": 1}, LONG)
	_breakfast_presses(node, [false, false, false])
	assert_signal_not_emitted(node, "finished", "the gag plays first")
	await wait_seconds(WAIT)
	assert_eq(_result(node), {"score": 0.0, "skipped": false, "failed": true})


func test_breakfast_with_one_hit_is_not_a_miss() -> void:
	var node := _host(BREAKFAST, {"window": 0.3, "speed": 1.6, "beats": 3, "fail_hits": 1}, LONG)
	_breakfast_presses(node, [true, false, false])
	assert_signal_emit_count(node, "finished", 1)
	assert_false(_result(node).failed)
	assert_almost_eq(_result(node).score, 1.0 / 3.0, 0.0001)


func test_a_breakfast_miss_keeps_its_real_score() -> void:
	var node := _host(BREAKFAST, {"window": 0.3, "speed": 1.6, "beats": 3, "fail_hits": 2}, LONG)
	_breakfast_presses(node, [true, false, false])
	await wait_seconds(WAIT)
	assert_true(_result(node).failed, "1 hit is under a 2-hit floor")
	assert_almost_eq(_result(node).score, 1.0 / 3.0, 0.0001, "the energy refill reads it")


# --- cooking ----------------------------------------------------------------


func _cook(params: Dictionary) -> Minigame:
	return _host(COOKING, params, LONG)


func test_the_spoil_limit_ends_the_pan_as_a_miss() -> void:
	var node := _cook({"tolerance": 0.0, "text_speed": 300.0, "spoil_limit": 3})
	node._commit("chop", 0.0)
	node._commit("transfer", 0.0)
	assert_true(node.is_running(), "two spoils still cook")
	node._commit("stir", 0.0)
	assert_false(node.is_running(), "the third spoil loses the pan at once")
	await wait_seconds(WAIT)
	assert_signal_emit_count(node, "finished", 1)
	var result := _result(node)
	assert_true(result.failed)
	assert_eq(result.spoiled, 3, "the session result rides along")
	assert_almost_eq(result.score, 0.25, 0.0001, "and so does its real score")


func test_two_spoils_finish_the_pan_without_a_miss() -> void:
	var node := _cook({"tolerance": 0.0, "text_speed": 300.0, "spoil_limit": 3})
	node._commit("chop", 0.0)
	node._commit("transfer", 0.0)
	node._commit("stir", 1.0)
	node._commit("pour", 1.0)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(_result(node), {"score": 0.5, "skipped": false, "failed": false, "spoiled": 2})


func test_a_lost_pan_ignores_further_presses() -> void:
	var node := _cook({"tolerance": 0.0, "text_speed": 300.0, "spoil_limit": 1, "window": 1.0})
	node._commit("chop", 0.0)
	var index: int = node._session.index
	node._unhandled_input(_space())
	node._unhandled_input(_space())
	node._unhandled_input(_space())
	assert_eq(node._session.index, index, "input is dead during the gag")


func test_cooking_runs_while_it_cooks() -> void:
	var node := _cook({"tolerance": 1.0, "text_speed": 300.0})
	assert_true(node.is_running(), "the pan is a live game, like every other one")


# --- work -------------------------------------------------------------------


func _shift(par: int, fail_score: float) -> Minigame:
	return _host(TYPING, {
		"tier": 4, "wrong_cap": 5, "shift_time": 0.2, "par_units": par,
		"fail_score": fail_score, "fail_gag_seconds": 0.05,
	})


func _type_one_phrase(node: Minigame) -> void:
	for c in node._shift.target:
		_type_char(node, c)


func test_a_shift_under_the_fail_score_is_a_miss_that_keeps_its_score() -> void:
	var node := _shift(4, 0.5)
	_type_one_phrase(node)
	await wait_seconds(WAIT + 0.2)
	assert_signal_emit_count(node, "finished", 1)
	assert_true(_result(node).failed)
	assert_almost_eq(_result(node).score, 0.25, 0.0001, "the work EMA reads the real score")
	assert_true(_gag_shown(node))


func test_a_shift_at_the_fail_score_is_not_a_miss() -> void:
	var node := _shift(2, 0.5)
	_type_one_phrase(node)
	await wait_seconds(WAIT + 0.2)
	assert_eq(_result(node), {"score": 0.5, "skipped": false, "failed": false})


func test_the_shift_timer_is_not_a_time_limit() -> void:
	var node := _shift(2, 0.5)
	assert_almost_eq(node._countdown_total, 0.2, 0.0001, "the shift keeps its own timer")


# --- lunch ------------------------------------------------------------------


func _lunch() -> Minigame:
	return _host(LISTENING, {
		"window": 1.2, "tier": 4, "text_speed": 300.0,
		"fail_score": 0.01, "fail_gag_seconds": 0.05,
	})


func test_a_lunch_with_no_hits_is_a_miss() -> void:
	var node := _lunch()
	node._process(20.0)
	assert_signal_not_emitted(node, "finished", "the gag plays first")
	await wait_seconds(WAIT)
	assert_eq(_result(node), {"score": 0.0, "skipped": false, "failed": true})


func test_a_lunch_with_one_hit_is_not_a_miss() -> void:
	var node := _lunch()
	node._process(1.6)
	assert_eq(node._session.gesture("nod"), "hit", "precondition: the first cue landed")
	node._process(20.0)
	assert_signal_emit_count(node, "finished", 1)
	assert_false(_result(node).failed)
	assert_almost_eq(_result(node).score, 1.0 / 3.0, 0.0001)
