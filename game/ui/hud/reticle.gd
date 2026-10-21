class_name OOTReticle
extends Control
## Centre-of-screen reticle. A small dot normally; when something can be
## interacted with it morphs into a glyph that says what kind of thing it is
## (eye ring = inspect, open hand = pick up, gear = use, door, speech = talk).
## Drawn in code, no textures.

const STYLES: Array[StringName] = [&"dot", &"inspect", &"pickup", &"use", &"door", &"talk"]
const SIZE: float = 44.0

## The style currently shown (target of the morph).
var style: StringName = &"dot"
var _from: StringName = &"dot"
var _t: float = 1.0
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2(SIZE, SIZE) * 0.5


func set_style(new_style: StringName) -> void:
	if not STYLES.has(new_style):
		new_style = &"dot"
	if new_style == style:
		return
	_from = style
	style = new_style
	_t = 0.0
	if _tween != null:
		_tween.kill()
	if is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_t, 0.0, 1.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_t = 1.0
	queue_redraw()


func _set_t(v: float) -> void:
	_t = v
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	# Fade the old glyph out and the new one in, with a small scale pop.
	if _t < 1.0:
		_draw_style(_from, c, 1.0 - _t, 1.0)
	_draw_style(style, c, _t if _from != style else 1.0, lerpf(0.8, 1.0, _t))


func _draw_style(s: StringName, c: Vector2, alpha: float, k: float) -> void:
	if alpha <= 0.01:
		return
	# Dark halo first, then the light stroke, so it reads on any background.
	_glyph(s, c, k, Color(0, 0, 0, 0.55 * alpha), 4.0)
	_glyph(s, c, k, Color(1, 1, 1, 0.95 * alpha), 2.0)


func _glyph(s: StringName, c: Vector2, k: float, col: Color, w: float) -> void:
	match s:
		&"dot":
			draw_circle(c, 2.0 + w * 0.5 - 1.0, col)
		&"inspect":
			_eye(c, k, col, w)
		&"pickup":
			_hand(c, k, col, w)
		&"use":
			_gear(c, k, col, w)
		&"door":
			_door(c, k, col, w)
		&"talk":
			_speech(c, k, col, w)


func _p(c: Vector2, k: float, x: float, y: float) -> Vector2:
	return c + Vector2(x, y) * k


func _eye(c: Vector2, k: float, col: Color, w: float) -> void:
	draw_arc(c, 17.0 * k, 0.0, TAU, 40, col, w, true)
	var upper: PackedVector2Array = PackedVector2Array()
	var lower: PackedVector2Array = PackedVector2Array()
	for i: int in range(0, 13):
		var x: float = lerpf(-9.0, 9.0, float(i) / 12.0)
		var y: float = 5.5 * (1.0 - (x / 9.0) * (x / 9.0))
		upper.append(_p(c, k, x, -y))
		lower.append(_p(c, k, x, y))
	draw_polyline(upper, col, w, true)
	draw_polyline(lower, col, w, true)
	draw_circle(c, 2.4 * k + (w - 2.0) * 0.4, col)


func _hand(c: Vector2, k: float, col: Color, w: float) -> void:
	# Open hand: palm outline with four fingers and a thumb.
	var palm: PackedVector2Array = PackedVector2Array([
		_p(c, k, -8, 12), _p(c, k, -8, 1), _p(c, k, 8, 1), _p(c, k, 8, 12), _p(c, k, -8, 12)])
	draw_polyline(palm, col, w, true)
	for i: int in range(4):
		var x: float = -6.0 + i * 4.0
		var top: float = -12.0 + (3.0 if i == 0 or i == 3 else 0.0) - (2.0 if i == 1 or i == 2 else 0.0)
		draw_line(_p(c, k, x, 1), _p(c, k, x, top), col, w, true)
	draw_line(_p(c, k, -8, 6), _p(c, k, -14, -2), col, w, true)


func _gear(c: Vector2, k: float, col: Color, w: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var teeth: int = 8
	for i: int in range(teeth * 4 + 1):
		var a: float = TAU * float(i) / float(teeth * 4)
		var tooth: bool = (i % 4) == 1 or (i % 4) == 2
		var r: float = (15.0 if tooth else 11.5) * k
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, col, w, true)
	draw_arc(c, 4.5 * k, 0.0, TAU, 20, col, w, true)


func _door(c: Vector2, k: float, col: Color, w: float) -> void:
	var frame: PackedVector2Array = PackedVector2Array([
		_p(c, k, -9, 16), _p(c, k, -9, -16), _p(c, k, 9, -16), _p(c, k, 9, 16)])
	draw_polyline(frame, col, w, true)
	draw_line(_p(c, k, -13, 16), _p(c, k, 13, 16), col, w, true)
	draw_circle(_p(c, k, 4, 2), 1.8 * k + (w - 2.0) * 0.4, col)


func _speech(c: Vector2, k: float, col: Color, w: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		_p(c, k, -14, -10), _p(c, k, 14, -10), _p(c, k, 14, 7), _p(c, k, 0, 7),
		_p(c, k, -7, 15), _p(c, k, -6, 7), _p(c, k, -14, 7), _p(c, k, -14, -10)])
	draw_polyline(pts, col, w, true)
	for x: float in [-6.0, 0.0, 6.0]:
		draw_circle(_p(c, k, x, -1.5), 1.3 * k + (w - 2.0) * 0.3, col)
