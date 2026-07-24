extends GutTest


func _beats() -> Array:
	return [
		{"t": 1.0, "cue": "nod", "emoji": "(^-^)", "text": "big project right?"},
		{"t": 3.0, "cue": "none", "emoji": "(-_-)", "text": "let me vent a sec"},
		{"t": 5.0, "cue": "shake", "emoji": "(?!)", "text": "can you believe it?"},
	]


func test_hit_inside_window() -> void:
	var s := ListeningSession.new(_beats(), 1.0)
	s.advance(1.2)
	assert_eq(s.gesture("nod"), "hit")
	assert_eq(s.hits, 1)


func test_wrong_gesture_inside_window() -> void:
	var s := ListeningSession.new(_beats(), 1.0)
	s.advance(1.2)
	assert_eq(s.gesture("shake"), "wrong")
	assert_eq(s.misses, 1)


func test_expired_cue_counts_miss() -> void:
	var s := ListeningSession.new(_beats(), 1.0)
	var expired := s.advance(2.5)  # beat 1 window (1.0-2.0) passed unanswered
	assert_eq(expired.size(), 1)
	assert_eq(s.misses, 1)


func test_gesture_during_none_trap_is_wrong() -> void:
	var s := ListeningSession.new(_beats(), 1.0)
	s.advance(3.2)
	assert_eq(s.gesture("nod"), "wrong")


func test_gesture_between_beats_is_idle() -> void:
	var s := ListeningSession.new(_beats(), 1.0)
	s.advance(0.5)
	assert_eq(s.gesture("nod"), "idle")
	assert_eq(s.misses, 0)


func test_double_hit_same_beat_ignored() -> void:
	var s := ListeningSession.new(_beats(), 1.0)
	s.advance(1.2)
	s.gesture("nod")
	assert_eq(s.gesture("nod"), "idle")
	assert_eq(s.hits, 1)


func test_full_run_score() -> void:
	var s := ListeningSession.new(_beats(), 1.0)
	s.advance(1.2)
	s.gesture("nod")
	s.advance(4.0)  # through beat 2 (none, silent) into beat 3
	s.gesture("shake")
	s.advance(2.0)
	assert_true(s.is_over())
	assert_almost_eq(s.score(), 1.0, 0.001)  # 2 hits / 2 gesture cues
