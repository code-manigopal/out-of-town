class_name OOTDialogueBox
extends Control
## Reusable dialogue presentation: speaker, line, English subtitle under every
## spoken line, and choices. Bind it to a runner with begin(). It walks the
## runner through scenes until it reaches the stop scene (not shown), a scene
## that hands control back to gameplay (puzzle / combat), or the end.
## Click / Enter / Space / Interact advances.

signal opened
signal closed
## Emitted when the box hands control back. scene_id is the scene it stopped at.
signal finished(scene_id: String)

@export var opaque_background: bool = false

var runner: OOTStoryRunner = null
var stop_at: String = ""
var is_open: bool = false

var _line_index: int = 0
var _bg: ColorRect
var _panel: PanelContainer
var _speaker: Label
var _text: RichTextLabel
var _subtitle: Label
var _choices: VBoxContainer
var _hint: Label


func _ready() -> void:
	_build_ui()
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.color = Color.BLACK
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var spacer_col: VBoxContainer = VBoxContainer.new()
	spacer_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(spacer_col)
	var top_spacer: Control = Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_col.add_child(top_spacer)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.06, 0.82)
	sb.set_content_margin_all(18)
	sb.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_col.add_child(_panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	_speaker = Label.new()
	_speaker.name = "Speaker"
	_speaker.add_theme_font_size_override("font_size", 20)
	_speaker.modulate = Color(0.9, 0.75, 0.45)
	box.add_child(_speaker)

	_text = RichTextLabel.new()
	_text.name = "LineText"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 24)
	_text.add_theme_font_size_override("italics_font_size", 24)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_text)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.modulate = Color(1, 1, 1, 0.78)
	box.add_child(_subtitle)

	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override("separation", 6)
	box.add_child(_choices)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.modulate = Color(1, 1, 1, 0.4)
	box.add_child(_hint)


## Binds to a runner and presents its current scene. If stop_scene is entered
## the box closes without showing it.
func begin(p_runner: OOTStoryRunner, stop_scene: String = "") -> void:
	_unbind()
	runner = p_runner
	stop_at = stop_scene
	runner.scene_entered.connect(_on_scene_entered)
	_bg.visible = opaque_background
	if not is_open:
		is_open = true
		visible = true
		opened.emit()
	if runner.scene != null:
		_on_scene_entered(runner.scene)


func _unbind() -> void:
	if runner != null and runner.scene_entered.is_connected(_on_scene_entered):
		runner.scene_entered.disconnect(_on_scene_entered)


func _finish(scene_id: String) -> void:
	_unbind()
	_clear_choices()
	var was_open: bool = is_open
	is_open = false
	visible = false
	if was_open:
		closed.emit()
	finished.emit(scene_id)


func _on_scene_entered(scene: OOTScene) -> void:
	if not stop_at.is_empty() and scene.id == stop_at:
		_finish(scene.id)
		return
	_line_index = 0
	_show_line()


func _show_line() -> void:
	_clear_choices()
	var scene: OOTScene = runner.scene
	if scene.lines.is_empty():
		_speaker.text = ""
		_text.text = ""
		_subtitle.text = ""
		_after_lines()
		return
	var line: OOTDialogueLine = scene.lines[_line_index]
	_speaker.text = _speaker_label(line)
	_text.text = _to_bbcode(line.text)
	_subtitle.text = line.get_subtitle()
	_subtitle.visible = not _subtitle.text.is_empty()
	_hint.text = "Click / Enter to continue"
	if _line_index == scene.lines.size() - 1:
		var opts: Array[OOTChoice] = runner.get_choices()
		if not opts.is_empty():
			_show_choices(opts)


## Called when the last line has been read (or the scene has no lines).
func _after_lines() -> void:
	var scene: OOTScene = runner.scene
	_hint.text = ""
	if scene.is_ending():
		_finish(scene.id)
		return
	var opts: Array[OOTChoice] = runner.get_choices()
	if not opts.is_empty():
		_show_choices(opts)
		return
	if not scene.puzzle.is_empty() or not scene.combat.is_empty():
		_finish(scene.id)
		return
	if runner.get_continue_target().is_empty():
		_finish(scene.id)
		return
	runner.continue_story()


func _show_choices(opts: Array[OOTChoice]) -> void:
	_hint.text = ""
	var first: Button = null
	for choice: OOTChoice in opts:
		var db: Node = OOTServices.db()
		var ok: bool = db.is_choice_available(choice)
		var label: String = choice.label.replace("*", "")
		if not choice.sub_label.is_empty():
			label += "\n    " + choice.sub_label.replace("*", "")
		if not ok:
			label += "\n    Locked: " + db.get_locked_reason(choice)
		var b: Button = Button.new()
		b.text = label
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not ok
		b.pressed.connect(func() -> void: runner.choose(choice))
		_choices.add_child(b)
		if first == null and ok:
			first = b
	if first != null:
		(func() -> void:
			if is_instance_valid(first) and first.is_inside_tree() and visible:
				first.grab_focus()).call_deferred()


func _clear_choices() -> void:
	for c: Node in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


## Advances one step (a line, or past the last line). Public so tests can drive it.
func advance() -> void:
	if not is_open or runner == null or runner.scene == null:
		return
	var scene: OOTScene = runner.scene
	if _line_index < scene.lines.size() - 1:
		_line_index += 1
		_show_line()
	elif _line_index == scene.lines.size() - 1 and _choices.get_child_count() == 0:
		_line_index += 1
		_after_lines()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var go: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		go = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		go = true
	if go:
		advance()
		get_viewport().set_input_as_handled()


func _speaker_label(line: OOTDialogueLine) -> String:
	if line.is_narration:
		return ""
	if line.channel.is_empty():
		return line.speaker
	return "%s (%s)" % [line.speaker, line.channel]


## Prototype markup: *word* is emphasis.
func _to_bbcode(s: String) -> String:
	var escaped: String = s.replace("[", "[lb]")
	var re: RegEx = RegEx.new()
	re.compile("\\*([^*]+)\\*")
	return re.sub(escaped, "[i]$1[/i]", true)
