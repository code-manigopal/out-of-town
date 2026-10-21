class_name OOTCallImages
extends RefCounted
## Webcam stills for the Amma and Appa video call (Ep 1 scene 2).
## For each key the real image `res://props/photos/call/<key>.png` is used when it exists and loads,
## else `<key>_placeholder.png`, else null (the call screen then draws the procedural placeholder).

const DIR: String = "res://props/photos/call/"
const KEYS: Array[String] = ["amma_appa_wide", "amma_close", "appa_close"]
## Size the real images should be generated at (16:9).
const IMAGE_SIZE: Vector2i = Vector2i(1920, 1080)


static func real_path(key: String, dir: String = DIR) -> String:
	return "%s%s.png" % [dir, key]


static func placeholder_path(key: String, dir: String = DIR) -> String:
	return "%s%s_placeholder.png" % [dir, key]


## Returns {"texture": Texture2D or null, "path": String, "placeholder": bool}. `dir` is for tests.
static func find(key: String, dir: String = DIR) -> Dictionary:
	var tex: Texture2D = _load(real_path(key, dir))
	if tex != null:
		return {"texture": tex, "path": real_path(key, dir), "placeholder": false}
	tex = _load(placeholder_path(key, dir))
	if tex != null:
		return {"texture": tex, "path": placeholder_path(key, dir), "placeholder": true}
	return {"texture": null, "path": "", "placeholder": true}


static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	# A freshly dropped PNG that the editor has not imported yet (or a non-imported run).
	if FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null
