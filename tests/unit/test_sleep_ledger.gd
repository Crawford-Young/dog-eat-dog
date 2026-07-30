extends GutTest


func _cfg() -> BalanceConfig:
	return BalanceConfig.new()


func test_a_night_at_need_leaves_the_ledger_square() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	# Wake at 7:00 (minute 420); eight hours earlier is 23:00 (minute 1380).
	var slept := ledger.record_night(1380.0, 420.0, cfg)
	assert_eq(slept, 480.0)
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
	ledger.record_night(1421.0, 420.0, cfg)
	assert_eq(ledger.debt_minutes, 41.0, "480 needed, 439 slept")


func test_debt_compounds_across_nights() -> void:
	# The weakness this class exists to fix: energy carryover is one night deep,
	# so a week of late nights costs exactly what one costs.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	for _night in range(5):
		ledger.record_night(1421.0, 420.0, cfg)
	assert_eq(ledger.debt_minutes, 205.0, "five short nights cost five times one")


func test_a_long_night_pays_debt_back() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.record_night(1421.0, 420.0, cfg)
	# 21:30 (1290) to 7:00 is 570 minutes — 90 over need.
	ledger.record_night(1290.0, 420.0, cfg)
	assert_eq(ledger.debt_minutes, -49.0, "41 owed minus 90 banked")


func test_banked_surplus_is_capped() -> void:
	# A good week buys one late night, not immunity.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	for _night in range(20):
		ledger.record_night(1290.0, 420.0, cfg)
	assert_eq(ledger.debt_minutes, -cfg.sleep_bank_cap_minutes)


func test_debt_is_capped_too() -> void:
	# Uncapped debt is a death spiral — the ceiling bottoms out and no reachable
	# number of good nights climbs back.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	for _night in range(60):
		ledger.record_night(1439.0, 420.0, cfg)
	assert_eq(ledger.debt_minutes, cfg.sleep_debt_cap_minutes)


func test_no_debt_means_no_ceiling() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	assert_eq(ledger.max_energy(cfg), 100.0)
	ledger.record_night(1290.0, 420.0, cfg)
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
	var slept := ledger.record_night(1421.0, 420.0, cfg)
	assert_string_contains(ledger.ledger_text(slept, cfg), "7h19")


func test_ledger_text_says_square_when_it_is_square() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	var slept := ledger.record_night(1380.0, 420.0, cfg)
	assert_string_contains(ledger.ledger_text(slept, cfg), "square")


func test_ledger_text_says_banking_it_on_a_surplus() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.debt_minutes = -cfg.sleep_need_minutes
	assert_string_contains(ledger.ledger_text(500.0, cfg), "banking it")


func test_ledger_text_counts_nights_behind() -> void:
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.debt_minutes = cfg.sleep_need_minutes
	assert_string_contains(ledger.ledger_text(400.0, cfg), "a night behind")
	ledger.debt_minutes = cfg.sleep_need_minutes * 3.0
	assert_string_contains(ledger.ledger_text(400.0, cfg), "3 nights behind")


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
		"720 slept against a 480 need pays 240 off a maxed 960",
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


func test_a_sick_day_still_respects_the_bank_cap() -> void:
	# The escape hatch may not double as a surplus farm. record_sick_day routes
	# through record_night for exactly this — one place owns the caps.
	var cfg := _cfg()
	var ledger := SleepLedger.new()
	ledger.debt_minutes = -cfg.sleep_bank_cap_minutes
	ledger.record_sick_day(cfg)
	assert_eq(ledger.debt_minutes, -cfg.sleep_bank_cap_minutes)
