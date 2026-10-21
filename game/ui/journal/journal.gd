class_name OOTJournal
extends Control
## Mani's notebook (J). Opens as a two-page spread on a lined notebook, pauses
## the game while open, and turns pages with A/D, the arrow keys, the mouse
## wheel or a click on a page corner. Sections: Current goal, People, Clues,
## Notes. Entries come from StoryState.journal_entries(); their text from
## data/journal/*.json (OOTJournalData). Tanglish entries show text + subtitle.

signal opened
signal closed

const BOOK_SIZE: Vector2 = Vector2(1040, 600)
const PAGE_SIZE: Vector2 = Vector2(480, 540)
const LINE: int = 30
const LINES_PER_PAGE: int = 15
const MARGIN_X: float = 58.0
const TOP_PAD: float = 34.0
const CORNER: float = 80.0
const INK: Color = Color(0.12, 0.17, 0.36)
const INK_SOFT: Color = Color(0.32, 0.36, 0.5)
const SFX_OPEN: String = "res://audio/sfx/kenney/interface/open_002.ogg"
const SFX_CLOSE: String = "res://audio/sfx/kenney/interface/close_002.ogg"
const SFX_TURN: String = "res://audio/sfx/kenney/interface/scroll_002.ogg"

var is_open: bool = false
## Index into the spreads; see spread_count().
var spread_index: int = 0

var _spreads: Array[Dictionary] = []
var _book: Control
var _content: Control
var _left: _Paper
var _right: _Paper
var _tabs: Dictionary = {}
var _font: FontVariation
var _page_label_l: Label
var _page_label_r: Label
var _sfx: AudioStreamPlayer
var _prev_mouse: int = Input.MOUSE_MODE_VISIBLE
var _was_paused: bool = false
var _turn_tween: Tween


## Ruled notebook paper.
class _Paper extends Control:
	var right_side: bool = false
	var corner_hot: bool = false

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.965, 0.94, 0.86))
		# Shade toward the spine.
		var spine_x: float = size.x if not right_side else 0.0
		for i: int in range(18):
			var a: float = 0.07 * (1.0 - float(i) / 18.0)
			var x: float = (spine_x - (i * 3.0 + 3.0)) if not right_side else (spine_x + i * 3.0)
			draw_rect(Rect2(x, 0, 3, size.y), Color(0.3, 0.2, 0.1, a))
		for i: int in range(1, 16):
			var y: float = 34.0 + i * 30.0
			draw_line(Vector2(14, y), Vector2(size.x - 14, y), Color(0.45, 0.58, 0.78, 0.45), 1.0)
		var mx: float = 46.0 if not right_side else 40.0
		draw_line(Vector2(mx, 0), Vector2(mx, size.y), Color(0.8, 0.3, 0.3, 0.45), 1.5)
		# Dog-ear at the outer bottom corner (click to turn).
		var cx: float = size.x if right_side else 0.0
		var dir: float = -1.0 if right_side else 1.0
		var tri: PackedVector2Array = PackedVector2Array([
			Vector2(cx, size.y - 34.0), Vector2(cx + dir * 34.0, size.y), Vector2(cx, size.y)])
		draw_colored_polygon(tri, Color(0.82, 0.77, 0.66) if not corner_hot else Color(0.7, 0.62, 0.45))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("oot_journal")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.16, 1), Vector2.ZERO)
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"UI"
	_sfx.volume_db = -6.0
	add_child(_sfx)
	_build()


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_book = Control.new()
	_book.name = "Book"
	_book.custom_minimum_size = BOOK_SIZE
	_book.size = BOOK_SIZE
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.anchor_left = 0.5
	_book.anchor_right = 0.5
	_book.anchor_top = 0.5
	_book.anchor_bottom = 0.5
	_book.offset_left = -BOOK_SIZE.x * 0.5
	_book.offset_right = BOOK_SIZE.x * 0.5
	_book.offset_top = -BOOK_SIZE.y * 0.5 + 20.0
	_book.offset_bottom = BOOK_SIZE.y * 0.5 + 20.0
	add_child(_book)

	var cover: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.12, 0.1)
	sb.set_corner_radius_all(14)
	sb.shadow_size = 24
	sb.shadow_color = Color(0, 0, 0, 0.5)
	cover.add_theme_stylebox_override("panel", sb)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(cover)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_content)

	_left = _Paper.new()
	_left.position = Vector2(BOOK_SIZE.x * 0.5 - PAGE_SIZE.x - 2.0, 30)
	_left.size = PAGE_SIZE
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_left)
	_right = _Paper.new()
	_right.right_side = true
	_right.position = Vector2(BOOK_SIZE.x * 0.5 + 2.0, 30)
	_right.size = PAGE_SIZE
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_right)

	_page_label_l = _small_label(_left, Vector2(0, PAGE_SIZE.y - 28), HORIZONTAL_ALIGNMENT_CENTER)
	_page_label_r = _small_label(_right, Vector2(0, PAGE_SIZE.y - 28), HORIZONTAL_ALIGNMENT_CENTER)

	# Section tabs along the top edge of the notebook.
	var x: float = 70.0
	for sec: String in OOTJournalData.SECTIONS:
		var b: Button = Button.new()
		b.text = str(OOTJournalData.SECTION_TITLES[sec])
		b.flat = false
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(140, 26)
		b.position = Vector2(x, 2)
		b.size = Vector2(140, 26)
		b.pressed.connect(_on_tab.bind(sec))
		_book.add_child(b)
		_tabs[sec] = b
		x += 148.0


func _small_label(parent: Control, pos: Vector2, align: HorizontalAlignment) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = Vector2(PAGE_SIZE.x, 24)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", INK_SOFT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# --- Data / pagination --------------------------------------------------------

## Entry ids held in StoryState for a section (the goal section keeps only the latest).
func entries_for(section: String) -> Array[String]:
	var out: Array[String] = []
	var st: Node = OOTServices.state()
	if st == null:
		return out
	for id: String in st.journal_entries():
		if str(OOTJournalData.get_entry(id).get("section", "notes")) == section:
			out.append(id)
	if section == "goal" and out.size() > 1:
		out = [out[out.size() - 1]]
	return out


func _para_lines(text: String, size: int, width: float) -> int:
	if text.is_empty():
		return 0
	var tp: TextParagraph = TextParagraph.new()
	tp.add_string(text, _font, size)
	tp.width = width
	return maxi(tp.get_line_count(), 1)


func _block_lines(id: String) -> int:
	var e: Dictionary = OOTJournalData.get_entry(id)
	var w: float = PAGE_SIZE.x - MARGIN_X - 28.0
	var n: int = _para_lines(str(e.get("title", id)), 24, w)
	n += _para_lines(str(e.get("text", "")), 21, w)
	n += _para_lines(str(e.get("subtitle", "")), 18, w)
	return n + 1  # blank line after


func rebuild_spreads() -> void:
	_spreads.clear()
	for sec: String in OOTJournalData.SECTIONS:
		var ids: Array[String] = entries_for(sec)
		var left: Array[String] = []
		var right: Array[String] = []
		var left_used: int = 1  # the section heading takes a line
		var right_used: int = 0
		var cur_left: bool = true
		var any: bool = false
		for id: String in ids:
			var n: int = _block_lines(id)
			if cur_left and left_used + n > LINES_PER_PAGE and not left.is_empty():
				cur_left = false
			if not cur_left and right_used + n > LINES_PER_PAGE and not right.is_empty():
				_spreads.append({"section": sec, "left": left, "right": right})
				left = []
				right = []
				left_used = 1
				right_used = 0
				cur_left = true
			if cur_left:
				left.append(id)
				left_used += n
			else:
				right.append(id)
				right_used += n
			any = true
		_spreads.append({"section": sec, "left": left, "right": right, "empty": not any})
	spread_index = clampi(spread_index, 0, _spreads.size() - 1)


func spread_count() -> int:
	return _spreads.size()


func current_section() -> String:
	if _spreads.is_empty():
		return OOTJournalData.SECTIONS[0]
	return str(_spreads[spread_index]["section"])


## Ids on the current spread (left page then right page).
func current_entry_ids() -> Array[String]:
	var out: Array[String] = []
	if _spreads.is_empty():
		return out
	out.append_array(_spreads[spread_index]["left"])
	out.append_array(_spreads[spread_index]["right"])
	return out


# --- Showing --------------------------------------------------------------------

func open(section: String = "") -> void:
	if is_open:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	rebuild_spreads()
	if section.is_empty():
		spread_index = 0
	else:
		_go_section(section)
	_show_spread(false)
	_play(SFX_OPEN)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = _was_paused
	Input.mouse_mode = _prev_mouse as Input.MouseMode
	_play(SFX_CLOSE)
	closed.emit()


func next_page() -> bool:
	return _turn(1)


func prev_page() -> bool:
	return _turn(-1)


func _turn(dir: int) -> bool:
	var n: int = spread_index + dir
	if n < 0 or n >= _spreads.size():
		return false
	spread_index = n
	_show_spread(true)
	_play(SFX_TURN)
	return true


func _go_section(section: String) -> void:
	for i: int in range(_spreads.size()):
		if str(_spreads[i]["section"]) == section:
			spread_index = i
			return


func _on_tab(section: String) -> void:
	if section == current_section():
		return
	_go_section(section)
	_show_spread(true)
	_play(SFX_TURN)


func _play(path: String) -> void:
	if ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.play()


func _show_spread(animate: bool) -> void:
	for page: _Paper in [_left, _right]:
		for c: Node in page.get_children():
			if c.is_in_group("oot_journal_text"):
				page.remove_child(c)
				c.queue_free()
	var sp: Dictionary = _spreads[spread_index]
	var sec: String = str(sp["section"])
	_text_line(_left, 0, str(OOTJournalData.SECTION_TITLES[sec]), 26, INK, true)
	_fill(_left, sp["left"], 1)
	_fill(_right, sp["right"], 0)
	if bool(sp.get("empty", false)):
		_text_line(_left, 2, "Nothing yet.", 21, INK_SOFT, false)
	_page_label_l.text = "%d" % (spread_index * 2 + 1)
	_page_label_r.text = "%d" % (spread_index * 2 + 2)
	for s: String in _tabs:
		var b: Button = _tabs[s]
		b.modulate = Color(1, 1, 1, 1) if s == sec else Color(1, 1, 1, 0.55)
	if animate:
		if _turn_tween != null:
			_turn_tween.kill()
		_content.modulate.a = 0.0
		_turn_tween = create_tween()
		_turn_tween.tween_property(_content, "modulate:a", 1.0, 0.18)
	else:
		_content.modulate.a = 1.0


func _fill(page: _Paper, ids: Array, start_line: int) -> void:
	var line: int = start_line
	var w: float = PAGE_SIZE.x - MARGIN_X - 28.0
	for id: Variant in ids:
		var e: Dictionary = OOTJournalData.get_entry(str(id))
		line += _text_block(page, line, str(e.get("title", id)), 24, INK, true, w)
		line += _text_block(page, line, str(e.get("text", "")), 21, INK, false, w)
		var sub: String = str(e.get("subtitle", ""))
		if not sub.is_empty():
			line += _text_block(page, line, sub, 18, INK_SOFT, false, w)
		line += 1


func _text_line(page: _Paper, line: int, text: String, size: int, col: Color, underline: bool) -> void:
	_text_block(page, line, text, size, col, underline, PAGE_SIZE.x - MARGIN_X - 28.0)


## Puts a wrapped paragraph on the ruled grid; returns the lines used.
func _text_block(page: _Paper, line: int, text: String, size: int, col: Color, underline: bool, w: float) -> int:
	var lines: int = _para_lines(text, size, w)
	if lines == 0:
		return 0
	var l: Label = Label.new()
	l.add_to_group("oot_journal_text")
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("line_spacing", LINE - int(_font.get_height(size)))
	l.position = Vector2(MARGIN_X, TOP_PAD + line * LINE + 6.0)
	l.size = Vector2(w, lines * LINE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(l)
	if underline:
		var u: ColorRect = ColorRect.new()
		u.add_to_group("oot_journal_text")
		u.color = Color(col.r, col.g, col.b, 0.5)
		u.position = Vector2(MARGIN_X, TOP_PAD + (line + 1) * LINE - 2.0)
		u.size = Vector2(minf(w, _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x), 1.5)
		u.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(u)
	return lines


# --- Input ------------------------------------------------------------------------

func _is_other_modal_open() -> bool:
	for n: Node in get_tree().get_nodes_in_group("oot_modal"):
		if bool(n.get("is_open")):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if is_open:
			close()
		elif not _is_other_modal_open():
			open()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("pause"):
		close()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var k: Key = (event as InputEventKey).physical_keycode
		if k == KEY_D or k == KEY_RIGHT:
			next_page()
		elif k == KEY_A or k == KEY_LEFT:
			prev_page()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				next_page()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				prev_page()
			MOUSE_BUTTON_LEFT:
				_click(mb.global_position)
		accept_event()
	elif event is InputEventMouseMotion:
		var p: Vector2 = (event as InputEventMouseMotion).global_position
		_left.corner_hot = _in_corner(_left, p)
		_right.corner_hot = _in_corner(_right, p)
		_left.queue_redraw()
		_right.queue_redraw()


func _in_corner(page: _Paper, p: Vector2) -> bool:
	var r: Rect2 = page.get_global_rect()
	var corner: Rect2 = Rect2(
		Vector2(r.end.x - CORNER if page.right_side else r.position.x, r.end.y - CORNER), Vector2(CORNER, CORNER))
	return corner.has_point(p)


func _click(p: Vector2) -> void:
	if _in_corner(_right, p):
		next_page()
	elif _in_corner(_left, p):
		prev_page()
