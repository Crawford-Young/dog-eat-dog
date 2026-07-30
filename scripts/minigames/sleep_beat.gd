extends Minigame

## Bedtime stopped being a choice — it fell out of how many "one more game"s
## happened at freetime. This beat is non-interactive: it just types out what
## the night turned into, holds a moment, and ends the day.

## The band's FEEL, with no hour in it. The evening clock states the time now,
## and a hardcoded "3am" contradicts a 23:41 bedtime the player just watched.
const LINES := {
	"early": "the ceiling is still boring and you are already gone.",
	"mid": "one last scroll, you promise yourself. it is not the last scroll.",
	"late": "the room is blue with screen light. the alarm is closer than it should be.",
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
	var lines: Array[String] = [
		"%s. %s" % [params.get("bed_clock", "23:30"), LINES.get(bedtime, LINES["mid"])],
	]
	var ledger: String = params.get("ledger", "")
	if not ledger.is_empty():
		lines.append(ledger)
	_typer.play("\n".join(lines), params.get("text_speed", Typewriter.DEFAULT_CHARS_PER_SEC))


func _on_line_finished() -> void:
	_holding = true


func _process(delta: float) -> void:
	if not _holding:
		return
	_held += delta
	if _held >= _hold:
		_holding = false
		_finish(1.0)
