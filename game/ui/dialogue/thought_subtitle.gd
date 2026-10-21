class_name OOTThoughtSubtitle
extends Control
## Mani's inner voice: an italic subtitle near the bottom of the screen with no speaker name and no frame, spoken over
## the VO bus in his close, clean voice (no radio or phone filter). Lines are story data, channel "THOUGHT"
## (e.g. scene e1_thought_pack1). The HUD owns one (OOTHud.show_thought); the dialogue box uses the same style for
## THOUGHT lines it meets in a scene.

signal started(line_id: String)
signal finished(line_id: String)

const CHANNEL: String = "THOUGHT"
const TAIL_SECONDS: float = 0.9
const SILENT_SECONDS: float = 3.5

var is_showing: bool = false
var line_id: String = ""
var text_shown: String = ""
var subtitle_shown: String = ""

var _text: Label
var _sub: Label
var _player: AudioStreamPlayer
var _tween: Tween
var _token: int = 0


static func is_thought(line: OOTDialogueLine) -> bool:
	return line != null and line.channel.to_upper() == CHANNEL


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = -480.0
	col.offset_right = 480.0
	col.offset_top = -190.0
	col.offset_bottom = -96.0
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	_text = _make_label(26, 0.96)
	_text.name = "Text"
	col.add_child(_text)
	_sub = _make_label(20, 0.72)
	_sub.name = "Subtitle"
	col.add_child(_sub)
	_player = AudioStreamPlayer.new()
	_player.name = "ThoughtVoice"
	_player.bus = OOTVoiceLines.VO_BUS
	add_child(_player)
	modulate.a = 0.0
	visible = false


func _make_label(size_px: int, alpha: float) -> Label:
	var l: Label = Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", OOTUiStyle.italic_font(400))
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color(1, 1, 1, alpha))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 7)
	return l


## Speaks and shows line `order` of a story scene (scene ids and order as in data/story). False if the line is missing.
func play(scene_id: String, order: int = 0, part_id: String = "p1") -> bool:
	var db: Node = OOTServices.db()
	if db == null:
		return false
	var scene: OOTScene = db.get_scene(part_id, scene_id)
	if scene == null or order < 0 or order >= scene.lines.size():
		return false
	var line: OOTDialogueLine = scene.lines[order]
	line_id = OOTVoiceLines.make_id(scene_id, order)
	text_shown = line.text
	subtitle_shown = line.get_subtitle()
	_text.text = text_shown
	_sub.text = subtitle_shown if subtitle_shown != text_shown else ""
	_sub.visible = not _sub.text.is_empty()
	var stream: AudioStream = OOTVoiceLines.get_stream(line_id, part_id)
	var hold: float = SILENT_SECONDS
	_player.stop()
	if stream != null:
		_player.stream = stream
		_player.play()
		hold = stream.get_length() + TAIL_SECONDS
	_token += 1
	var mine: int = _token
	is_showing = true
	visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.35)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, 0.7)
	_tween.tween_callback(func() -> void: _end(mine))
	started.emit(line_id)
	return true


func _end(token: int) -> void:
	if token != _token:
		return
	is_showing = false
	visible = false
	finished.emit(line_id)


func hide_now() -> void:
	_token += 1
	if _tween != null:
		_tween.kill()
	_player.stop()
	is_showing = false
	visible = false
	modulate.a = 0.0
