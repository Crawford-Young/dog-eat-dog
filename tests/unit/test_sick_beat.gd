extends GutTest

const SickBeatScene := preload("res://scenes/minigames/sick.tscn")


func _beat() -> Minigame:
	var b: Minigame = SickBeatScene.instantiate()
	add_child_autofree(b)
	b.setup({"burrow_target": 4, "burrow_time": 0.5, "text_speed": 0.0})
	return b


func test_one_press_fills_a_quarter_of_the_bar() -> void:
	var b := _beat()
	b.press()
	assert_eq(b.get_node("%BurrowBar").value, 0.25, "bar writes 0..1 fractions like wake/brush")


func test_full_mash_scores_one() -> void:
	var b := _beat()
	for i in 4:
		b.press()
	b._process(0.6)
	await wait_for_signal(b.finished, 2.0)
	var result: Dictionary = get_signal_parameters(b, "finished")[0]
	assert_eq(result.score, 1.0)


func test_no_mash_scores_zero() -> void:
	var b := _beat()
	b._process(0.6)
	await wait_for_signal(b.finished, 2.0)
	var result: Dictionary = get_signal_parameters(b, "finished")[0]
	assert_eq(result.score, 0.0)


func test_overmash_caps_at_one() -> void:
	var b := _beat()
	for i in 9:
		b.press()
	b._process(0.6)
	await wait_for_signal(b.finished, 2.0)
	var result: Dictionary = get_signal_parameters(b, "finished")[0]
	assert_eq(result.score, 1.0)
