extends Minigame

## Mash SPACE to fill the bar. A bar still short of full at the time limit is
## a MISS (issue #17).

const FAIL_GAG := "😴⏰"

var _logic: WakeLogic

@onready var _bar: ProgressBar = %WakeBar


func setup(params: Dictionary) -> void:
	_logic = WakeLogic.new(params)
	_start(params)


func _process(delta: float) -> void:
	if not _running:
		return
	_logic.tick(delta)
	_bar.value = _logic.progress
	if _logic.is_done():
		_finish(1.0)


func _on_timeout() -> void:
	if _logic.is_done():
		_finish(1.0)
	else:
		_fail(FAIL_GAG)


func _unhandled_input(event: InputEvent) -> void:
	if _running and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		_logic.press()
