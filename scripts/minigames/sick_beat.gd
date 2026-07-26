extends Minigame

## The floor. The dog cannot get up today — the mash is inverted: burrow
## INTO the blanket. Press count decides tomorrow's recovery quality.
## Always exactly one day; mash never shortens or lengthens it.

var _target: int = 20
var _window: float = 6.0
var _elapsed: float = 0.0
var _presses: int = 0
var _mashing: bool = false
var _narrating: bool = false
var _text_speed: float = 30.0

@onready var _prompt: Label = %Prompt
@onready var _bar: ProgressBar = %BurrowBar
@onready var _typer := TypewriterLabel.new()


func _ready() -> void:
	add_child(_typer)
	_typer.bind(_prompt)
	_typer.completed.connect(_on_narration_done)


func setup(params: Dictionary) -> void:
	_target = params.get("burrow_target", _target)
	_window = params.get("burrow_time", _window)
	_text_speed = params.get("text_speed", _text_speed)
	_prompt.text = "everything hurts. burrow. (mash SPACE)"
	_mashing = true


func press() -> void:
	if _mashing:
		_presses += 1
		_bar.value = clampf(float(_presses) / float(_target), 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if _mashing and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		press()


func _process(delta: float) -> void:
	if not _mashing:
		return
	_elapsed += delta
	if _elapsed >= _window:
		_mashing = false
		_narrating = true
		_typer.play("the day happens somewhere else. the burrito holds.", _text_speed)


func _on_narration_done() -> void:
	if _narrating:
		_narrating = false
		_finish(clampf(float(_presses) / float(_target), 0.0, 1.0))
