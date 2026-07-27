extends GutTest


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng


func _type_through(shift: WorkShift) -> void:
	# Type the current phrase to completion exactly.
	var t := shift.target
	for c in t:
		shift.input_char(c)


func test_starts_with_a_phrase() -> void:
	var shift := WorkShift.new(4, 5, _rng())
	assert_gt(shift.target.length(), 0)
	assert_eq(shift.units_done, 0)


func test_completing_phrase_advances_units_and_serves_next() -> void:
	var shift := WorkShift.new(4, 5, _rng())
	var first := shift.target
	_type_through(shift)
	assert_eq(shift.units_done, 1)
	assert_gt(shift.target.length(), 0)
	assert_false(shift.session.is_complete())
	# a fresh session took over (typed_count reset)
	assert_eq(shift.session.typed_count, 0)
	# not asserting target != first: the tiny phrase pool can repeat
	assert_true(first.length() > 0)


func test_progress_counts_fractional_current_phrase() -> void:
	var shift := WorkShift.new(4, 5, _rng())
	var half := int(shift.target.length() / 2.0)
	for i in half:
		shift.input_char(shift.target[i])
	assert_almost_eq(shift.progress(), float(half) / shift.target.length(), 0.001)


func test_score_is_progress_over_par_clamped() -> void:
	var shift := WorkShift.new(4, 5, _rng())
	_type_through(shift)
	_type_through(shift)
	assert_eq(shift.units_done, 2)
	assert_almost_eq(shift.score(4), 0.5, 0.05)  # 2 done + tiny fraction
	assert_almost_eq(shift.score(1), 1.0, 0.001)  # clamped at 1


func test_wrong_key_blocks_progress_until_backspace() -> void:
	var shift := WorkShift.new(4, 5, _rng())
	shift.input_char("1")  # digits never appear in any phrase pool
	var before := shift.session.typed_count
	shift.input_char(shift.target[0])
	assert_eq(shift.session.typed_count, before)  # jammed
	# Two wrong inputs queued ("1" and the jammed retry) -> two backspaces to
	# clear, matching TypingSession's own established semantics
	# (test_wrong_char_blocks_until_backspaced in test_typing_session.gd).
	shift.backspace()
	shift.backspace()
	shift.input_char(shift.target[0])
	assert_eq(shift.session.typed_count, before + 1)


func test_score_par_floor_guard() -> void:
	var shift := WorkShift.new(4, 5, _rng())
	assert_almost_eq(shift.score(0), 0.0, 0.001)  # guard, no div-by-zero
