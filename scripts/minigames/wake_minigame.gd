extends Minigame

var _logic: WakeLogic

@onready var _bar: ProgressBar = %WakeBar


func setup(params: Dictionary) -> void:
	_logic = WakeLogic.new(params)
	_start()


func _process(delta: float) -> void:
	if not _running:
		return
	_logic.tick(delta)
	_bar.value = _logic.progress
	if _logic.is_done():
		_finish(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if _running and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		_logic.press()
