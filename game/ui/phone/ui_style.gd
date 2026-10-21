class_name OOTUiStyle
extends RefCounted
## Shared look for the storytelling UI (phone, lock screen, objective toast): Inter font, a dark glass palette,
## small helpers for rounded boxes. Fonts: ui/fonts/SOURCES.md.

const FONT_PATH: String = "res://ui/fonts/Inter.ttf"
const HAND_PATH: String = "res://ui/fonts/Caveat.ttf"

const BG: Color = Color(0.055, 0.065, 0.09)
const BG_TOP: Color = Color(0.09, 0.14, 0.2)
const CARD: Color = Color(0.125, 0.14, 0.18)
const CARD_HI: Color = Color(0.17, 0.2, 0.26)
const TEXT: Color = Color(0.94, 0.95, 0.97)
const TEXT_DIM: Color = Color(0.62, 0.66, 0.74)
const ACCENT: Color = Color(0.36, 0.78, 0.74)
const ACCENT_DARK: Color = Color(0.13, 0.42, 0.42)
const ALERT: Color = Color(0.9, 0.36, 0.34)
const BUBBLE_ME: Color = Color(0.18, 0.5, 0.52)
const BUBBLE_THEM: Color = Color(0.19, 0.21, 0.27)

static var _fonts: Dictionary = {}


## Inter at a weight (400 regular, 500 medium, 600 semibold, 700 bold). Falls back to the engine font.
static func font(weight: int = 400) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f: Font = null
	var base: Font = load(FONT_PATH) as Font
	if base != null:
		var fv: FontVariation = FontVariation.new()
		fv.base_font = base
		var tag: int = TextServerManager.get_primary_interface().name_to_tag("weight")
		fv.variation_opentype = {tag: weight}
		f = fv
	else:
		f = ThemeDB.fallback_font
	_fonts[weight] = f
	return f


## Inter slanted (the font has no italic face): Mani's inner voice and other thought-style text.
static func italic_font(weight: int = 400) -> Font:
	var key: int = 1000 + weight
	if _fonts.has(key):
		return _fonts[key]
	var fv: FontVariation = FontVariation.new()
	fv.base_font = font(weight)
	fv.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
	_fonts[key] = fv
	return fv


static func box(color: Color, radius: int = 14, margin: int = 0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## A Theme with Inter and flat, rounded buttons whose focus ring is the accent colour (mouse, keys and gamepad alike).
static func make_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font = font(400)
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var c: Color = Color(0, 0, 0, 0)
		match state:
			"hover":
				c = Color(1, 1, 1, 0.07)
			"pressed":
				c = Color(1, 1, 1, 0.14)
		var sb: StyleBoxFlat = box(c, 14, 8)
		if state == "focus":
			sb = box(Color(1, 1, 1, 0.06), 14, 8)
			sb.set_border_width_all(2)
			sb.border_color = ACCENT
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	return t


static func label(text: String, size: int = 15, color: Color = TEXT, weight: int = 400) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
