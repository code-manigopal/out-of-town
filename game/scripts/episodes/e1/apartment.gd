class_name OOTApartment
extends Node3D
## G1: Mani's apartment. Free exploration, inspect objects, pack three items
## into the duffel, then the laptop rings and the video call (e1_call) plays
## through the story runner. All story text comes from StoryDB.

signal item_packed(item_id: String, count: int, total: int)
signal all_packed
signal laptop_ringing
signal call_started
signal call_finished(scene_id: String)

const PART_ID: String = "p1"
const INTRO_SCENE: String = "e1_apt"

## Seconds the laptop may ring unanswered before the call starts by itself.
@export var auto_answer_seconds: float = 90.0
## Play the e1_apt narration when the apartment loads.
@export var play_intro: bool = true

## Shared with the episode flow; created here when the scene runs on its own.
var runner: OOTStoryRunner = null
var packed_ids: Array[String] = []
var is_ringing: bool = false
var call_active: bool = false

@onready var player: OOTPlayer = %Player
@onready var hud: OOTHud = %Hud
@onready var dialogue: OOTDialogueBox = %DialogueBox
@onready var inspect: OOTInspectView = %InspectView
@onready var laptop: OOTInteractable = %Laptop
@onready var duffel: OOTInteractable = %Duffel
@onready var call_trigger: OOTStoryTrigger = %CallTrigger
@onready var _ring_label: Label3D = %LaptopRingLabel
@onready var _timer: Timer = %AutoAnswerTimer


func _ready() -> void:
	player.yaw = deg_to_rad(-90.0)
	player.body.rotation.y = player.yaw
	var inter: OOTInteractor = player.interactor
	inter.prompt_changed.connect(hud.set_prompt)
	inter.pickup_taken.connect(_on_pickup_taken)
	inter.carried_changed.connect(_on_carried_changed)
	inter.inspect_requested.connect(_on_inspect_requested)
	inter.used.connect(_on_used)
	for ui: Node in [dialogue, inspect]:
		ui.connect("opened", player.lock_input)
		ui.connect("closed", player.unlock_input)
	call_trigger.started.connect(_on_call_started)
	call_trigger.target_reached.connect(_on_call_target_reached)
	_timer.one_shot = true
	_timer.timeout.connect(_answer_laptop)
	_ring_label.visible = false
	hud.set_packed(0, get_pack_total())
	_on_carried_changed(null)
	if runner == null:
		_ensure_runner()
	if play_intro:
		dialogue.begin(runner)


func _ensure_runner() -> void:
	var state: Node = OOTServices.state()
	if state != null and state.get_part() != PART_ID:
		state.start_part(PART_ID)
	runner = OOTStoryRunner.new()
	runner.part_id = PART_ID
	runner.enter(INTRO_SCENE)


func set_runner(p_runner: OOTStoryRunner) -> void:
	runner = p_runner


# --- Packing -----------------------------------------------------------------

func get_pack_items() -> Array[OOTInteractable]:
	var items: Array[OOTInteractable] = []
	for n: Node in find_children("*", "OOTInteractable", true, false):
		var it: OOTInteractable = n as OOTInteractable
		if it.pack_item:
			items.append(it)
	return items


func get_pack_total() -> int:
	return get_pack_items().size()


func get_packed_count() -> int:
	return packed_ids.size()


## Packs one item into the duffel. Returns false for unknown / already packed ids.
## The third item makes the laptop ring.
func pack_item(item_id: String) -> bool:
	if packed_ids.has(item_id):
		return false
	var found: OOTInteractable = null
	for it: OOTInteractable in get_pack_items():
		if it.item_id == item_id:
			found = it
	if found == null:
		return false
	packed_ids.append(item_id)
	found.set_active(false)
	var total: int = get_pack_total()
	hud.set_packed(packed_ids.size(), total)
	item_packed.emit(item_id, packed_ids.size(), total)
	if packed_ids.size() >= total:
		all_packed.emit()
		_start_ringing()
	return true


func _on_pickup_taken(target: OOTInteractable) -> void:
	hud.show_toast("Picked up: %s" % target.display_name)


func _on_carried_changed(item: OOTInteractable) -> void:
	hud.set_carried("" if item == null else item.display_name)
	if item != null:
		duffel.prompt_text = "Pack %s" % item.display_name
		duffel.kind = OOTInteractable.Kind.USE
	else:
		duffel.prompt_text = ""
		duffel.kind = OOTInteractable.Kind.INSPECT


func _on_inspect_requested(target: OOTInteractable) -> void:
	inspect.open_for(target)


func _on_used(target: OOTInteractable) -> void:
	if target == duffel:
		var carried: OOTInteractable = player.interactor.carried
		if carried != null and pack_item(carried.item_id):
			player.interactor.clear_carried()
	elif target == laptop and is_ringing:
		_answer_laptop()


# --- Ringing and the call ----------------------------------------------------

func _start_ringing() -> void:
	if is_ringing or call_active:
		return
	is_ringing = true
	laptop.kind = OOTInteractable.Kind.USE
	laptop.prompt_text = "Answer the call"
	_ring_label.visible = true
	hud.set_ringing(true)
	_timer.start(auto_answer_seconds)
	laptop_ringing.emit()


func _answer_laptop() -> void:
	if not is_ringing or call_active:
		return
	is_ringing = false
	call_active = true
	_timer.stop()
	_ring_label.visible = false
	hud.set_ringing(false)
	laptop.kind = OOTInteractable.Kind.INSPECT
	laptop.prompt_text = ""
	call_trigger.runner = runner
	call_trigger.fire()


func _on_call_started(r: OOTStoryRunner) -> void:
	call_started.emit()
	dialogue.begin(r, call_trigger.stop_scene_id)


func _on_call_target_reached(scene_id: String) -> void:
	call_active = false
	call_finished.emit(scene_id)


func _process(_delta: float) -> void:
	if is_ringing:
		_ring_label.modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 7.0))
