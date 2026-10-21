class_name OOTPenIcon
extends Control
## Tiny pen glyph used by the "Journal updated" note.


func _init() -> void:
	custom_minimum_size = Vector2(22, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var col: Color = Color(1, 1, 1, 0.9)
	draw_line(Vector2(4, 19), Vector2(17, 5), col, 3.0, true)
	draw_line(Vector2(4, 19), Vector2(3, 21), col, 2.0, true)
	draw_line(Vector2(2, 21), Vector2(9, 21), Color(1, 1, 1, 0.45), 1.5, true)
