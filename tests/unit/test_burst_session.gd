extends GutTest

## BurstSession: work AM's word burst (issue #18). One word at a time, each
## typed before its window runs out; score = words typed / words shown.

const WINDOW := 2.0


func _rng(seed_value := 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _session(tier := 4, speed := 1.0, seed_value := 7) -> BurstSession:
	return BurstSession.new(tier, WINDOW, speed, _rng(seed_value))


func _type_word(session: BurstSession) -> void:
	for c in session.remaining():
		session.input_char(c)


func _is_letters(word: String) -> bool:
	for c in word:
		if c < "a" or c > "z":
			return false
	return true


func _lengths(words: Array) -> Vector2i:
	var span := Vector2i(1000, 0)
	for w in words:
		span = Vector2i(mini(span.x, w.length()), maxi(span.y, w.length()))
	return span


func test_a_fresh_burst_shows_its_first_word_with_nothing_scored() -> void:
	var s := _session()
	assert_gt(s.word.length(), 0)
	assert_eq(s.typed_count, 0)
	assert_eq(s.words_typed, 0)
	assert_eq(s.words_missed, 0)
	assert_eq(s.words_shown(), 0, "the word on screen is not resolved yet")
	assert_eq(s.remaining(), s.word)


func test_a_right_key_advances_through_the_word() -> void:
	var s := _session()
	var word := s.word
	assert_true(s.input_char(word[0]))
	assert_eq(s.typed_count, 1)
	assert_eq(s.remaining(), word.substr(1))


func test_typing_the_whole_word_scores_it_and_serves_the_next() -> void:
	var s := _session()
	var first := s.word
	_type_word(s)
	assert_eq(s.words_typed, 1)
	assert_eq(s.words_shown(), 1)
	assert_eq(s.typed_count, 0, "the next word starts untyped")
	assert_ne(s.word, first, "never the same word twice in a row")


## Ride round 2 (2026-10-14): a wrong key loses the word, so a typo costs it.
func test_a_wrong_key_loses_the_word_and_serves_the_next() -> void:
	var s := _session()
	var first := s.word
	assert_true(s.input_char(first[0]))
	var wrong := "z" if first[1] != "z" else "q"
	assert_false(s.input_char(wrong))
	assert_eq(s.errors, 1)
	assert_eq(s.words_missed, 1, "shown, not typed")
	assert_eq(s.words_typed, 0)
	assert_ne(s.word, first, "the next word is up")
	assert_eq(s.typed_count, 0, "and starts untyped")
	assert_almost_eq(s.time_left(), WINDOW, 0.0001, "with its whole window")
	assert_almost_eq(s.score(), 0.0, 0.0001)


func test_capitals_type_their_lower_case_letter() -> void:
	var s := _session()
	assert_true(s.input_char(s.word[0].to_upper()), "caps lock is not a typo")


func test_every_word_gets_the_same_window_whatever_its_length() -> void:
	var s := _session(0)
	for i in 5:
		assert_almost_eq(s.window(), WINDOW, 0.0001)
		_type_word(s)
	assert_almost_eq(s.time_left(), s.window(), 0.0001)
	assert_almost_eq(s.window_fraction(), 1.0, 0.0001)


func test_play_speed_shrinks_the_window() -> void:
	var slow := _session(4, 1.0)
	var fast := _session(4, 2.0)
	assert_eq(fast.word, slow.word, "same seed, same word")
	assert_almost_eq(fast.window(), slow.window() / 2.0, 0.0001)


func test_play_speed_has_a_floor() -> void:
	var s := _session(4, 0.0)
	assert_almost_eq(s.window(), WINDOW / BurstSession.MIN_SPEED, 0.0001,
			"a zero speed is the slowest stream, not a divide by zero")


func test_a_window_never_drops_under_the_floor() -> void:
	var s := BurstSession.new(4, 0.0, 1.0, _rng())
	assert_almost_eq(s.window(), BurstSession.MIN_WINDOW, 0.0001,
			"a zero window would stall tick() forever")
	s.tick(BurstSession.MIN_WINDOW * 3.5)
	assert_eq(s.words_missed, 3)


func test_time_runs_the_word_down_without_expiring_it() -> void:
	var s := _session()
	var word := s.word
	s.tick(0.5)
	assert_eq(s.word, word)
	assert_almost_eq(s.time_left(), WINDOW - 0.5, 0.0001)
	assert_almost_eq(s.window_fraction(), (WINDOW - 0.5) / WINDOW, 0.0001)
	assert_eq(s.words_missed, 0)


func test_a_word_expires_exactly_when_its_window_is_used_up() -> void:
	var s := _session()
	s.tick(s.time_left())
	assert_eq(s.words_missed, 1)
	assert_almost_eq(s.time_left(), WINDOW, 0.0001, "the next word starts with its full window")


func test_a_word_left_past_its_window_expires_as_a_miss() -> void:
	var s := _session()
	s.input_char(s.word[0])
	s.tick(WINDOW + 0.01)
	assert_eq(s.words_missed, 1)
	assert_eq(s.words_shown(), 1)
	assert_eq(s.typed_count, 0, "a half-typed word is still a miss and the next starts clean")
	assert_almost_eq(s.time_left(), WINDOW - 0.01, 0.0001, "the overshoot runs into the next word")


func test_one_long_tick_expires_every_word_it_covers() -> void:
	var s := _session()
	s.tick(WINDOW * 3.0 + 0.01)
	assert_eq(s.words_missed, 3)


func test_the_next_word_after_an_expiry_takes_input() -> void:
	var s := _session()
	s.tick(WINDOW + 0.01)
	assert_true(s.input_char(s.word[0]))


func test_score_is_words_typed_over_words_shown() -> void:
	var s := _session()
	_type_word(s)
	_type_word(s)
	_type_word(s)
	s.tick(WINDOW)
	assert_eq(s.words_shown(), 4)
	assert_almost_eq(s.score(), 0.75, 0.0001)


func test_score_ignores_the_unfinished_word_on_screen() -> void:
	var s := _session()
	_type_word(s)
	s.input_char(s.word[0])
	assert_almost_eq(s.score(), 1.0, 0.0001, "the word still on screen had no full window")


func test_nothing_shown_scores_zero() -> void:
	assert_almost_eq(_session().score(), 0.0, 0.0001)


func test_the_same_seed_streams_the_same_words() -> void:
	var a := _session(3, 1.0, 11)
	var b := _session(3, 1.0, 11)
	for i in 5:
		assert_eq(a.word, b.word)
		_type_word(a)
		_type_word(b)


func test_no_word_follows_itself_at_any_tier() -> void:
	for tier in 5:
		var s := _session(tier)
		for i in 40:
			var previous := s.word
			_type_word(s)
			assert_ne(s.word, previous, "tier %d" % tier)


func test_a_list_word_never_repeats_the_word_it_avoids() -> void:
	for tier in [4, 3]:
		var rng := _rng()
		for avoid in BurstSession.WORDS[tier]:
			for i in 10:
				assert_ne(BurstSession.word_for(tier, rng, avoid), avoid)


func test_unlike_changes_only_a_clash_and_keeps_its_length() -> void:
	assert_eq(BurstSession.unlike("memo", "sync"), "memo", "no clash, no change")
	var bumped := BurstSession.unlike("memo", "memo")
	assert_ne(bumped, "memo")
	assert_eq(bumped.length(), 4)
	assert_true(_is_letters(BurstSession.unlike("buzz", "buzz")), "z wraps to a letter")


func test_the_top_tier_draws_short_clean_words() -> void:
	var rng := _rng()
	for i in 30:
		assert_has(BurstSession.WORDS[4], BurstSession.word_for(4, rng))


func test_tier_three_draws_longer_clean_words() -> void:
	var rng := _rng()
	for i in 30:
		assert_has(BurstSession.WORDS[3], BurstSession.word_for(3, rng))


func test_lower_tiers_garble_long_words_progressively() -> void:
	var span := _lengths(BurstSession.LONG_WORDS)
	var garbled := {1: 0, 2: 0}
	for tier in [2, 1]:
		var rng := _rng()
		for i in 60:
			var w := BurstSession.word_for(tier, rng)
			assert_true(_is_letters(w), "%s is typeable letters" % w)
			assert_between(w.length(), span.x, span.y, "%s keeps a long word's length" % w)
			if not BurstSession.LONG_WORDS.has(w):
				garbled[tier] += 1
	assert_gt(garbled[2], 0, "tier 2 garbles some words")
	assert_gt(garbled[1], garbled[2], "tier 1 garbles more than tier 2")


func test_the_bottom_tier_is_keysmash() -> void:
	var rng := _rng()
	for i in 30:
		var w := BurstSession.word_for(0, rng)
		assert_true(_is_letters(w), "%s is typeable letters" % w)
		assert_between(w.length(), BurstSession.SMASH_MIN, BurstSession.SMASH_MAX)


func test_words_never_get_shorter_as_the_tier_falls() -> void:
	var top := _lengths(BurstSession.WORDS[4])
	var clean := _lengths(BurstSession.WORDS[3])
	var long := _lengths(BurstSession.LONG_WORDS)
	assert_lt(top.y, clean.x, "tier 4's longest is shorter than tier 3's shortest")
	assert_lt(clean.y, long.x, "tier 3's longest is shorter than the garbled tiers' shortest")
	assert_lt(long.y, BurstSession.SMASH_MIN, "keysmash is the longest of all")


## A typist clears a word when its reaction plus a per-letter time fits the
## window. Lower clarity must never make more words clearable — for a fast
## typist or a slow one — or the energy and coffee levers read inverted.
func test_the_share_of_clearable_words_never_rises_as_the_tier_falls() -> void:
	var cfg := BalanceConfig.new()
	var typists := {"fast": Vector2(0.25, 0.15), "slow": Vector2(0.6, 0.3)}
	for rank in cfg.burst_word_windows.size():
		var window: float = cfg.burst_word_windows[rank]
		for typist in typists:
			var t: Vector2 = typists[typist]
			var previous := 1.0
			for tier in [4, 3, 2, 1, 0]:
				var rng := _rng()
				var clear := 0
				for i in 200:
					if t.x + t.y * BurstSession.word_for(tier, rng).length() <= window:
						clear += 1
				var share := clear / 200.0
				assert_true(share <= previous,
						"%s typist, rank %d: tier %d clears %.2f, above %.2f" % [
							typist, rank, tier, share, previous])
				previous = share
