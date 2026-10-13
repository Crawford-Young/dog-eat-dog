extends Minigame

## Work PM's inbox triage (issue #18): TriageSession lands emails in an inbox;
## A (or Left) replies to the one on top and D (or Right) trashes it, by its
## subject icon. The shift timer ends the triage. Score = correct sorts /
## emails shown; a triage under fail_score is an inbox-avalanche MISS that
## keeps its real score, because the work EMA reads it (#17).

## The inbox avalanche.
const FAIL_GAG := "📨"
## The subject icons by TriageSession icon index: [art slot, placeholder].
## The first TriageSession.WORK_ICONS are work (reply), the rest junk (trash).
const ICONS := [
	["report", "📊"], ["meeting", "📅"], ["invoice", "🧾"],
	["jackpot", "🎰"], ["sale", "🛍️"], ["prince", "🤴"],
]
## work_pm/<name>.png draws each desk prop; until it exists, these emoji.
const MONITOR_PLACEHOLDER := "🖥️"
const REPLY_PLACEHOLDER := "📤"
const TRASH_PLACEHOLDER := "🗑️"
const MONITOR_FONT_SIZE := 260
const EMAIL_FONT_SIZE := 110
const BIN_FONT_SIZE := 90
const PILE_FONT_SIZE := 40
## How faint the top email is while it is still out of focus.
const BLUR_ALPHA := 0.15
## How long a bin shows green (right) or red (wrong) after a sort.
const FLASH_SECONDS := 0.2
const RIGHT_FLASH := Color(0.5, 1.0, 0.5)
const WRONG_FLASH := Color(1.0, 0.4, 0.4)

var _session: TriageSession
## A triage scoring under this is a MISS; 0 (no param) never misses.
var _fail_score: float = 0.0
var _flash_left: float = 0.0
var _flash_bin: Control
## What the inbox last drew: [top email id, waiting icons].
var _drawn: Array = []

@onready var _monitor_slot: Control = %MonitorSlot
@onready var _email_slot: Control = %EmailSlot
@onready var _email_bar: ProgressBar = %EmailBar
@onready var _pile: HBoxContainer = %PileRow
@onready var _reply_slot: Control = %ReplySlot
@onready var _trash_slot: Control = %TrashSlot
@onready var _shift_bar: ProgressBar = %ShiftBar
@onready var _tally: Label = %TallyLabel


func _art_folder() -> String:
	return "work_pm"


## The live inbox, read-only by contract: the autoplay bot reads the email on
## top from it and sorts through real key events.
func session() -> TriageSession:
	return _session


func _ready() -> void:
	_monitor_slot.add_child(_art("monitor", MONITOR_PLACEHOLDER, MONITOR_FONT_SIZE))
	_reply_slot.add_child(_art("reply", REPLY_PLACEHOLDER, BIN_FONT_SIZE))
	_trash_slot.add_child(_art("trash", TRASH_PLACEHOLDER, BIN_FONT_SIZE))


func setup(params: Dictionary) -> void:
	_session = TriageSession.new(params, RngSource.from_params(params))
	_fail_score = params.get("fail_score", 0.0)
	_start_countdown(params.shift_time)
	_start(params)
	_render()


func _process(delta: float) -> void:
	if not _running:
		return
	_session.tick(delta)
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left <= 0.0 and _flash_bin:
		_flash_bin.modulate = Color.WHITE
		_flash_bin = null
	_render()


## The shift timer is the base countdown: the triage ends when it runs out.
func _on_timeout() -> void:
	var score := _session.score()
	if score < _fail_score:
		_fail(FAIL_GAG, {"score": score})
	else:
		_finish(score)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _running or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT:
			_sort(true)
		KEY_D, KEY_RIGHT:
			_sort(false)


func _sort(reply: bool) -> void:
	var outcome := _session.sort(reply)
	if outcome == TriageSession.IGNORED:
		return
	if _flash_bin:
		_flash_bin.modulate = Color.WHITE
	_flash_bin = _reply_slot if reply else _trash_slot
	_flash_bin.modulate = RIGHT_FLASH if outcome == TriageSession.CORRECT else WRONG_FLASH
	_flash_left = FLASH_SECONDS
	_render()


## The bars and the focus move every frame; the art is rebuilt only when the
## inbox changes.
func _render() -> void:
	_email_bar.value = _session.front_fraction()
	_shift_bar.value = time_fraction()
	_email_slot.modulate.a = lerpf(BLUR_ALPHA, 1.0, _session.focus_fraction())
	var state := [_session.front_id(), _session.icons()]
	if state == _drawn:
		return
	_drawn = state
	_clear(_email_slot)
	var icons := _session.icons()
	if not icons.is_empty():
		var top: Array = ICONS[icons[0]]
		_email_slot.add_child(_art(top[0], top[1], EMAIL_FONT_SIZE))
	_clear(_pile)
	for icon in icons.slice(1):
		var art := _art(ICONS[icon][0], ICONS[icon][1], PILE_FONT_SIZE)
		art.custom_minimum_size = Vector2(PILE_FONT_SIZE, PILE_FONT_SIZE) * 1.2
		_pile.add_child(art)
	_tally.text = "sorted right: %d / %d" % [_session.correct, _session.emails_shown()]


## A work_pm art slot filling its parent: the PNG, or `placeholder` centred at
## `font_size`. PropArt makes it mouse-transparent either way.
func _art(slot: String, placeholder: String, font_size: int) -> Control:
	var art := PropArt.make(_art_folder(), slot, placeholder, props_root)
	if art is Label:
		var label := art as Label
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", font_size)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art


## Frees `parent`'s children now, so a count read this frame is current.
func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
