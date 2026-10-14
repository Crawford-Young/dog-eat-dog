extends Minigame

## The coffee cart's cup grab (issue #18): CoffeeSession slides a cup past the
## desk; SPACE or a click makes the dog grab at it. A press while the cup is in
## the paw's zone buys the coffee; a press off the cup spills it (a MISS that
## still pays the cart); a cup left to pass is water, a choice and no result.
## A dog that cannot pay sees the cup greyed out and its presses do nothing.

## The spilled coffee.
const FAIL_GAG := "💦"
## coffee/<name>.png draws each prop; until it exists, these emoji.
const CUP_PLACEHOLDER := "☕"
const DESK_PLACEHOLDER := "🗄️"
const PAW_PLACEHOLDER := "🐾"
const CUP_FONT_SIZE := 110
const DESK_FONT_SIZE := 220
const PAW_FONT_SIZE := 90
## Half the cup slot's width, in pixels either side of its place on the track.
const CUP_HALF_WIDTH := 70.0
## How the cup is tinted when the dog cannot pay for it.
const BROKE_TINT := Color(0.5, 0.5, 0.5, 0.45)
const HINT := "SPACE or click to grab it"
const BROKE_HINT := "can't afford it. let it pass"

var _session: CoffeeSession

@onready var _desk_slot: Control = %DeskSlot
@onready var _zone: Control = %Zone
@onready var _paw_slot: Control = %PawSlot
@onready var _cup_slot: Control = %CupSlot
@onready var _hint: Label = %Hint


func _art_folder() -> String:
	return "coffee"


## The live cup, read-only by contract: the autoplay bot times its press from it.
func session() -> CoffeeSession:
	return _session


func probe_detail() -> Dictionary:
	return _session.probe_detail() if _session else {}


func _ready() -> void:
	_desk_slot.add_child(_prop("desk", DESK_PLACEHOLDER, DESK_FONT_SIZE))
	_paw_slot.add_child(_prop("paw", PAW_PLACEHOLDER, PAW_FONT_SIZE))
	_cup_slot.add_child(_prop("cup", CUP_PLACEHOLDER, CUP_FONT_SIZE))
	_cup_slot.offset_left = -CUP_HALF_WIDTH
	_cup_slot.offset_right = CUP_HALF_WIDTH


func setup(params: Dictionary) -> void:
	_session = CoffeeSession.new(params)
	var half := _session.zone_width() / 2.0
	for control: Control in [_zone, _paw_slot]:
		control.anchor_left = _session.zone_center() - half
		control.anchor_right = _session.zone_center() + half
	if not _session.can_afford():
		_cup_slot.modulate = BROKE_TINT
	_hint.text = HINT if _session.can_afford() else BROKE_HINT
	_start(params)
	_render()


func _process(delta: float) -> void:
	if not _running:
		return
	_session.tick(delta)
	_render()
	if _session.outcome() == CoffeeSession.SKIP:
		_finish_with({"choice": CoffeeSession.SKIP})


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_SPACE:
		_grab()
	elif click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_grab()


func _grab() -> void:
	match _session.grab():
		CoffeeSession.BUY:
			_finish_with({"choice": CoffeeSession.BUY})
		CoffeeSession.SPILL:
			_fail(FAIL_GAG, {"choice": CoffeeSession.SPILL})


func _render() -> void:
	_cup_slot.visible = _session.cup_on_screen()
	_cup_slot.anchor_left = _session.position()
	_cup_slot.anchor_right = _session.position()
