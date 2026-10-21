class_name OOTPhoneLockScreen
extends Control
## The cold open: Mani's phone lock screen on black, showing the voicemail notification ("Voicemail", Nila, the day
## and time from the scene data) with a waveform that moves while the VO plays. The dialogue box runs on top of it for
## the subtitles. Bind the box's VoicePlayer with bind_voice().

const BODY: Vector2 = Vector2(240, 430)

var body: OOTPhoneBody
var wave: OOTWaveform
var title_text: String = "Voicemail"
var who_text: String = ""
var when_text: String = ""

var _voice: AudioStreamPlayer = null
var _line_count: int = 1
var _line_index: int = 0
var _status: Label
var _clock: Label
var _day: Label
var _who: Label
var _when: Label
var _glow: ColorRect


## scene = the cold-open scene (e1_open): its `time` ("Sunday 23:52") and the first spoken line's speaker feed the card.
func setup(scene: OOTScene) -> void:
	if scene == null:
		return
	when_text = scene.time
	for l: OOTDialogueLine in scene.lines:
		if not l.is_narration and not l.speaker.is_empty():
			who_text = l.speaker.capitalize()
			break
	_line_count = 0
	for l2: OOTDialogueLine in scene.lines:
		if not l2.is_narration:
			_line_count += 1
	_line_count = maxi(_line_count, 1)
	if is_inside_tree():
		_apply_text()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: ColorRect = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	body = OOTPhoneBody.make(BODY)
	body.name = "Body"
	# Sits in the upper part of the screen so the dialogue box (subtitles) has room below.
	body.anchor_left = 0.5
	body.anchor_right = 0.5
	body.anchor_top = 0.0
	body.anchor_bottom = 0.0
	body.offset_left = -BODY.x * 0.5
	body.offset_right = BODY.x * 0.5
	body.offset_top = 24.0
	body.offset_bottom = 24.0 + BODY.y
	body.rotation = deg_to_rad(-2.5)
	add_child(body)

	var scr: Vector2 = body.screen_size()
	var wall: ColorRect = ColorRect.new()
	wall.size = scr
	wall.color = Color(0.05, 0.07, 0.1)
	body.add_to_screen(wall)
	_glow = ColorRect.new()
	_glow.size = Vector2(scr.x, scr.y * 0.6)
	_glow.color = Color(0.1, 0.2, 0.24, 0.5)
	body.add_to_screen(_glow)

	_status = OOTUiStyle.label("", 12, OOTUiStyle.TEXT_DIM, 600)
	_status.position = Vector2(0, 42)
	_status.size = Vector2(scr.x, 16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_to_screen(_status)
	_clock = OOTUiStyle.label("", 58, OOTUiStyle.TEXT, 300)
	_clock.position = Vector2(0, 58)
	_clock.size = Vector2(scr.x, 70)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_to_screen(_clock)
	_day = OOTUiStyle.label("", 14, OOTUiStyle.TEXT_DIM, 500)
	_day.position = Vector2(0, 126)
	_day.size = Vector2(scr.x, 20)
	_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_to_screen(_day)

	# Notification card.
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	card.position = Vector2(12, 190)
	card.size = Vector2(scr.x - 24.0, 150)
	card.add_theme_stylebox_override("panel", OOTUiStyle.box(Color(0.14, 0.16, 0.2, 0.92), 18, 12))
	body.add_to_screen(card)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	vb.add_child(head)
	head.add_child(OOTIcons.rect("voicemail", 16, OOTUiStyle.ACCENT))
	var app: Label = OOTUiStyle.label(title_text.to_upper(), 11, OOTUiStyle.ACCENT, 700)
	app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(app)
	_when = OOTUiStyle.label("", 11, OOTUiStyle.TEXT_DIM)
	head.add_child(_when)
	_who = OOTUiStyle.label("", 18, OOTUiStyle.TEXT, 700)
	vb.add_child(_who)
	wave = OOTWaveform.new()
	wave.bar_count = 34
	wave.custom_minimum_size = Vector2(0, 52)
	vb.add_child(wave)
	var hint: Label = OOTUiStyle.label("New voicemail", 12, OOTUiStyle.TEXT_DIM)
	vb.add_child(hint)

	var pill: Panel = Panel.new()
	pill.add_theme_stylebox_override("panel", OOTUiStyle.box(Color(1, 1, 1, 0.5), 3))
	pill.size = Vector2(100, 5)
	pill.position = Vector2((scr.x - 100.0) * 0.5, scr.y - 14.0)
	body.add_to_screen(pill)
	_apply_text()


func _apply_text() -> void:
	if _who == null:
		return
	var parts: PackedStringArray = when_text.split(" ")
	_clock.text = parts[parts.size() - 1] if parts.size() > 0 and not when_text.is_empty() else "23:52"
	_day.text = parts[0] if parts.size() > 1 else ""
	_status.text = "Locked"
	_who.text = who_text
	_when.text = when_text


## The box's VO player drives the waveform: it moves while a line plays and the playhead advances across the lines.
func bind_voice(player: AudioStreamPlayer) -> void:
	_voice = player
	if player != null and not player.finished.is_connected(_on_line_finished):
		player.finished.connect(_on_line_finished)


## Call when a line is shown (the box's voice_requested): advances the playhead.
func line_started(line_id: String, has_audio: bool) -> void:
	if line_id.is_empty():
		return
	var tail: String = line_id.substr(line_id.rfind("_") + 1)
	_line_index = clampi(int(tail) - 1, 0, _line_count - 1)
	wave.set_active(has_audio)


func _on_line_finished() -> void:
	wave.set_active(false)


func _process(_delta: float) -> void:
	if _voice != null and is_instance_valid(_voice) and _voice.playing and _voice.stream != null:
		var len_s: float = maxf(_voice.stream.get_length(), 0.01)
		wave.set_active(true)
		wave.set_progress((float(_line_index) + clampf(_voice.get_playback_position() / len_s, 0.0, 1.0)) / float(_line_count))
