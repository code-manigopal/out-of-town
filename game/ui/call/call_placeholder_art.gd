class_name OOTCallPlaceholderArt
extends Control
## Procedural, clearly marked placeholder for a webcam still: silhouettes on a warm room background with
## "AMMA" / "APPA" text. `who` is "amma", "appa" or "wide" (both). Used to render the *_placeholder.png files
## and as the in-memory fallback when no image file can be loaded.

@export var who: String = "wide":
	set(v):
		who = v
		queue_redraw()

const WALL_TOP: Color = Color(0.78, 0.55, 0.34)
const WALL_BOTTOM: Color = Color(0.55, 0.34, 0.2)
const SIL: Color = Color(0.13, 0.08, 0.07)


func _draw() -> void:
	var s: Vector2 = size
	# warm wall, vertical gradient
	var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)])
	draw_polygon(pts, PackedColorArray([WALL_TOP, WALL_TOP, WALL_BOTTOM, WALL_BOTTOM]))
	# lamp glow, shelf and a framed picture so it reads as a living room
	for i: int in 8:
		draw_circle(Vector2(s.x * 0.86, s.y * 0.22), s.y * (0.34 - i * 0.035), Color(1.0, 0.85, 0.5, 0.07))
	draw_rect(Rect2(s.x * 0.05, s.y * 0.2, s.x * 0.16, s.y * 0.22), Color(0.35, 0.2, 0.12), true)
	draw_rect(Rect2(s.x * 0.06, s.y * 0.21, s.x * 0.14, s.y * 0.2), Color(0.85, 0.7, 0.45), true)
	draw_rect(Rect2(0, s.y * 0.86, s.x, s.y * 0.14), Color(0.3, 0.17, 0.1), true)  # sofa back / furniture
	match who:
		"amma":
			_person(Vector2(s.x * 0.5, s.y * 1.02), s.y * 0.8, true)
		"appa":
			_person(Vector2(s.x * 0.5, s.y * 1.02), s.y * 0.8, false)
		_:
			_person(Vector2(s.x * 0.32, s.y * 1.02), s.y * 0.62, true)
			_person(Vector2(s.x * 0.68, s.y * 1.02), s.y * 0.62, false)
	var label: String = {"amma": "AMMA", "appa": "APPA"}.get(who, "AMMA + APPA")
	var font: Font = ThemeDB.fallback_font
	var fs: int = int(s.y * 0.11)
	var ts: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2((s.x - ts.x) * 0.5, s.y * 0.2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.85, 0.95))
	var note: String = "PLACEHOLDER - replace with %s.png" % {"amma": "amma_close", "appa": "appa_close"}.get(who, "amma_appa_wide")
	var nfs: int = int(s.y * 0.035)
	var ns: Vector2 = font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs)
	draw_string(font, Vector2((s.x - ns.x) * 0.5, s.y * 0.26), note, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(1, 0.9, 0.7, 0.8))


## Head-and-shoulders silhouette; `base` is bottom centre, `h` the total height.
func _person(base: Vector2, h: float, amma: bool) -> void:
	var head_r: float = h * 0.15
	var head_c: Vector2 = base + Vector2(0, -h * 0.62)
	var sh: PackedVector2Array = PackedVector2Array()
	var w: float = h * 0.8
	for i: int in 21:  # shoulders: half ellipse
		var a: float = PI + PI * i / 20.0
		sh.append(base + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.42))
	draw_colored_polygon(sh, SIL)
	draw_rect(Rect2(head_c.x - head_r * 0.35, head_c.y, head_r * 0.7, head_r * 1.5), SIL, true)  # neck
	draw_circle(head_c, head_r, SIL)
	if amma:
		draw_circle(head_c + Vector2(0, -head_r * 1.0), head_r * 0.5, SIL)  # hair bun
	else:
		# shop-shirt collar: two light triangles
		var c: Color = Color(0.82, 0.78, 0.7)
		var n: Vector2 = base + Vector2(0, -h * 0.47)
		draw_colored_polygon(PackedVector2Array([n, n + Vector2(-head_r * 0.7, -head_r * 0.2), n + Vector2(-head_r * 0.1, head_r * 0.9)]), c)
		draw_colored_polygon(PackedVector2Array([n, n + Vector2(head_r * 0.7, -head_r * 0.2), n + Vector2(head_r * 0.1, head_r * 0.9)]), c)
