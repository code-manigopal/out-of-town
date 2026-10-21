class_name OOTPhone
extends Control
## Mani's own phone (P, action "phone"). It slides up to screen focus as a 3D-looking frame drawn in UI and locks
## player input; the world keeps running. Apps: Objectives (current and completed), Messages (threads with bubbles,
## timestamps, read state, Tanglish with the English subtitle under each bubble), Photos, Calls (including Nila's Sunday
## voicemail, which plays its existing VO when opened). Content: data/phone/p1_phone.json (OOTPhoneData).
##
## API:
##   OOTPhone.notify_message("tess", "tess_2")   a message arrives: banner + vibrate (StoryState.phone_deliver)
##   OOTPhone.instance()                         the phone in the tree (the HUD creates it), or null
##   phone.open() / close() / toggle() / go("messages") / go("thread", "nila") / back()
## Navigation: mouse, keys (arrows / Enter, Backspace = back) and gamepad (D-pad, A, B = back). Esc or P closes.

signal opened
signal closed
signal page_changed(page_name: String)
signal banner_shown(thread_id: String, message_id: String)

const BODY_SIZE: Vector2 = Vector2(330, 650)
const SCREEN_MARGIN: float = 16.0
const BANNER_SECONDS: float = 4.0
const SFX_OPEN: String = "res://audio/sfx/kenney/interface/maximize_003.ogg"
const SFX_CLOSE: String = "res://audio/sfx/kenney/interface/minimize_003.ogg"
const SFX_CLICK: String = "res://audio/sfx/kenney/interface/click_003.ogg"
const WEEKDAYS: Dictionary = {
	"Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday", "Fri": "Friday", "Sat": "Saturday",
	"Sun": "Sunday",
}
const APPS: Array = [
	{"page": "calls", "label": "Calls", "icon": "phone", "color": Color(0.3, 0.7, 0.4)},
	{"page": "messages", "label": "Messages", "icon": "messages-square", "color": Color(0.27, 0.5, 0.86)},
	{"page": "objectives", "label": "Objectives", "icon": "list-checks", "color": Color(0.2, 0.62, 0.6)},
	{"page": "photos", "label": "Photos", "icon": "image", "color": Color(0.86, 0.55, 0.22)},
]

static var _vibrate: AudioStreamWAV = null

var is_open: bool = false
## Tests switch the slide animation off.
var animate: bool = true
var page: String = "home"
var page_arg: String = ""
## Voicemail state (calls app).
var vm_playing: bool = false
var vm_index: int = 0

var _stack: Array[Array] = []
var _root: Control
var _dim: ColorRect
var _body: OOTPhoneBody
var _status_time: Label
var _content: Control
var _page_node: Control = null
var _scroll: ScrollContainer = null
var _banner: PanelContainer
var _banner_name: Label
var _banner_text: Label
var _banner_sub: Label
var _banner_avatar: Control
var _banner_tween: Tween
var _slide_tween: Tween
var _sfx: AudioStreamPlayer
var _vib_player: AudioStreamPlayer
var _vm_player: AudioStreamPlayer
var _vm_lines: Array[String] = []
var _vm_wave: OOTWaveform = null
var _vm_button: Button = null
var _vm_line_labels: Array[Control] = []
var _locked_players: Array[Node] = []
var _prev_mouse: int = Input.MOUSE_MODE_VISIBLE
var _photo_index: int = 0


static func instance() -> OOTPhone:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var found: Array[Node] = tree.get_nodes_in_group("oot_phone")
	return found[0] as OOTPhone if not found.is_empty() else null


## A message arrives on Mani's phone. Shows the banner and vibrates when the phone is closed. The message must exist in
## data/phone/*.json and belong to `thread_id`. False if it had already been delivered or is unknown.
static func notify_message(thread_id: String, message_id: String) -> bool:
	var st: Node = OOTServices.state()
	var m: Dictionary = OOTPhoneData.message(message_id)
	if st == null or m.is_empty() or str(m.get("thread", "")) != thread_id:
		push_warning("OOTPhone.notify_message: unknown message '%s' for thread '%s'" % [message_id, thread_id])
		return false
	return st.phone_deliver(message_id)   # the phone (if any) reacts to StoryState.phone_message_delivered


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("oot_phone")
	add_to_group("oot_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"UI"
	_sfx.volume_db = -6.0
	add_child(_sfx)
	_vib_player = AudioStreamPlayer.new()
	_vib_player.bus = &"UI"
	_vib_player.volume_db = -3.0
	_vib_player.stream = vibrate_stream()
	add_child(_vib_player)
	_vm_player = AudioStreamPlayer.new()
	_vm_player.bus = OOTVoiceLines.VO_BUS
	_vm_player.finished.connect(_on_vm_line_finished)
	add_child(_vm_player)
	var st: Node = OOTServices.state()
	if st != null:
		st.phone_message_delivered.connect(_on_delivered)
		st.objective_started.connect(_on_objective_changed)
		st.objective_finished.connect(_on_objective_changed)
	_root.visible = false


# --- Building the frame ---------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_input)
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.015, 0.03, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	_body = OOTPhoneBody.make(BODY_SIZE)
	_body.name = "Body"
	_root.add_child(_body)

	var scr: Vector2 = _body.screen_size()
	var status: Control = Control.new()
	status.name = "StatusBar"
	status.size = Vector2(scr.x, 34)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_to_screen(status)
	_status_time = OOTUiStyle.label("9:41", 14, OOTUiStyle.TEXT, 600)
	_status_time.position = Vector2(24, 8)
	status.add_child(_status_time)
	var x: float = scr.x - 22.0
	for ic: String in ["battery-full", "wifi", "signal"]:
		var r: TextureRect = OOTIcons.rect(ic, 16, OOTUiStyle.TEXT)
		x -= 16.0
		r.position = Vector2(x, 9)
		status.add_child(r)
		x -= 5.0

	_content = Control.new()
	_content.name = "Content"
	_content.position = Vector2(0, 34)
	_content.size = Vector2(scr.x, scr.y - 34.0 - 24.0)
	_content.clip_contents = true
	_body.add_to_screen(_content)

	var home_bar: Button = Button.new()
	home_bar.name = "HomeBar"
	home_bar.flat = true
	home_bar.focus_mode = Control.FOCUS_NONE
	home_bar.position = Vector2(0, scr.y - 24.0)
	home_bar.size = Vector2(scr.x, 24)
	home_bar.pressed.connect(func() -> void: go("home"))
	_body.add_to_screen(home_bar)
	var pill: Panel = Panel.new()
	pill.add_theme_stylebox_override("panel", OOTUiStyle.box(Color(1, 1, 1, 0.55), 3))
	pill.size = Vector2(110, 5)
	pill.position = Vector2((scr.x - 110.0) * 0.5, 12)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_bar.add_child(pill)
	_build_banner()


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.name = "Banner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override("panel", OOTUiStyle.box(Color(0.09, 0.1, 0.13, 0.94), 18, 12))
	_banner.custom_minimum_size = Vector2(380, 0)
	_banner.visible = false
	add_child(_banner)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(row)
	_banner_avatar = Control.new()
	_banner_avatar.custom_minimum_size = Vector2(42, 42)
	_banner_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_banner_avatar)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_banner_name = OOTUiStyle.label("", 15, OOTUiStyle.TEXT, 700)
	_banner_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_banner_name)
	head.add_child(OOTUiStyle.label("Messages  now", 12, OOTUiStyle.TEXT_DIM))
	_banner_text = OOTUiStyle.label("", 15, OOTUiStyle.TEXT)
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.custom_minimum_size.x = 280
	col.add_child(_banner_text)
	_banner_sub = OOTUiStyle.label("", 13, OOTUiStyle.TEXT_DIM)
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_sub.custom_minimum_size.x = 280
	col.add_child(_banner_sub)
	col.add_child(OOTUiStyle.label("%s to read" % key_name(), 11, OOTUiStyle.ACCENT, 600))


## "P" for the phone action's keyboard binding.
static func key_name() -> String:
	if InputMap.has_action("phone"):
		for e: InputEvent in InputMap.action_get_events("phone"):
			if e is InputEventKey:
				return OS.get_keycode_string((e as InputEventKey).physical_keycode)
	return "P"


static func vibrate_stream() -> AudioStreamWAV:
	if _vibrate != null:
		return _vibrate
	var rate: int = 22050
	var n: int = int(rate * 0.62)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var pulses: Array = [[0.0, 0.22], [0.31, 0.53]]
	for i: int in range(n):
		var t: float = float(i) / float(rate)
		var v: float = 0.0
		for p: Array in pulses:
			if t >= float(p[0]) and t < float(p[1]):
				var lt: float = t - float(p[0])
				var dur: float = float(p[1]) - float(p[0])
				var env: float = minf(lt / 0.012, 1.0) * minf((dur - lt) / 0.045, 1.0)
				var buzz: float = sin(TAU * 168.0 * t) + 0.45 * sin(TAU * 336.0 * t) + 0.3 * sin(TAU * 84.0 * t)
				v = buzz * env * 0.5 * (0.82 + 0.18 * sin(TAU * 31.0 * t))
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	_vibrate = w
	return w


# --- Open / close -------------------------------------------------------------------

## The area the phone lays out in (its own full-rect size, else the viewport).
func _screen_size() -> Vector2:
	return size if size.x > 200.0 and size.y > 200.0 else get_viewport_rect().size


func _rest_position() -> Vector2:
	return _screen_size() * 0.5 - BODY_SIZE * 0.5


func _fit_scale() -> float:
	return clampf(_screen_size().y / 740.0, 0.7, 1.6)


func _other_modal_open() -> bool:
	for n: Node in get_tree().get_nodes_in_group("oot_modal"):
		if n != self and bool(n.get("is_open")):
			return true
	for n: Node in get_tree().get_nodes_in_group("oot_journal"):
		if bool(n.get("is_open")):
			return true
	return false


func can_open() -> bool:
	return not is_open and not _other_modal_open()


func toggle() -> void:
	if is_open:
		close()
	elif can_open():
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_hide_banner()
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_locked_players.clear()
	for n: Node in get_tree().root.find_children("*", "OOTPlayer", true, false):
		(n as OOTPlayer).lock_input()   # pauses player input, not the world
		_locked_players.append(n)
	_stack.clear()
	_root.visible = true
	_body.scale = Vector2.ONE * _fit_scale()
	_refresh_clock()
	_show_page("home", "")
	_play(SFX_OPEN)
	var rest: Vector2 = _rest_position()
	if _slide_tween != null:
		_slide_tween.kill()
	if animate:
		var vp_h: float = _screen_size().y
		_body.position = Vector2(rest.x, rest.y + vp_h * 0.85)
		_body.rotation = deg_to_rad(7.0)
		_dim.modulate.a = 0.0
		_slide_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(_body, "position", rest, 0.42)
		_slide_tween.tween_property(_body, "rotation", 0.0, 0.42)
		_slide_tween.tween_property(_dim, "modulate:a", 1.0, 0.3)
	else:
		_body.position = rest
		_body.rotation = 0.0
		_dim.modulate.a = 1.0
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_vm_stop()
	_stack.clear()
	for p: Node in _locked_players:
		if is_instance_valid(p):
			(p as OOTPlayer).unlock_input()
	if _locked_players.is_empty():
		Input.mouse_mode = _prev_mouse as Input.MouseMode
	_locked_players.clear()
	_play(SFX_CLOSE)
	if _slide_tween != null:
		_slide_tween.kill()
	if animate and is_inside_tree():
		var vp_h: float = _screen_size().y
		_slide_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_slide_tween.tween_property(_body, "position:y", _rest_position().y + vp_h * 0.85, 0.28)
		_slide_tween.tween_property(_body, "rotation", deg_to_rad(5.0), 0.28)
		_slide_tween.tween_property(_dim, "modulate:a", 0.0, 0.22)
		_slide_tween.chain().tween_callback(func() -> void:
			if not is_open:
				_root.visible = false)
	else:
		_root.visible = false
	closed.emit()


func _play(path: String) -> void:
	if _sfx != null and ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.play()


func _story_time() -> String:
	var st: Node = OOTServices.state()
	var db: Node = OOTServices.db()
	if st == null or db == null or str(st.scene).is_empty():
		return ""
	var sc: OOTScene = db.get_scene(str(st.get_part()), str(st.scene))
	return sc.time if sc != null else ""


func _refresh_clock() -> void:
	var t: String = _story_time()
	_status_time.text = OOTPhoneData.clock_of(t) if not t.is_empty() else "9:41"


# --- Navigation ---------------------------------------------------------------------

## Opens a page: "home", "objectives", "messages", "thread" (arg = thread id), "photos", "photo" (arg = photo index),
## "calls", "call" (arg = call id).
func go(page_name: String, arg: String = "") -> void:
	if page_name == "home":
		_stack.clear()
	elif not page.is_empty() and not (page == page_name and page_arg == arg):
		_stack.append([page, page_arg])
	_show_page(page_name, arg)


func back() -> void:
	if _stack.is_empty():
		if page != "home":
			_show_page("home", "")
		return
	var prev: Array = _stack.pop_back()
	_show_page(str(prev[0]), str(prev[1]))


func _show_page(page_name: String, arg: String) -> void:
	_vm_stop()
	page = page_name
	page_arg = arg
	_scroll = null
	if _page_node != null:
		_content.remove_child(_page_node)
		_page_node.queue_free()
		_page_node = null
	match page_name:
		"objectives":
			_page_node = _build_objectives()
		"messages":
			_page_node = _build_messages()
		"thread":
			_page_node = _build_thread(arg)
		"photos":
			_page_node = _build_photos()
		"photo":
			_page_node = _build_photo(int(arg))
		"calls":
			_page_node = _build_calls()
		"call":
			_page_node = _build_call(arg)
		_:
			page = "home"
			_page_node = _build_home()
	_page_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(_page_node)
	if animate and is_open:
		_page_node.modulate.a = 0.0
		create_tween().tween_property(_page_node, "modulate:a", 1.0, 0.14)
	_focus_first.call_deferred()
	page_changed.emit(page)


func _focus_first() -> void:
	if not is_open or _page_node == null:
		return
	for b: Node in _page_node.find_children("*", "Button", true, false):
		if (b as Button).focus_mode == Control.FOCUS_ALL and (b as Button).is_visible_in_tree():
			(b as Button).grab_focus()
			return


func _on_root_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		var r: Rect2 = Rect2(_body.position, BODY_SIZE).grow(8.0)
		if not r.has_point(p):
			close()


func _input(event: InputEvent) -> void:
	if not InputMap.has_action("phone"):
		return
	if event.is_action_pressed("phone", false, true):
		if is_open:
			close()
		elif can_open():
			open()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).physical_keycode == KEY_BACKSPACE) \
			or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		back()
		get_viewport().set_input_as_handled()
	elif page == "photo" and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		_step_photo(-1 if event.is_action_pressed("ui_left") else 1)
		get_viewport().set_input_as_handled()
	elif _scroll != null and get_viewport().gui_get_focus_owner() == null \
			and (event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true)):
		_scroll.scroll_vertical += -70 if event.is_action_pressed("ui_up", true) else 70
		get_viewport().set_input_as_handled()


# --- Building blocks -------------------------------------------------------------------

func _page_shell(title: String, with_back: bool = true) -> Array:
	var page_root: Control = Control.new()
	var vb: VBoxContainer = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	page_root.add_child(vb)
	var head: HBoxContainer = HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 44)
	head.add_theme_constant_override("separation", 4)
	vb.add_child(head)
	head.add_child(_margin_spacer(8))
	if with_back:
		head.add_child(_back_button())
	else:
		head.add_child(_margin_spacer(8))
	var t: Label = OOTUiStyle.label(title, 21, OOTUiStyle.TEXT, 700)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(t)
	return [page_root, vb, head]


func _margin_spacer(w: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _back_button() -> Button:
	var b: Button = Button.new()
	b.icon = OOTIcons.get_icon("chevron-left", 22)
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = "Back"
	b.pressed.connect(func() -> void:
		_play(SFX_CLICK)
		back())
	return b


## A flat full-width Button that can hold an HBox of children (cards, rows).
func _row_button(min_height: float = 56.0) -> Array:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(0, min_height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 10)
	for side: String in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	b.add_child(m)
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	return [b, h]


func _scroll_list() -> Array:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad: MarginContainer = MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	sc.add_child(pad)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	pad.add_child(list)
	_scroll = sc
	return [sc, list]


func _avatar(thread_id: String, px: int) -> Control:
	var th: Dictionary = OOTPhoneData.thread(thread_id)
	return _avatar_for(str(th.get("name", "?")), Color.html(str(th.get("color", "#6688aa"))), px)


func _avatar_for(person: String, color: Color, px: int) -> Control:
	var a: Panel = Panel.new()
	a.custom_minimum_size = Vector2(px, px)
	a.add_theme_stylebox_override("panel", OOTUiStyle.box(color, px / 2))
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = OOTUiStyle.label(person.substr(0, 1).to_upper(), int(px * 0.46), Color.WHITE, 700)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a.add_child(l)
	return a


func _section_label(text: String) -> Label:
	var l: Label = OOTUiStyle.label(text.to_upper(), 11, OOTUiStyle.TEXT_DIM, 700)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _empty_note(text: String) -> Label:
	var l: Label = OOTUiStyle.label(text, 14, OOTUiStyle.TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(240, 0)
	return l


func _badge(n: int) -> Control:
	var p: Panel = Panel.new()
	p.custom_minimum_size = Vector2(22, 22)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", OOTUiStyle.box(OOTUiStyle.ALERT, 11))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = OOTUiStyle.label(str(n), 12, Color.WHITE, 700)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


# --- Home --------------------------------------------------------------------------------

func _build_home() -> Control:
	var root: Control = Control.new()
	var wall: TextureRect = TextureRect.new()
	var grad: Gradient = Gradient.new()
	grad.colors = PackedColorArray([Color(0.13, 0.25, 0.3), OOTUiStyle.BG])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.3, 0.0)
	gt.fill_to = Vector2(0.6, 0.85)
	gt.width = 64
	gt.height = 128
	wall.texture = gt
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wall)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	root.add_child(vb)
	vb.add_child(_margin_spacer(0))
	(vb.get_child(0) as Control).custom_minimum_size.y = 20
	var t: String = _story_time()
	var clock: Label = OOTUiStyle.label(OOTPhoneData.clock_of(t) if not t.is_empty() else "9:41", 62, OOTUiStyle.TEXT, 300)
	clock.name = "Clock"
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(clock)
	var day_key: String = OOTPhoneData.day_of(t)
	var day: Label = OOTUiStyle.label(str(WEEKDAYS.get(day_key, day_key)), 16, OOTUiStyle.TEXT_DIM, 500)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(day)
	var gap: Control = _margin_spacer(0)
	gap.custom_minimum_size.y = 34
	vb.add_child(gap)

	var grid: GridContainer = GridContainer.new()
	grid.name = "Apps"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	var center: CenterContainer = CenterContainer.new()
	center.add_child(grid)
	vb.add_child(center)
	for app: Dictionary in APPS:
		grid.add_child(_app_button(app))

	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(fill)
	var st: Node = OOTServices.state()
	if st != null and not str(st.objective_current()).is_empty():
		var rb: Array = _row_button(58.0)
		var card: Button = rb[0]
		var h: HBoxContainer = rb[1]
		card.name = "NowCard"
		var col: VBoxContainer = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(OOTIcons.rect("list-checks", 22, OOTUiStyle.ACCENT))
		h.add_child(col)
		col.add_child(OOTUiStyle.label("NOW", 10, OOTUiStyle.ACCENT, 700))
		var e: Dictionary = OOTJournalData.get_entry(str(st.objective_current()))
		var tl: Label = OOTUiStyle.label(str(e.get("title", "")), 15, OOTUiStyle.TEXT, 600)
		tl.clip_text = true
		col.add_child(tl)
		card.add_theme_stylebox_override("normal", OOTUiStyle.box(Color(0.05, 0.08, 0.1, 0.62), 16))
		card.pressed.connect(func() -> void:
			_play(SFX_CLICK)
			go("objectives"))
		var wrap: MarginContainer = MarginContainer.new()
		wrap.add_theme_constant_override("margin_left", 14)
		wrap.add_theme_constant_override("margin_right", 14)
		wrap.add_child(card)
		vb.add_child(wrap)
	var bot: Control = _margin_spacer(0)
	bot.custom_minimum_size.y = 10
	vb.add_child(bot)
	return root


func _app_button(app: Dictionary) -> Button:
	var b: Button = Button.new()
	b.name = "App_" + str(app["page"])
	b.custom_minimum_size = Vector2(128, 112)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var tile: Panel = Panel.new()
	tile.custom_minimum_size = Vector2(60, 60)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.add_theme_stylebox_override("panel", OOTUiStyle.box(app["color"], 18))
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tile)
	var ic: TextureRect = OOTIcons.rect(str(app["icon"]), 32, Color.WHITE)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 14.0
	ic.offset_top = 14.0
	ic.offset_right = -14.0
	ic.offset_bottom = -14.0
	tile.add_child(ic)
	var lab: Label = OOTUiStyle.label(str(app["label"]), 14, OOTUiStyle.TEXT, 500)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lab)
	var count: int = 0
	if str(app["page"]) == "messages":
		count = OOTPhoneData.unread_count()
	if count > 0:
		var badge: Control = _badge(count)
		badge.name = "Badge"
		badge.position = Vector2(84, 2)
		b.add_child(badge)
	var target: String = str(app["page"])
	b.pressed.connect(func() -> void:
		_play(SFX_CLICK)
		go(target))
	return b


# --- Objectives ---------------------------------------------------------------------------

func _build_objectives() -> Control:
	var shell: Array = _page_shell("Objectives")
	var vb: VBoxContainer = shell[1]
	var sl: Array = _scroll_list()
	vb.add_child(sl[0])
	var list: VBoxContainer = sl[1]
	var st: Node = OOTServices.state()
	var current: String = str(st.objective_current()) if st != null else ""
	var done: Array[String] = []
	if st != null:
		for id: String in st.objective_list():
			if st.objective_is_done(id):
				done.append(id)
	if current.is_empty() and done.is_empty():
		list.add_child(_margin_spacer(0))
		(list.get_child(0) as Control).custom_minimum_size.y = 80
		list.add_child(_empty_note("Nothing to do yet."))
		return shell[0]
	list.add_child(_section_label("Current"))
	if current.is_empty():
		list.add_child(_empty_note("Nothing pending."))
	else:
		list.add_child(_objective_card(current, true))
	if not done.is_empty():
		var gap: Control = _margin_spacer(0)
		gap.custom_minimum_size.y = 8
		list.add_child(gap)
		list.add_child(_section_label("Completed"))
		for i: int in range(done.size() - 1, -1, -1):
			list.add_child(_objective_card(done[i], false))
	return shell[0]


func _objective_card(objective_id: String, current: bool) -> Button:
	var e: Dictionary = OOTJournalData.get_entry(objective_id)
	var b: Button = Button.new()
	b.name = "Objective_" + objective_id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var bg: Color = Color(0.1, 0.22, 0.24) if current else OOTUiStyle.CARD
	for state: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, OOTUiStyle.box(bg, 16, 12))
	var fs: StyleBoxFlat = OOTUiStyle.box(bg, 16, 12)
	fs.set_border_width_all(2)
	fs.border_color = OOTUiStyle.ACCENT
	b.add_theme_stylebox_override("focus", fs)
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12.0
	h.offset_right = -12.0
	h.offset_top = 10.0
	h.offset_bottom = -10.0
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(OOTIcons.rect("list-checks" if current else "check", 22, OOTUiStyle.ACCENT if current else OOTUiStyle.TEXT_DIM))
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	col.add_child(OOTUiStyle.label(str(e.get("title", objective_id)), 16, OOTUiStyle.TEXT if current else OOTUiStyle.TEXT_DIM, 700))
	var tx: Label = OOTUiStyle.label(str(e.get("text", "")), 13, OOTUiStyle.TEXT if current else OOTUiStyle.TEXT_DIM)
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.custom_minimum_size.x = 200
	col.add_child(tx)
	# Size the button to its content (children of a Button do not size it).
	var tw: float = 200.0
	var lines: int = maxi(1, int(ceil(OOTUiStyle.font(400).get_string_size(tx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x / tw)))
	b.custom_minimum_size = Vector2(0, 24.0 + 20.0 + 17.0 * float(lines) + 8.0)
	return b


# --- Messages -----------------------------------------------------------------------------

func _build_messages() -> Control:
	var shell: Array = _page_shell("Messages")
	var vb: VBoxContainer = shell[1]
	var sl: Array = _scroll_list()
	vb.add_child(sl[0])
	var list: VBoxContainer = sl[1]
	for tid: String in OOTPhoneData.thread_ids():
		list.add_child(_thread_row(tid))
	return shell[0]


func _thread_row(thread_id: String) -> Button:
	var th: Dictionary = OOTPhoneData.thread(thread_id)
	var msgs: Array[Dictionary] = OOTPhoneData.messages(thread_id)
	var unread: int = OOTPhoneData.unread_count(thread_id)
	var rb: Array = _row_button(64.0)
	var b: Button = rb[0]
	var h: HBoxContainer = rb[1]
	b.name = "Thread_" + thread_id
	b.add_theme_stylebox_override("normal", OOTUiStyle.box(OOTUiStyle.CARD, 16))
	h.add_child(_avatar(thread_id, 44))
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var nm: Label = OOTUiStyle.label(str(th.get("name", thread_id)), 16, OOTUiStyle.TEXT, 700 if unread > 0 else 600)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var preview: Label
	if msgs.is_empty():
		preview = OOTUiStyle.label("No messages yet", 13, OOTUiStyle.TEXT_DIM)
	else:
		var last: Dictionary = msgs[msgs.size() - 1]
		top.add_child(OOTUiStyle.label(OOTPhoneData.clock_of(str(last.get("time", ""))), 12, OOTUiStyle.TEXT_DIM))
		var who: String = "You: " if str(last.get("from", "them")) == "me" else ""
		preview = OOTUiStyle.label(who + str(last.get("text", "")), 13, OOTUiStyle.TEXT if unread > 0 else OOTUiStyle.TEXT_DIM)
	preview.clip_text = true
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(preview)
	if unread > 0:
		h.add_child(_badge(unread))
	b.pressed.connect(func() -> void:
		_play(SFX_CLICK)
		go("thread", thread_id))
	return b


func _build_thread(thread_id: String) -> Control:
	var th: Dictionary = OOTPhoneData.thread(thread_id)
	var shell: Array = _page_shell(str(th.get("name", thread_id)))
	var head: HBoxContainer = shell[2]
	head.add_child(_margin_spacer(2))
	head.move_child(head.get_child(head.get_child_count() - 1), 2)
	var av: Control = _avatar(thread_id, 30)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(av)
	head.move_child(av, 2)
	var vb: VBoxContainer = shell[1]
	var sl: Array = _scroll_list()
	vb.add_child(sl[0])
	var list: VBoxContainer = sl[1]
	list.add_theme_constant_override("separation", 3)
	var msgs: Array[Dictionary] = OOTPhoneData.messages(thread_id)
	if msgs.is_empty():
		var gap: Control = _margin_spacer(0)
		gap.custom_minimum_size.y = 120
		list.add_child(gap)
		list.add_child(_empty_note("No messages yet."))
		return shell[0]
	var st: Node = OOTServices.state()
	var last_day: String = ""
	for m: Dictionary in msgs:
		var day: String = OOTPhoneData.day_of(str(m.get("time", "")))
		if day != last_day:
			last_day = day
			var sep: Label = OOTUiStyle.label(str(WEEKDAYS.get(day, day)), 12, OOTUiStyle.TEXT_DIM, 600)
			sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sep.custom_minimum_size.y = 26
			sep.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			list.add_child(sep)
		list.add_child(_bubble(m))
		if st != null and str(m.get("from", "them")) == "them":
			st.phone_mark_read(str(m.get("id", "")))
	_scroll_to_bottom.call_deferred()
	return shell[0]


func _scroll_to_bottom() -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


## One chat bubble: the message, its English subtitle under it (Tanglish), then time and read state.
func _bubble(m: Dictionary) -> Control:
	var mine: bool = str(m.get("from", "them")) == "me"
	var text: String = str(m.get("text", ""))
	var sub: String = str(m.get("subtitle", ""))
	var max_w: float = 214.0
	var f: Font = OOTUiStyle.font(400)
	var w: float = minf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 4.0, max_w)
	if not sub.is_empty():
		w = maxf(w, minf(f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 4.0, max_w))
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Msg_" + str(m.get("id", ""))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mine:
		row.add_child(spacer)
		row.add_child(col)
	else:
		row.add_child(col)
		row.add_child(spacer)
	var bubble: PanelContainer = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", OOTUiStyle.box(OOTUiStyle.BUBBLE_ME if mine else OOTUiStyle.BUBBLE_THEM, 18, 11))
	col.add_child(bubble)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	bubble.add_child(inner)
	var tl: Label = OOTUiStyle.label(text, 15, OOTUiStyle.TEXT)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size.x = w
	inner.add_child(tl)
	if not sub.is_empty():
		var sl: Label = OOTUiStyle.label(sub, 12, Color(1, 1, 1, 0.66))
		sl.name = "Subtitle"
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size.x = w
		inner.add_child(sl)
	var meta: String = OOTPhoneData.clock_of(str(m.get("time", "")))
	if mine:
		meta += "  " + ("Read" if str(m.get("status", "read")) == "read" else "Delivered")
	var ml: Label = OOTUiStyle.label(meta, 11, OOTUiStyle.TEXT_DIM)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mine else HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(ml)
	return row


# --- Photos -------------------------------------------------------------------------------

func _build_photos() -> Control:
	var shell: Array = _page_shell("Photos")
	var vb: VBoxContainer = shell[1]
	var sl: Array = _scroll_list()
	vb.add_child(sl[0])
	var list: VBoxContainer = sl[1]
	var photos: Array[Dictionary] = OOTPhoneData.photos()
	if photos.is_empty():
		list.add_child(_empty_note("No photos."))
		return shell[0]
	var grid: GridContainer = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	for i: int in range(photos.size()):
		var p: Dictionary = photos[i]
		var b: Button = Button.new()
		b.name = "Photo_" + str(p.get("id", i))
		b.custom_minimum_size = Vector2(136, 150)
		b.add_theme_stylebox_override("normal", OOTUiStyle.box(OOTUiStyle.CARD, 14))
		var col: VBoxContainer = VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 5.0
		col.offset_right = -5.0
		col.offset_top = 5.0
		col.offset_bottom = -5.0
		col.add_theme_constant_override("separation", 4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var tr: TextureRect = TextureRect.new()
		tr.texture = load(str(p.get("file", ""))) as Texture2D
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.clip_contents = true
		tr.custom_minimum_size = Vector2(0, 108)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(tr)
		var tl: Label = OOTUiStyle.label(str(p.get("title", "")), 12, OOTUiStyle.TEXT, 500)
		tl.clip_text = true
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(tl)
		var idx: int = i
		b.pressed.connect(func() -> void:
			_play(SFX_CLICK)
			go("photo", str(idx)))
		grid.add_child(b)
	return shell[0]


func _build_photo(index: int) -> Control:
	var photos: Array[Dictionary] = OOTPhoneData.photos()
	_photo_index = clampi(index, 0, maxi(photos.size() - 1, 0))
	var shell: Array = _page_shell("%d of %d" % [_photo_index + 1, photos.size()])
	var vb: VBoxContainer = shell[1]
	if photos.is_empty():
		return shell[0]
	var p: Dictionary = photos[_photo_index]
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", OOTUiStyle.box(Color(0, 0, 0, 0.5), 0, 0))
	vb.add_child(frame)
	var tr: TextureRect = TextureRect.new()
	tr.name = "Picture"
	tr.texture = load(str(p.get("file", ""))) as Texture2D
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tr)
	var cap: VBoxContainer = VBoxContainer.new()
	cap.add_theme_constant_override("separation", 2)
	var mc: MarginContainer = MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 16)
	mc.add_theme_constant_override("margin_right", 16)
	mc.add_child(cap)
	vb.add_child(mc)
	cap.add_child(OOTUiStyle.label(str(p.get("title", "")), 16, OOTUiStyle.TEXT, 700))
	var cl: Label = OOTUiStyle.label(str(p.get("caption", "")), 13, OOTUiStyle.TEXT_DIM)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl.custom_minimum_size.x = 260
	cap.add_child(cl)
	var nav: HBoxContainer = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 14)
	for step: int in [-1, 1]:
		var nb: Button = Button.new()
		nb.text = "Previous" if step < 0 else "Next"
		nb.custom_minimum_size = Vector2(110, 36)
		nb.disabled = (_photo_index + step < 0) or (_photo_index + step >= photos.size())
		var s: int = step
		nb.pressed.connect(func() -> void:
			_play(SFX_CLICK)
			_step_photo(s))
		nav.add_child(nb)
	var navm: MarginContainer = MarginContainer.new()
	navm.add_theme_constant_override("margin_bottom", 8)
	navm.add_child(nav)
	vb.add_child(navm)
	return shell[0]


func _step_photo(step: int) -> void:
	var n: int = OOTPhoneData.photos().size()
	var target: int = _photo_index + step
	if target < 0 or target >= n:
		return
	_show_page("photo", str(target))   # replaces the page in place; Back still returns to the gallery


# --- Calls ----------------------------------------------------------------------------------

const CALL_ICONS: Dictionary = {
	"voicemail": "voicemail", "missed": "phone-missed", "incoming": "phone-incoming", "outgoing": "phone-outgoing",
	"video": "video",
}


func _call_color(kind: String) -> Color:
	match kind:
		"missed":
			return OOTUiStyle.ALERT
		"voicemail", "video":
			return OOTUiStyle.ACCENT
		"incoming":
			return Color(0.45, 0.8, 0.5)
	return OOTUiStyle.TEXT_DIM


func _build_calls() -> Control:
	var shell: Array = _page_shell("Calls")
	var vb: VBoxContainer = shell[1]
	var sl: Array = _scroll_list()
	vb.add_child(sl[0])
	var list: VBoxContainer = sl[1]
	var calls: Array[Dictionary] = OOTPhoneData.calls()
	if calls.is_empty():
		list.add_child(_empty_note("No calls."))
		return shell[0]
	# Newest first: the file is in time order.
	for i: int in range(calls.size() - 1, -1, -1):
		var c: Dictionary = calls[i]
		var kind: String = str(c.get("kind", "missed"))
		var rb: Array = _row_button(60.0)
		var b: Button = rb[0]
		var h: HBoxContainer = rb[1]
		b.name = "Call_" + str(c.get("id", i))
		b.add_theme_stylebox_override("normal", OOTUiStyle.box(OOTUiStyle.CARD, 16))
		h.add_child(OOTIcons.rect(str(CALL_ICONS.get(kind, "phone")), 24, _call_color(kind)))
		var col: VBoxContainer = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(col)
		col.add_child(OOTUiStyle.label(str(c.get("name", "")), 16, OOTUiStyle.ALERT if kind == "missed" else OOTUiStyle.TEXT, 600))
		var note: Label = OOTUiStyle.label(str(c.get("note", kind.capitalize())), 12, OOTUiStyle.TEXT_DIM)
		note.clip_text = true
		note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(note)
		var tm: Label = OOTUiStyle.label(str(c.get("time", "")), 12, OOTUiStyle.TEXT_DIM)
		tm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tm)
		var cid: String = str(c.get("id", ""))
		b.pressed.connect(func() -> void:
			_play(SFX_CLICK)
			go("call", cid))
		list.add_child(b)
	return shell[0]


func _call_by_id(call_id: String) -> Dictionary:
	for c: Dictionary in OOTPhoneData.calls():
		if str(c.get("id", "")) == call_id:
			return c
	return {}


func _build_call(call_id: String) -> Control:
	var c: Dictionary = _call_by_id(call_id)
	var kind: String = str(c.get("kind", ""))
	var shell: Array = _page_shell("Voicemail" if kind == "voicemail" else "Call")
	var vb: VBoxContainer = shell[1]
	var mc: MarginContainer = MarginContainer.new()
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mc.add_theme_constant_override("margin_left", 16)
	mc.add_theme_constant_override("margin_right", 16)
	vb.add_child(mc)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	mc.add_child(col)
	var who: String = str(c.get("name", ""))
	var ctr: CenterContainer = CenterContainer.new()
	ctr.add_child(_avatar_for(who, Color.html("#d98a3d") if who == "Nila" else Color(0.4, 0.5, 0.6), 64))
	col.add_child(ctr)
	var nm: Label = OOTUiStyle.label(who, 20, OOTUiStyle.TEXT, 700)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(nm)
	var info: Label = OOTUiStyle.label("%s  -  %s" % [str(c.get("note", "")), str(c.get("time", ""))], 13, OOTUiStyle.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	_vm_lines.clear()
	_vm_line_labels.clear()
	_vm_wave = null
	_vm_button = null
	if kind != "voicemail":
		return shell[0]
	for l: Variant in c.get("lines", []):
		_vm_lines.append(str(l))
	var wave: OOTWaveform = OOTWaveform.new()
	wave.custom_minimum_size = Vector2(0, 56)
	col.add_child(wave)
	_vm_wave = wave
	var pb: Button = Button.new()
	pb.name = "PlayButton"
	pb.custom_minimum_size = Vector2(52, 52)
	pb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("normal", OOTUiStyle.box(OOTUiStyle.ACCENT_DARK, 26))
	pb.add_theme_stylebox_override("hover", OOTUiStyle.box(OOTUiStyle.ACCENT, 26))
	pb.add_theme_stylebox_override("pressed", OOTUiStyle.box(OOTUiStyle.ACCENT, 26))
	var fs: StyleBoxFlat = OOTUiStyle.box(OOTUiStyle.ACCENT_DARK, 26)
	fs.set_border_width_all(2)
	fs.border_color = Color.WHITE
	pb.add_theme_stylebox_override("focus", fs)
	pb.icon = OOTIcons.get_icon("play", 24)
	pb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb.pressed.connect(_on_vm_button)
	col.add_child(pb)
	_vm_button = pb
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll = scroll
	col.add_child(scroll)
	var tl: VBoxContainer = VBoxContainer.new()
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_theme_constant_override("separation", 8)
	scroll.add_child(tl)
	for id: String in _vm_lines:
		var line: OOTDialogueLine = OOTPhoneData.vo_line(id)
		var blk: VBoxContainer = VBoxContainer.new()
		blk.name = "Line_" + id
		blk.add_theme_constant_override("separation", 1)
		blk.custom_minimum_size.x = 268
		if line != null:
			var t1: Label = OOTUiStyle.label(line.text, 14, OOTUiStyle.TEXT)
			t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t1.custom_minimum_size.x = 268
			blk.add_child(t1)
			var t2: Label = OOTUiStyle.label(line.get_subtitle(), 12, OOTUiStyle.TEXT_DIM)
			t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t2.custom_minimum_size.x = 268
			blk.add_child(t2)
		tl.add_child(blk)
		_vm_line_labels.append(blk)
	_vm_highlight(-1)
	_vm_start.call_deferred()
	return shell[0]


func _vm_start() -> void:
	if is_open and page == "call" and not _vm_lines.is_empty():
		vm_play_from(0)


func _on_vm_button() -> void:
	if vm_playing:
		_vm_player.stream_paused = not _vm_player.stream_paused
		_vm_sync_button(not _vm_player.stream_paused)
	else:
		vm_play_from(0)


## Plays the voicemail's VO lines one after another, starting at line `index`.
func vm_play_from(index: int) -> void:
	if index >= _vm_lines.size():
		_vm_finish()
		return
	vm_index = index
	var part: String = OOTPhoneData.PART_ID
	var stream: AudioStream = OOTVoiceLines.get_stream(_vm_lines[index], part)
	_vm_highlight(index)
	if stream == null:
		vm_play_from(index + 1)
		return
	vm_playing = true
	_vm_player.stream_paused = false
	_vm_player.stream = stream
	_vm_player.play()
	_vm_sync_button(true)
	if _vm_wave != null:
		_vm_wave.set_active(true)


func _on_vm_line_finished() -> void:
	if vm_playing:
		vm_play_from(vm_index + 1)


func _vm_finish() -> void:
	vm_playing = false
	if _vm_wave != null:
		_vm_wave.set_active(false)
		_vm_wave.set_progress(1.0)
	_vm_highlight(-1)
	_vm_sync_button(false)


func _vm_stop() -> void:
	if _vm_player != null and _vm_player.playing:
		_vm_player.stop()
	vm_playing = false
	_vm_wave = null
	_vm_button = null


func _vm_sync_button(playing: bool) -> void:
	if _vm_button != null and is_instance_valid(_vm_button):
		_vm_button.icon = OOTIcons.get_icon("pause" if playing else "play", 24)


func _vm_highlight(index: int) -> void:
	for i: int in range(_vm_line_labels.size()):
		var blk: Control = _vm_line_labels[i]
		if is_instance_valid(blk):
			blk.modulate = Color(1, 1, 1, 1.0) if (index < 0 or i == index) else Color(1, 1, 1, 0.45)


func _process(_delta: float) -> void:
	if vm_playing and _vm_wave != null and is_instance_valid(_vm_wave) and _vm_player.playing and _vm_player.stream != null:
		var len_s: float = maxf(_vm_player.stream.get_length(), 0.01)
		var n: int = maxi(_vm_lines.size(), 1)
		_vm_wave.set_progress((float(vm_index) + clampf(_vm_player.get_playback_position() / len_s, 0.0, 1.0)) / float(n))


# --- Incoming messages -------------------------------------------------------------------------

func _on_objective_changed(_id: String) -> void:
	if is_open and (page == "home" or page == "objectives"):
		_show_page(page, page_arg)


func _on_delivered(message_id: String) -> void:
	var m: Dictionary = OOTPhoneData.message(message_id)
	if m.is_empty():
		return
	var thread_id: String = str(m.get("thread", ""))
	_vibrate_now()
	if is_open:
		if page == "thread" and page_arg == thread_id:
			_show_page("thread", thread_id)
		elif page == "messages" or page == "home":
			_show_page(page, page_arg)
		return
	_show_banner(thread_id, m)


func _vibrate_now() -> void:
	if _vib_player != null and is_inside_tree():
		_vib_player.play()
	for dev: int in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, 0.4, 0.2, 0.45)


func _show_banner(thread_id: String, m: Dictionary) -> void:
	var th: Dictionary = OOTPhoneData.thread(thread_id)
	_banner_name.text = str(th.get("name", thread_id))
	_banner_text.text = str(m.get("text", ""))
	var sub: String = str(m.get("subtitle", ""))
	_banner_sub.text = sub
	_banner_sub.visible = not sub.is_empty()
	for c: Node in _banner_avatar.get_children():
		c.queue_free()
	var av: Control = _avatar(thread_id, 42)
	av.position = Vector2.ZERO
	av.size = Vector2(42, 42)
	_banner_avatar.add_child(av)
	_banner.size = Vector2(380, 10)   # shrink to content, then centre at the top
	_banner.visible = true
	_banner.reset_size()
	var vp_w: float = _screen_size().x
	var x: float = (vp_w - _banner.size.x) * 0.5
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.position = Vector2(x, -_banner.size.y - 10.0)
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "position:y", 16.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(BANNER_SECONDS)
	_banner_tween.tween_property(_banner, "position:y", -_banner.size.y - 10.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_banner_tween.tween_callback(func() -> void: _banner.visible = false)
	banner_shown.emit(thread_id, str(m.get("id", "")))


func _hide_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	if _banner != null:
		_banner.visible = false


func banner_visible() -> bool:
	return _banner != null and _banner.visible
