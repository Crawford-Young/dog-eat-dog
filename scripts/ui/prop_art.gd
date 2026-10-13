class_name PropArt
extends RefCounted

## An art slot: `<root>/<game>/<name>.png` when that file exists, else the
## slot's Twemoji placeholder. Dropping a PNG into assets/props/<game>/ swaps
## the emoji for the art with no code change (the art itself is issue #24).

const ROOT := "res://assets/props"
## The default font has no emoji glyphs; web builds have no system fallback.
const EMOJI_FONT := preload("res://assets/fonts/twemoji_mozilla.ttf")


static func path(game: String, name: String, root := ROOT) -> String:
	return "%s/%s/%s.png" % [root, game, name]


## The slot's PNG when it exists and loads, else `placeholder` (see
## from_texture). An absent game folder always draws the placeholder.
static func make(
		game: String, name: String, placeholder: String, root := ROOT, font: Font = null
) -> Control:
	var file := path(game, name, root)
	var texture: Texture2D = null
	if not game.is_empty() and ResourceLoader.exists(file):
		texture = load(file) as Texture2D
	return from_texture(texture, placeholder, font)


## A mouse-transparent TextureRect showing `texture`, or with no texture a
## Label showing `placeholder` in `font` — by default the label's own font
## backed by Twemoji.
static func from_texture(texture: Texture2D, placeholder: String, font: Font = null) -> Control:
	if texture:
		var art := TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return art
	var label := Label.new()
	label.text = placeholder
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		label.add_theme_font_override(&"font", font)
	else:
		with_emoji_fallback(label)
	return label


## Keeps the label's own font and backs it with Twemoji for the emoji.
static func with_emoji_fallback(label: Label) -> void:
	var font := FontVariation.new()
	font.base_font = label.get_theme_font(&"font")
	font.fallbacks = [EMOJI_FONT]
	label.add_theme_font_override(&"font", font)
