extends GutTest

## PropArt: an art slot draws `<root>/<game>/<name>.png` when the file exists,
## else the Twemoji placeholder, so dropping a PNG in needs no code change.
## The fixture root holds one 4x4 PNG at probe/gag.png.

const FIXTURE_ROOT := "res://tests/fixtures/props"
const FIXTURE_PNG := "res://tests/fixtures/props/probe/gag.png"

## Each game that can be lost, and the art folder its gag is read from.
const GAME_FOLDERS := [
	["res://scenes/minigames/wake.tscn", "wake"],
	["res://scenes/minigames/brush.tscn", "brush"],
	["res://scenes/minigames/shower.tscn", "shower"],
	["res://scenes/minigames/clothes.tscn", "clothes"],
	["res://scenes/minigames/breakfast.tscn", "breakfast"],
	["res://scenes/minigames/cooking.tscn", "cooking"],
	["res://scenes/minigames/burst.tscn", "work_am"],
	["res://scenes/minigames/triage.tscn", "work_pm"],
	["res://scenes/minigames/listening.tscn", "lunch"],
	["res://scenes/minigames/coffee.tscn", "coffee"],
]


## A minigame whose gag art is read from the fixture root.
class ArtProbe extends Minigame:
	func _art_folder() -> String:
		return "probe"


func _draws(font: Font, glyph: String) -> bool:
	if font.has_char(glyph.unicode_at(0)):
		return true
	for fallback in font.fallbacks:
		if (fallback as Font).has_char(glyph.unicode_at(0)):
			return true
	return false


func test_the_path_is_root_game_name_png() -> void:
	assert_eq(PropArt.path("wake", "gag"), "res://assets/props/wake/gag.png")
	assert_eq(PropArt.path("probe", "gag", FIXTURE_ROOT), FIXTURE_PNG)


func test_an_existing_png_draws_as_a_texture() -> void:
	var art := PropArt.make("probe", "gag", "💥", FIXTURE_ROOT)
	autofree(art)
	assert_is(art, TextureRect)
	var texture := (art as TextureRect).texture
	assert_is(texture, Texture2D, "a real texture, not an empty rect")
	assert_eq(texture, load(FIXTURE_PNG), "the slot's own PNG")
	assert_eq(art.mouse_filter, Control.MOUSE_FILTER_IGNORE, "art never eats a click")


func test_a_missing_png_draws_the_emoji_placeholder() -> void:
	var art := PropArt.make("probe", "absent", "💥", FIXTURE_ROOT)
	autofree(art)
	assert_is(art, Label)
	assert_eq((art as Label).text, "💥")
	assert_true(_draws((art as Label).get_theme_font(&"font"), "💥"), "Twemoji backs it")
	assert_eq(art.mouse_filter, Control.MOUSE_FILTER_IGNORE, "art never eats a click")


func test_a_png_that_will_not_load_draws_the_placeholder() -> void:
	# ResourceLoader.exists can say yes while load() yields no texture (a stale
	# or missing import); the slot falls back to the emoji, never an empty rect.
	var art := PropArt.from_texture(null, "💥")
	autofree(art)
	assert_is(art, Label)
	assert_eq((art as Label).text, "💥")


func test_a_given_font_replaces_the_emoji_fallback() -> void:
	var art := PropArt.make("probe", "absent", "💥", FIXTURE_ROOT, Minigame.GAG_FONT)
	autofree(art)
	assert_eq((art as Label).get_theme_font(&"font"), Minigame.GAG_FONT, "one font, as given")


func test_a_game_with_no_folder_draws_the_placeholder() -> void:
	var art := PropArt.make("", "gag", "💥", FIXTURE_ROOT)
	autofree(art)
	assert_is(art, Label)


func test_emoji_fallback_keeps_the_base_font_and_adds_twemoji() -> void:
	var label := Label.new()
	autofree(label)
	var base := label.get_theme_font(&"font")
	PropArt.with_emoji_fallback(label)
	var font := label.get_theme_font(&"font") as FontVariation
	assert_not_null(font)
	assert_eq(font.base_font, base)
	assert_eq(font.fallbacks, [PropArt.EMOJI_FONT])


## Minigame._prop is every scene's art slot: the game's own folder, filling the
## parent slot, and a placeholder centred at the slot's size.
func test_a_prop_with_art_fills_its_slot_with_the_png() -> void:
	var probe := ArtProbe.new()
	probe.props_root = FIXTURE_ROOT
	autofree(probe)
	var art := probe._prop("gag", "💥", 40)
	autofree(art)
	assert_is(art, TextureRect, "the game's own folder, under its props root")
	assert_eq([art.anchor_left, art.anchor_top, art.anchor_right, art.anchor_bottom],
			[0.0, 0.0, 1.0, 1.0], "it fills the slot")


func test_a_prop_without_art_is_its_placeholder_centred_at_its_size() -> void:
	var probe := ArtProbe.new()
	probe.props_root = FIXTURE_ROOT
	autofree(probe)
	var art := probe._prop("absent", "💥", 40)
	autofree(art)
	assert_is(art, Label)
	var label := art as Label
	assert_eq(label.text, "💥")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
	assert_eq(label.get_theme_font_size(&"font_size"), 40)
	assert_true(_draws(label.get_theme_font(&"font"), "💥"), "Twemoji backs it")
	assert_eq([art.anchor_left, art.anchor_top, art.anchor_right, art.anchor_bottom],
			[0.0, 0.0, 1.0, 1.0], "it fills the slot")
	assert_eq(art.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_a_gag_with_art_draws_the_png() -> void:
	var probe := ArtProbe.new()
	probe.props_root = FIXTURE_ROOT
	add_child_autofree(probe)
	probe._start({"fail_gag_seconds": 100.0})
	probe._fail("💥")
	var art := probe.find_children("*", "TextureRect", true, false)
	assert_eq(art.size(), 1, "one gag, drawn from the PNG")
	var texture := (art[0] as TextureRect).texture
	assert_is(texture, Texture2D, "a real texture, not an empty rect")
	assert_eq(texture, load(FIXTURE_PNG))
	assert_eq(probe.find_children("*", "Label", true, false).size(), 0, "no emoji")


func test_a_gag_without_art_draws_the_emoji_as_before() -> void:
	var bare := Minigame.new()
	bare.props_root = FIXTURE_ROOT
	add_child_autofree(bare)
	bare._start({"fail_gag_seconds": 100.0})
	bare._fail("🙈")
	var labels := bare.find_children("*", "Label", true, false)
	assert_eq(labels.size(), 1, "no folder, so the emoji label")
	var label := labels[0] as Label
	assert_eq(label.text, "🙈")
	assert_eq(label.get_theme_font(&"font"), Minigame.GAG_FONT, "the gag's own Twemoji font")
	assert_eq(label.get_theme_font_size(&"font_size"), Minigame.GAG_FONT_SIZE)
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_each_losable_game_names_its_art_folder(p = use_parameters(GAME_FOLDERS)) -> void:
	var node: Minigame = load(p[0]).instantiate()
	autofree(node)
	assert_eq(node._art_folder(), p[1])
