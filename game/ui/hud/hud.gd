class_name OOTHud
extends Control
## In-world HUD: interaction prompt dot, packing counter, carried item, toast
## and the ringing banner. Pure presentation; the apartment drives it.

var _prompt: Label
var _packed: Label
var _carried: Label
var _toast: Label
var _ring: Label
var _toast_left: float = 0.0
var _ringing: bool = false
var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt = _label(Vector2(0, 560), 22, HORIZONTAL_ALIGNMENT_CENTER)
	_packed = _label(Vector2(24, 20), 22, HORIZONTAL_ALIGNMENT_LEFT)
	_packed.text = "Packed 0/3"
	_carried = _label(Vector2(24, 52), 18, HORIZONTAL_ALIGNMENT_LEFT)
	_toast = _label(Vector2(0, 100), 22, HORIZONTAL_ALIGNMENT_CENTER)
	_ring = _label(Vector2(0, 150), 30, HORIZONTAL_ALIGNMENT_CENTER)
	_ring.visible = false
	var dot: ColorRect = ColorRect.new()
	dot.name = "CenterDot"
	dot.color = Color(1, 1, 1, 0.5)
	dot.size = Vector2(4, 4)
	dot.position = Vector2(638, 358)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)


func _label(pos: Vector2, font_size: int, align: HorizontalAlignment) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = Vector2(1280, 30)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func set_prompt(text: String) -> void:
	_prompt.text = "" if text.is_empty() else "•  [E] %s" % text


func set_packed(count: int, total: int) -> void:
	_packed.text = "Packed %d/%d" % [count, total]


func set_carried(item_name: String) -> void:
	_carried.text = "" if item_name.is_empty() else "Carrying: %s" % item_name


func show_toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast_left = seconds


func set_ringing(on: bool) -> void:
	_ringing = on
	_ring.visible = on
	_ring.text = "Your laptop is ringing"


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""
	if _ringing:
		_t += delta
		_ring.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 6.0))
