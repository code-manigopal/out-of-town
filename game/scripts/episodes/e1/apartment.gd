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
## The front door was used with the car keys in the pocket and the duffel in hand: leave for the building exterior.
signal exit_requested

const PART_ID: String = "p1"
const INTRO_SCENE: String = "e1_apt"
## Packed items are shown in the duffel at this scale (the bag is a 0.75 m weekend bag with clothes in one end).
const SLOT_ITEM_SCALE: float = 0.75

# Placeholder sound (CC0 / synthesised, see tools/voice/gen_sfx.sh).
const SND_RING: String = "res://audio/sfx/laptop_ring.ogg"
const SND_ROOM: String = "res://audio/ambience/apartment_morning.ogg"
const SND_PICKUP: String = "res://audio/sfx/kenney/impact/impactSoft_medium_000.ogg"
const SND_PUTDOWN: String = "res://audio/sfx/kenney/impact/impactSoft_heavy_000.ogg"
const SND_ZIP: String = "res://audio/sfx/kenney/interface/scratch_003.ogg"
const SND_KEYS: String = "res://audio/sfx/apartment/keys_jingle.ogg"

# Short UI hints for the locked front door.
# TODO: move these into the story data once Mani's inner-voice lines are written (design doc section 11).
const REASON_NEED_KEYS: String = "I need my car keys."
const REASON_NEED_BAG: String = "I'm not leaving without the bag."
## Where Mani stands to look in the bathroom mirror (facing the glass, west).
const MIRROR_STAND: Vector3 = Vector3(-0.62, 0.0, 1.8)

## Seconds the laptop may ring unanswered before the call starts by itself.
@export var auto_answer_seconds: float = 90.0
## Play the e1_apt narration when the apartment loads.
@export var play_intro: bool = true
## Show the floating object name tags (greybox debugging aid; the interaction prompt already names objects).
@export var show_debug_labels: bool = false

## Shared with the episode flow; created here when the scene runs on its own.
var runner: OOTStoryRunner = null
var packed_ids: Array[String] = []
var is_ringing: bool = false
var call_active: bool = false
## item_id -> the copy of that item's Visual shown sitting in its duffel slot.
var slot_items: Dictionary = {}
## Car keys are in Mani's pocket (also the StoryState flag `has_car_keys`).
var has_car_keys: bool = false
## True once the call is over: the zipped duffel can then be picked up (two hands) and carried out.
var duffel_ready: bool = false

var _ring_player: AudioStreamPlayer3D
var _room_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

@onready var player: OOTPlayer = %Player
@onready var hud: OOTHud = %Hud
@onready var dialogue: OOTDialogueBox = %DialogueBox
@onready var inspect: OOTInspectView = %InspectView
@onready var laptop: OOTInteractable = %Laptop
@onready var duffel: OOTInteractable = %Duffel
@onready var call_trigger: OOTStoryTrigger = %CallTrigger
@onready var exit_door: OOTDoor = %ExitDoor
@onready var car_keys: OOTInteractable = %CarKeys
@onready var mirror: OOTMirror = %Mirror
@onready var _ring_label: Label3D = %LaptopRingLabel
@onready var _timer: Timer = %AutoAnswerTimer


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--skip-intro"):
		play_intro = false  # debug/render aid: godot ... res://scenes/p1/e1/apartment.tscn -- --skip-intro
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
	for n: Node in find_children("NameLabel", "Label3D", true, false):
		(n as Label3D).visible = show_debug_labels
	hud.set_packed(0, get_pack_total())
	_setup_audio()
	_on_carried_changed(null)
	_setup_interactives()
	OOTApartmentContent.apply(self)
	OOTJournalData.grant("e1_goal_packing")
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
	_show_in_slot(found)
	var total: int = get_pack_total()
	hud.set_packed(packed_ids.size(), total)
	_play_sfx(SND_PUTDOWN)
	item_packed.emit(item_id, packed_ids.size(), total)
	if packed_ids.size() >= total:
		_zip_duffel()
		_play_sfx(SND_ZIP, 0.35)
		all_packed.emit()
		_start_ringing()
	return true


## Swaps the duffel's open model for the zipped one once everything is packed.
func get_slot(item_id: String) -> Marker3D:
	return duffel.get_node_or_null("Slots/Slot_%s" % item_id) as Marker3D


## Puts a copy of the item's model into its (empty) spot in the open duffel, resting on the packed layer.
func _show_in_slot(item: OOTInteractable) -> void:
	var slot: Marker3D = get_slot(item.item_id)
	var src: Node3D = item.get_visual()
	if slot == null or src == null or slot_items.has(item.item_id):
		return
	var copy: Node3D = src.duplicate() as Node3D
	copy.name = "Packed_%s" % item.item_id
	copy.visible = true
	slot.add_child(copy)
	copy.transform = Transform3D(Basis().scaled(Vector3.ONE * SLOT_ITEM_SCALE), Vector3.ZERO)
	# Snap: footprint centred on the marker, underside on the marker's height.
	var box: AABB = _world_aabb(copy)
	var target: Vector3 = slot.global_position
	copy.global_position += Vector3(target.x - (box.position.x + box.size.x * 0.5), target.y - box.position.y, target.z - (box.position.z + box.size.z * 0.5))
	slot_items[item.item_id] = copy


func _world_aabb(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _zip_duffel() -> void:
	var open_model: Node3D = duffel.get_node_or_null("Visual/ModelOpen") as Node3D
	var zipped_model: Node3D = duffel.get_node_or_null("Visual/ModelZipped") as Node3D
	if open_model != null and zipped_model != null:
		open_model.visible = false
		zipped_model.visible = true
	for c: Node3D in slot_items.values():
		c.visible = false


func _on_pickup_taken(target: OOTInteractable) -> void:
	_play_sfx(SND_PICKUP)
	hud.show_toast("Picked up: %s" % target.display_name)


func _on_carried_changed(item: OOTInteractable) -> void:
	hud.set_carried("" if item == null else item.display_name)
	if duffel_ready:
		_update_exit_lock()
		return
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


# --- Sound -------------------------------------------------------------------

## Builds the audio players in code (no scene nodes to keep in sync). Every
## stream is optional: a missing file just means silence.
func _setup_audio() -> void:
	_room_player = AudioStreamPlayer.new()
	_room_player.name = "RoomTone"
	_room_player.bus = &"Ambience"
	_room_player.volume_db = -6.0
	_room_player.stream = _load_looping(SND_ROOM)
	add_child(_room_player)
	if _room_player.stream != null:
		_room_player.play()
	_ring_player = AudioStreamPlayer3D.new()
	_ring_player.name = "LaptopRing"
	_ring_player.bus = &"SFX"
	_ring_player.unit_size = 4.0
	_ring_player.stream = _load_looping(SND_RING)
	laptop.add_child(_ring_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	_sfx_player.bus = &"SFX"
	add_child(_sfx_player)


func _load_looping(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = (load(path) as AudioStream).duplicate() as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


func _set_ring_sound(on: bool) -> void:
	if _ring_player == null or _ring_player.stream == null:
		return
	if on:
		_ring_player.play()
	else:
		_ring_player.stop()


func _play_sfx(path: String, delay: float = 0.0) -> void:
	if _sfx_player == null or not ResourceLoader.exists(path):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var one_shot: AudioStreamPlayer = AudioStreamPlayer.new()
	one_shot.bus = &"SFX"
	one_shot.stream = load(path) as AudioStream
	add_child(one_shot)
	one_shot.finished.connect(one_shot.queue_free)
	one_shot.play()


# --- Ringing and the call ----------------------------------------------------

func _start_ringing() -> void:
	if is_ringing or call_active:
		return
	is_ringing = true
	laptop.kind = OOTInteractable.Kind.USE
	laptop.prompt_text = "Answer the call"
	_ring_label.visible = true
	_set_ring_sound(true)
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
	_set_ring_sound(false)
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
	_enable_duffel_pickup()
	OOTJournalData.grant("e1_goal_leave")
	call_finished.emit(scene_id)


func _process(_delta: float) -> void:
	if is_ringing:
		_ring_label.modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 7.0))


# --- Interactive apartment: keys, front door, mirror ---------------------------------

func _setup_interactives() -> void:
	var state: Node = OOTServices.state()
	has_car_keys = state != null and state.has_flag("has_car_keys")
	if has_car_keys:
		car_keys.set_active(false)
	car_keys.interacted.connect(_on_keys_used)
	for d: Node in find_children("*", "OOTDoor", true, false):
		(d as OOTDoor).locked_attempt.connect(_on_door_locked)
	exit_door.activated.connect(_on_exit_door_used)
	mirror.view_entered.connect(_on_mirror_view_entered)
	mirror.view_exited.connect(_on_mirror_view_exited)
	_update_exit_lock()


## The keys go into Mani's pocket (never the hands): sets `has_car_keys` and shows a toast.
func _on_keys_used(_by: Node) -> void:
	take_car_keys()


func take_car_keys() -> bool:
	if has_car_keys:
		return false
	has_car_keys = true
	var state: Node = OOTServices.state()
	if state != null:
		state.set_flag("has_car_keys")
	car_keys.set_active(false)
	_play_sfx(SND_KEYS)
	hud.show_toast("Car keys in your pocket")
	_update_exit_lock()
	return true


## After the call the zipped bag can be lifted with both hands.
func _enable_duffel_pickup() -> void:
	if duffel_ready:
		return
	duffel_ready = true
	duffel.kind = OOTInteractable.Kind.PICKUP
	duffel.prompt_text = "Pick up the duffel bag"
	duffel.set_meta("carry_two_hand", true)   # the player's carry_duffel pose reads this
	_update_exit_lock()


func is_carrying_duffel() -> bool:
	return player.interactor.carried == duffel


## Locked with a reason until the keys are in the pocket and the duffel is in hand.
func _update_exit_lock() -> void:
	if not has_car_keys:
		exit_door.set_locked(true, REASON_NEED_KEYS)
	elif not is_carrying_duffel():
		exit_door.set_locked(true, REASON_NEED_BAG)
	else:
		exit_door.set_locked(false)


func _on_door_locked(reason: String) -> void:
	if not reason.is_empty():
		hud.show_toast(reason)


func _on_exit_door_used() -> void:
	if not (has_car_keys and is_carrying_duffel()):
		return
	exit_door.open()
	exit_requested.emit()


func _on_mirror_view_entered() -> void:
	player.lock_input()
	player.global_position = Vector3(MIRROR_STAND.x, player.global_position.y, MIRROR_STAND.z)
	player.velocity = Vector3.ZERO
	player.yaw = deg_to_rad(90.0)
	player.body.rotation.y = player.yaw


func _on_mirror_view_exited() -> void:
	player.unlock_input()
