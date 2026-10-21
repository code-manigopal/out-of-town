class_name OOTWindsorExterior
extends Node3D
## Episode 1 exit sequence (design/ep01-county-roads.md beat 3 -> 4): Mani leaves the upper flat (number 2) with the
## duffel and the car keys. Verandah -> turn left to the stairs -> the building's main door (mailboxes 1 and 2, flat
## numbers on the flat doors) -> the busy Windsor street -> the side alley (dumpster, graffiti slots, puddles, poles) ->
## the back lot (three parked cars, his is the grey sedan) -> trunk -> driver's seat -> ignition -> drive out of the lot,
## left onto the back street, a couple of blocks following the navigation chevrons -> fade to the e1_road card.
##
## The authored layout is in windsor_exterior.tscn; the streets, houses, traffic and route are built by
## exterior_world.gd; the car is oot_car.gd; the chevrons are oot_nav_arrows.gd. Story text (the card's place and time)
## comes from the StoryDB scene `e1_road`; the few UI hints below are placeholders until Mani's inner-voice lines exist.

## The end of the drive: the fade to the "County Road 20, Essex County - 10:10" card is done and the next beat can start.
signal drive_reached_county_road
signal stage_changed(new_stage: StringName)
signal trunk_loaded
signal seated
signal engine_started

const PART_ID: String = "p1"
const ROAD_SCENE_ID: String = "e1_road"
const SND_AMBIENCE: String = "res://audio/ambience/city_morning.ogg"
const GRAFFITI_DIR: String = "res://environments/windsor/exterior/graffiti/"
const DUFFEL_MODEL: String = "res://environments/windsor/apartment/models/duffel_zipped.glb"
## Bay centres (x) of the two other cars in the back lot; Mani's sedan stands in the bay at x -0.8.
## Mural slots on the alley wall: z along the wall, height of the centre, width in metres.
const GRAFFITI_LAYOUT: Array[Vector4] = [Vector4(3.15, 1.55, 2.5, 0.0), Vector4(0.85, 2.0, 2.1, 0.0), Vector4(-1.55, 2.15, 2.3, 0.0), Vector4(-3.55, 1.75, 1.7, 0.0)]
const LOT_BAY_X: Array[float] = [-6.4, 4.8]
const FADE_SECONDS: float = 1.3
const CARD_SECONDS: float = 2.6
## Where Mani stands to push the main door (the clip then walks him 0.86 m through it).
const MAIN_DOOR_MARK: Vector3 = Vector3(-3.9, 0.0, 10.78)
const PLAYER_START: Vector3 = Vector3(2.0, 2.93, 5.25)
## Sun: altitude 28 degrees, azimuth 145 (south-east), 10:10 on an early-November morning (Windsor, EST); the HDRI sun is aligned to it.
const SUN_ALT_DEG: float = 28.8
const SUN_AZ_DEG: float = 145.0
## Placeholder hints (TODO: replace with Mani's inner-voice lines from the story data, design doc section 11).
const HINT_CAR: String = "My car's out back."
const HINT_DRIVE: String = "W / S throttle and brake, A / D steer"

@export var play_audio: bool = true
@export var show_hints: bool = true
## Standalone use (the scene run on its own, tests, renders): give Mani the duffel and the keys.
@export var standalone_start: bool = true

var stage: StringName = &"verandah"
var duffel: OOTInteractable = null
var trunk_done: bool = false
var is_seated: bool = false
var engine_is_on: bool = false
var drive_finished: bool = false
var busy: bool = false
## The duffel's resting copy: on the ground, then in the trunk.
var bag: Node3D = null

var _pending_duffel: OOTInteractable = null
var _ambience: AudioStreamPlayer
var _card_layer: CanvasLayer
var _card_fade: ColorRect
var _card_title: Label
var _drive_active: bool = false
var _seat_shot: Marker3D
var _graffiti_tex: Dictionary = {}

@onready var player: OOTPlayer = %Player
@onready var hud: OOTHud = %Hud
@onready var main_door: OOTDoor = %MainDoor
@onready var car: OOTCar = %Sedan
@onready var world: OOTExteriorWorld = %World
@onready var arrows: OOTNavArrows = %NavArrows
@onready var stairs_volume: Area3D = %StairsVolume
@onready var sun: DirectionalLight3D = %Sun


func _ready() -> void:
	_apply_sun()
	_setup_collisions()
	_setup_lot()
	_setup_graffiti()
	_setup_ui()
	_setup_audio()
	_setup_player()
	_setup_car()
	_setup_card()
	if _pending_duffel != null:
		_adopt_duffel(_pending_duffel)
	elif standalone_start:
		_adopt_duffel(_make_placeholder_duffel())
	_refresh_interactables()


## Called by the episode flow before the scene enters the tree: the duffel Mani carried out of the apartment.
func carry_in(item: OOTInteractable) -> void:
	_pending_duffel = item
	if is_inside_tree() and player != null:
		_adopt_duffel(item)


func _apply_sun() -> void:
	var az: float = deg_to_rad(SUN_AZ_DEG)
	var alt: float = deg_to_rad(SUN_ALT_DEG)
	var to_sun: Vector3 = Vector3(sin(az) * cos(alt), sin(alt), -cos(az) * cos(alt))
	sun.global_transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)


## Trimesh collision for the kit's solid parts: walls, verandah, fences, neighbours and the alley clutter.
func _setup_collisions() -> void:
	var solid: Array[String] = ["Collide_Walls", "Collide_Verandah", "Collide_Neighbours", "Collide_Fences", "Dumpster",
		"AlleyClutter", "UtilityPoles"]
	for n: Node in find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not (String(mi.name) in solid):
			continue
		mi.create_trimesh_collision()
		for c: Node in mi.get_children():
			if c is StaticBody3D:
				c.set_meta("surface", "wood" if String(mi.name) == "Collide_Verandah" else "concrete")
	_remap_kit()


func _remap_kit() -> void:
	for root_name: String in ["Building", "Neighbours", "AlleyProps"]:
		var r: Node = get_node_or_null(root_name)
		if r != null:
			world._remap(r)
	var leaf: Node = main_door.get_node_or_null("Leaf")
	if leaf != null:
		world._remap(leaf)


## The back lot: the two other parked cars (a hatchback and an SUV) next to Mani's grey sedan.
func _setup_lot() -> void:
	var lot: Node3D = Node3D.new()
	lot.name = "LotCars"
	add_child(lot)
	# nose-in bays 2.8 m wide (the white bay lines are drawn by the world): Mani's car in the middle bay, the two others
	# a bay away on either side so the driver's door has room
	var a: Node3D = world.place("traffic_hatchback", Vector3(LOT_BAY_X[0], 0.0, -10.5), 180.0, lot)
	var c: Node3D = world.place("traffic_suv", Vector3(LOT_BAY_X[1], 0.0, -10.5), 180.0, lot)
	if a != null:
		world.paint(a, Color(0.55, 0.14, 0.12))
		world.box_body(lot, "ParkedCol_A", Vector3(LOT_BAY_X[0], 0.8, -10.5), Vector3(1.9, 1.6, 4.3))
	if c != null:
		world.paint(c, Color(0.86, 0.86, 0.84))
		world.box_body(lot, "ParkedCol_C", Vector3(LOT_BAY_X[1], 0.9, -10.5), Vector3(1.95, 1.8, 4.7))


func _setup_ui() -> void:
	var packed: Variant = hud.get("_packed")
	if packed is Label:
		(packed as Label).visible = false
	player.interactor.carried_changed.connect(_on_carried_changed)


func _setup_audio() -> void:
	if not play_audio:
		return
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "CityAmbience"
	_ambience.bus = &"Ambience"
	_ambience.volume_db = -4.0
	if ResourceLoader.exists(SND_AMBIENCE):
		var s: AudioStream = (load(SND_AMBIENCE) as AudioStream).duplicate() as AudioStream
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_ambience.stream = s
		add_child(_ambience)
		_ambience.play()


func _setup_player() -> void:
	# traffic yields to Mani on foot and to his car (OOTTrafficCar looks for this group)
	player.add_to_group(&"traffic_obstacle")
	player.set_meta("traffic_radius", 0.4)
	car.add_to_group(&"traffic_obstacle")
	car.set_meta("traffic_radius", 1.1)
	player.global_position = PLAYER_START
	player.yaw = deg_to_rad(90.0)            # facing west along the verandah
	player.body.rotation.y = player.yaw
	player.default_surface = "wood"
	main_door.activated.connect(_on_main_door_activated)
	stairs_volume.body_entered.connect(_on_stairs_entered)
	stairs_volume.body_exited.connect(_on_stairs_exited)


func _setup_car() -> void:
	car.play_audio = play_audio
	car.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-0.8, 0.02, -10.5))
	car.engine_started.connect(_on_engine_started)
	car.trunk_use.interacted.connect(_on_trunk_used)
	car.door_use.interacted.connect(_on_car_door_used)
	car.ignition.interacted.connect(_on_ignition_used)
	car.route = world.route
	arrows.setup(world.route, car)
	arrows.visible = false
	_seat_shot = Marker3D.new()
	_seat_shot.name = "SeatShot"
	car.add_child(_seat_shot)
	# a locked-off shot from in front of the bonnet through the windshield at Mani and the lit dash (design 4.8 adapted:
	# the windshield is the only unobstructed angle on the driver in this model)
	var from: Vector3 = Vector3(-1.25, 1.5, 3.7)
	var look: Vector3 = Vector3(0.3, 1.05, 0.15)
	_seat_shot.transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)


func _setup_card() -> void:
	_card_layer = CanvasLayer.new()
	_card_layer.name = "CardLayer"
	_card_layer.layer = 20
	add_child(_card_layer)
	_card_fade = ColorRect.new()
	_card_fade.color = Color.BLACK
	_card_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_fade.modulate.a = 0.0
	_card_layer.add_child(_card_fade)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 40)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_fade.add_child(_card_title)


# --- the duffel -----------------------------------------------------------------------------

func _make_placeholder_duffel() -> OOTInteractable:
	var it: OOTInteractable = OOTInteractable.new()
	it.name = "Duffel"
	it.item_id = "duffel"
	it.display_name = "duffel bag"
	it.kind = OOTInteractable.Kind.PICKUP
	it.set_meta("carry_two_hand", true)
	var vis: Node3D = Node3D.new()
	vis.name = "Visual"
	it.add_child(vis)
	if ResourceLoader.exists(DUFFEL_MODEL):
		vis.add_child((load(DUFFEL_MODEL) as PackedScene).instantiate())
	else:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.75, 0.3, 0.3)
		mi.mesh = bm
		vis.add_child(mi)
	var state: Node = OOTServices.state()
	if state != null:
		if state.get_part() != PART_ID:
			state.start_part(PART_ID)
		state.set_flag("has_car_keys")
	return it


## Puts the duffel (an OOTInteractable with a Visual child) in Mani's hands and keeps it alive under this scene.
func _adopt_duffel(item: OOTInteractable) -> void:
	duffel = item
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	add_child(item)
	item.set_active(false)
	player.interactor.carried = item
	player.interactor.carried_changed.emit(item)


func is_carrying_duffel() -> bool:
	return duffel != null and player.interactor.carried == duffel


func _on_carried_changed(item: OOTInteractable) -> void:
	hud.set_carried("" if item == null else item.display_name)
	_refresh_interactables()


# --- stage tracking ------------------------------------------------------------------------------

## The stage the player's position puts them in (pure function of the position, for tests).
static func stage_for(p: Vector3) -> StringName:
	if p.y > 2.0 and p.z < 6.1:
		return &"verandah"
	if p.x > -5.45 and p.x < -2.95 and p.z > 5.9 and p.z < 9.65 and p.y > 0.0:
		return &"stairs"
	if p.x > -5.45 and p.x < -2.95 and p.z >= 9.6 and p.z < 11.7:
		return &"lobby"
	if p.z < -4.5:
		return &"lot"
	if p.x > 5.0 and p.x < 8.6 and p.z > -4.5 and p.z < 12.6:
		return &"alley"
	if p.z >= 11.7:
		return &"street"
	return &"yard"


func _set_stage(s: StringName) -> void:
	if s == stage:
		return
	stage = s
	stage_changed.emit(s)
	if s == &"lot" and show_hints and hud != null:
		hud.show_toast(HINT_CAR, 3.0)
	_refresh_interactables()


func _physics_process(_delta: float) -> void:
	if _drive_active and not drive_finished and arrows.progress >= arrows.get_route_length() - 7.0:
		finish_drive()
	if is_seated or busy:
		return
	_set_stage(stage_for(player.global_position))
	if _in_stairs:
		player.set_stairs_down(player.velocity.z > 0.2)


var _in_stairs: bool = false


func _on_stairs_entered(body: Node3D) -> void:
	if body == player:
		_in_stairs = true


func _on_stairs_exited(body: Node3D) -> void:
	if body == player:
		_in_stairs = false
		player.set_stairs_down(false)


func _refresh_interactables() -> void:
	if car == null or player == null:
		return
	var near_lot: bool = stage == &"lot"
	car.trunk_use.set_active(near_lot and is_carrying_duffel() and not trunk_done and not busy)
	car.door_use.set_active(near_lot and trunk_done and not is_seated and not busy)
	car.ignition.set_active(is_seated and not engine_is_on and not busy)


# --- the main door ---------------------------------------------------------------------------------

func _on_main_door_activated() -> void:
	if busy:
		return
	if main_door.is_open():
		main_door.close()
		return
	if player.global_position.z > main_door.global_position.z + 0.2:
		main_door.open()           # standing outside: just open it
		return
	_run_push_door()


func _run_push_door() -> void:
	busy = true
	player.lock_input()
	await _move_player_to(MAIN_DOOR_MARK, PI, 0.3)
	player.unlock_input()
	player.play_action(&"door_open_push", true, true)
	await get_tree().create_timer(0.18).timeout
	main_door.open()
	await _action_done()
	busy = false
	_refresh_interactables()


## Slides the player to `pos` (ground position) and turns the body to `yaw` (body.rotation.y) over `seconds`.
func _move_player_to(pos: Vector3, yaw: float, seconds: float) -> void:
	player.velocity = Vector3.ZERO
	var from: Vector3 = player.global_position
	var to: Vector3 = Vector3(pos.x, from.y if pos.y == 0.0 else pos.y, pos.z)
	var from_yaw: float = player.body.rotation.y
	var t: float = 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var u: float = clampf(t / seconds, 0.0, 1.0)
		player.global_position = from.lerp(to, u)
		player.body.rotation.y = lerp_angle(from_yaw, yaw, u)
	player.global_position = to
	player.body.rotation.y = yaw
	player.yaw = yaw


# --- trunk ------------------------------------------------------------------------------------------

func _on_trunk_used(_by: Node) -> void:
	if busy or trunk_done or not is_carrying_duffel():
		return
	_run_trunk()


## Duffel into the trunk: set it down (put_down), open the trunk (trunk_open), lift it in (reach_low), close (trunk_close).
func _run_trunk() -> void:
	busy = true
	_refresh_interactables()
	player.lock_input()
	var rear: Vector3 = car.to_global(Vector3(0.0, 0.0, OOTCar.REAR_Z))
	var back: Vector3 = car.global_basis.z                         # points from the rear toward the car front
	var mark: Vector3 = rear - back * 0.82
	mark.y = car.global_position.y
	await _move_player_to(mark, atan2(back.x, back.z) + PI, 0.35)   # body forward = along the car
	player.unlock_input()
	# 1. set the bag on the ground just in front of the bumper
	var held: Node3D = player.get_carry_holder()
	bag = held.duplicate() as Node3D if held != null else null
	player.play_action(&"put_down", true, false)
	await get_tree().create_timer(0.4).timeout
	if bag != null:
		add_child(bag)
		if held != null:
			bag.global_transform = held.global_transform
		var h: float = _holder_height(bag)
		var rest: Vector3 = rear - back * 0.75 + car.global_basis.x * 0.7      # on the ground at his side, beside the bumper
		rest.y = h * 0.5
		var tw: Tween = create_tween()
		tw.tween_property(bag, "global_position", rest, 0.18)
	player.interactor.clear_carried()
	await _action_done()
	# 2. open the trunk
	player.play_action(&"trunk_open", true, true)
	await get_tree().create_timer(0.38).timeout
	car.open_trunk(0.57)
	await _action_done()
	# 3. lift the bag into the trunk
	player.play_action(&"reach_low", true, false)
	await get_tree().create_timer(0.45).timeout
	if bag != null:
		bag.reparent(car, true)
		var h2: float = _holder_height(bag)
		var target: Vector3 = car.trunk_cargo.position + Vector3(0.0, h2 * 0.5, 0.0)
		var start: Vector3 = bag.position
		var tw2: Tween = create_tween()
		tw2.tween_method(func(u: float) -> void:
			var q: Vector3 = start.lerp(target, u)
			q.y += sin(u * PI) * 0.35
			bag.position = q, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
		tw2.parallel().tween_property(bag, "quaternion", Basis(Vector3.UP, PI).get_rotation_quaternion(), 0.55)
		await tw2.finished
	await _action_done()
	# 4. close it
	player.play_action(&"trunk_close", true, false)
	await get_tree().create_timer(0.3).timeout
	car.close_trunk(0.46)
	await _action_done()
	trunk_done = true
	busy = false
	_refresh_interactables()
	trunk_loaded.emit()


## Waits for the player's current action clip, unless it already finished: awaiting the
## signal after it fired would hang the sequence (the trunk never closed).
func _action_done() -> void:
	if player.is_acting():
		await player.action_finished


## Height of the bag's meshes (world metres).
func _holder_height(n: Node3D) -> float:
	var top: float = -INF
	var bottom: float = INF
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		top = maxf(top, b.end.y)
		bottom = minf(bottom, b.position.y)
	return maxf(top - bottom, 0.1) if top > bottom else 0.3


# --- the car: door, seat, ignition ------------------------------------------------------------

func _on_car_door_used(_by: Node) -> void:
	if busy or is_seated or not trunk_done:
		return
	_run_enter_car()


func _run_enter_car() -> void:
	busy = true
	_refresh_interactables()
	player.lock_input()
	var seat: Vector3 = car.to_global(OOTCar.SEAT_ANCHOR_POS)
	var out: Vector3 = car.global_basis.x                   # the driver's side is the car's +X
	out.y = 0.0
	out = out.normalized()
	var start: Vector3 = seat + out * 0.75
	start.y = car.global_position.y
	await _move_player_to(start, atan2(out.x, out.z), 0.45)
	player.unlock_input()
	player.play_action(&"car_enter_driver", true, true)
	await get_tree().create_timer(0.55).timeout
	car.open_door(0.4)
	await get_tree().create_timer(1.2).timeout           # the clip's 'seated' event is at 1.75
	player.set_pose_override(&"sit_drive", 0.15)
	await _action_done()
	_seat_player()
	await get_tree().create_timer(0.25).timeout
	car.close_door(0.4)
	busy = false
	is_seated = true
	_set_stage(&"seated")
	_refresh_interactables()
	if show_hints:
		hud.show_toast("Press E to start the engine", 4.0)
	seated.emit()


## Mani becomes part of the car: parented to the seat anchor, physics off, collision off, facing car-forward.
func _seat_player() -> void:
	player.set_pose_override(&"sit_drive", 0.0)
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	car.seat_anchor.add_child(player)
	player.transform = Transform3D.IDENTITY
	player.body.rotation.y = PI                    # the car's forward is +Z, the body's forward is -Z
	player.body.position = Vector3.ZERO
	player.use_shot(_seat_shot)


## E works for the car steps without aiming the reticle: seated, the camera sits outside the
## windshield and the player's interactor is off, and the driver's door is easy to miss.
func _unhandled_input(event: InputEvent) -> void:
	if busy or car == null or player == null or not event.is_action_pressed("interact"):
		return
	if is_seated and not engine_is_on:
		_on_ignition_used(null)
		get_viewport().set_input_as_handled()
	elif stage == &"lot" and trunk_done and not is_seated:
		var door: Vector3 = car.to_global(OOTCar.SEAT_ANCHOR_POS) + car.global_basis.x.normalized() * 0.75
		if player.global_position.distance_to(door) < 3.0:
			_run_enter_car()
			get_viewport().set_input_as_handled()


func _on_ignition_used(_by: Node) -> void:
	if not is_seated or engine_is_on or car.starting:
		return
	car.ignition.set_active(false)
	car.start_engine()


func _on_engine_started() -> void:
	engine_is_on = true
	player.release_shot()
	car.use_player_input = true
	car.activate_chase_camera()
	arrows.visible = true
	_drive_active = true
	_set_stage(&"driving")
	if show_hints:
		hud.show_toast(HINT_DRIVE, 5.0)
	engine_started.emit()


# --- the end of the drive -------------------------------------------------------------------------

## Fade out, show the e1_road place/time card ("County Road 20, Essex County - 10:10") and emit drive_reached_county_road.
func finish_drive() -> void:
	if drive_finished:
		return
	drive_finished = true
	_drive_active = false
	car.use_player_input = false
	car.auto_cruise = false
	car.set_ai_inputs(0.0, 0.0, 0.5)
	var tw: Tween = create_tween()
	tw.tween_property(_card_fade, "modulate:a", 1.0, FADE_SECONDS)
	await tw.finished
	car.stop_engine()
	_card_title.text = road_card_text()
	await get_tree().create_timer(CARD_SECONDS).timeout
	stage = &"done"
	stage_changed.emit(stage)
	drive_reached_county_road.emit()


## "County Road 20, Essex County - 10:10", from the e1_road scene's place and time.
func road_card_text() -> String:
	var db: Node = OOTServices.db()
	if db != null:
		var sc: OOTScene = db.get_scene(PART_ID, ROAD_SCENE_ID)
		if sc != null:
			return "%s — %s" % [sc.place, sc.time]
	return "County Road 20, Essex County — 10:10"


# --- graffiti slots ---------------------------------------------------------------------------------

## Decal nodes Graffiti_1..4: the paint cut out of graffiti/graffiti_N.png (graffiti_N_alpha.png, brick and ground keyed
## to alpha by art_source/environments/windsor/exterior/tools/key_graffiti.py), laid on the east alley wall (x 8.6) at mural
## size; falls back to the original image, then to a procedural placeholder tag.
func _setup_graffiti() -> void:
	for i: int in range(1, 5):
		var d: Decal = find_child("Graffiti_%d" % i, true, false) as Decal
		if d == null:
			continue
		var tex: Texture2D = _load_graffiti("%sgraffiti_%d_alpha.png" % [GRAFFITI_DIR, i])
		var alpha_cut: bool = tex != null
		if tex == null:
			tex = _load_graffiti("%sgraffiti_%d.png" % [GRAFFITI_DIR, i])
		if tex == null:
			tex = make_tag_texture(i)
		d.texture_albedo = tex
		_graffiti_tex[i] = tex
		d.set_meta("alpha_cut", alpha_cut)
		var spec: Vector4 = GRAFFITI_LAYOUT[i - 1]      # wall z, centre height, width, (unused)
		var aspect: float = float(tex.get_height()) / float(tex.get_width())
		var width: float = spec.z
		var height: float = width * aspect
		# decal basis: local X = +Z (along the wall, to the viewer's right), local Y = -X (the projection axis, into the
		# wall), local Z = down; the box is a thin slab centred on the wall face so it never paints the dumpster or fences
		d.global_transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)), Vector3(8.6, spec.y, spec.x))
		d.size = Vector3(width, 0.14, height)
		d.albedo_mix = 1.0
		d.normal_fade = 0.2
		d.modulate = Color(0.94, 0.94, 0.92)
		d.upper_fade = 0.02
		d.lower_fade = 0.02


func _load_graffiti(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(path)
		if img != null:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null


## A simple abstract spray-paint tag (strokes, drips, shapes), transparent background. No letters, no names.
static func make_tag_texture(slot: int, size: Vector2i = Vector2i(768, 384)) -> ImageTexture:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1000 + slot
	var pal: Array[Color] = [Color(0.25, 0.95, 0.55), Color(1.0, 0.5, 0.15), Color(0.95, 0.25, 0.7), Color(0.3, 0.8, 1.0),
		Color(1.0, 0.9, 0.25), Color(0.96, 0.96, 0.94)]
	var c1: Color = pal[(slot * 2) % pal.size()]
	var c2: Color = pal[(slot * 2 + 3) % pal.size()]
	var dark: Color = Color(0.05, 0.05, 0.07, 0.95)
	var w: float = float(size.x)
	var h: float = float(size.y)
	match slot % 4:
		1:   # looping signature + underline swoosh
			var pts: Array[Vector2] = []
			for k: int in 220:
				var t: float = float(k) / 219.0 * TAU * 2.2
				pts.append(Vector2(w * 0.5 + (w * 0.30) * cos(t * 0.5 + 0.4) + w * 0.06 * cos(t * 2.3), h * 0.45 + h * 0.2 * sin(t) + h * 0.05 * sin(t * 3.0)))
			_stroke(img, pts, 24.0, dark)
			_stroke(img, pts, 16.0, c1)
			var sw: Array[Vector2] = []
			for k2: int in 60:
				var u: float = float(k2) / 59.0
				sw.append(Vector2(w * (0.12 + 0.76 * u), h * (0.84 - 0.08 * sin(u * PI))))
			_stroke(img, sw, 18.0, dark)
			_stroke(img, sw, 11.0, c2)
		2:   # arrow with stars
			var arrow: Array[Vector2] = [Vector2(w * 0.1, h * 0.55), Vector2(w * 0.6, h * 0.55), Vector2(w * 0.6, h * 0.3), Vector2(w * 0.92, h * 0.6),
				Vector2(w * 0.6, h * 0.9), Vector2(w * 0.6, h * 0.65), Vector2(w * 0.1, h * 0.65), Vector2(w * 0.1, h * 0.55)]
			_stroke(img, arrow, 24.0, dark)
			_stroke(img, arrow, 16.0, c1)
			for s: Vector2 in [Vector2(w * 0.2, h * 0.25), Vector2(w * 0.45, h * 0.18), Vector2(w * 0.78, h * 0.15)]:
				var star: Array[Vector2] = []
				for k3: int in 6:
					var a: float = float(k3 * 2 % 5) / 5.0 * TAU - PI / 2.0
					star.append(s + Vector2(cos(a), sin(a)) * 34.0)
				_stroke(img, star, 16.0, dark)
				_stroke(img, star, 9.0, c2)
		3:   # overlapping bubble outlines
			for k4: int in 5:
				var cc: Vector2 = Vector2(w * (0.2 + 0.15 * k4), h * (0.45 + 0.1 * sin(float(k4) * 2.0)))
				var r: float = 70.0 + 14.0 * float(k4 % 3)
				var circle: Array[Vector2] = []
				for k5: int in 41:
					var a2: float = float(k5) / 40.0 * TAU
					circle.append(cc + Vector2(cos(a2), sin(a2)) * r)
				_stroke(img, circle, 22.0, dark)
				_stroke(img, circle, 14.0, c1 if k4 % 2 == 0 else c2)
		_:   # zigzag crown
			var zz: Array[Vector2] = []
			for k6: int in 9:
				zz.append(Vector2(w * (0.12 + 0.095 * float(k6)), h * (0.35 if k6 % 2 == 0 else 0.7)))
			_stroke(img, zz, 24.0, dark)
			_stroke(img, zz, 16.0, c1)
			var base: Array[Vector2] = [Vector2(w * 0.1, h * 0.85), Vector2(w * 0.9, h * 0.85)]
			_stroke(img, base, 20.0, dark)
			_stroke(img, base, 12.0, c2)
			for k7: int in 4:
				_brush(img, Vector2(w * (0.2 + 0.2 * k7), h * 0.2), 12.0, c2)
	# drips
	for k8: int in 7:
		var x: float = rng.randf_range(w * 0.12, w * 0.88)
		var y0: float = rng.randf_range(h * 0.3, h * 0.8)
		var len_: float = rng.randf_range(18.0, 80.0)
		var drip: Array[Vector2] = [Vector2(x, y0), Vector2(x + rng.randf_range(-2.0, 2.0), y0 + len_)]
		_stroke(img, drip, 6.0, c1 if k8 % 2 == 0 else c2)
	return ImageTexture.create_from_image(img)


static func _brush(img: Image, p: Vector2, r: float, col: Color) -> void:
	var x0: int = maxi(int(p.x - r), 0)
	var x1: int = mini(int(p.x + r), img.get_width() - 1)
	var y0: int = maxi(int(p.y - r), 0)
	var y1: int = mini(int(p.y + r), img.get_height() - 1)
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var d: float = Vector2(x, y).distance_to(p)
			if d > r:
				continue
			var a: float = clampf((r - d) / (r * 0.35), 0.0, 1.0) * col.a
			var dst: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, dst.blend(Color(col.r, col.g, col.b, a)))


static func _stroke(img: Image, pts: Array[Vector2], r: float, col: Color) -> void:
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps: int = maxi(int(a.distance_to(b) / (r * 0.4)), 1)
		for k: int in steps + 1:
			_brush(img, a.lerp(b, float(k) / float(steps)), r, col)


# --- test / render helpers ---------------------------------------------------------------------------

func debug_teleport_player(pos: Vector3, yaw: float = 0.0) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.yaw = yaw
	player.body.rotation.y = yaw
