class_name ProbeLog
extends RefCounted

## The play probes (#18 step 12): game.gd hands this one entry per finished
## game, and it appends the entry as one JSON line to `path` and prints it with
## a `[probe]` prefix, so a ride records how hard each game was for the human.
## Every line carries the run id, fixed when the run starts.
##
## Opening the file per record keeps nothing open across a crash or a closed
## tab; a game ends every few seconds at most, so the cost is nothing. Lives
## under scripts/core so the web pack ships it (scripts/dev is excluded).

const PATH := "user://probes.jsonl"
const PREFIX := "[probe] "

var run_id: String
var _path: String


func _init(run: String, path := PATH) -> void:
	run_id = run
	_path = path


## True when a run should get a recorder: the config switch is on and the
## display is not headless, so GUT, autoplay and the CI launch write nothing.
static func should_write(enabled: bool, display_name: String) -> bool:
	return enabled and display_name != "headless"


## A fresh run id: the local start time plus a microsecond tick, readable in
## the file and distinct across launches and restarts.
static func new_run_id() -> String:
	return "%s-%d" % [Time.get_datetime_string_from_system(), Time.get_ticks_usec()]


## Appends `entry`, tagged with the run id, as one JSON line, prints it, and
## returns the printed line.
func record(entry: Dictionary) -> String:
	var tagged := {"run": run_id}
	tagged.merge(entry)
	var json := JSON.stringify(tagged)
	var file := FileAccess.open(_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		push_warning("probe file %s would not open: %s" % [_path, FileAccess.get_open_error()])
	else:
		file.seek_end()
		file.store_line(json)
		file.close()
	var line := PREFIX + json
	print(line)
	return line
