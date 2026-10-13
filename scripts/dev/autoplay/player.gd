extends RefCounted

## The oracle player. One coroutine per hosted node reads the node's internals
## to decide WHAT to press (lane state, the typing target, spot positions, beat
## timing) and then presses it through Hands, as real InputEvents. It never
## calls a minigame method, a button's pressed signal or a game.gd handler.
##
## Every coroutine re-checks that its node is still hosted after each await,
## so a node that finished mid-gesture is simply abandoned.

## Emitted by the runner once per frame, after Hands.tick().
signal ticked

const Hands := preload("res://scripts/dev/autoplay/hands.gd")
const FRAME := 1.0 / 60.0
const TYPO_KEYS := "qwertyuiopasdfghjklzxcvbnm"
const BEAT_CENTER := 0.5
## A gesture can never take longer than this; it bounds every inner loop so a
## driver that misreads its game is caught by the runner's stall cap instead
## of spinning inside one frame.
const LOOP_CAP_FRAMES := 60 * 600

var hands: Hands
var profile: Dictionary
## Counted for the report: chores ducked, keyed by slot.
var skips := {}

var _rng := RandomNumberGenerator.new()


func _init(hands_: Hands, profile_: Dictionary, seed_value: int) -> void:
	hands = hands_
	profile = profile_
	_rng.seed = seed_value


## Starts the right coroutine for a freshly hosted node. `day` feeds the
## dinner policy. Fire-and-forget: the coroutine paces itself on `ticked`.
## Every screen, beats and choice cards included, is first taken in for the
## profile's orient time; only then does its driver start reacting.
func play(slot: String, node: Node, day: int) -> void:
	var orient: Vector2 = profile.orient
	if not await _wait(node, roundi(_rng.randf_range(orient.x, orient.y) * 60.0)):
		return
	match slot:
		"wake":
			_mash(node, "_running")
		"sick":
			_mash(node, "_mashing")
		"brush":
			_brush(node, slot)
		"shower":
			_shower(node, slot)
		"clothes":
			_clothes(node)
		"breakfast":
			_breakfast(node, slot)
		"drive", "drive_home":
			_drive(node)
		"coffee":
			_choose(node, "Buy" if profile.coffee == "buy" else "Skip", "Skip")
		"dinner":
			var cook: bool = day % int(profile.cook_every) == 0
			_choose(node, "Cook" if cook else "Takeout", "Cook")
		"retire_offer":
			_choose(node, "Retire", "Retire")
		"work_am", "work_pm":
			_type(node)
		"lunch":
			_listen(node)
		"cooking":
			_cook(node)
		"freetime":
			_freetime(node)
		_:
			pass  # narration beats and sleep take no input


## The summary's "next day" button — not a minigame, but clicked the same way.
func next_day(button: Button) -> void:
	if await _think(button):
		await _click(button, button)


# --- pacing -----------------------------------------------------------------


## Untyped on purpose: a typed Node parameter rejects a freed instance
## before is_instance_valid can look at it.
static func _alive(node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() \
			and not node.is_queued_for_deletion()


func _wait(node: Node, frames: int) -> bool:
	for i in maxi(frames, 1):
		await ticked
	return _alive(node)


func _react_frames() -> int:
	var r: Vector2 = profile.react
	return roundi(_rng.randf_range(r.x, r.y) * 60.0)


## One decision's worth of human reaction time.
func _think(node: Node) -> bool:
	return await _wait(node, _react_frames())


func _chance(p: float) -> bool:
	return _rng.randf() < p


# --- mouse ------------------------------------------------------------------


## A deliberate move to `to`, one motion event per frame.
func _travel(node: Node, to: Vector2) -> bool:
	var span: Vector2i = profile.travel_frames
	var n := _rng.randi_range(span.x, span.y)
	var from := hands.mouse
	for i in n:
		hands.move_to(from.lerp(to, float(i + 1) / n))
		if not await _wait(node, 1):
			return false
	return true


## Move onto the control's centre, press, release a frame later. The release
## always goes out, even when the press already ended the node.
func _click(node: Node, target: Control) -> bool:
	if not await _travel(node, target.get_global_rect().get_center()):
		return false
	hands.button(true)
	var alive := await _wait(node, 1)
	hands.button(false)
	return alive


func _skip_chore(node: Node, slot: String) -> bool:
	if not _chance(profile.skip):
		return false
	skips[slot] = skips.get(slot, 0) + 1
	if await _think(node):
		await _click(node, node.get_node("SkipButton"))
	return true


# --- beat timing ------------------------------------------------------------


## Frames from now until pressing would land the cursor on the beat's centre,
## no sooner than `min_frames`, `passes` crossings late, plus a gaussian
## timing error. Simulates a copy of the live BeatTimer, frame by frame: the
## press is delivered before the node's next _process, so pressing after t
## waits judges the position after t ticks.
func _beat_frames(beat: BeatTimer, min_frames: int, passes: int) -> int:
	var sim := BeatTimer.new(beat.get("_speed"), beat.get("_window"))
	sim.position = beat.position
	sim.set("_dir", beat.get("_dir"))
	var prev := sim.position
	var crossings := 0
	var best := min_frames
	for t in range(1, 600):
		sim.tick(FRAME)
		var cur := sim.position
		if t >= min_frames and (prev - BEAT_CENTER) * (cur - BEAT_CENTER) <= 0.0:
			crossings += 1
			if crossings > passes:
				var closer_prev := absf(prev - BEAT_CENTER) < absf(cur - BEAT_CENTER)
				best = t - 1 if closer_prev and t - 1 >= min_frames else t
				break
		prev = cur
	var error := roundi(_rng.randfn(0.0, profile.beat_sd) * 60.0)
	return maxi(best + error, 1)


func _passes() -> int:
	return 1 if _chance(profile.late_pass) else 0


# --- drivers ----------------------------------------------------------------


## Wake and the sick burrow: mash SPACE until the node stops listening.
func _mash(node: Node, flag: String) -> void:
	if not await _think(node):
		return
	var span: Vector2i = profile.mash_frames
	for i in LOOP_CAP_FRAMES:
		if not node.get(flag):
			return
		hands.tap(KEY_SPACE)
		if not await _wait(node, _rng.randi_range(span.x, span.y)):
			return


## Left-right swipes. A short swipe falls under the stroke amplitude and
## does not count, which is how a sloppy brush loses time.
func _brush(node: Node, slot: String) -> void:
	if await _skip_chore(node, slot):
		return
	if not await _think(node):
		return
	var frames: int = profile.stroke_frames
	var dir := 1.0
	for i in LOOP_CAP_FRAMES:
		var px: float = 30.0 if _chance(profile.short_stroke) else profile.stroke_px
		for f in frames:
			hands.move_by(Vector2(dir * px / frames, 0.0))
			if not await _wait(node, 1):
				return
		dir = -dir


## Circle each stink spot until it moves on.
func _shower(node: Node, slot: String) -> void:
	if await _skip_chore(node, slot):
		return
	var spot: Control = node.get_node("%Spot")
	var step: float = profile.circle_rps * TAU / 60.0
	var radii: Vector2 = profile.circle_radius
	for s in LOOP_CAP_FRAMES:
		if not await _think(node):
			return
		var center := spot.get_global_rect().get_center()
		var radius := _rng.randf_range(radii.x, radii.y)
		var angle := 0.0
		if not await _travel(node, center + Vector2(radius, 0.0)):
			return
		while spot.get_global_rect().get_center().is_equal_approx(center):
			angle += step
			hands.move_to(center + Vector2(radius, 0.0).rotated(angle))
			if not await _wait(node, 1):
				return


## Drag every item onto the dog, pants before shoes. A fumble drops the item
## home mid-drag; the player lets go, notices, and goes back for it.
func _clothes(node: Node) -> void:
	var order: Array[String] = ["Shirt", "Pants", "Shoes", "Collar"]
	if _chance(profile.shoes_first):
		order = ["Shirt", "Shoes", "Pants", "Shoes", "Collar"]
	var dog: Control = node.get_node("%DogZone")
	if not await _think(node):
		return
	for i in order.size():
		var item: Control = node.get_node("%Items").get_node(order[i])
		var eager := order[i] == "Shoes" and i < order.find("Pants")
		for attempt in 30:
			if not item.visible:
				break
			if not await _travel(node, item.get_global_rect().get_center()):
				return
			hands.button(true)
			if not await _wait(node, 1):
				hands.button(false)
				return
			var dest := dog.get_global_rect().get_center()
			if _chance(profile.misdrop):
				dest.x += dog.size.x
			if not await _drag(node, dest):
				hands.button(false)
				return
			hands.button(false)
			if not await _think(node):
				return
			if eager:
				break  # bounced off: "shoes need pants"; go get the pants


## The drag half of a carry. Stops early when the item slipped (fumble).
func _drag(node: Node, to: Vector2) -> bool:
	var span: Vector2i = profile.travel_frames
	var n := _rng.randi_range(span.x, span.y)
	var from := hands.mouse
	for i in n:
		if node.get("_held") == null:
			return true
		hands.move_to(from.lerp(to, float(i + 1) / n))
		if not await _wait(node, 1):
			return false
	return await _wait(node, 1)


## Three beats: press SPACE as the marker crosses the plate.
func _breakfast(node: Node, slot: String) -> void:
	if await _skip_chore(node, slot):
		return
	for i in LOOP_CAP_FRAMES:
		if not node.get("_running"):
			return
		var beat: BeatTimer = node.get("_beat")
		var frames := _beat_frames(beat, _react_frames(), _passes())
		if not await _wait(node, frames):
			return
		hands.tap(KEY_SPACE)
		if not await _wait(node, 1):
			return


## Read the road, wait a reaction, then steer one lane toward the clearest
## lane ahead. Decisions act on what was seen a reaction ago.
func _drive(node: Node) -> void:
	if not await _think(node):
		return
	for i in LOOP_CAP_FRAMES:
		var sim: LaneSim = node.get("_sim")
		var dir := _steer(sim)
		if not await _think(node):
			return
		if dir != 0 and not _chance(profile.drive_zone_out):
			hands.tap(KEY_RIGHT if dir > 0 else KEY_LEFT)


func _steer(sim: LaneSim) -> int:
	var current := _lane_value(sim, sim.lane)
	var best_lane := sim.lane
	var best := current
	for lane in LaneSim.LANES:
		var value := _lane_value(sim, lane) - 0.5 * absi(lane - sim.lane)
		if value > best + 5.0:
			best = value
			best_lane = lane
	if best_lane == sim.lane:
		return 0
	var dir := signi(best_lane - sim.lane)
	var margin: float = sim.get("_block_margin")
	for car in sim.cars():
		if car.lane == sim.lane + dir and absf(car.pos - sim.distance) <= margin:
			return 0  # someone alongside; wait for the gap
	return dir


## How fast a lane lets the dog go, read off the nearest car ahead inside
## the lookahead; an empty lane reads as top speed.
func _lane_value(sim: LaneSim, lane: int) -> float:
	var lookahead: float = profile.drive_lookahead
	var top: float = sim.get("_top_speed")
	var nearest := {}
	for car in sim.cars():
		if car.lane == lane and car.pos >= sim.distance \
				and (nearest.is_empty() or car.pos < nearest.pos):
			nearest = car
	if nearest.is_empty() or nearest.pos - sim.distance > lookahead:
		return top * 10.0 + lookahead * 0.05
	return nearest.speed * 10.0 + (nearest.pos - sim.distance) * 0.05


func _choose(node: Node, wanted: String, fallback: String) -> void:
	if not await _think(node):
		return
	var button: Button = node.get_node("%Choices").get_node(wanted)
	if button.disabled:
		button = node.get_node("%Choices").get_node(fallback)
	await _click(node, button)


## Type the target; a typo lodges in the wrong-buffer, gets noticed a reaction
## later and is backspaced out. The shift timer ends the slot.
func _type(node: Node) -> void:
	if not await _think(node):
		return
	for i in LOOP_CAP_FRAMES:
		if not node.get("_running"):
			return
		var shift: WorkShift = node.get("_shift")
		if not shift.session.wrong_buffer.is_empty():
			if not await _think(node):
				return
			for c in shift.session.wrong_buffer:
				hands.tap(KEY_BACKSPACE)
				if not await _wait(node, _char_frames()):
					return
			continue
		var c := shift.target[shift.session.typed_count]
		if _chance(profile.typo):
			c = _typo_for(c)
		hands.type_char(c)
		if not await _wait(node, _char_frames()):
			return


func _char_frames() -> int:
	return maxi(roundi(_rng.randfn(profile.char_frames, profile.char_sd)), 3)


func _typo_for(c: String) -> String:
	var wrong := c
	while wrong == c:
		wrong = TYPO_KEYS[_rng.randi_range(0, TYPO_KEYS.length() - 1)]
	return wrong


## Nod or shake once per cued beat, a reaction after it starts talking.
func _listen(node: Node) -> void:
	var handled := {}
	var frames: int = profile.gesture_frames
	for i in LOOP_CAP_FRAMES:
		if not node.get("_running"):
			return
		var session: ListeningSession = node.get("_session")
		var beat := session.active_beat()
		if not beat.is_empty() and not handled.has(beat.t):
			handled[beat.t] = true
			if beat.cue != "none":
				if not await _think(node):
					return
				var kind: String = beat.cue
				if _chance(profile.wrong_gesture):
					kind = "shake" if kind == "nod" else "nod"
				var axis := Vector2(0.0, 1.0) if kind == "nod" else Vector2(1.0, 0.0)
				var px: float = profile.gesture_px
				for dir in [1.0, -1.0]:
					for f in frames:
						hands.move_by(axis * dir * px / frames)
						if not await _wait(node, 1):
							return
				continue
		if not await _wait(node, 1):
			return


## The four verbs: chop and transfer on the beat, stir by circling the pan
## until it shines, pour by holding SPACE until the line.
func _cook(node: Node) -> void:
	for i in LOOP_CAP_FRAMES:
		if not node.get("_running"):
			return  # finished, or lost and playing its gag
		var session: CookingSession = node.get("_session")
		var verb := CookingSession.VERBS[session.index]
		var ok := true
		match verb:
			"chop", "transfer":
				var frames := _beat_frames(node.get("_beat"), _react_frames(), _passes())
				ok = await _wait(node, frames)
				if ok:
					hands.tap(KEY_SPACE)
			"stir":
				ok = await _stir(node)
			"pour":
				ok = await _pour(node)
		if not ok or not await _wait(node, 1):
			return


## Where the player lets go of a hold meter: the scene's own release band
## centre, plus the profile's release error.
func _hold_target(node: Node) -> float:
	var center: float = node.get_script().get_script_constant_map()["HOLD_BAND_CENTER"]
	return clampf(center + _rng.randfn(0.0, profile.hold_sd), 0.5, 0.99)


func _stir(node: Node) -> bool:
	if not await _think(node):
		return false
	var pan: Control = node.get_node("%Pan")
	var center := pan.get_global_rect().get_center()
	var radii: Vector2 = profile.circle_radius
	var radius := _rng.randf_range(maxf(radii.x, 30.0), radii.y)
	if not await _travel(node, center + Vector2(radius, 0.0)):
		return false
	var target := _hold_target(node)
	var step: float = profile.circle_rps * TAU / 60.0
	var angle := 0.0
	hands.button(true)
	for i in LOOP_CAP_FRAMES:
		if not await _wait(node, 1):
			hands.button(false)
			return false
		var meter: HoldMeter = node.get("_meter")
		if meter == null or meter.value >= target:
			break
		angle += step
		hands.move_to(center + Vector2(radius, 0.0).rotated(angle))
	hands.button(false)
	return true


func _pour(node: Node) -> bool:
	if not await _think(node):
		return false
	var target := _hold_target(node)
	hands.key(KEY_SPACE, true)
	for i in LOOP_CAP_FRAMES:
		if not await _wait(node, 1):
			hands.key(KEY_SPACE, false)
			return false
		var meter: HoldMeter = node.get("_meter")
		if meter == null or meter.value >= target:
			break
	hands.key(KEY_SPACE, false)
	return true


## Let the pull win `freetime_games` times, then fight the cursor over to
## log off and click it.
func _freetime(node: Node) -> void:
	var games: int = profile.freetime_games
	for i in LOOP_CAP_FRAMES:
		var session: FreetimeSession = node.get("_session")
		if session.games_played >= games:
			break
		if not await _wait(node, 1):
			return
	if not await _think(node):
		return
	var logoff: Control = node.get_node("%LogoffButton")
	var flick: float = profile.flick_px
	for i in LOOP_CAP_FRAMES:
		var cursor: Vector2 = node.get("_cursor_pos")
		var rect := logoff.get_rect()
		if rect.grow(-16.0).has_point(cursor):
			hands.button(true)
			var alive := await _wait(node, 1)
			hands.button(false)
			if not alive or not await _wait(node, 1):
				return
			continue
		hands.move_by((rect.get_center() - cursor).limit_length(flick))
		if not await _wait(node, 1):
			return
