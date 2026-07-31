extends GutTest


func test_the_recipe_runs_in_order() -> void:
	var s := CookingSession.new(0.3)
	assert_eq(CookingSession.VERBS[0], "chop")
	assert_true(s.act("chop", 1.0))
	assert_eq(s.index, 1)
	assert_true(s.act("transfer", 1.0))
	assert_true(s.act("stir", 1.0))
	assert_true(s.act("pour", 1.0))
	assert_true(s.is_done())


func test_a_verb_out_of_order_spoils_a_step_without_advancing() -> void:
	# Nothing in this game FAILS. Stirring an unchopped pan does not end the
	# dinner — it just wastes a step, and wasted steps are what the score is
	# missing.
	var s := CookingSession.new(0.3)
	assert_false(s.act("stir", 1.0))
	assert_eq(s.index, 0, "the recipe still wants a chop")
	assert_eq(s.spoiled, 1)


func test_a_sloppy_gesture_advances_but_spoils() -> void:
	var s := CookingSession.new(0.3)
	assert_true(s.act("chop", 0.5), "0.5 is outside a 0.3 tolerance")
	assert_eq(s.index, 1, "the step is done either way — the pan moves on")
	assert_eq(s.spoiled, 1)


func test_tolerance_is_per_verb_and_widens_with_slack() -> void:
	var tight := CookingSession.new(0.1)
	var loose := CookingSession.new(0.5)
	tight.act("chop", 0.7)
	loose.act("chop", 0.7)
	assert_eq(tight.spoiled, 1)
	assert_eq(loose.spoiled, 0, "a wrecked dog gets more slack, not fewer steps")


func test_a_clean_run_scores_one() -> void:
	var s := CookingSession.new(0.3)
	for verb in CookingSession.VERBS:
		s.act(verb, 1.0)
	assert_eq(s.score(), 1.0)


func test_every_step_spoiled_scores_zero() -> void:
	var s := CookingSession.new(0.3)
	for verb in CookingSession.VERBS:
		s.act(verb, 0.0)
	assert_eq(s.score(), 0.0)
	assert_true(s.is_done(), "a bad dinner is still a dinner")


func test_score_degrades_one_step_at_a_time() -> void:
	var s := CookingSession.new(0.3)
	s.act("chop", 0.0)
	s.act("transfer", 1.0)
	s.act("stir", 1.0)
	s.act("pour", 1.0)
	assert_eq(s.score(), 0.75)


func test_spoiling_can_never_push_the_score_below_zero() -> void:
	# Wrong verbs are unbounded — you can stir a cold pan all night.
	var s := CookingSession.new(0.3)
	for _i in range(20):
		s.act("pour", 1.0)
	for verb in CookingSession.VERBS:
		s.act(verb, 1.0)
	assert_eq(s.score(), 0.0)


func test_acting_past_the_end_does_nothing() -> void:
	var s := CookingSession.new(0.3)
	for verb in CookingSession.VERBS:
		s.act(verb, 1.0)
	assert_false(s.act("chop", 1.0))
	assert_eq(s.spoiled, 0, "a finished pan cannot be spoiled")


func test_result_carries_the_minigame_contract() -> void:
	var s := CookingSession.new(0.3)
	for verb in CookingSession.VERBS:
		s.act(verb, 1.0)
	var r := s.result()
	assert_eq(r.score, 1.0)
	assert_false(r.skipped)
	assert_eq(r.spoiled, 0)
