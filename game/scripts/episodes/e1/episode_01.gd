class_name OOTEpisode01
extends Node
## Episode 1 flow: opening montage (Windsor riverside, a busy road, the forest edge, Mani's house, Nila's voicemail over it)
## -> through the blinds into the apartment (pack, laptop call) -> building exterior and the drive (windsor_exterior.tscn);
## when the drive reaches the county road the screen fades and the title card "OUT OF TOWN: GREYHAVEN / EPISODE 1 - COUNTY
## ROADS" shows -> end card (until the next scenes exist).

signal flow_finished

const PART_ID: String = "p1"
const EPISODE: int = 1
const MONTAGE_SCENE: String = "res://scenes/p1/e1/opening_montage.tscn"
const APARTMENT_SCENE: String = "res://scenes/p1/e1/apartment.tscn"
const EXTERIOR_SCENE: String = "res://scenes/p1/e1/windsor_exterior.tscn"
const END_SCENE_ID: String = "e1_road"
const TITLE_SECONDS: float = 4.5

var runner: OOTStoryRunner = OOTStoryRunner.new()
var montage: OOTOpeningMontage = null
var apartment: OOTApartment = null
var exterior: OOTWindsorExterior = null
## "cold_open" (the montage), "apartment", "exterior", "title", "end".
var stage: String = "boot"

var _layer: CanvasLayer
var _card: ColorRect
var _card_title: Label
var _card_sub: Label


func _ready() -> void:
	_build_card()
	stage = "cold_open"
	runner.start(PART_ID, EPISODE)  # enters e1_open: the montage plays its voicemail lines itself
	montage = (load(MONTAGE_SCENE) as PackedScene).instantiate() as OOTOpeningMontage
	montage.finished.connect(_on_montage_finished)
	add_child(montage)


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


## The montage ended (or was skipped): the voicemail is in the journal; the camera continues through the blinds.
func _on_montage_finished(_skipped: bool) -> void:
	if stage != "cold_open":
		return
	OOTJournalData.grant("e1_voicemail")
	runner.continue_story()   # e1_open -> e1_apt (the apartment runs from there)
	if montage != null:
		montage.queue_free()
		montage = null
	_start_apartment()


func _start_apartment() -> void:
	if stage != "cold_open":
		return
	stage = "apartment"
	apartment = (load(APARTMENT_SCENE) as PackedScene).instantiate() as OOTApartment
	apartment.intro_through_window = true
	apartment.set_runner(runner)  # parked at e1_apt
	apartment.exit_requested.connect(_on_apartment_exit)
	add_child(apartment)


## Mani leaves through the front door with the bag and the car keys: cut to black, swap the apartment for the building
## exterior (the duffel stays in his hands, the `has_car_keys` flag lives in StoryState) and let him walk to the car and
## drive. If the exterior is missing the slice ends on the card below, as before.
func _on_apartment_exit() -> void:
	if stage != "apartment":
		return
	stage = "exterior"
	var item: OOTInteractable = apartment.duffel if apartment != null else null
	if item != null and item.get_parent() != null:
		item.get_parent().remove_child(item)       # keep the bag alive: it goes out with Mani
	_card_title.text = ""
	_card_sub.text = ""
	_card.visible = true
	await get_tree().create_timer(0.7).timeout
	if apartment != null:
		apartment.queue_free()
		apartment = null
	if not ResourceLoader.exists(EXTERIOR_SCENE):
		_show_end_card()
		return
	exterior = (load(EXTERIOR_SCENE) as PackedScene).instantiate() as OOTWindsorExterior
	exterior.standalone_start = item == null
	if item != null:
		exterior.carry_in(item)
	exterior.drive_reached_county_road.connect(_on_drive_reached)
	add_child(exterior)
	await get_tree().process_frame
	await get_tree().process_frame
	_card.visible = false


## The drive ended: the exterior has already faded to black on the way to the county road. The title card shows here, then the
## fallback end card follows until the next scenes exist.
func _on_drive_reached() -> void:
	stage = "title"
	if exterior != null:
		exterior.queue_free()
		exterior = null
	_card_title.text = title_text()
	_card_sub.text = episode_text()
	_card.color = Color.BLACK
	_card.visible = true
	await get_tree().create_timer(TITLE_SECONDS).timeout
	if stage == "title":
		_show_end_card()


func _show_end_card() -> void:
	stage = "end"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var road: OOTScene = runner.scene
	_card_title.text = "To be continued: County Road 20"
	_card_sub.text = "%s — %s" % [road.place, road.time] if road != null else ""
	_card.visible = true
	flow_finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if stage == "title" and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_show_end_card()
		get_viewport().set_input_as_handled()
