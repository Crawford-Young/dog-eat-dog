extends GutTest

var rng := RandomNumberGenerator.new()


func before_each() -> void:
	rng.seed = 42


func test_tier_4_returns_known_phrase() -> void:
	var s := TextForge.generate(4, rng)
	assert_has(TextForge.PHRASES[4], s)


func test_tier_3_returns_known_phrase() -> void:
	var s := TextForge.generate(3, rng)
	assert_has(TextForge.PHRASES[3], s)


func test_tier_0_is_noise_of_expected_length() -> void:
	var s := TextForge.generate(0, rng)
	assert_between(s.length(), 18, 26)
	for phrase in TextForge.PHRASES[4] + TextForge.PHRASES[3]:
		assert_ne(s, phrase)


func test_tier_2_preserves_length_of_source_phrase() -> void:
	var s := TextForge.generate(2, rng)
	var lengths := []
	for phrase in TextForge.PHRASES[3]:
		lengths.append(phrase.length())
	assert_has(lengths, s.length())


func test_deterministic_with_seed() -> void:
	var a := TextForge.generate(0, rng)
	rng.seed = 42
	var b := TextForge.generate(0, rng)
	assert_eq(a, b)
