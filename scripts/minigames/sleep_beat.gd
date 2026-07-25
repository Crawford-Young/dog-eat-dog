extends Minigame

## Bedtime stopped being a choice — it fell out of how many "one more game"s
## happened at freetime. This beat is non-interactive: it just types out what
## the night turned into, holds a moment, and ends the day.

const LINES := {
	"early": "10pm. the ceiling gets twenty solid minutes of your attention, and then you are out.",
	"mid": "midnight. one last scroll, you promise yourself. it is not the last scroll.",
	"late": "3am. the room is blue with screen light. the alarm is in four hours.",
}

var _hold: float = 1.4
var _held: float = 0.0
var _holding: bool = false

@onready var _line: Label = %Line
@onready var _typer := TypewriterLabel.new()


func _ready() -> void:
	add_child(_typer)
	_typer.bind(_line)
	_typer.completed.connect(_on_line_finished)
	_line.text = ""


func setup(params: Dictionary) -> void:
	_hold = params.get("hold", _hold)
	var bedtime: String = params.get("bedtime", "mid")
	var line: String = LINES.get(bedtime, LINES["mid"])
	_typer.play(line, params.get("text_speed", Typewriter.DEFAULT_CHARS_PER_SEC))


func _on_line_finished() -> void:
	_holding = true


func _process(delta: float) -> void:
	if not _holding:
		return
	_held += delta
	if _held >= _hold:
		_holding = false
		_finish(1.0)
