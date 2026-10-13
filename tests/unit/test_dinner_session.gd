extends GutTest

## Dinner as a walk (issue #18), as pure rules: the dog stands on a floor 0..1
## wide with the pan at the left end and the phone at the right. Walking left or
## right moves it `speed` floor widths a second; reaching the pan cooks,
## reaching the phone orders takeout, unless the dog cannot pay for it.

const SPEED := 0.5
const START := 0.5


func _session(overrides := {}) -> DinnerSession:
	var params := {"speed": SPEED, "start": START}
	params.merge(overrides, true)
	return DinnerSession.new(params)


func test_the_dog_starts_where_it_is_told_and_stands_still() -> void:
	var s := _session()
	assert_almost_eq(s.position(), START, 0.0001)
	assert_eq(s.heading(), 0)
	s.tick(1.0)
	assert_almost_eq(s.position(), START, 0.0001, "no heading, no walk")
	assert_eq(s.outcome(), "", "standing still decides nothing")


func test_the_accessors_read_back_the_params() -> void:
	var s := _session({"can_afford": false})
	assert_almost_eq(s.speed(), SPEED, 0.0001)
	assert_false(s.can_afford())


func test_an_unstated_dog_can_afford_takeout() -> void:
	assert_true(_session().can_afford())


func test_the_pan_is_left_and_the_phone_right() -> void:
	assert_lt(DinnerSession.PAN, DinnerSession.PHONE)


func test_walking_right_moves_toward_the_phone_at_speed() -> void:
	var s := _session()
	s.walk(1)
	s.tick(0.2)
	assert_almost_eq(s.position(), START + SPEED * 0.2, 0.0001)


func test_walking_left_moves_toward_the_pan_at_speed() -> void:
	var s := _session()
	s.walk(-1)
	s.tick(0.2)
	assert_almost_eq(s.position(), START - SPEED * 0.2, 0.0001)


func test_any_heading_is_one_step_a_tick_whatever_its_size() -> void:
	var s := _session()
	s.walk(5)
	assert_eq(s.heading(), 1)
	s.walk(-3)
	assert_eq(s.heading(), -1)
	s.walk(0)
	assert_eq(s.heading(), 0)


func test_reaching_the_pan_cooks() -> void:
	var s := _session()
	s.walk(-1)
	s.tick(START / SPEED + 0.1)
	assert_eq(s.outcome(), DinnerSession.COOK)
	assert_eq(DinnerSession.COOK, "cook", "game.gd hosts the pan on this choice")
	assert_almost_eq(s.position(), DinnerSession.PAN, 0.0001, "the dog stops at the pan")


func test_reaching_the_phone_orders_takeout() -> void:
	var s := _session()
	s.walk(1)
	s.tick((1.0 - START) / SPEED + 0.1)
	assert_eq(s.outcome(), DinnerSession.TAKEOUT)
	assert_eq(DinnerSession.TAKEOUT, "takeout", "StatEffects pays takeout on this choice")
	assert_almost_eq(s.position(), DinnerSession.PHONE, 0.0001)


func test_short_of_a_target_nothing_is_decided() -> void:
	var s := _session()
	s.walk(1)
	s.tick((1.0 - START) / SPEED - 0.05)
	assert_eq(s.outcome(), "")


func test_a_broke_dog_at_the_phone_stands_there_and_nothing_happens() -> void:
	var s := _session({"can_afford": false})
	s.walk(1)
	s.tick(10.0)
	assert_eq(s.outcome(), "", "the phone does nothing for a broke dog")
	assert_almost_eq(s.position(), DinnerSession.PHONE, 0.0001, "it cannot walk past it")
	s.walk(-1)
	s.tick(1.0 / SPEED + 0.1)
	assert_eq(s.outcome(), DinnerSession.COOK, "the pan still works")


func test_once_decided_the_dog_stops_for_good() -> void:
	var s := _session()
	s.walk(-1)
	s.tick(10.0)
	s.walk(1)
	s.tick(10.0)
	assert_eq(s.outcome(), DinnerSession.COOK)
	assert_almost_eq(s.position(), DinnerSession.PAN, 0.0001)
	assert_eq(s.heading(), 0, "a decided walk ignores the keys")


func test_seconds_to_a_target_is_the_walk_left() -> void:
	var s := _session()
	assert_almost_eq(s.seconds_to(DinnerSession.PAN), START / SPEED, 0.0001)
	assert_almost_eq(s.seconds_to(DinnerSession.PHONE), (1.0 - START) / SPEED, 0.0001)
	s.walk(1)
	s.tick(0.2)
	assert_almost_eq(s.seconds_to(DinnerSession.PHONE), (1.0 - START) / SPEED - 0.2, 0.0001)


func test_a_start_off_the_floor_is_put_back_on_it() -> void:
	assert_almost_eq(_session({"start": -1.0}).position(), DinnerSession.PAN, 0.0001)
	assert_almost_eq(_session({"start": 3.0}).position(), DinnerSession.PHONE, 0.0001)


func test_a_dog_set_down_on_a_target_still_has_to_take_a_step() -> void:
	# The start is a tunable; one that lands on a target must not decide a
	# dinner the player never walked to.
	var s := _session({"start": DinnerSession.PAN})
	s.tick(1.0)
	assert_eq(s.outcome(), "")
	s.walk(-1)
	s.tick(0.01)
	assert_eq(s.outcome(), DinnerSession.COOK)


func test_a_zero_or_negative_speed_still_walks() -> void:
	assert_almost_eq(_session({"speed": 0.0}).speed(), DinnerSession.MIN_SPEED, 0.0001)
	assert_almost_eq(_session({"speed": -1.0}).speed(), DinnerSession.MIN_SPEED, 0.0001)
