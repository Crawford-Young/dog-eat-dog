extends GutTest

## Node-level regression coverage for the typing minigame's key filter.
## TypingSession itself is covered by test_typing_session.gd — this is only
## the InputEventKey -> char() translation that sits in front of it.

const TypingScene := preload("res://scenes/minigames/typing.tscn")


func _minigame() -> Minigame:
	var node: Minigame = TypingScene.instantiate()
	add_child_autofree(node)
	node.setup({"tier": 4, "error_tolerance": 0.3, "wrong_cap": 5})
	return node


func _key_event(keycode: Key, unicode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.unicode = unicode
	return event


func test_modifier_keydown_does_not_jam_the_wrong_buffer() -> void:
	var node := _minigame()
	# Shift carries unicode 0 — char(0) is a length-1 NUL string, not "", so a
	# naive "" guard lets it through and jams a NUL into the wrong buffer.
	node._unhandled_key_input(_key_event(KEY_SHIFT, 0))
	assert_eq(node._session.wrong_buffer, "", "a bare modifier must not register as a wrong key")
	assert_eq(node._session.typed_count, 0, "a bare modifier must not advance typing either")


func test_printable_keydown_still_advances() -> void:
	var node := _minigame()
	var first_char: String = node._target[0]
	node._unhandled_key_input(_key_event(KEY_NONE, first_char.unicode_at(0)))
	assert_eq(node._session.typed_count, 1, "a real printable key still types normally")
