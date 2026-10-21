class_name OOTPhoneBody
extends Control
## A phone drawn in UI so it reads as a 3D object: soft shadow, a darker side wall offset below-right (the phone's
## thickness), a metal rim, black bezel, glass screen with a diagonal glare and a camera island. Children go into
## `screen` (rounded, clipped). Used by the phone (P) and by the cold-open lock screen.

const RIM: float = 3.0
const BEZEL: float = 10.0
const DEPTH: Vector2 = Vector2(7.0, 9.0)

var corner: float = 44.0
var screen: Panel
var _glare: _Glare


## The glass-reflection layer, last in the screen so it sits on top of everything.
class _Glare extends Control:
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.55, 0), Vector2(w, 0), Vector2(w, h * 0.22), Vector2(w * 0.18, h * 0.7)]),
			Color(1, 1, 1, 0.035))
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.3, 0), Vector2(w * 0.4, 0), Vector2(0, h * 0.34), Vector2(0, h * 0.2)]),
			Color(1, 1, 1, 0.025))


static func make(p_size: Vector2) -> OOTPhoneBody:
	var b: OOTPhoneBody = OOTPhoneBody.new()
	b.size = p_size
	b.custom_minimum_size = p_size
	b.corner = p_size.x * 0.135
	b._build()
	return b


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	pivot_offset = size * 0.5
	screen = Panel.new()
	screen.name = "Screen"
	var inset: float = RIM + BEZEL
	screen.position = Vector2(inset, inset)
	screen.size = size - Vector2(inset, inset) * 2.0
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = OOTUiStyle.BG
	sb.set_corner_radius_all(int(corner - inset * 0.55))
	screen.add_theme_stylebox_override("panel", sb)
	screen.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	screen.theme = OOTUiStyle.make_theme()
	add_child(screen)
	var island: Panel = Panel.new()
	island.name = "Island"
	var isb: StyleBoxFlat = StyleBoxFlat.new()
	isb.bg_color = Color.BLACK
	isb.set_corner_radius_all(12)
	island.add_theme_stylebox_override("panel", isb)
	island.size = Vector2(minf(screen.size.x * 0.3, 86.0), 22.0)
	island.position = Vector2((screen.size.x - island.size.x) * 0.5, 9.0)
	island.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(island)
	_glare = _Glare.new()
	_glare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glare.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(_glare)


## Adds a child under the glare (so the glare stays on top).
func add_to_screen(c: Control) -> void:
	screen.add_child(c)
	screen.move_child(_glare, screen.get_child_count() - 1)


func screen_size() -> Vector2:
	return screen.size


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	# Shadow on the "table".
	var sh: StyleBoxFlat = StyleBoxFlat.new()
	sh.bg_color = Color(0, 0, 0, 0.0)
	sh.set_corner_radius_all(int(corner))
	sh.shadow_size = 46
	sh.shadow_color = Color(0, 0, 0, 0.62)
	sh.shadow_offset = Vector2(10, 26)
	draw_style_box(sh, r)
	# Side wall: the phone's thickness, seen from above-left.
	var wall: StyleBoxFlat = StyleBoxFlat.new()
	wall.bg_color = Color(0.05, 0.055, 0.065)
	wall.set_corner_radius_all(int(corner))
	draw_style_box(wall, Rect2(DEPTH, size))
	var wall_hi: StyleBoxFlat = StyleBoxFlat.new()
	wall_hi.bg_color = Color(0.15, 0.16, 0.18)
	wall_hi.set_corner_radius_all(int(corner))
	draw_style_box(wall_hi, Rect2(DEPTH * 0.55, size))
	# Metal rim.
	var rim: StyleBoxFlat = StyleBoxFlat.new()
	rim.bg_color = Color(0.36, 0.38, 0.42)
	rim.set_corner_radius_all(int(corner))
	draw_style_box(rim, r)
	var rim_hi: StyleBoxFlat = StyleBoxFlat.new()
	rim_hi.bg_color = Color(0.2, 0.21, 0.24)
	rim_hi.set_corner_radius_all(int(corner - 1.0))
	draw_style_box(rim_hi, r.grow(-1.2))
	# Bezel.
	var bez: StyleBoxFlat = StyleBoxFlat.new()
	bez.bg_color = Color(0.015, 0.015, 0.02)
	bez.set_corner_radius_all(int(corner - RIM))
	draw_style_box(bez, r.grow(-RIM))
	# Side buttons (on the left rim, power on the right).
	draw_rect(Rect2(-2.5, size.y * 0.2, 3.0, 26.0), Color(0.3, 0.32, 0.36))
	draw_rect(Rect2(-2.5, size.y * 0.2 + 38.0, 3.0, 40.0), Color(0.3, 0.32, 0.36))
	draw_rect(Rect2(-2.5, size.y * 0.2 + 86.0, 3.0, 40.0), Color(0.3, 0.32, 0.36))
	draw_rect(Rect2(size.x - 0.5, size.y * 0.27, 3.0, 62.0), Color(0.3, 0.32, 0.36))
