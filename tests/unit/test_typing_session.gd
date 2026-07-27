extends GutTest


func test_correct_chars_advance() -> void:
	var t := TypingSession.new("cat")
	assert_true(t.input_char("c"))
	assert_true(t.input_char("a"))
	assert_true(t.input_char("t"))
	assert_true(t.is_complete())
	assert_eq(t.errors, 0)


func test_wrong_char_counts_error_no_advance() -> void:
	var t := TypingSession.new("cat")
	assert_false(t.input_char("x"))
	assert_eq(t.errors, 1)
	assert_eq(t.typed_count, 0)
	assert_eq(t.wrong_buffer, "x")


func test_wrong_char_blocks_until_backspaced() -> void:
	var t := TypingSession.new("cat")
	t.input_char("x")
	assert_false(t.input_char("c"))  # the right key, still blocked
	assert_eq(t.typed_count, 0)
	assert_eq(t.errors, 2)
	assert_eq(t.wrong_buffer, "xc")
	t.backspace()
	t.backspace()
	assert_eq(t.wrong_buffer, "")
	assert_true(t.input_char("c"))
	assert_eq(t.typed_count, 1)


func test_backspace_is_never_an_error() -> void:
	var t := TypingSession.new("cat")
	t.input_char("x")
	assert_true(t.backspace())
	assert_false(t.backspace())  # already empty
	assert_eq(t.errors, 1)


func test_backspace_never_erases_correct_progress() -> void:
	var t := TypingSession.new("cat")
	t.input_char("c")
	assert_false(t.backspace())
	assert_eq(t.typed_count, 1)
	assert_eq(t.errors, 0)


func test_wrong_buffer_stops_growing_at_the_cap() -> void:
	var t := TypingSession.new("cat", 3)
	for c in "xyzwv":
		t.input_char(c)
	assert_eq(t.wrong_buffer, "xyz")
	assert_eq(t.errors, 5)


func test_input_after_complete_ignored() -> void:
	var t := TypingSession.new("a")
	t.input_char("a")
	assert_false(t.input_char("a"))
	assert_eq(t.errors, 0)
	assert_eq(t.wrong_buffer, "")
