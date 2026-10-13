extends GutTest

## The four morning chores draw their props through the art slots (issue #18,
## wave B step 9): wake's rattling alarm clock, brush's mouth and the brush on
## the cursor, shower's stinky dog with the showerhead on the cursor and
## shrinking stink clouds, and clothes' item icons. All of it is presentation:
## every prop is mouse-transparent and no hit area moves.

const WAKE := "res://scenes/minigames/wake.tscn"
const BRUSH := "res://scenes/minigames/brush.tscn"
const SHOWER := "res://scenes/minigames/shower.tscn"
const CLOTHES := "res://scenes/minigames/clothes.tscn"

const WAKE_PARAMS := {"mash_target": 50, "decay_per_sec": 0.0}
const BRUSH_PARAMS := {"strokes_required": 6, "amplitude": 40.0}
const SHOWER_PARAMS := {"spots": 2, "revolutions": 2.0, "min_radius": 12.0}
const CLOTHES_PARAMS := {"fumble_chance": 0.0}
## Holds no art, so every slot draws its emoji placeholder.
const NO_ART_ROOT := "res://tests/fixtures/props/none"

## Each chore's prop slots and the emoji each draws until its PNG lands.
const SLOTS := [
	[WAKE, WAKE_PARAMS, "%ClockSlot", "⏰"],
	[BRUSH, BRUSH_PARAMS, "%MouthSlot", "👄"],
	[BRUSH, BRUSH_PARAMS, "%BrushSlot", "🪥"],
	[SHOWER, SHOWER_PARAMS, "%DogSlot", "🐕"],
	[SHOWER, SHOWER_PARAMS, "%ShowerheadSlot", "🚿"],
	[SHOWER, SHOWER_PARAMS, "%Spot", "💨"],
	[CLOTHES, CLOTHES_PARAMS, "%DogZone", "🐕"],
	[CLOTHES, CLOTHES_PARAMS, "%Items/Shirt", "👕"],
	[CLOTHES, CLOTHES_PARAMS, "%Items/Pants", "👖"],
	[CLOTHES, CLOTHES_PARAMS, "%Items/Shoes", "👟"],
	[CLOTHES, CLOTHES_PARAMS, "%Items/Collar", "📿"],
]
const SCENES := [
	[WAKE, WAKE_PARAMS],
	[BRUSH, BRUSH_PARAMS],
	[SHOWER, SHOWER_PARAMS],
	[CLOTHES, CLOTHES_PARAMS],
]
## Each clothes item's hit rect, as the scene lays it out: [x, y, w, h].
const ITEM_RECTS := {
	"Shirt": [60.0, 120.0, 80.0, 50.0],
	"Pants": [60.0, 220.0, 80.0, 50.0],
	"Shoes": [60.0, 320.0, 80.0, 50.0],
	"Collar": [60.0, 420.0, 80.0, 50.0],
}


func _host(path: String, params: Dictionary) -> Minigame:
	var node: Minigame = load(path).instantiate()
	node.props_root = NO_ART_ROOT
	add_child_autofree(node)
	node.setup(params.duplicate())
	return node


func _art(slot: Control) -> Control:
	for child in slot.get_children():
		if child is Label or child is TextureRect:
			return child
	return null


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = Vector2.ZERO
	return event


func test_each_slot_draws_its_placeholder_through_the_game_folder(
		p = use_parameters(SLOTS)) -> void:
	var node := _host(p[0], p[1])
	var slot: Control = node.get_node(p[2])
	var art := _art(slot)
	assert_is(art, Label, "%s: no PNG, so its emoji draws" % p[2])
	if art:
		assert_eq((art as Label).text, p[3])
		assert_eq(art.mouse_filter, Control.MOUSE_FILTER_IGNORE, "art never eats a click")


func test_every_placeholder_has_a_twemoji_glyph(p = use_parameters(SLOTS)) -> void:
	var glyph: String = p[3]
	assert_true(PropArt.EMOJI_FONT.has_char(glyph.unicode_at(0)),
			"%s draws as tofu on the web build" % glyph)


func test_no_control_eats_the_mouse(p = use_parameters(SCENES)) -> void:
	var node := _host(p[0], p[1])
	var blockers: Array = []
	var controls: Array = node.find_children("*", "Control", true, false)
	controls.push_back(node)
	for control in controls:
		if control is Button:
			continue
		if (control as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blockers.append(String(control.name))
	assert_eq(blockers, [], "these nodes eat the mouse")


# --- wake --------------------------------------------------------------------


func test_the_alarm_rattles_faster_as_the_bar_falls() -> void:
	var script: GDScript = load("res://scripts/minigames/wake_minigame.gd")
	var full: float = script.rattle_hz(1.0)
	var half: float = script.rattle_hz(0.5)
	var empty: float = script.rattle_hz(0.0)
	assert_gt(full, 0.0, "even a fresh clock rattles")
	assert_gt(half, full)
	assert_gt(empty, half)


func test_the_alarm_clock_shakes_while_the_game_runs() -> void:
	var node := _host(WAKE, WAKE_PARAMS.merged({"time_limit": 10.0}))
	var clock: Control = node.get_node("%ClockSlot")
	var angles := {}
	for i in 6:
		node._process(0.03)
		angles[snappedf(clock.rotation, 0.0001)] = true
	assert_gt(angles.size(), 1, "the clock never moved")
	assert_eq(node.get_node("%WakeBar").value, node._logic.progress, "the bar still reads the mash")


# --- brush -------------------------------------------------------------------


func test_the_brush_follows_the_cursor() -> void:
	var node := _host(BRUSH, BRUSH_PARAMS)
	var brush: Control = node.get_node("%BrushSlot")
	node._input(_motion(Vector2(300.0, 200.0)))
	assert_almost_eq(brush.get_global_rect().get_center(), Vector2(300.0, 200.0), Vector2.ONE)
	node._input(_motion(Vector2(500.0, 260.0)))
	assert_almost_eq(brush.get_global_rect().get_center(), Vector2(500.0, 260.0), Vector2.ONE)


# --- shower ------------------------------------------------------------------


func test_the_showerhead_follows_the_cursor() -> void:
	var node := _host(SHOWER, SHOWER_PARAMS)
	var head: Control = node.get_node("%ShowerheadSlot")
	node._input(_motion(Vector2(420.0, 330.0)))
	assert_almost_eq(head.get_global_rect().get_center(), Vector2(420.0, 330.0), Vector2.ONE)


func test_the_stink_cloud_shrinks_as_the_spot_is_scrubbed() -> void:
	var node := _host(SHOWER, SHOWER_PARAMS)
	var spot: Control = node.get_node("%Spot")
	var cloud := _art(spot)
	node._process(0.016)
	var fresh := cloud.scale.x
	node._tracker.revolutions = 1.0
	node._process(0.016)
	var half := cloud.scale.x
	node._tracker.revolutions = 1.9
	node._process(0.016)
	assert_lt(half, fresh, "half scrubbed is smaller")
	assert_lt(cloud.scale.x, half, "nearly clean is smaller still")
	assert_gt(cloud.scale.x, 0.0, "it never vanishes before the spot is clean")


func test_a_new_spot_brings_a_full_cloud() -> void:
	var node := _host(SHOWER, SHOWER_PARAMS)
	var cloud := _art(node.get_node("%Spot"))
	node._process(0.016)
	var fresh := cloud.scale.x
	node._tracker.revolutions = 2.0
	node._process(0.016)
	assert_eq(node._spots_left, 1, "the first spot is clean")
	assert_eq(cloud.scale.x, fresh)


func test_the_spot_hit_area_is_unchanged_by_its_cloud() -> void:
	var node := _host(SHOWER, SHOWER_PARAMS)
	var spot: Control = node.get_node("%Spot")
	node._tracker.revolutions = 1.0
	node._process(0.016)
	assert_eq(spot.size, Vector2(48.0, 48.0), "the spot's hit square")
	assert_eq(spot.scale, Vector2.ONE, "only the art inside it shrinks")


# --- clothes -----------------------------------------------------------------


func test_each_item_is_an_icon_not_a_coloured_rect() -> void:
	var node := _host(CLOTHES, CLOTHES_PARAMS)
	for item in node.get_node("%Items").get_children():
		assert_false(item is ColorRect, "%s is still a coloured rect" % item.name)


func test_each_item_keeps_its_hit_rect() -> void:
	var node := _host(CLOTHES, CLOTHES_PARAMS)
	for item_name: String in ITEM_RECTS:
		var item: Control = node.get_node("%Items").get_node(item_name)
		var r: Array = ITEM_RECTS[item_name]
		assert_eq(item.get_rect(), Rect2(r[0], r[1], r[2], r[3]), item_name)


func test_a_dropped_item_wobbles_its_icon_but_lands_home() -> void:
	var node := _host(CLOTHES, CLOTHES_PARAMS)
	var shirt: Control = node.get_node("%Items/Shirt")
	var home := shirt.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = shirt.get_global_rect().get_center()
	node._unhandled_input(press)
	shirt.position = Vector2(900.0, 600.0)  # dragged far off the dog
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	node._unhandled_input(release)
	assert_eq(shirt.position, home, "the item itself snaps home at once")
	await wait_seconds(0.05)
	assert_ne(_art(shirt).rotation, 0.0, "its icon wobbles")
