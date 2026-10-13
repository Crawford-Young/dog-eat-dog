extends Minigame

## Drag each item onto the dog. Shoes bounce off until pants are on. Low
## energy = butterfingers: a per-second fumble roll drops the held item.
## Mandatory — no skip; fumbles cost clock, and still being undressed at the
## time limit is a MISS (issue #17). Each item draws as its icon prop over the
## same hit rect, and a dropped item's icon wobbles; that is presentation only.

const FAIL_GAG := "👕😳"
## clothes/<name>.png draws each prop (an item's slot is its name in lower
## case); until it exists, these emoji.
const ITEM_PLACEHOLDERS := {
	"Shirt": "👕", "Pants": "👖", "Shoes": "👟", "Collar": "📿",
}
const DOG_PLACEHOLDER := "🐕"
const ITEM_FONT_SIZE := 44
const DOG_FONT_SIZE := 200
## A dropped icon tips this far each way, in radians, over this many seconds.
const WOBBLE_ANGLE := 0.35
const WOBBLE_SECONDS := 0.3

var _logic := DressLogic.new()
var _fumble_chance: float = 0.0
var _held: Control = null
var _held_home: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator

@onready var _dog_zone: ColorRect = %DogZone
@onready var _status: Label = %Status


func _art_folder() -> String:
	return "clothes"


func _ready() -> void:
	_dog_zone.add_child(_prop("dog", DOG_PLACEHOLDER, DOG_FONT_SIZE))
	for item: Control in _item_nodes():
		var slot := String(item.name)
		item.add_child(_prop(slot.to_lower(), ITEM_PLACEHOLDERS[slot], ITEM_FONT_SIZE))


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
	_wobble(_held)
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


## Tips the item's icon to and fro about its centre; the item itself, and so
## its hit rect, stays put.
func _wobble(item: Control) -> void:
	var art := item.get_child(0) as Control
	art.pivot_offset = art.size / 2.0
	var step := WOBBLE_SECONDS / 3.0
	var tween := art.create_tween()
	tween.tween_property(art, "rotation", WOBBLE_ANGLE, step)
	tween.tween_property(art, "rotation", -WOBBLE_ANGLE, step)
	tween.tween_property(art, "rotation", 0.0, step)
