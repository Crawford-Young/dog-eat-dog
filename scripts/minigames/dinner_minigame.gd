extends Minigame

## Dinner as a walk (issue #18): DinnerSession walks the dog along the kitchen
## floor while A / LEFT or D / RIGHT is held. Reaching the pan cooks (game.gd
## then hosts the pan); reaching the phone orders takeout. Running out of time
## first is the sad kibble, a MISS with no dinner. A dog that cannot pay for
## takeout sees the phone greyed out, and reaching it does nothing.

## The sad kibble.
const FAIL_GAG := "🥣"
## dinner/<name>.png draws each prop; until it exists, these emoji.
const DOG_PLACEHOLDER := "🐕"
const PAN_PLACEHOLDER := "🍳"
const PHONE_PLACEHOLDER := "📱"
const DOG_FONT_SIZE := 110
const TARGET_FONT_SIZE := 120
## Half the dog slot's width, in pixels either side of its place on the floor.
const DOG_HALF_WIDTH := 70.0
## How the phone is tinted when the dog cannot pay for takeout.
const BROKE_TINT := Color(0.5, 0.5, 0.5, 0.45)
const HINT := "hold A or D to walk: the pan to cook, the phone for takeout"
const BROKE_HINT := "too broke for takeout. walk to the pan"
const LEFT_KEYS: Array[Key] = [KEY_A, KEY_LEFT]
const RIGHT_KEYS: Array[Key] = [KEY_D, KEY_RIGHT]

var _session: DinnerSession
var _left_held := false
var _right_held := false

@onready var _pan_slot: Control = %PanSlot
@onready var _phone_slot: Control = %PhoneSlot
@onready var _dog_slot: Control = %DogSlot
@onready var _hint: Label = %Hint


func _art_folder() -> String:
	return "dinner"


## The live walk, read-only by contract: the autoplay bot steers from it.
func session() -> DinnerSession:
	return _session


func _ready() -> void:
	_pan_slot.add_child(_prop("pan", PAN_PLACEHOLDER, TARGET_FONT_SIZE))
	_phone_slot.add_child(_prop("phone", PHONE_PLACEHOLDER, TARGET_FONT_SIZE))
	_dog_slot.add_child(_prop("dog", DOG_PLACEHOLDER, DOG_FONT_SIZE))
	_dog_slot.offset_left = -DOG_HALF_WIDTH
	_dog_slot.offset_right = DOG_HALF_WIDTH


func setup(params: Dictionary) -> void:
	_session = DinnerSession.new(params)
	if not _session.can_afford():
		_phone_slot.modulate = BROKE_TINT
	_hint.text = HINT if _session.can_afford() else BROKE_HINT
	_start(params)
	_render()


func _process(delta: float) -> void:
	if not _running:
		return
	_session.tick(delta)
	_render()
	if _session.outcome() != "":
		_finish_with({"choice": _session.outcome()})


func _on_timeout() -> void:
	_fail(FAIL_GAG)


## Held keys set the heading: one side held walks that way, both or neither
## stands still.
func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	if key.physical_keycode in LEFT_KEYS:
		_left_held = key.pressed
	elif key.physical_keycode in RIGHT_KEYS:
		_right_held = key.pressed
	else:
		return
	_session.walk(int(_right_held) - int(_left_held))


func _render() -> void:
	_dog_slot.anchor_left = _session.position()
	_dog_slot.anchor_right = _session.position()
