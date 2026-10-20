extends Control
## Minimal dialogue player: Part 1 Episode 1. Shows speaker, line and an English
## subtitle; click / Enter / Space advances; choices appear as buttons.

const PART_ID: String = "p1"
const EPISODE: int = 1

var _runner: OOTStoryRunner = OOTStoryRunner.new()
var _line_index: int = 0
var _timer_left: float = 0.0

var _header: Label
var _speaker: Label
var _text: RichTextLabel
var _subtitle: Label
var _hint: Label
var _choices: VBoxContainer
var _timer_bar: ProgressBar


func _ready() -> void:
	_build_ui()
	_runner.scene_entered.connect(_on_scene_entered)
	_runner.story_ended.connect(_on_story_ended)
	_runner.start(PART_ID, EPISODE)


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.06, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Column"
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	_header = Label.new()
	_header.name = "Header"
	_header.modulate = Color(1, 1, 1, 0.55)
	box.add_child(_header)

	_speaker = Label.new()
	_speaker.name = "Speaker"
	_speaker.add_theme_font_size_override("font_size", 22)
	_speaker.modulate = Color(0.85, 0.7, 0.45)
	box.add_child(_speaker)

	_text = RichTextLabel.new()
	_text.name = "LineText"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 26)
	_text.add_theme_font_size_override("italics_font_size", 26)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_text)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_subtitle)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)

	_timer_bar = ProgressBar.new()
	_timer_bar.name = "TimerBar"
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 8)
	_timer_bar.visible = false
	box.add_child(_timer_bar)

	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override("separation", 8)
	box.add_child(_choices)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.modulate = Color(1, 1, 1, 0.4)
	box.add_child(_hint)


func _on_scene_entered(scene: OOTScene) -> void:
	_line_index = 0
	_timer_left = 0.0
	_timer_bar.visible = false
	_header.text = "Part 1 - Ep %d - %s  |  %s  |  %s   (danger %d, trust: %s)" % [
		scene.episode, scene.id, scene.place, scene.time,
		StoryState.get_danger(), str(StoryState.trust)]
	_show_line()


func _show_line() -> void:
	_clear_choices()
	var scene: OOTScene = _runner.scene
	if _line_index < scene.lines.size():
		var line: OOTDialogueLine = scene.lines[_line_index]
		_speaker.text = _speaker_label(line)
		_text.text = _to_bbcode(line.text)
		_subtitle.text = line.get_subtitle()
		_hint.text = "Click / Enter to continue"
	else:
		_show_options()


func _show_options() -> void:
	var scene: OOTScene = _runner.scene
	if scene.lines.is_empty():
		_speaker.text = ""
		_text.text = ""
		_subtitle.text = ""
	_hint.text = ""
	if scene.is_ending():
		_speaker.text = "THE END"
		_text.text = _to_bbcode("Ending: %s" % scene.ending)
		_subtitle.text = ""
		_add_button("Restart", func() -> void: _runner.start(PART_ID, EPISODE))
		return
	var choices: Array[OOTChoice] = _runner.get_choices()
	if choices.is_empty():
		var target: String = _runner.get_continue_target()
		var caption: String = "Continue"
		if not scene.puzzle.is_empty():
			caption = "Puzzle skipped: %s - Continue" % str(scene.puzzle.get("title", ""))
		elif not scene.combat.is_empty():
			caption = "Combat skipped - Continue"
		elif scene.is_episode_end:
			caption = "End of episode %d - Continue" % scene.episode
		if target.is_empty():
			_add_button("Restart", func() -> void: _runner.start(PART_ID, EPISODE))
		else:
			_add_button(caption, func() -> void: _runner.continue_story())
		return
	for choice: OOTChoice in choices:
		var ok: bool = StoryDB.is_choice_available(choice)
		var label: String = _to_plain(choice.label)
		if not choice.sub_label.is_empty():
			label += "\n    " + _to_plain(choice.sub_label)
		if not ok:
			label += "\n    Locked: " + StoryDB.get_locked_reason(choice)
		var b: Button = _add_button(label, func() -> void: _runner.choose(choice))
		b.disabled = not ok
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if scene.timer_seconds > 0.0 and not scene.timer_target.is_empty():
		_timer_left = scene.timer_seconds
		_timer_bar.max_value = scene.timer_seconds
		_timer_bar.value = scene.timer_seconds
		_timer_bar.visible = true


func _add_button(label: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_press)
	_choices.add_child(b)
	return b


func _clear_choices() -> void:
	for c: Node in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func _on_story_ended(_ending: String) -> void:
	pass


func _process(delta: float) -> void:
	if _timer_left > 0.0:
		_timer_left -= delta
		_timer_bar.value = maxf(_timer_left, 0.0)
		if _timer_left <= 0.0:
			_runner.time_out()


func _unhandled_input(event: InputEvent) -> void:
	var advance: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		advance = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event.is_action_pressed("ui_accept"):
		advance = true
	if not advance:
		return
	var scene: OOTScene = _runner.scene
	if scene != null and _line_index < scene.lines.size():
		_line_index += 1
		_show_line()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and _choices.get_child_count() == 1:
		var only: Button = _choices.get_child(0)
		if not only.disabled:
			only.pressed.emit()
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


func _to_plain(s: String) -> String:
	return s.replace("*", "")
