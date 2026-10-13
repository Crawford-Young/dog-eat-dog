extends GutTest


func _cfg() -> BalanceConfig:
	return BalanceConfig.new()


## The shipped wake minute. Debt is need minus sleep counted to the wake, so a
## debt assertion only means something against the wake the game ships.
func _wake(cfg: BalanceConfig) -> float:
	return float(cfg.morning_start_minutes)


func test_a_night_at_need_leaves_the_ledger_square() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	# The need is sized so a 23:00 bed (minute 1380) sleeps exactly it.
	var slept := ledger.record_night(1380.0, _wake(cfg), cfg)
	assert_eq(slept, cfg.sleep_need_minutes)
	assert_eq(ledger.debt_minutes, 0.0)


func test_the_night_wraps_past_midnight() -> void:
	# The mandatory case, not a defensive one: the bed minute is absolute from
	# midnight and the evening crosses it, so a naive wake - bed is NEGATIVE for
	# every late night — exactly the band this mechanic exists to punish.
	var ledger := SleepLedger.new()
	var slept := ledger.record_night(1421.0, 420.0, _cfg())
	assert_eq(slept, 439.0, "23:41 to 7:00 is 439 minutes, not -1001")


func test_a_short_night_accrues_the_difference() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.record_night(1421.0, _wake(cfg), cfg)
	assert_eq(ledger.debt_minutes, 41.0, "a 23:41 bed is 41 minutes past the square 23:00")


func test_debt_compounds_across_nights() -> void:
	# The weakness this class exists to fix: energy carryover is one night deep,
	# so a week of late nights costs exactly what one costs.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	for _night in range(5):
		ledger.record_night(1421.0, _wake(cfg), cfg)
	assert_eq(ledger.debt_minutes, 205.0, "five short nights cost five times one")


func test_a_long_night_pays_debt_back() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.record_night(1421.0, _wake(cfg), cfg)
	# A 21:30 (1290) bed is 90 minutes before the square 23:00 — 90 over need.
	ledger.record_night(1290.0, _wake(cfg), cfg)
	assert_eq(ledger.debt_minutes, -49.0, "41 owed minus 90 banked")


func test_banked_surplus_is_capped() -> void:
	# A good week buys one late night, not immunity.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	for _night in range(20):
		ledger.record_night(1290.0, _wake(cfg), cfg)
	assert_eq(ledger.debt_minutes, -cfg.sleep_bank_cap_minutes)


func test_debt_is_capped_too() -> void:
	# Uncapped debt is a death spiral — the ceiling bottoms out and no reachable
	# number of good nights climbs back.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	for _night in range(60):
		ledger.record_night(1439.0, _wake(cfg), cfg)
	assert_eq(ledger.debt_minutes, cfg.sleep_debt_cap_minutes)


func test_no_debt_means_no_ceiling() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	assert_eq(ledger.max_energy(cfg), 100.0)
	ledger.record_night(1290.0, _wake(cfg), cfg)
	assert_eq(ledger.max_energy(cfg), 100.0, "a banked surplus does not raise the ceiling past 100")


func test_the_ceiling_falls_with_debt() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.debt_minutes = cfg.sleep_debt_cap_minutes * 0.5
	var half := ledger.max_energy(cfg)
	assert_between(half, cfg.sleep_ceiling_min, 100.0)
	ledger.debt_minutes = cfg.sleep_debt_cap_minutes
	assert_eq(ledger.max_energy(cfg), cfg.sleep_ceiling_min)
	assert_lt(ledger.max_energy(cfg), half, "more debt is never a higher ceiling")


func test_a_maxed_ceiling_lands_under_the_sick_threshold() -> void:
	# Ceiling and cliff are ONE chain — the sick day needs no new code, it just
	# needs the ceiling to be able to reach down to it.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.debt_minutes = cfg.sleep_debt_cap_minutes
	assert_true(Difficulty.is_sick_morning(ledger.max_energy(cfg), cfg))


func test_ledger_text_states_the_night_in_hours_and_minutes() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	# 23:41 to a 7:00 wake: pure formatting, so the wake is pinned here.
	var slept := ledger.record_night(1421.0, 420.0, cfg)
	assert_string_contains(ledger.ledger_text(slept, cfg), "7h19")


func test_ledger_text_says_square_when_it_is_square() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	var slept := ledger.record_night(1380.0, _wake(cfg), cfg)
	assert_string_contains(ledger.ledger_text(slept, cfg), "square")


func test_ledger_text_says_banked_on_any_surplus() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	var slept := ledger.record_night(float(cfg.bed_early_line_minutes), _wake(cfg), cfg)
	assert_lt(ledger.debt_minutes, 0.0, "a bed on the early line sleeps past need")
	assert_string_contains(ledger.ledger_text(slept, cfg), "banked")


func test_the_ledger_never_says_square_while_the_dog_looks_tired() -> void:
	# The copy and the sprite were two independently-tuned numbers that agreed
	# by luck, and the 420 cap broke the luck: "square" with the ceiling at ~47.
	# The rung is now the ceiling's own clarity tier, so this holds at every
	# debt and through any future retune of the cap.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	for step in range(0, 43):
		ledger.debt_minutes = cfg.sleep_debt_cap_minutes * step / 42.0
		var tired := Difficulty.clarity_tier(ledger.max_energy(cfg)) < 4
		var text := ledger.ledger_text(400.0, cfg)
		assert_eq(text.contains("square"), not tired, "debt %d: %s" % [ledger.debt_minutes, text])


func test_every_rung_is_reachable_under_the_cap() -> void:
	# The old "N nights behind" rung could never print once the cap fell under
	# one night of need. Every rung here must be a debt the ledger can hold.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	var seen := {}
	for step in range(-42, 43):
		ledger.debt_minutes = clampf(
			cfg.sleep_debt_cap_minutes * step / 42.0,
			-cfg.sleep_bank_cap_minutes, cfg.sleep_debt_cap_minutes
		)
		var text := ledger.ledger_text(400.0, cfg)
		for rung in ["banked", "square", "running short", "running on fumes"]:
			if text.contains(rung):
				seen[rung] = true
	assert_eq(seen.size(), 4, "rungs seen: %s" % [seen.keys()])


func test_on_fumes_shows_before_the_cliff() -> void:
	# The last rung must print on a night that does NOT yet make the dog sick,
	# or the copy only ever announces the cliff after the fall.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.debt_minutes = cfg.sleep_debt_cap_minutes
	assert_string_contains(ledger.ledger_text(400.0, cfg), "running on fumes")
	var wobble := false
	for step in range(0, 43):
		ledger.debt_minutes = cfg.sleep_debt_cap_minutes * step / 42.0
		if (
			ledger.ledger_text(400.0, cfg).contains("running on fumes")
			and not Difficulty.is_sick_morning(ledger.max_energy(cfg), cfg)
		):
			wobble = true
	assert_true(wobble)


func test_nonsense_bed_minutes_never_produce_negative_sleep() -> void:
	# The lab can hand this class anything. Nothing here may go negative — a
	# negative night would pay off debt for staying up later.
	var ledger := SleepLedger.new()
	assert_eq(ledger.record_night(5000.0, 420.0, _cfg()), 0.0)


func test_a_sick_day_banks_a_long_night() -> void:
	# A sick day has no evening, so no freetime slot records a night and the debt
	# would freeze. Being sick IS sleeping all day, so the day banks one long
	# night — the only thing that can pay debt down with no bedtime to have.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.debt_minutes = cfg.sleep_debt_cap_minutes
	var slept: float = ledger.record_sick_day(cfg)
	assert_eq(slept, cfg.sick_sleep_minutes)
	assert_eq(
		ledger.debt_minutes,
		cfg.sleep_debt_cap_minutes + cfg.sleep_need_minutes - cfg.sick_sleep_minutes,
		"a sick day sleeps 240 past the need and pays that off a maxed debt",
	)
	assert_gt(
		ledger.max_energy(cfg),
		cfg.sick_energy_threshold,
		"and the lifted ceiling has to clear the cliff, or the sick day cannot end",
	)


func test_a_sick_day_has_to_out_sleep_the_need_or_the_loop_never_ends() -> void:
	# Held as data, in this wave's style. A retune that drops sick_sleep_minutes
	# to or below sleep_need_minutes silently restores the permanent-sickness
	# loop — the sick day would accrue debt instead of paying it down, and the
	# outcome tests above would be the only witnesses.
	var cfg := _cfg()
	assert_gt(cfg.sick_sleep_minutes, cfg.sleep_need_minutes)


func test_moving_the_wake_never_moves_what_a_bedtime_costs() -> void:
	# The ledger counts sleep from the wake minute, so a later wake would quietly
	# pay down every night's debt unless the need moves with it (issue #18: the
	# wake moved 7:00 -> 7:15 for the ~10 s drive). The economy is anchored to
	# the clock the player sees, not to the wake: a 23:00 bed is square, every
	# minute later owes one, every minute earlier banks one.
	var cfg := _cfg()
	var wake := float(cfg.morning_start_minutes)
	for bed in [1290.0, 1320.0, 1380.0, 1410.0, 1421.0, 1440.0, 1500.0]:
		var ledger := SleepLedger.new()
		ledger.record_night(bed, wake, cfg)
		assert_eq(ledger.debt_minutes, bed - 1380.0,
				"bed %s costs what it cost before the recalibration" % DayClock.format_minutes(int(bed)))


func test_moving_the_wake_never_moves_what_a_sick_day_banks() -> void:
	# The sick-day night is synthesized back from the wake, so the credit is
	# sick_sleep_minutes - sleep_need_minutes; it stays the 240 the bank and
	# debt caps were sized against.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.debt_minutes = cfg.sleep_debt_cap_minutes
	ledger.record_sick_day(cfg)
	assert_eq(ledger.debt_minutes, cfg.sleep_debt_cap_minutes - 240.0)


func test_a_sick_day_still_respects_the_bank_cap() -> void:
	# The escape hatch may not double as a surplus farm. record_sick_day routes
	# through record_night for exactly this — one place owns the caps.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.debt_minutes = -cfg.sleep_bank_cap_minutes
	ledger.record_sick_day(cfg)
	assert_eq(ledger.debt_minutes, -cfg.sleep_bank_cap_minutes)
