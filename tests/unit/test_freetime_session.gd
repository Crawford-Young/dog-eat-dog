extends GutTest

## Freetime is a loop, not a choice: hovering the game button long enough
## auto-plays a game, and only a deliberate logoff ends the night.


func _session() -> FreetimeSession:
	return FreetimeSession.new(60.0, 0.25, 40.0, 1000.0)


func test_pull_never_exceeds_the_ceiling() -> void:
	# without a ceiling the pull outruns any achievable mouse speed and the
	# recentre -> drift -> dwell -> auto-play cycle closes with no way to logoff
	var s := FreetimeSession.new(60.0, 0.25, 40.0, 200.0)
	for i in 20:
		s.hover(0.3)
	assert_eq(s.games_played, 20)
	assert_almost_eq(s.pull_strength(), 200.0, 0.001)


func test_pull_still_grows_below_the_ceiling() -> void:
	var s := FreetimeSession.new(60.0, 0.25, 40.0, 200.0)
	s.hover(0.3)
	assert_almost_eq(s.pull_strength(), 100.0, 0.001)


func test_starts_clean() -> void:
	var s := _session()
	assert_eq(s.games_played, 0)
	assert_false(s.is_done())
	assert_almost_eq(s.pull_strength(), 60.0, 0.001)


func test_short_hover_does_not_play() -> void:
	var s := _session()
	assert_false(s.hover(0.1))
	assert_eq(s.games_played, 0)


func test_hover_past_dwell_auto_plays() -> void:
	var s := _session()
	assert_false(s.hover(0.1))
	assert_true(s.hover(0.2))
	assert_eq(s.games_played, 1)


func test_leaving_the_button_resets_dwell() -> void:
	var s := _session()
	s.hover(0.2)
	s.leave()
	assert_false(s.hover(0.2))
	assert_eq(s.games_played, 0)


func test_dwell_resets_after_each_game() -> void:
	var s := _session()
	assert_true(s.hover(0.3))
	assert_false(s.hover(0.1))
	assert_true(s.hover(0.2))
	assert_eq(s.games_played, 2)


func test_pull_grows_with_each_game() -> void:
	var s := _session()
	s.hover(0.3)
	assert_almost_eq(s.pull_strength(), 100.0, 0.001)
	s.hover(0.3)
	assert_almost_eq(s.pull_strength(), 140.0, 0.001)


func test_dwell_ratio_reports_progress() -> void:
	var s := _session()
	s.hover(0.125)
	assert_almost_eq(s.dwell_ratio(), 0.5, 0.001)
	s.leave()
	assert_almost_eq(s.dwell_ratio(), 0.0, 0.001)


func test_only_logoff_ends_the_session() -> void:
	var s := _session()
	for i in 5:
		s.hover(0.3)
	assert_false(s.is_done())
	s.logoff()
	assert_true(s.is_done())


func test_hover_after_logoff_is_inert() -> void:
	var s := _session()
	s.logoff()
	assert_false(s.hover(1.0))
	assert_eq(s.games_played, 0)


func test_result_always_reports_logoff() -> void:
	var s := _session()
	s.hover(0.3)
	s.logoff()
	var r := s.result()
	assert_eq(r.choice, "logoff")
	assert_false(r.skipped)
	assert_eq(r.games_played, 1)
	assert_almost_eq(r.score, s.score(), 0.001)


func test_score_decays_with_games_played() -> void:
	var clean := _session()
	assert_almost_eq(clean.score(), 1.0, 0.001)
	var hooked := _session()
	hooked.hover(0.3)
	hooked.hover(0.3)
	assert_lt(hooked.score(), clean.score())
	assert_gt(hooked.score(), 0.0)
