extends GutTest

var cfg: BalanceConfig
var state: GameState


func before_each() -> void:
	cfg = BalanceConfig.new()
	state = GameState.new()


func test_brush_done_restores_energy_and_flags() -> void:
	var before := state.energy
	StatEffects.apply("brush", {"score": 1.0, "skipped": false}, state, cfg)
	assert_eq(state.energy, before + cfg.selfcare_restore)
	assert_true(state.brushed_today)


func test_brush_skipped_no_restore() -> void:
	var before := state.energy
	StatEffects.apply("brush", {"score": 0.0, "skipped": true}, state, cfg)
	assert_eq(state.energy, before)
	assert_false(state.brushed_today)


func test_work_records_score_and_drains() -> void:
	var before_e := state.energy
	StatEffects.apply("work_am", {"score": 1.0, "skipped": false}, state, cfg)
	assert_almost_eq(state.performance, 0.65, 0.001)
	assert_eq(state.energy, before_e - cfg.work_drain)


func test_dinner_cook_beats_takeout() -> void:
	var s2 := GameState.new()
	StatEffects.apply("dinner", {"score": 1.0, "skipped": false, "choice": "cook"}, state, cfg)
	StatEffects.apply("dinner", {"score": 1.0, "skipped": false, "choice": "takeout"}, s2, cfg)
	assert_gt(state.energy, s2.energy)


func test_freetime_game_drains_and_hooks() -> void:
	StatEffects.apply("freetime", {"score": 0.3, "skipped": false, "choice": "game"}, state, cfg)
	assert_true(state.played_late)


func test_freetime_logoff_clears_habit() -> void:
	state.played_late = true
	StatEffects.apply("freetime", {"score": 1.0, "skipped": false, "choice": "logoff"}, state, cfg)
	assert_false(state.played_late)


func test_sleep_sets_bedtime() -> void:
	StatEffects.apply("sleep", {"score": 1.0, "skipped": false, "choice": "late"}, state, cfg)
	assert_eq(state.bedtime, "late")
