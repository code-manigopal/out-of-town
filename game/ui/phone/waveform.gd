class_name OOTWaveform
extends Control
## Voicemail waveform: vertical bars of a fixed pseudo-random shape. `progress` (0..1) lights the played part;
## `active` makes the bars breathe while audio plays.

@export var bar_count: int = 44
@export var seed_value: int = 52
var progress: float = 0.0
var active: bool = false
var played_color: Color = OOTUiStyle.ACCENT
var rest_color: Color = Color(1, 1, 1, 0.28)

var _shape: PackedFloat32Array = PackedFloat32Array()
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in range(bar_count):
		var env: float = 0.45 + 0.55 * sin(PI * (float(i) + 0.5) / float(bar_count))
		_shape.append(clampf(rng.randf_range(0.18, 1.0) * env, 0.12, 1.0))


func _process(delta: float) -> void:
	if active:
		_t += delta
		queue_redraw()


func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	queue_redraw()


func set_active(on: bool) -> void:
	active = on
	queue_redraw()


func _draw() -> void:
	if _shape.is_empty():
		return
	var n: int = _shape.size()
	var step: float = size.x / float(n)
	var w: float = maxf(step * 0.55, 1.5)
	for i: int in range(n):
		var h: float = _shape[i]
		if active:
			h *= 0.72 + 0.28 * sin(_t * 9.0 + float(i) * 0.7)
		var bh: float = maxf(size.y * h, 3.0)
		var x: float = step * float(i) + (step - w) * 0.5
		var col: Color = played_color if float(i) / float(n) < progress else rest_color
		draw_rect(Rect2(x, (size.y - bh) * 0.5, w, bh), col)
