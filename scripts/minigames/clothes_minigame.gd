extends Minigame

## Drag each item onto the dog. Shoes bounce off until pants are on. Low
## energy = butterfingers: a per-second fumble roll drops the held item.
## Mandatory — no skip; fumbles cost clock, and still being undressed at the
## time limit is a MISS (issue #17).

const FAIL_GAG := "👕😳"

var _logic := DressLogic.new()
var _fumble_chance: float = 0.0
var _held: Control = null
var _held_home: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator

@onready var _dog_zone: ColorRect = %DogZone
@onready var _status: Label = %Status


func _art_folder() -> String:
	return "clothes"


func setup(params: Dictionary) -> void:
	_fumble_chance = params.fumble_chance
	_rng = RngSource.from_params(params)
	_start(params)
	_status.text = "get dressed!"


func _item_nodes() -> Array:
	return get_node("%Items").get_children()


func _process(delta: float) -> void:
	if not _running or _held == null:
		return
	_held.global_position = get_global_mouse_position() - _held.size / 2.0
	if _rng.randf() < _fumble_chance * delta:
		_drop_home("fumble! it slipped")


func _on_timeout() -> void:
	if _logic.is_dressed():
		_finish(1.0)
	else:
		_fail(FAIL_GAG)


func _drop_home(message: String) -> void:
	_held.position = _held_home
	_held = null
	_status.text = message


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(event.position)
		elif _held != null:
			_try_wear()


func _try_grab(at: Vector2) -> void:
	for item in _item_nodes():
		if item is Control and item.visible \
				and (item as Control).get_global_rect().has_point(at):
			_held = item
			_held_home = item.position
			return


func _try_wear() -> void:
	var over_dog := _dog_zone.get_global_rect().intersects(_held.get_global_rect())
	if not over_dog:
		_drop_home("onto the dog!")
		return
	var item_name := String(_held.name).to_lower()
	if _logic.wear(item_name):
		_held.visible = false
		_held = null
		_status.text = "%s on!" % item_name
		if _logic.is_dressed():
			_finish(1.0)
	else:
		_drop_home("not yet! (shoes need pants)")
