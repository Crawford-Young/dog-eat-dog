extends GutTest

## One seed reproduces a whole run: the source hands each slot a fresh RNG
## derived from one master stream, so slot order alone fixes every roll.


func _draws(source: RngSource, slots: int) -> Array:
	var out := []
	for i in slots:
		out.append(source.next_rng().randi())
	return out


func test_same_seed_gives_the_same_next_rng_sequence() -> void:
	assert_eq(_draws(RngSource.seeded(42), 5), _draws(RngSource.seeded(42), 5))


func test_different_seeds_diverge() -> void:
	assert_ne(_draws(RngSource.seeded(1), 5), _draws(RngSource.seeded(2), 5))


func test_successive_slots_get_different_streams() -> void:
	var draws := _draws(RngSource.seeded(7), 5)
	var seen := {}
	for d in draws:
		seen[d] = true
	assert_eq(seen.size(), 5)


func test_seed_zero_is_a_real_seed_not_unseeded() -> void:
	assert_eq(_draws(RngSource.seeded(0), 3), _draws(RngSource.seeded(0), 3))


func test_unseeded_source_still_hands_out_working_rngs() -> void:
	var rng := RngSource.new().next_rng()
	assert_not_null(rng)
	assert_between(rng.randf(), 0.0, 1.0)


func test_from_params_returns_the_passed_rng() -> void:
	var rng := RandomNumberGenerator.new()
	assert_same(RngSource.from_params({"rng": rng}), rng)


func test_from_params_falls_back_to_a_fresh_rng_without_one() -> void:
	var a := RngSource.from_params({})
	var b := RngSource.from_params({})
	assert_not_null(a)
	assert_ne(a, b)


func _drive_cars(seed_value: int) -> Array:
	var node = load("res://scenes/minigames/drive.tscn").instantiate()
	add_child_autofree(node)
	var params := Difficulty.drive_params(100.0, BalanceConfig.new())
	params["rng"] = RngSource.seeded(seed_value).next_rng()
	node.setup(params)
	return node._sim.cars()


func test_drive_given_identically_seeded_rngs_builds_identical_traffic() -> void:
	var first := _drive_cars(99)
	assert_gt(first.size(), 0)
	assert_eq(first, _drive_cars(99))


func test_drive_given_different_seeds_builds_different_traffic() -> void:
	assert_ne(_drive_cars(99), _drive_cars(100))
