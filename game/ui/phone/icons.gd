class_name OOTIcons
extends RefCounted
## Lucide SVG icons (ISC, see ui/icons/SOURCES.md), rasterised crisp at the size asked for and tinted white
## (use Control.modulate or TextureRect.self_modulate to colour them).

const DIR: String = "res://ui/icons/"

static var _cache: Dictionary = {}


static func get_icon(icon_name: String, px: int = 32) -> Texture2D:
	var key: String = "%s@%d" % [icon_name, px]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	var path: String = DIR + icon_name + ".svg"
	if FileAccess.file_exists(path):
		var img: Image = Image.new()
		if img.load_svg_from_string(FileAccess.get_file_as_string(path), float(px) / 24.0) == OK:
			tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func rect(icon_name: String, px: int = 32, tint: Color = Color.WHITE) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = get_icon(icon_name, px)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.self_modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
