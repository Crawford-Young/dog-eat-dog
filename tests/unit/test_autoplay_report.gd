extends GutTest

## The autoplay report's MISS count (issue #17): per slot, in both the
## markdown table and the JSON dump, so the loss rules can be tuned.

const Report := preload("res://scripts/dev/autoplay/report.gd")


func _tally() -> Dictionary:
	return {
		"profile": "sharp",
		"seed": 1,
		"days": 2,
		"seconds": {"wake": [1.0, 2.0], "brush": [1.5, 1.5], "drive": [30.0, 31.0]},
		"scores": {"wake": [1.0, 0.0], "brush": [1.0, 1.0], "drive": [1.0, 1.0]},
		"misses": {"wake": 1, "drive": 2},
		"overruns": [],
		"nights": 2,
		"late_band_nights": 0,
		"fumes_nights": 0,
		"sick_days": 0,
		"retired_day": 0,
		"freetime_games": 0,
		"skips": {},
		"final_day": 2,
		"final_rank": "intern",
		"final_savings": 10,
		"retirement_target": 4000,
		"frames": 600,
		"wall_seconds": 1.0,
	}


func _row(markdown: String, slot: String) -> String:
	for line in markdown.split("\n"):
		if line.begins_with("| %s |" % slot):
			return line
	return ""


func test_the_table_counts_each_slots_misses() -> void:
	var markdown := Report.markdown(_tally())
	assert_string_contains(markdown, "| misses |", "the table has a misses column")
	assert_true(_row(markdown, "wake").ends_with("| 1 |"), _row(markdown, "wake"))
	assert_true(_row(markdown, "drive").ends_with("| 2 |"), _row(markdown, "drive"))
	assert_true(_row(markdown, "brush").ends_with("| 0 |"), "a slot that never missed reads 0")


func test_the_json_carries_the_misses_per_slot() -> void:
	var parsed: Dictionary = JSON.parse_string(Report.json(_tally()))
	assert_eq(parsed.misses, {"wake": 1.0, "drive": 2.0})


func test_a_tally_without_misses_still_prints() -> void:
	var tally := _tally()
	tally.erase("misses")
	assert_true(_row(Report.markdown(tally), "wake").ends_with("| 0 |"))


func test_the_report_prints_the_morning_arrival_margin() -> void:
	# Minutes before 8:00 at the end of each drive, negative when late (#18):
	# the number the wake is tuned against, so a re-run can re-measure it.
	var tally := _tally()
	tally["margins"] = [6.0, -1.5, 4.0]
	var markdown := Report.markdown(tally)
	assert_string_contains(markdown, "- arrival margin (min before 8:00): median 4.0, min -1.5")
	var parsed: Dictionary = JSON.parse_string(Report.json(tally))
	assert_eq(parsed.margins, [6.0, -1.5, 4.0])


func test_a_tally_without_margins_still_prints() -> void:
	assert_string_contains(Report.markdown(_tally()), "- arrival margin (min before 8:00): none")


func test_the_report_prints_the_drive_home_margin() -> void:
	# Minutes before home_by at the end of each drive home, negative when late
	# (#18): the number home_by is tuned against.
	var tally := _tally()
	tally["home_margins"] = [3.0, -0.5, 2.0, 1.0]
	var markdown := Report.markdown(tally)
	assert_string_contains(markdown, "- home margin (min before home-by): median 1.5, min -0.5")
	var parsed: Dictionary = JSON.parse_string(Report.json(tally))
	assert_eq(parsed.home_margins, [3.0, -0.5, 2.0, 1.0])


func test_a_tally_without_home_margins_still_prints() -> void:
	assert_string_contains(Report.markdown(_tally()), "- home margin (min before home-by): none")


func test_the_report_prints_the_bed_band_of_every_night() -> void:
	# What the evening clock costs shows up as bedtime: early / mid / late.
	var tally := _tally()
	tally["bands"] = {"early": 1, "late": 3}
	assert_string_contains(Report.markdown(tally), "- bed bands: early 1, mid 0, late 3")


func test_a_tally_without_bands_still_prints() -> void:
	assert_string_contains(Report.markdown(_tally()), "- bed bands: early 0, mid 0, late 0")
