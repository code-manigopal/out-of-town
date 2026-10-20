class_name OOTEpisode01
extends Node
## Episode 1 flow (G1 slice): cold open voicemail on black -> title card ->
## apartment (pack, laptop call) -> end card at e1_road.

signal flow_finished

const PART_ID: String = "p1"
const EPISODE: int = 1
const APARTMENT_SCENE: String = "res://scenes/p1/e1/apartment.tscn"
const DIALOGUE_BOX_SCENE: String = "res://ui/dialogue/dialogue_box.tscn"
const END_SCENE_ID: String = "e1_road"
const TITLE_SECONDS: float = 4.0

var runner: OOTStoryRunner = OOTStoryRunner.new()
var apartment: OOTApartment = null
var stage: String = "boot"

var _layer: CanvasLayer
var _card: ColorRect
var _card_title: Label
var _card_sub: Label
var _card_skip: bool = false
var _opening_box: OOTDialogueBox


func _ready() -> void:
	_build_card()
	_opening_box = (load(DIALOGUE_BOX_SCENE) as PackedScene).instantiate() as OOTDialogueBox
	_opening_box.opaque_background = true
	_layer.add_child(_opening_box)
	_opening_box.finished.connect(_on_open_finished)
	stage = "cold_open"
	runner.start(PART_ID, EPISODE)  # enters e1_open
	_opening_box.begin(runner, "e1_apt")


func _build_card() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_card = ColorRect.new()
	_card.color = Color.BLACK
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_card)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 44)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_title.position.y = -30
	_card.add_child(_card_title)
	_card_sub = Label.new()
	_card_sub.add_theme_font_size_override("font_size", 26)
	_card_sub.modulate = Color(1, 1, 1, 0.7)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_sub.position.y = 40
	_card.add_child(_card_sub)


func title_text() -> String:
	var db: Node = OOTServices.db()
	return str(db.get_part_name(PART_ID)).to_upper()


func episode_text() -> String:
	var db: Node = OOTServices.db()
	var eps: Array = db.get_episodes(PART_ID)
	var title: String = str((eps[EPISODE - 1] as Dictionary).get("title", "")).to_upper()
	return "EPISODE %d — %s" % [EPISODE, title]


func _on_open_finished(_scene_id: String) -> void:
	if stage != "cold_open":
		return
	stage = "title"
	_opening_box.queue_free()
	_card_title.text = title_text()
	_card_sub.text = episode_text()
	_card.visible = true
	_card_skip = false
	await get_tree().create_timer(TITLE_SECONDS).timeout
	_start_apartment()


func _start_apartment() -> void:
	if stage != "title":
		return
	stage = "apartment"
	_card.visible = false
	apartment = (load(APARTMENT_SCENE) as PackedScene).instantiate() as OOTApartment
	apartment.set_runner(runner)  # parked at e1_apt
	apartment.call_finished.connect(_on_call_finished)
	add_child(apartment)


func _on_call_finished(_scene_id: String) -> void:
	stage = "end"
	if apartment != null:
		apartment.queue_free()
		apartment = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var road: OOTScene = runner.scene
	_card_title.text = "To be continued: County Road 20"
	_card_sub.text = "%s — %s" % [road.place, road.time] if road != null else ""
	_card.visible = true
	flow_finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if stage == "title" and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_start_apartment()
		get_viewport().set_input_as_handled()
