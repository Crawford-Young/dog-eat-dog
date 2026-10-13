extends SceneTree

## Headless autoplay: plays full days of main.tscn with real InputEvents and
## reports how long every slot takes, which is what sets the minigame time
## limits (issue #17). Dev tooling only; scripts/dev is excluded from export.
##
##   just autoplay days=30 seed=1 profile=sharp [out=path.json]
##
## Args (key=value after --):
##   days     days to play (default 3); the run also ends at retirement
##   seed     seeds both the game (RngSource) and the bot's own choices
##   profile  sharp | sloppy (default sharp)
##   out      optional path for a JSON copy of the report (no wall time).
##            just passes args through sh unquoted, so on Windows write the
##            path with forward slashes: out=C:/tmp/run.json
##
## Profiles (full knobs in autoplay/profiles.gd):
##   sharp   skilled player: 0.8-1.0 s to take in each new screen, then
##           0.20-0.30 s reaction per decision, ~8.6 Hz
##           mashing, 20 ms beat timing error, ~80 wpm typing with 1% typos
##           (1% of triage sorts in the wrong bin), never skips.
##   sloppy  tired casual: 1.2-1.6 s to take in each new screen, then
##           0.45-0.70 s reaction, ~6 Hz mashing, 70 ms beat
##           error and late passes, ~40 wpm with 6% typos (and 6% of sorts
##           in the wrong bin), short brush strokes, fumbled drops, wrong
##           gestures, skips 15% of chores.
##
## Policy, deterministic per profile:
##                    sharp            sloppy
##   orient           0.8-1.0 s        1.2-1.6 s (every hosted screen)
##   coffee           water            buy (water when unaffordable)
##   dinner           always cook      cook every 3rd day, else takeout
##                                     (cook when takeout is unaffordable)
##   free-time games  0                2 per night
##   retire offer     take it          take it (ends the run either way)
##
## Measurement: a slot's seconds are frames/60 while its node is hosted.
## Out-of-band hosts (late arrival, rank news, cooking) are measured too.
## Exit 0 on a clean run; 1 on a stall (a node hosted over STALL_SECONDS,
## nothing hosted for IDLE_STALL_SECONDS, or the frame budget spent); 2 on
## bad args.

const Hands := preload("res://scripts/dev/autoplay/hands.gd")
const Player := preload("res://scripts/dev/autoplay/player.gd")
const Profiles := preload("res://scripts/dev/autoplay/profiles.gd")
const Report := preload("res://scripts/dev/autoplay/report.gd")
const MAIN := preload("res://scenes/main.tscn")

const FPS := 60
const STALL_SECONDS := 300
const IDLE_STALL_SECONDS := 30
## Generous: a sloppy day runs a few simulated minutes.
const BUDGET_SECONDS_PER_DAY := 1200

var _args := {"days": 3, "seed": 1, "profile": "sharp", "out": ""}
var _game: Control
var _host: Control
var _summary: Control
var _ending: Control
var _hands: Hands
var _player: Player
var _scene_slots := {}
var _frame := 0
var _idle_frames := 0
var _summary_frames := 0
var _summary_pending := false
var _done := false
var _started_msec := 0

var _current: Node = null
var _current_id := 0
var _current_slot := ""
var _current_start := 0
var _freetime_games_seen := 0

## Everything the report reads.
var _tally := {
	"seconds": {},
	"scores": {},
	## The rank each score was played at, parallel to scores (JSON only), so a
	## work score can be read by rank.
	"score_ranks": {},
	## Lost games (result.failed), keyed by slot. game.gd's own finished
	## handler runs first, so the drive, drive-home and free-time stamps are already on.
	"misses": {},
	"overruns": [],
	## Minutes before 8:00 when each drive ends, negative when late: the
	## number the wake (morning_start_minutes) is tuned against.
	"margins": [],
	## Minutes before home_by when each drive home ends, negative when late:
	## the number home_by_minutes is tuned against.
	"home_margins": [],
	"nights": 0,
	## Nights per bed band (early / mid / late), read at the sleep beat.
	"bands": {},
	"late_band_nights": 0,
	"fumes_nights": 0,
	"sick_days": 0,
	"retired_day": 0,
	"freetime_games": 0,
}


func _initialize() -> void:
	_started_msec = Time.get_ticks_msec()
	var error := _parse_args(OS.get_cmdline_user_args())
	if error != "":
		print("autoplay: %s" % error)
		print("usage: just autoplay days=N seed=S profile=%s [out=path.json]" % "|".join(Profiles.names()))
		_done = true
		quit(2)
		return
	# One motion event per frame is all the bot sends; turning accumulation
	# off makes sure no two are ever merged into one relative.
	Input.use_accumulated_input = false
	_game = MAIN.instantiate()
	_game.rng = RngSource.seeded(_args.seed)
	for slot in _game.SCENES:
		var path: String = _game.SCENES[slot].resource_path
		_scene_slots[slot] = path
	root.add_child(_game)
	_host = _game.get_node("%MinigameHost")
	_summary = _game.get_node("%Summary")
	_ending = _game.get_node("%Ending")
	_hands = Hands.new(root)
	var profile: Dictionary = Profiles.PROFILES[_args.profile]
	_player = Player.new(_hands, profile, _args.seed * 7919 + Profiles.names().find(_args.profile))


func _parse_args(user_args: PackedStringArray) -> String:
	for arg in user_args:
		var parts := arg.split("=", true, 1)
		if parts.size() != 2 or not _args.has(parts[0]):
			return "unknown arg '%s'" % arg
		match parts[0]:
			"days", "seed":
				if not parts[1].is_valid_int():
					return "%s must be an integer, got '%s'" % [parts[0], parts[1]]
				_args[parts[0]] = parts[1].to_int()
			"profile":
				if parts[1] not in Profiles.names():
					return "unknown profile '%s'" % parts[1]
				_args.profile = parts[1]
			"out":
				_args.out = parts[1]
	if _args.days < 1:
		return "days must be at least 1"
	return ""


func _process(_delta: float) -> bool:
	if _done:
		return false
	_frame += 1
	_hands.tick()
	_observe()
	if _done:
		return false
	_player.ticked.emit()
	_check_stalls()
	return false


# --- hosting ----------------------------------------------------------------


func _hosted_node() -> Node:
	for i in range(_host.get_child_count() - 1, -1, -1):
		var child := _host.get_child(i)
		if not child.is_queued_for_deletion():
			return child
	return null


func _observe() -> void:
	var hosted := _hosted_node()
	var hosted_id := 0 if hosted == null else hosted.get_instance_id()
	if hosted_id != _current_id:
		if _current_id != 0:
			_close_current()
		if hosted != null:
			_open(hosted)
	if _current_slot == "freetime" and is_instance_valid(_current):
		var session: FreetimeSession = _current.get("_session")
		if session != null:
			_freetime_games_seen = session.games_played
	if _ending.visible:
		_tally.retired_day = _game.state.day
		_finish()
		return
	if _summary.visible:
		_summary_frames += 1
		if not _summary_pending:
			_summary_pending = true
			if _game.state.day >= _args.days:
				_finish()
				return
			_player.next_day(_summary.get_node("NextDayButton"))
	else:
		_summary_frames = 0
		_summary_pending = false
	_idle_frames = _idle_frames + 1 if hosted == null and not _summary.visible else 0


func _open(node: Node) -> void:
	_current = node
	_current_id = node.get_instance_id()
	_current_start = _frame
	_current_slot = _classify(node)
	match _current_slot:
		"late_arrival":
			_tally.overruns.append(_game.clock.overrun())
		"sick":
			_tally.sick_days += 1
		"sleep":
			_tally.nights += 1
			var bands: Dictionary = _tally.bands
			bands[_game.state.bedtime] = bands.get(_game.state.bedtime, 0) + 1
			if _game.state.bedtime == "late":
				_tally.late_band_nights += 1
			var ledger: String = _game.state.ledger.ledger_text(0.0, _game.cfg)
			if ledger.ends_with("running on fumes."):
				_tally.fumes_nights += 1
		"freetime":
			_freetime_games_seen = 0
	# Listening only: the result dict is read for the report, never produced.
	# Connected after game.gd's handler, so its stamps are visible here.
	var slot := _current_slot
	var rank: int = _game.state.rank
	(node as Minigame).finished.connect(
		func(result: Dictionary) -> void: _record_score(slot, result, rank)
	)
	if slot == "drive":
		(node as Minigame).finished.connect(func(_result: Dictionary) -> void:
			_tally.margins.append(_game.clock.remaining() - _game.clock.overrun()))
	if slot == "drive_home":
		(node as Minigame).finished.connect(func(_result: Dictionary) -> void:
			_tally.home_margins.append(_game.cfg.home_budget() - _game.clock.elapsed))
	_player.play(_current_slot, node, _game.state.day)


func _record_score(slot: String, result: Dictionary, rank: int) -> void:
	var scores: Dictionary = _tally.scores
	var ranks: Dictionary = _tally.score_ranks
	if not scores.has(slot):
		scores[slot] = []
		ranks[slot] = []
	scores[slot].append(float(result.get("score", 0.0)))
	ranks[slot].append(rank)
	if result.get("failed", false):
		var misses: Dictionary = _tally.misses
		misses[slot] = misses.get(slot, 0) + 1


func _close_current() -> void:
	var seconds: Dictionary = _tally.seconds
	if not seconds.has(_current_slot):
		seconds[_current_slot] = []
	seconds[_current_slot].append(float(_frame - _current_start) / FPS)
	if _current_slot == "freetime":
		_tally.freetime_games += _freetime_games_seen
	_current = null
	_current_id = 0
	_current_slot = ""


## The schedule names the slot; a node whose scene is not that slot's is one
## game.gd hosted out of band, named by where the schedule is paused.
func _classify(node: Node) -> String:
	var slot: String = _game.schedule.current()
	if node.scene_file_path == _scene_slots.get(slot, ""):
		return slot
	if node.scene_file_path == _scene_slots.cooking:
		return "cooking"
	if node.scene_file_path == _scene_slots.warning:
		match slot:
			"drive":
				return "late_arrival"
			"work_pm":
				return "rank_news"
	return "unknown(%s during %s)" % [node.scene_file_path.get_file(), slot]


# --- ending -----------------------------------------------------------------


func _check_stalls() -> void:
	if _current_id != 0 and _frame - _current_start > STALL_SECONDS * FPS:
		_stall("slot '%s' hosted for more than %d s" % [_current_slot, STALL_SECONDS])
	elif _idle_frames > IDLE_STALL_SECONDS * FPS:
		_stall("nothing hosted and no summary for %d s" % IDLE_STALL_SECONDS)
	elif _summary_frames > IDLE_STALL_SECONDS * FPS:
		_stall("day summary up for %d s without advancing" % IDLE_STALL_SECONDS)
	elif _frame > _args.days * BUDGET_SECONDS_PER_DAY * FPS:
		_stall("frame budget (%d s per day) exhausted in slot '%s'" % [
			BUDGET_SECONDS_PER_DAY, _current_slot,
		])


func _stall(why: String) -> void:
	_done = true
	print("AUTOPLAY STALL: day %d, %s" % [_game.state.day, why])
	print(Report.markdown(_final_tally()))
	quit(1)


func _finish() -> void:
	_done = true
	if _current_id != 0:
		_close_current()
	var tally := _final_tally()
	print(Report.markdown(tally))
	if _args.out != "":
		var file := FileAccess.open(_args.out, FileAccess.WRITE)
		if file == null:
			print("autoplay: could not write %s (%s)" % [_args.out, error_string(FileAccess.get_open_error())])
			quit(2)
			return
		tally.erase("wall_seconds")
		file.store_string(Report.json(tally))
		file.close()
	quit(0)


func _final_tally() -> Dictionary:
	var tally := _tally.duplicate(true)
	tally.merge({
		"profile": _args.profile,
		"seed": _args.seed,
		"days": _args.days,
		"skips": _player.skips.duplicate(),
		"final_day": _game.state.day,
		"final_rank": RankLadder.RANK_NAMES[_game.state.rank],
		"final_savings": _game.state.wallet.savings,
		"retirement_target": _game.cfg.retirement_target,
		"frames": _frame,
		"wall_seconds": (Time.get_ticks_msec() - _started_msec) / 1000.0,
	})
	return tally
