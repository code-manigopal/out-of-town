class_name OOTHud
extends Control
## In-world HUD: the centre reticle (changes style with what you look at, no
## key prompts), a faint object name, packing counter, carried item, toast, the
## ringing banner and the "Journal updated" note. It also owns the journal
## notebook (J), Mani's phone (P) and the top-left objective toast so every scene with a HUD gets them.
## Pure presentation.

const JOURNAL_SCENE: PackedScene = preload("res://ui/journal/journal.tscn")
const SFX_JOURNAL: String = "res://audio/sfx/kenney/interface/scratch_002.ogg"
const NAME_FADE_SPEED: float = 7.0

var reticle: OOTReticle
var name_label: Label
var journal: Control
var phone: OOTPhone
var objective_toast: OOTObjectiveToast
var thought: OOTThoughtSubtitle
var _packed: Label
var _carried: Label
var _toast: Label
var _ring: Label
var _note: PanelContainer
var _note_label: Label
var _note_left: float = 0.0
var _toast_left: float = 0.0
var _ringing: bool = false
var _t: float = 0.0
var _interactor: OOTInteractor = null
var _target: OOTInteractable = null
var _sfx: AudioStreamPlayer


func _ready() -> void:
	OOTUiSettings.ensure_loaded()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_packed = _label(Vector2(24, 140), 22, HORIZONTAL_ALIGNMENT_LEFT)
	_packed.text = "Packed 0/3"
	_carried = _label(Vector2(24, 172), 18, HORIZONTAL_ALIGNMENT_LEFT)
	_toast = _label(Vector2(0, 100), 22, HORIZONTAL_ALIGNMENT_CENTER)
	_ring = _label(Vector2(0, 150), 30, HORIZONTAL_ALIGNMENT_CENTER)
	_ring.visible = false

	reticle = OOTReticle.new()
	reticle.name = "Reticle"
	_center(reticle, Vector2(-OOTReticle.SIZE, -OOTReticle.SIZE) * 0.5, Vector2(OOTReticle.SIZE, OOTReticle.SIZE) * 0.5)
	add_child(reticle)

	name_label = Label.new()
	name_label.name = "InteractName"
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.modulate.a = 0.0
	_center(name_label, Vector2(-200, 30), Vector2(200, 56))
	add_child(name_label)

	_build_note()
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"UI"
	_sfx.volume_db = -8.0
	add_child(_sfx)

	var st: Node = OOTServices.state()
	if st != null and st.has_signal("journal_added"):
		st.connect("journal_added", _on_journal_added)
	if get_tree().get_nodes_in_group("oot_journal").is_empty():
		journal = JOURNAL_SCENE.instantiate() as Control
		add_child(journal)
	if OOTPhone.instance() == null:
		phone = OOTPhone.new()
		phone.name = "Phone"
		add_child(phone)
	else:
		phone = OOTPhone.instance()
	objective_toast = OOTObjectiveToast.new()
	objective_toast.name = "ObjectiveToast"
	add_child(objective_toast)
	thought = OOTThoughtSubtitle.new()
	thought.name = "Thought"
	add_child(thought)
	_register_modals.call_deferred()


## Anchors a control to the screen centre with offsets from it.
func _center(c: Control, top_left: Vector2, bottom_right: Vector2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = top_left.x
	c.offset_top = top_left.y
	c.offset_right = bottom_right.x
	c.offset_bottom = bottom_right.y


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


func _build_note() -> void:
	_note = PanelContainer.new()
	_note.name = "JournalNote"
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08, 0.78)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	_note.add_theme_stylebox_override("panel", sb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_child(row)
	var pen: OOTPenIcon = OOTPenIcon.new()
	row.add_child(pen)
	_note_label = Label.new()
	_note_label.add_theme_font_size_override("font_size", 17)
	_note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_note_label)
	_note.anchor_top = 1.0
	_note.anchor_bottom = 1.0
	_note.offset_left = 24.0
	_note.offset_top = -72.0
	_note.offset_bottom = -24.0
	_note.grow_horizontal = Control.GROW_DIRECTION_END
	add_child(_note)
	_note.modulate.a = 0.0


## Kept for older callers (the interactor's prompt_changed). There is no key
## prompt any more: the reticle and name come from the interactor's target.
func set_prompt(_text: String) -> void:
	pass


## Points the reticle at an interactable (null = plain dot). Normally driven
## automatically from the player's OOTInteractor.
func set_target(target: OOTInteractable) -> void:
	_target = target
	if target == null or not is_instance_valid(target):
		_target = null
		reticle.set_style(&"dot")
		return
	reticle.set_style(target.get_reticle_hint())
	name_label.text = target.display_name


func set_packed(count: int, total: int) -> void:
	_packed.text = "Packed %d/%d" % [count, total]


func set_carried(item_name: String) -> void:
	_carried.text = "" if item_name.is_empty() else "Carrying: %s" % item_name


func show_toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast_left = seconds


## Mani's inner voice: italic subtitle, no speaker frame, plus his clean close-mic VO (story scene id, e.g. e1_thought_pack1).
func show_thought(scene_id: String, order: int = 0) -> bool:
	return thought.play(scene_id, order)


func set_ringing(on: bool) -> void:
	_ringing = on
	_ring.visible = on
	_ring.text = "Your laptop is ringing"


## Soft "Journal updated" note with a pen-scratch sound.
func notify_journal(entry_id: String) -> void:
	var title: String = str(OOTJournalData.get_entry(entry_id).get("title", ""))
	_note_label.text = "Journal updated" if title.is_empty() else "Journal updated  -  %s" % title
	_note_left = 3.2
	if ResourceLoader.exists(SFX_JOURNAL):
		_sfx.stream = load(SFX_JOURNAL)
		_sfx.play()


func _on_journal_added(entry_id: String) -> void:
	notify_journal(entry_id)


func _register_modals() -> void:
	for n: Node in get_tree().root.find_children("*", "OOTDialogueBox", true, false):
		n.add_to_group("oot_modal")


func is_modal_open() -> bool:
	for n: Node in get_tree().get_nodes_in_group("oot_modal"):
		if bool(n.get("is_open")):
			return true
	return false


func _bind_interactor() -> void:
	var found: Array[Node] = get_tree().get_nodes_in_group("oot_interactor")
	if found.is_empty():
		return
	_interactor = found[0] as OOTInteractor


func _process(delta: float) -> void:
	if _interactor == null or not is_instance_valid(_interactor):
		_interactor = null
		_bind_interactor()
	var modal: bool = is_modal_open()
	reticle.visible = not modal
	if _interactor != null:
		var t: OOTInteractable = _interactor.target if _interactor.enabled and not modal else null
		if t != _target or (t != null and t.get_reticle_hint() != reticle.style):
			set_target(t)
	var want_name: bool = _target != null and OOTUiSettings.show_interact_names and not modal
	name_label.modulate.a = move_toward(name_label.modulate.a, 0.9 if want_name else 0.0, delta * NAME_FADE_SPEED)

	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.text = ""
	if _note_left > 0.0:
		_note_left -= delta
		_note.modulate.a = move_toward(_note.modulate.a, 1.0, delta * 4.0)
	else:
		_note.modulate.a = move_toward(_note.modulate.a, 0.0, delta * 2.0)
	if _ringing:
		_t += delta
		_ring.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 6.0))
