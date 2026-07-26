class_name NarrationBeat
extends Minigame

## One typed line, a beat of stillness, done. Copy comes in through params
## so scenes stay copy-free and game.gd owns the words.

var _hold: float = 1.4
var _held: float = 0.0
var _holding: bool = false

@onready var _line: Label = %Line
@onready var _typer := TypewriterLabel.new()


func _ready() -> void:
	add_child(_typer)
	_typer.bind(_line)
	_typer.completed.connect(func() -> void: _holding = true)
	_line.text = ""


func setup(params: Dictionary) -> void:
	_hold = params.get("hold", _hold)
	_typer.play(params.get("text", ""), params.get("text_speed", Typewriter.DEFAULT_CHARS_PER_SEC))


func _process(delta: float) -> void:
	if not _holding:
		return
	_held += delta
	if _held >= _hold:
		_holding = false
		_finish(1.0)
