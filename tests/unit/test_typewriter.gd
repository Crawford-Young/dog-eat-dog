extends GutTest

## Typewriter is pure logic: elapsed time in, visible character count out.


func test_starts_with_nothing_visible() -> void:
	var t := Typewriter.new("hello", 10.0)
	assert_eq(t.visible_count(), 0)
	assert_eq(t.visible_text(), "")
	assert_false(t.is_done())


func test_reveals_at_the_configured_rate() -> void:
	var t := Typewriter.new("hello there", 10.0)
	t.advance(0.25)
	assert_eq(t.visible_text(), "he")
	t.advance(0.25)
	assert_eq(t.visible_text(), "hello")
	assert_false(t.is_done())


func test_never_reveals_past_the_end() -> void:
	var t := Typewriter.new("hi", 10.0)
	t.advance(99.0)
	assert_eq(t.visible_count(), 2)
	assert_eq(t.visible_text(), "hi")
	assert_true(t.is_done())


func test_skip_reveals_everything() -> void:
	var t := Typewriter.new("hello", 1.0)
	t.advance(0.5)
	t.skip()
	assert_eq(t.visible_text(), "hello")
	assert_true(t.is_done())


func test_empty_text_is_done_immediately() -> void:
	var t := Typewriter.new("", 30.0)
	assert_true(t.is_done())
	assert_eq(t.visible_text(), "")


func test_restart_replaces_text_and_rewinds() -> void:
	var t := Typewriter.new("first", 10.0)
	t.advance(1.0)
	t.restart("second")
	assert_eq(t.visible_count(), 0)
	assert_false(t.is_done())
	t.advance(0.25)
	assert_eq(t.visible_text(), "se")


func test_default_rate_is_fast_enough_for_a_short_line() -> void:
	var t := Typewriter.new("abcdefghij")
	t.advance(1.0)
	assert_true(t.is_done())


func test_non_positive_rate_reveals_instantly() -> void:
	var t := Typewriter.new("hello", 0.0)
	t.advance(0.001)
	assert_true(t.is_done())
	assert_eq(t.visible_text(), "hello")
