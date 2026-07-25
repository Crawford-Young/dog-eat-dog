class_name TextForge

## Generates work text by clarity tier. Tier 4 = healthy short phrases,
## tier 0 = keysmash. Tiers 2/1 scramble tier-3 phrases progressively.

const PHRASES := {
	4: ["good idea", "on it now", "done and sent", "nice catch", "ship it"],
	3: [
		"circling back on the report",
		"scheduling the team sync now",
		"drafting the client update",
		"reviewing the quarterly numbers",
	],
}
const NOISE_CHARS := "qwertyuiopasdfghjklzxcvbnm;#@!~"


static func generate(tier: int, rng: RandomNumberGenerator) -> String:
	match tier:
		4:
			return PHRASES[4][rng.randi_range(0, PHRASES[4].size() - 1)]
		3:
			return PHRASES[3][rng.randi_range(0, PHRASES[3].size() - 1)]
		2:
			return _scramble(_pick3(rng), 0.25, rng)
		1:
			return _scramble(_pick3(rng), 0.6, rng)
		_:
			return _noise(rng.randi_range(18, 26), rng)


static func _pick3(rng: RandomNumberGenerator) -> String:
	return PHRASES[3][rng.randi_range(0, PHRASES[3].size() - 1)]


static func _scramble(phrase: String, fraction: float, rng: RandomNumberGenerator) -> String:
	var out := ""
	for c in phrase:
		if c != " " and rng.randf() < fraction:
			out += NOISE_CHARS[rng.randi_range(0, NOISE_CHARS.length() - 1)]
		else:
			out += c
	return out


static func _noise(length: int, rng: RandomNumberGenerator) -> String:
	var out := ""
	for i in length:
		if i % 6 == 5:
			out += " "
		else:
			out += NOISE_CHARS[rng.randi_range(0, NOISE_CHARS.length() - 1)]
	return out
