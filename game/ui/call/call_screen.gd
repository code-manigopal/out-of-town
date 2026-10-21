class_name OOTCallScreen
extends Control
## The laptop's video-call window (no real app branding): a main tile with Amma and Appa (webcam stills with a slow
## zoom/pan and grain), a small self-view tile of Mani, a call timer and mute / camera / end icons.
## Rendered by a SubViewport onto the laptop screen. Drive it with set_speaker().

const SCREEN_SIZE: Vector2i = Vector2i(1280, 800)
const TILE_RECT: Rect2 = Rect2(24, 68, 1232, 620)
const SELF_RECT: Rect2 = Rect2(940, 492, 300, 188)
const BG: Color = Color(0.085, 0.09, 0.105)
const ACCENT: Color = Color(0.3, 0.8, 0.45)

const NOISE_SHADER: String = """
shader_type canvas_item;
uniform float strength = 0.09;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 q = floor(UV * vec2(640.0, 310.0));
	float n = hash(q + floor(TIME * 24.0) * 1.37) - 0.5;
	float scan = 0.035 * sin(UV.y * 620.0 + TIME * 3.0);
	float vig = smoothstep(0.95, 0.35, distance(UV, vec2(0.5)));
	COLOR = vec4(vec3(0.5 + n), 0.0);
	COLOR.a = clamp(abs(n) * strength * 2.0 + abs(scan) + (1.0 - vig) * 0.32, 0.0, 1.0);
	COLOR.rgb = mix(vec3(0.02, 0.02, 0.03), vec3(0.85), step(0.0, n)) * 1.0;
	COLOR.rgb = mix(COLOR.rgb, vec3(0.0), (1.0 - vig) * 0.8);
}
"""

## "wide", "amma" or "appa": the tile shown now. The speaking person's close-up, wide for Mani and narration.
var tile: String = "wide"
var tile_key: String = "amma_appa_wide"
var tile_is_placeholder: bool = true
var speaker: String = ""
var elapsed: float = 0.0
var ended: bool = false

var _tile_box: Control
var _remote: TextureRect
var _fallback_art: OOTCallPlaceholderArt
var _speaking_border: Panel
var _name_label: Label
var _timer_label: Label
var _rec_dot: Control
var _self_rect: TextureRect
var _ended_overlay: ColorRect
var _tile_age: float = 0.0
var _pan_seed: float = 0.0
var _textures: Dictionary = {}  # key -> {"texture", "path", "placeholder"}


func _init() -> void:
	size = Vector2(SCREEN_SIZE)
	custom_minimum_size = size


func _ready() -> void:
	_build()
	set_speaker("")


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# top bar
	var title: Label = _label("Family  -  Amma, Appa", 26, Color(0.85, 0.87, 0.9))
	title.position = Vector2(30, 14)
	add_child(title)
	_timer_label = _label("00:00", 30, Color(0.95, 0.95, 0.95))
	_timer_label.position = Vector2(SCREEN_SIZE.x - 150, 12)
	add_child(_timer_label)
	_rec_dot = Control.new()
	_rec_dot.position = Vector2(SCREEN_SIZE.x - 180, 31)
	_rec_dot.draw.connect(func() -> void: _rec_dot.draw_circle(Vector2.ZERO, 8, Color(0.92, 0.22, 0.22)))
	add_child(_rec_dot)
	# main tile
	_tile_box = Control.new()
	_tile_box.position = TILE_RECT.position
	_tile_box.size = TILE_RECT.size
	_tile_box.clip_contents = true
	add_child(_tile_box)
	_remote = TextureRect.new()
	_remote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_remote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_remote.size = TILE_RECT.size
	_tile_box.add_child(_remote)
	_fallback_art = OOTCallPlaceholderArt.new()
	_fallback_art.size = TILE_RECT.size
	_fallback_art.visible = false
	_tile_box.add_child(_fallback_art)
	var noise: ColorRect = ColorRect.new()
	noise.size = TILE_RECT.size
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = NOISE_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	noise.material = mat
	_tile_box.add_child(noise)
	_name_label = _label("Amma, Appa", 26, Color.WHITE)
	_name_label.position = Vector2(16, TILE_RECT.size.y - 46)
	_tile_box.add_child(_name_label)
	_speaking_border = Panel.new()
	_speaking_border.position = TILE_RECT.position - Vector2(3, 3)
	_speaking_border.size = TILE_RECT.size + Vector2(6, 6)
	_speaking_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = ACCENT
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(4)
	_speaking_border.add_theme_stylebox_override("panel", sb)
	add_child(_speaking_border)
	# self view
	var frame: Panel = Panel.new()
	frame.position = SELF_RECT.position - Vector2(3, 3)
	frame.size = SELF_RECT.size + Vector2(6, 6)
	var fsb: StyleBoxFlat = StyleBoxFlat.new()
	fsb.bg_color = Color(0.02, 0.02, 0.03)
	fsb.border_color = Color(0.85, 0.87, 0.9, 0.9)
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", fsb)
	add_child(frame)
	_self_rect = TextureRect.new()
	_self_rect.position = SELF_RECT.position
	_self_rect.size = SELF_RECT.size
	_self_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_self_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_self_rect.flip_h = true  # self-view is mirrored, like every webcam app
	add_child(_self_rect)
	var you: Label = _label("You", 20, Color.WHITE)
	you.position = SELF_RECT.position + Vector2(10, SELF_RECT.size.y - 30)
	add_child(you)
	# controls
	var icons: Control = Control.new()
	icons.position = Vector2(SCREEN_SIZE.x * 0.5, 748)
	icons.draw.connect(func() -> void: _draw_icons(icons))
	add_child(icons)
	# ended overlay
	_ended_overlay = ColorRect.new()
	_ended_overlay.color = Color(0.03, 0.03, 0.04, 0.92)
	_ended_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ended_overlay.visible = false
	var end_label: Label = _label("Call ended", 54, Color(0.92, 0.92, 0.94))
	end_label.size = Vector2(SCREEN_SIZE)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ended_overlay.add_child(end_label)
	add_child(_ended_overlay)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## Mute, camera and end-call buttons, drawn simply around `c`'s origin.
func _draw_icons(c: Control) -> void:
	var grey: Color = Color(0.22, 0.24, 0.28)
	var white: Color = Color(0.96, 0.96, 0.98)
	var r: float = 34.0
	# mic
	var m: Vector2 = Vector2(-110, 0)
	c.draw_circle(m, r, grey)
	c.draw_rect(Rect2(m + Vector2(-7, -18), Vector2(14, 22)), white, true)
	c.draw_arc(m + Vector2(0, -2), 14, 0.0, PI, 16, white, 3.0)
	c.draw_line(m + Vector2(0, 12), m + Vector2(0, 20), white, 3.0)
	c.draw_line(m + Vector2(-8, 20), m + Vector2(8, 20), white, 3.0)
	# camera
	var cam: Vector2 = Vector2.ZERO
	c.draw_circle(cam, r, grey)
	c.draw_rect(Rect2(cam + Vector2(-17, -10), Vector2(22, 20)), white, true)
	c.draw_colored_polygon(PackedVector2Array([cam + Vector2(7, 0), cam + Vector2(18, -9), cam + Vector2(18, 9)]), white)
	# end call: red circle with a handset (a thick arc)
	var e: Vector2 = Vector2(110, 0)
	c.draw_circle(e, r, Color(0.88, 0.2, 0.2))
	c.draw_arc(e + Vector2(0, 12), 18, PI * 1.12, PI * 1.88, 16, white, 6.0)
	c.draw_line(e + Vector2(-17, 2), e + Vector2(-17, 8), white, 6.0)
	c.draw_line(e + Vector2(17, 2), e + Vector2(17, 8), white, 6.0)


## Gives the small self-view tile its texture (from the webcam camera's SubViewport).
func set_self_texture(tex: Texture2D) -> void:
	if _self_rect != null:
		_self_rect.texture = tex


## `who` is a dialogue speaker id (AMMA, APPA, MANI, "" for narration). The tile switches to the speaker's close-up.
func set_speaker(who: String) -> void:
	speaker = who.to_upper()
	match speaker:
		"AMMA":
			_show_tile("amma", "amma_close")
		"APPA":
			_show_tile("appa", "appa_close")
		_:
			_show_tile("wide", "amma_appa_wide")
	if _speaking_border != null:
		_speaking_border.visible = speaker == "AMMA" or speaker == "APPA"
		_name_label.text = {"AMMA": "Amma", "APPA": "Appa"}.get(speaker, "Amma, Appa")


func _show_tile(p_tile: String, key: String) -> void:
	if p_tile != tile:
		_tile_age = 0.0
		_pan_seed = randf() * 10.0
	tile = p_tile
	tile_key = key
	if not _textures.has(key):
		_textures[key] = OOTCallImages.find(key)
	var info: Dictionary = _textures[key]
	tile_is_placeholder = bool(info["placeholder"])
	if _remote == null:
		return
	_remote.texture = info["texture"] as Texture2D
	_remote.visible = _remote.texture != null
	_fallback_art.visible = _remote.texture == null
	_fallback_art.who = p_tile
	_tile_box.modulate = Color(1.18, 1.18, 1.18)  # a little autofocus / exposure blip on every cut


func end_call() -> void:
	ended = true
	if _ended_overlay != null:
		_ended_overlay.visible = true


func _process(delta: float) -> void:
	if _tile_box == null:
		return
	if not ended:
		elapsed += delta
	_tile_age += delta
	_timer_label.text = "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	_rec_dot.visible = ended or int(elapsed * 1.6) % 2 == 0
	_tile_box.modulate = _tile_box.modulate.lerp(Color.WHITE, minf(delta * 7.0, 1.0))
	# slow push-in with a little handheld-laptop drift
	var z: float = 1.03 + minf(_tile_age * 0.012, 0.07)
	var drift: Vector2 = Vector2(sin(_pan_seed + _tile_age * 0.31), cos(_pan_seed * 1.3 + _tile_age * 0.23)) * 9.0
	var target: Control = _remote if _remote.visible else _fallback_art
	target.pivot_offset = TILE_RECT.size * 0.5
	target.scale = Vector2(z, z)
	target.position = drift
