class_name OOTObjectiveToast
extends Control
## A small toast in the top-left corner when the objective changes: fades in, holds about four seconds, fades out
## smoothly. The objective stays readable later in the phone's Objectives app (P). Source of truth: StoryState
## objective_started (journal goal entries become objectives, see OOTJournalData.grant).

const HOLD_SECONDS: float = 4.0
const FADE_IN: float = 0.5
const FADE_OUT: float = 1.1
const SIZE_BOX: Vector2 = Vector2(360, 0)

var title_text: String = ""
var body_text: String = ""
var is_showing: bool = false

var _panel: PanelContainer
var _title: Label
var _body: Label
var _tween: Tween
var _slide: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(24, 24)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = OOTUiStyle.box(Color(0.06, 0.08, 0.1, 0.84), 10, 0)
	sb.border_color = OOTUiStyle.ACCENT
	sb.border_width_left = 4
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = SIZE_BOX
	add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	col.add_child(OOTUiStyle.label("OBJECTIVE", 11, OOTUiStyle.ACCENT, 700))
	_title = OOTUiStyle.label("", 18, OOTUiStyle.TEXT, 700)
	col.add_child(_title)
	_body = OOTUiStyle.label("", 14, Color(1, 1, 1, 0.78))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 320
	col.add_child(_body)
	modulate.a = 0.0
	visible = false
	var st: Node = OOTServices.state()
	if st != null:
		st.objective_started.connect(show_objective)


## Shows the toast for an objective id (a journal goal entry).
func show_objective(objective_id: String) -> void:
	var e: Dictionary = OOTJournalData.get_entry(objective_id)
	var title: String = str(e.get("title", objective_id))
	var action: String = str(e.get("key_action", ""))
	if not action.is_empty():
		title = "%s [%s]" % [title, OOTHints.key_name(action)]   # "Check the Phone [P]": the key comes from the input map
	show_text(title, str(e.get("toast_text", e.get("text", ""))))


func show_text(title: String, body: String) -> void:
	title_text = title
	body_text = body
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	_panel.reset_size()
	if _tween != null:
		_tween.kill()
	is_showing = true
	visible = true
	modulate.a = 0.0
	position = Vector2(12, 24)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		is_showing = false
		visible = false)
	if _slide != null:
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(self, "position:x", 24.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
