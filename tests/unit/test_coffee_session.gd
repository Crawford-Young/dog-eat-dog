extends GutTest

## The coffee cart's cup grab (issue #18), as pure rules: a cup slides across
## the track at `speed` (track widths per second), enters after `lead`
## seconds, and a press lands a grab only while the cup is in the zone.

const SPEED := 0.5
const CENTER := 0.6
const WIDTH := 0.2
const LEAD := 1.0


func _session(overrides := {}) -> CoffeeSession:
	var params := {"speed": SPEED, "zone_center": CENTER, "zone_width": WIDTH, "lead": LEAD}
	params.merge(overrides, true)
	return CoffeeSession.new(params)


## Runs the cup to the middle of the zone.
func _to_zone(s: CoffeeSession) -> void:
	s.tick(s.seconds_to_zone())


func test_the_cup_starts_off_screen_and_enters_after_the_lead() -> void:
	var s := _session()
	assert_lt(s.position(), 0.0, "off the left edge")
	assert_false(s.cup_on_screen())
	s.tick(LEAD)
	assert_almost_eq(s.position(), 0.0, 0.0001, "the lead in seconds, whatever the speed")
	assert_true(s.cup_on_screen())


func test_the_lead_is_in_seconds_at_any_speed() -> void:
	var s := _session({"speed": 2.0})
	s.tick(LEAD)
	assert_almost_eq(s.position(), 0.0, 0.0001)


func test_the_cup_moves_at_its_speed() -> void:
	var s := _session({"lead": 0.0})
	s.tick(0.5)
	assert_almost_eq(s.position(), SPEED * 0.5, 0.0001)


func test_seconds_to_zone_counts_to_the_zone_centre() -> void:
	var s := _session()
	assert_almost_eq(s.seconds_to_zone(), LEAD + CENTER / SPEED, 0.0001)
	s.tick(0.4)
	assert_almost_eq(s.seconds_to_zone(), LEAD + CENTER / SPEED - 0.4, 0.0001)
	_to_zone(s)
	assert_almost_eq(s.position(), CENTER, 0.0001)
	s.tick(0.2)
	assert_lt(s.seconds_to_zone(), 0.0, "negative once the cup is past the centre")


func test_the_zone_is_centred_and_inclusive() -> void:
	var s := _session({"lead": 0.0})
	s.tick((CENTER - WIDTH / 2.0 - 0.01) / SPEED)
	assert_false(s.in_zone(), "just short of the zone")
	s.tick(0.01 / SPEED)
	assert_true(s.in_zone(), "the leading edge is in")
	s.tick(WIDTH / SPEED)
	assert_true(s.in_zone(), "the trailing edge is in")
	s.tick(0.02 / SPEED)
	assert_false(s.in_zone(), "past the zone")


func test_a_press_in_the_zone_is_a_clean_grab() -> void:
	var s := _session()
	_to_zone(s)
	assert_eq(s.grab(), CoffeeSession.BUY)
	assert_eq(s.outcome(), CoffeeSession.BUY)


func test_a_press_before_the_zone_spills() -> void:
	var s := _session()
	s.tick(LEAD)
	assert_eq(s.grab(), CoffeeSession.SPILL)
	assert_eq(s.outcome(), CoffeeSession.SPILL)


func test_a_press_while_the_cup_is_still_off_screen_spills() -> void:
	assert_eq(_session().grab(), CoffeeSession.SPILL)


func test_a_press_past_the_zone_spills() -> void:
	var s := _session()
	_to_zone(s)
	s.tick(WIDTH / SPEED)
	assert_eq(s.grab(), CoffeeSession.SPILL)


func test_the_first_press_decides_it() -> void:
	var s := _session()
	s.tick(LEAD)
	s.grab()
	_to_zone(s)
	assert_eq(s.grab(), "", "a second press is ignored")
	assert_eq(s.outcome(), CoffeeSession.SPILL)


func test_a_grabbed_cup_stops() -> void:
	var s := _session()
	_to_zone(s)
	s.grab()
	var at := s.position()
	s.tick(10.0)
	assert_eq(s.position(), at)
	assert_eq(s.outcome(), CoffeeSession.BUY, "and it is not then left to pass")


func test_a_cup_left_alone_passes_as_water() -> void:
	var s := _session()
	assert_eq(s.outcome(), "", "undecided at the start")
	s.tick(s.seconds_to_zone())
	assert_eq(s.outcome(), "", "and in the zone")
	s.tick(LEAD + 1.0 / SPEED)
	assert_eq(s.outcome(), CoffeeSession.SKIP)
	assert_eq(s.position(), 1.0, "it stops at the far edge")
	assert_false(s.cup_on_screen(), "and is gone")


func test_a_press_after_the_cup_has_passed_is_ignored() -> void:
	var s := _session()
	s.tick(10.0)
	assert_eq(s.grab(), "")
	assert_eq(s.outcome(), CoffeeSession.SKIP)


func test_a_broke_dog_cannot_grab_and_the_cup_passes() -> void:
	var s := _session({"can_afford": false})
	assert_false(s.can_afford())
	_to_zone(s)
	assert_eq(s.grab(), "", "a press does nothing")
	assert_eq(s.outcome(), "")
	s.tick(10.0)
	assert_eq(s.outcome(), CoffeeSession.SKIP)


func test_the_dog_can_afford_it_by_default() -> void:
	assert_true(_session().can_afford())


func test_a_zero_speed_still_moves_the_cup() -> void:
	var s := _session({"speed": 0.0, "lead": 0.0})
	s.tick(1.0)
	assert_gt(s.position(), 0.0, "a zero speed reads as the slowest, not a stall")


func test_a_negative_lead_or_width_reads_as_zero() -> void:
	var s := _session({"lead": -3.0, "zone_width": -1.0})
	assert_eq(s.position(), 0.0)
	assert_eq(s.zone_width(), 0.0)


func test_the_accessors_echo_the_params() -> void:
	var s := _session()
	assert_eq(s.zone_center(), CENTER)
	assert_eq(s.zone_width(), WIDTH)
	assert_eq(s.speed(), SPEED)
