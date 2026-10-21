class_name OOTCar
extends VehicleBody3D
## Mani's grey sedan (vehicles/sedan/sedan.glb). A VehicleBody3D under Jolt with arcade handling: speed-limited engine,
## speed-sensitive steering, lateral-grip assist and a low centre of mass so it cannot flip on a city street.
##
## The model faces +Z (the glTF front), which is also the VehicleBody3D forward. The driver (left) side is +X.
## Parts found by name in the model: Body, DriverDoor (hinge origin), TrunkLid (hinge origin), Wheel_FL/FR/RL/RR,
## SteeringWheel, DashLights, DashScreen, Headlights, Taillights. Child markers the episode script uses: SeatAnchor (root
## of the seated Mani, pitched back like a real driver), TrunkCargo (where the duffel rests), plus three
## OOTInteractables (TrunkUse, DoorUse, Ignition).
##
## Controls (while the engine is on and use_player_input): W throttle, S brake / reverse, A / D steer, Space handbrake,
## C toggles the driver's-eye interior camera and the chase camera.
## Auto-cruise (set_auto_cruise) is the agreed design for "phone or radio open": the car holds its lane and speed.
##
## Cameras: one Camera3D (chase_cam, kept under that name) serves every view. Modes: INTERIOR (driver's eye, the default
## once the engine is on), CHASE (behind the car) and, on top of either, the DASH close-up (set_dash_camera) for the
## radio. The head of the seated Mani is hidden from this camera only (render layer 2).

signal engine_started
signal engine_stopped
signal trunk_changed(is_open: bool)
signal door_changed(is_open: bool)
signal camera_changed(mode: int)

enum CamMode { INTERIOR, CHASE }

const MODEL_SCENE: String = "res://vehicles/sedan/sedan.glb"
const SND_DIR: String = "res://audio/sfx/exterior/"
## The tyre mesh radius (m). The physics radius (phys_wheel_radius) is larger, see below.
const WHEEL_RADIUS: float = 0.334
## Model-space hub heights/positions come from the Wheel_* nodes; the suspension origin sits this far above the hub.
const WHEEL_REST_LENGTH: float = 0.10
## Where the seated driver's root (feet plane, under the pelvis) sits in car space, and how far it is pitched back (about
## X, head towards the rear). Mani's sit_drive pose then puts his hips on the cushion at (0.365, 0.575, -0.02), his heels
## on the floor (y 0.20) and his head top about 5 cm under the roof lining. Derived in tools/blender/build_sedan.py.
const SEAT_ANCHOR_POS: Vector3 = Vector3(0.365, 0.0485, 0.2137)
const SEAT_ANCHOR_PITCH_DEG: float = 20.0
## The driver's eyes, the wheel hub and the wheel's spin axis (tilted 22 degrees, pointing at the driver) in car space.
const EYE_POS: Vector3 = Vector3(0.365, 1.295, -0.209)
const STEER_HUB: Vector3 = Vector3(0.365, 1.048, 0.307)
const STEER_AXIS: Vector3 = Vector3(0.0, 0.37461, -0.92718)
const STEER_RATIO: float = 9.0
const TRUNK_CARGO_POS: Vector3 = Vector3(0.0, 0.42, -1.65)
const TRUNK_OPEN_DEG: float = 62.0
const DOOR_OPEN_DEG: float = 62.0
const REAR_Z: float = -2.40
const WHEELBASE: float = 2.83
## Grip the steering limit and the auto-cruise corner speed assume (m/s^2).
const LAT_ACCEL_LIMIT: float = 7.0
## Dash close-up (radio / phone): from just inboard of the driver's eye line (clear of his right arm), looking at the centre stack.
const DASH_CAM_POS: Vector3 = Vector3(0.08, 1.21, 0.04)
const DASH_CAM_TARGET: Vector3 = Vector3(0.0, 0.91, 0.47)

## Jolt applies this per driven wheel (all four): 0 to 10 m/s in about 4.5 s for the 1450 kg car.
@export var max_engine_force: float = 1600.0
## m/s (about 58 km/h): a city street, not a highway.
@export var max_speed: float = 16.0
@export var reverse_speed: float = 4.5
@export var brake_force: float = 38.0
@export var steer_max: float = 0.55
@export var steer_min: float = 0.08
@export var steer_rate: float = 2.4
## Extra sideways grip (1/s of lateral velocity removed): keeps the car on rails like an arcade game.
@export var lateral_grip: float = 5.5
## Lateral acceleration the auto-cruise allows itself in bends (it slows down for them); m/s^2.
@export var cruise_lat_accel: float = 4.5
## Pure-pursuit look-ahead of the auto-cruise: base + gain * speed (m).
@export var cruise_look_base: float = 3.0
@export var cruise_look_gain: float = 0.5
@export var use_player_input: bool = true
@export var play_audio: bool = true
## Spring / damper: 45 is a 1.05 Hz comfort sedan (sag = g / (4 k) = 5.4 cm, settles in about 0.8 s, 3 degrees of roll).
@export var spring_stiffness: float = 45.0
@export var damp_compression: float = 1.3
@export var damp_relaxation: float = 1.6
## Jolt's wheel centre settles lower than the physics radius says under a soft spring, so the physics radius is a little
## larger than the 0.334 m tyre and the suspension origin is raised by ride_offset: the car then rests at design height.
@export var phys_wheel_radius: float = 0.377
@export var ride_offset: float = -0.055

var engine_on: bool = false
var starting: bool = false
var auto_cruise: bool = false
var cruise_speed: float = 6.0
## Optional route the auto-cruise follows (world points); empty = hold the heading.
var route: PackedVector3Array = PackedVector3Array()
var ai_throttle: float = 0.0
var ai_steer: float = 0.0
var ai_brake: float = 0.0
var use_ai_inputs: bool = false

var model: Node3D
var door: Node3D
var trunk_lid: Node3D
var steering_wheel: Node3D
var seat_anchor: Marker3D
var trunk_cargo: Marker3D
var trunk_use: OOTInteractable
var door_use: OOTInteractable
var ignition: OOTInteractable
## The one camera (interior, chase and dash close-up all move this node).
var chase_cam: Camera3D
var wheels: Array[VehicleWheel3D] = []
var cam_mode: int = CamMode.INTERIOR

var _door_open: bool = false
var _trunk_open: bool = false
var _door_tween: Tween
var _trunk_tween: Tween
var _steer_wheel_base: Basis = Basis.IDENTITY
var _mats: Dictionary = {}                      # material name -> per-car StandardMaterial3D copy
var _tail_energy: float = 0.0
var _lights_on: bool = false
var _idle: AudioStreamPlayer
var _run: AudioStreamPlayer
var _cam_yaw: float = 0.0
var _chase_active: bool = false
var _dash_cam: bool = false
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _lat_smooth: float = 0.0
var _last_vel: Vector3 = Vector3.ZERO
var _flip_time: float = 0.0
var _throttle_vis: float = 0.0
var _route_idx: int = 0
var _route_kappa: float = 0.0
var _seat_lift: Tween
var _head_meshes_tagged: bool = false
var _wheel_angle: float = 0.0
var _wheel_meshes: Array[Node3D] = []
var _wheel_init_y: float = 0.0
var _wheel_fix_pending: bool = false


func _ready() -> void:
	mass = 1450.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.38, 0.0)
	linear_damp = 0.02
	angular_damp = 1.2
	continuous_cd = true
	_build_model()
	_build_collision()
	_build_wheels()
	_build_markers()
	_build_audio()
	_build_camera()
	_build_cabin_light()
	set_dash_lights(false)
	park(true)


func _build_model() -> void:
	model = get_node_or_null("Model") as Node3D
	if model == null:
		model = (load(MODEL_SCENE) as PackedScene).instantiate() as Node3D
		model.name = "Model"
		add_child(model)
	door = model.find_child("DriverDoor", true, false) as Node3D
	trunk_lid = model.find_child("TrunkLid", true, false) as Node3D
	steering_wheel = model.find_child("SteeringWheel", true, false) as Node3D
	if steering_wheel != null:
		_steer_wheel_base = steering_wheel.transform.basis
	# lamps, gauges, screen: own copies so toggling emission never touches other cars (they share the .glb materials)
	for part: String in ["DashLights", "DashScreen", "Headlights", "Taillights"]:
		_own_materials(model.find_child(part, true, false))
	# the cabin light only touches the car's own meshes: put them on render layer 3 as well as layer 1
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		mi.layers |= 4
		# the glTF importer drops KHR_materials_clearcoat: restore the lacquer on the paint
		for i: int in mi.mesh.get_surface_count():
			var m: StandardMaterial3D = mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m != null and m.resource_name == "CarPaint" and not m.clearcoat_enabled:
				m.clearcoat_enabled = true
				m.clearcoat = 1.0
				m.clearcoat_roughness = 0.06


## Duplicates every StandardMaterial3D of the part (keyed by material name in _mats).
func _own_materials(part: Node) -> void:
	var mi: MeshInstance3D = part as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	for i: int in mi.mesh.get_surface_count():
		var m: StandardMaterial3D = mi.mesh.surface_get_material(i) as StandardMaterial3D
		if m == null:
			continue
		var d: StandardMaterial3D = m.duplicate() as StandardMaterial3D
		d.emission_enabled = true
		d.emission = Color.BLACK
		d.emission_energy_multiplier = 0.0
		mi.set_surface_override_material(i, d)
		_mats[m.resource_name] = d


func _build_collision() -> void:
	if get_node_or_null("ChassisLow") != null:
		return
	var low: CollisionShape3D = CollisionShape3D.new()
	low.name = "ChassisLow"
	var b1: BoxShape3D = BoxShape3D.new()
	b1.size = Vector3(1.78, 0.62, 4.5)
	low.shape = b1
	low.position = Vector3(0.0, 0.5, 0.0)
	add_child(low)
	var cab: CollisionShape3D = CollisionShape3D.new()
	cab.name = "Cabin"
	var b2: BoxShape3D = BoxShape3D.new()
	b2.size = Vector3(1.5, 0.55, 2.4)
	cab.shape = b2
	cab.position = Vector3(0.0, 1.12, -0.2)
	add_child(cab)


func _build_wheels() -> void:
	var specs: Dictionary = {
		"Wheel_FL": [true, true], "Wheel_FR": [true, true], "Wheel_RL": [false, false], "Wheel_RR": [false, false]}
	for key: String in specs:
		var mesh_node: Node3D = model.find_child(key, true, false) as Node3D
		var hub: Vector3 = mesh_node.position if mesh_node != null else Vector3(0.785 * (1 if key.ends_with("L") else -1), WHEEL_RADIUS, 1.415 * (1 if key.begins_with("Wheel_F") else -1))
		var w: VehicleWheel3D = VehicleWheel3D.new()
		w.name = key.replace("Wheel_", "Wheel")
		w.position = hub + Vector3(0.0, WHEEL_REST_LENGTH + ride_offset, 0.0)
		w.wheel_radius = phys_wheel_radius
		w.wheel_rest_length = WHEEL_REST_LENGTH
		w.suspension_travel = 0.18
		w.suspension_stiffness = spring_stiffness
		w.suspension_max_force = 9000.0
		w.damping_compression = damp_compression
		w.damping_relaxation = damp_relaxation
		w.wheel_friction_slip = 4.5
		w.wheel_roll_influence = 0.15
		w.use_as_traction = true
		w.use_as_steering = bool(specs[key][0])
		add_child(w)
		wheels.append(w)
		if mesh_node != null:
			mesh_node.get_parent().remove_child(mesh_node)
			w.add_child(mesh_node)
			# Until Jolt has stepped the vehicle, the wheel node sits at the suspension origin, not at the hub: offset the mesh
			# so a parked (frozen) car stands on its tyres; _sync_wheel_meshes() removes the offset once the wheels move.
			mesh_node.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -(WHEEL_REST_LENGTH + ride_offset), 0.0))
			_wheel_meshes.append(mesh_node)
	if not wheels.is_empty():
		_wheel_init_y = wheels[0].position.y
		_wheel_fix_pending = true


func _build_markers() -> void:
	seat_anchor = Marker3D.new()
	seat_anchor.name = "SeatAnchor"
	seat_anchor.position = SEAT_ANCHOR_POS
	seat_anchor.rotation.x = -deg_to_rad(SEAT_ANCHOR_PITCH_DEG)
	seat_anchor.child_entered_tree.connect(_on_seat_child)
	add_child(seat_anchor)
	trunk_cargo = Marker3D.new()
	trunk_cargo.name = "TrunkCargo"
	trunk_cargo.position = TRUNK_CARGO_POS
	add_child(trunk_cargo)
	trunk_use = _make_interactable("TrunkUse", "trunk", "Open the trunk", Vector3(0.0, 0.85, REAR_Z - 0.1))
	door_use = _make_interactable("DoorUse", "car door", "Get in", Vector3(1.05, 0.9, 0.0))
	door_use.reticle_hint = OOTInteractable.HINT_DOOR
	ignition = _make_interactable("Ignition", "ignition", "Start the engine", Vector3(0.30, 0.95, 0.52))
	ignition.set_active(false)
	door_use.set_active(false)
	trunk_use.set_active(false)


## Mani is added to the seat anchor right after the enter-car clip ends (his feet plane was at the ground there): the
## anchor eases from the clip's last pose (upright, feet plane on the ground) to the pitched-back seat position so he
## does not pop into the seat.
func _on_seat_child(_n: Node) -> void:
	if _seat_lift != null and _seat_lift.is_valid():
		_seat_lift.kill()
	seat_anchor.position = Vector3(SEAT_ANCHOR_POS.x, 0.0, SEAT_ANCHOR_POS.z)
	seat_anchor.rotation.x = 0.0
	_seat_lift = create_tween().set_parallel(true)
	_seat_lift.tween_property(seat_anchor, "position", SEAT_ANCHOR_POS, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_seat_lift.tween_property(seat_anchor, "rotation:x", -deg_to_rad(SEAT_ANCHOR_PITCH_DEG), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_head_meshes_tagged = false


func _make_interactable(node_name: String, label: String, prompt: String, pos: Vector3) -> OOTInteractable:
	var it: OOTInteractable = OOTInteractable.new()
	it.name = node_name
	it.item_id = node_name.to_snake_case()
	it.display_name = label
	it.prompt_text = prompt
	it.kind = OOTInteractable.Kind.USE
	it.collision_layer = 0
	it.collision_mask = 0
	it.position = pos
	add_child(it)
	return it


func _build_audio() -> void:
	if not play_audio:
		return
	_idle = AudioStreamPlayer.new()
	_idle.name = "EngineIdle"
	_idle.bus = &"SFX"
	_idle.stream = _loop(SND_DIR + "engine_idle.ogg")
	_idle.volume_db = -80.0
	add_child(_idle)
	_run = AudioStreamPlayer.new()
	_run.name = "EngineRun"
	_run.bus = &"SFX"
	_run.stream = _loop(SND_DIR + "engine_run.ogg")
	_run.volume_db = -80.0
	add_child(_run)


func _loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = (load(path) as AudioStream).duplicate() as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


func _build_camera() -> void:
	chase_cam = Camera3D.new()
	chase_cam.name = "ChaseCam"
	chase_cam.top_level = true
	chase_cam.fov = 68.0
	chase_cam.near = 0.03
	chase_cam.far = 600.0
	add_child(chase_cam)


## A dim warm bounce light inside the cabin (the engine has no global illumination): lights only layer-3 meshes (the car).
func _build_cabin_light() -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.name = "CabinLight"
	l.position = Vector3(0.0, 1.22, -0.15)
	l.omni_range = 2.6
	l.light_energy = 0.55
	l.light_color = Color(1.0, 0.96, 0.9)
	l.shadow_enabled = false
	l.light_cull_mask = 4
	add_child(l)


# --- state -------------------------------------------------------------------------

## Parked cars are frozen (static to the player); driving releases the body.
func park(on: bool) -> void:
	freeze = on
	if on:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		engine_force = 0.0
		brake = 10.0
	else:
		sleeping = false
		brake = 0.0


func is_parked() -> bool:
	return freeze


func get_forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)


func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


## Heading as a yaw (rotation about Y) of the car's forward (+Z) axis.
func get_heading() -> float:
	return atan2(global_basis.z.x, global_basis.z.z)


func is_trunk_open() -> bool:
	return _trunk_open


func is_door_open() -> bool:
	return _door_open


## Current brightness of the red tail / brake lamps (0 = off, about 1.4 tail, 6 braking).
func get_taillight_energy() -> float:
	return _tail_energy


func get_steering_wheel_angle() -> float:
	return _wheel_angle


# --- doors, trunk -----------------------------------------------------------------------

func open_trunk(seconds: float = 0.55) -> void:
	_set_trunk(true, seconds)


func close_trunk(seconds: float = 0.45) -> void:
	_set_trunk(false, seconds)


func _set_trunk(open: bool, seconds: float) -> void:
	if trunk_lid == null or _trunk_open == open:
		return
	_trunk_open = open
	if _trunk_tween != null and _trunk_tween.is_valid():
		_trunk_tween.kill()
	_trunk_tween = create_tween()
	_trunk_tween.tween_property(trunk_lid, "rotation:x", deg_to_rad(TRUNK_OPEN_DEG) if open else 0.0, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if open:
		_sound(SND_DIR + "trunk_open.ogg", Vector3(0, 0.9, REAR_Z), -4.0)
	else:
		_trunk_tween.tween_callback(func() -> void: _sound(SND_DIR + "trunk_close.ogg", Vector3(0, 0.9, REAR_Z), -2.0))
	trunk_changed.emit(open)


func open_door(seconds: float = 0.4) -> void:
	_set_door(true, seconds)


func close_door(seconds: float = 0.35) -> void:
	_set_door(false, seconds)


## The door's hinge is at its front edge; it swings outwards with a negative rotation about Y.
func _set_door(open: bool, seconds: float) -> void:
	if door == null or _door_open == open:
		return
	_door_open = open
	if _door_tween != null and _door_tween.is_valid():
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_property(door, "rotation:y", -deg_to_rad(DOOR_OPEN_DEG) if open else 0.0, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if open:
		_sound(SND_DIR + "car_door_open.ogg", Vector3(0.9, 0.9, 0.0), -3.0)
	else:
		_door_tween.tween_callback(func() -> void: _sound(SND_DIR + "car_door_close.ogg", Vector3(0.9, 0.9, 0.0), -1.0))
	door_changed.emit(open)


func snap_door(open: bool) -> void:
	if door == null:
		return
	_door_open = open
	door.rotation.y = -deg_to_rad(DOOR_OPEN_DEG) if open else 0.0


func snap_trunk(open: bool) -> void:
	if trunk_lid == null:
		return
	_trunk_open = open
	trunk_lid.rotation.x = deg_to_rad(TRUNK_OPEN_DEG) if open else 0.0


func _sound(path: String, local_pos: Vector3, volume_db: float = 0.0) -> void:
	if not play_audio or not ResourceLoader.exists(path) or not is_inside_tree():
		return
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = load(path) as AudioStream
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.position = local_pos
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# --- engine, dash, lights ---------------------------------------------------------------

func _mat(name: String) -> StandardMaterial3D:
	return _mats.get(name) as StandardMaterial3D


func _glow(name: String, color: Color, energy: float) -> void:
	var m: StandardMaterial3D = _mat(name)
	if m == null:
		return
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy


## Gauges, needle ticks and the radio screen light up (ignition on) or go dark.
func set_dash_lights(on: bool, energy: float = 1.6) -> void:
	var dl: StandardMaterial3D = _mat("DashLight")
	if dl != null:
		dl.albedo_color = Color(0.45, 0.8, 0.95) if on else Color(0.11, 0.115, 0.125)
	_glow("DashLight", Color(0.55, 0.9, 1.0), energy * 1.1 if on else 0.0)
	_glow("Needle", Color(1.0, 0.35, 0.1), energy * 1.3 if on else 0.0)
	_glow("Screen", Color(0.28, 0.5, 0.8), energy * 0.45 if on else 0.0)
	var sc: StandardMaterial3D = _mat("Screen")
	if sc != null:
		sc.albedo_color = Color(0.06, 0.1, 0.17) if on else Color(0.03, 0.035, 0.045)


func set_headlights(on: bool) -> void:
	_lights_on = on
	_glow("Headlight", Color(1.0, 0.95, 0.8), 3.0 if on else 0.0)


## Tail lamps glow with the engine, brighten hard under the brake pedal; the white reverse lamps come on in reverse.
func _update_lamps(brake_in: float, reversing: bool) -> void:
	var e: float = 0.0
	if engine_on or starting:
		e = 1.5
	if (brake_in > 0.1 and engine_on) or (is_parked() and engine_on):
		e = 6.0
	if _lights_on:
		e = maxf(e, 1.5)
	_tail_energy = e
	_glow("TailLamp", Color(1.0, 0.1, 0.12), e)
	_glow("Reverse", Color(1.0, 1.0, 1.0), 3.5 if (reversing and engine_on) else 0.0)


## Key turn: click, dash lights and chime, starter, engine catches. engine_on becomes true when the idle begins.
func start_engine() -> void:
	if engine_on or starting:
		return
	starting = true
	_sound(SND_DIR + "ignition_click.ogg", SEAT_ANCHOR_POS + Vector3(0, 0.8, 0.3), -2.0)
	set_dash_lights(true)
	await get_tree().create_timer(0.18).timeout
	_sound(SND_DIR + "dash_chime.ogg", SEAT_ANCHOR_POS + Vector3(0, 0.8, 0.3), -8.0)
	if play_audio and ResourceLoader.exists(SND_DIR + "engine_start.ogg"):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = load(SND_DIR + "engine_start.ogg") as AudioStream
		p.bus = &"SFX"
		p.volume_db = -3.0
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
	await get_tree().create_timer(1.35).timeout
	engine_on = true
	starting = false
	park(false)
	if _idle != null and _idle.stream != null:
		_idle.volume_db = -9.0
		_idle.play()
		_run.volume_db = -30.0
		_run.play()
	engine_started.emit()


func stop_engine() -> void:
	if not engine_on:
		return
	engine_on = false
	if _idle != null:
		_idle.stop()
		_run.stop()
	set_dash_lights(false)
	engine_force = 0.0
	brake = brake_force * 0.5
	_update_lamps(0.0, false)
	engine_stopped.emit()


# --- driving -----------------------------------------------------------------------------

## Auto-cruise: hold the lane and speed (used while the phone or radio is open). `speed` < 0 keeps the current speed.
## With a route set the car follows it; otherwise it holds its heading. Player pedals are ignored meanwhile.
func set_auto_cruise(on: bool, speed: float = -1.0) -> void:
	auto_cruise = on
	if on:
		cruise_speed = clampf(get_forward_speed() if speed < 0.0 else speed, 3.0, max_speed * 0.75)
		_route_idx = 0


## Scripted inputs (tests, cutscenes): throttle -1..1, steer -1 (right) .. 1 (left), brake 0..1.
func set_ai_inputs(throttle: float, steer: float, brake_in: float = 0.0) -> void:
	use_ai_inputs = true
	ai_throttle = throttle
	ai_steer = steer
	ai_brake = brake_in


func clear_ai_inputs() -> void:
	use_ai_inputs = false


# --- cameras ----------------------------------------------------------------------------

## The dash / radio close-up: the camera slides to the driver's eye line and looks at the centre stack (radio, screen).
## Works on top of either camera mode; false returns to the interior or chase view.
func set_dash_camera(on: bool) -> void:
	_dash_cam = on
	if on and not _chase_active:
		_chase_active = true
	_update_head_visibility()


func is_dash_camera() -> bool:
	return _dash_cam


## Starts driving-camera control (called by the episode script when the engine catches). The view is the driver's-eye
## interior camera unless the player has toggled to the chase camera.
func activate_chase_camera() -> void:
	_chase_active = true
	_cam_yaw = get_heading()
	_apply_mode_flags()
	_update_camera(1.0, true)
	chase_cam.make_current()


func deactivate_chase_camera() -> void:
	_chase_active = false


func use_interior_camera() -> void:
	_set_cam_mode(CamMode.INTERIOR)


func use_chase_camera() -> void:
	_set_cam_mode(CamMode.CHASE)


func toggle_camera() -> void:
	_set_cam_mode(CamMode.CHASE if cam_mode == CamMode.INTERIOR else CamMode.INTERIOR)


func is_interior_camera() -> bool:
	return cam_mode == CamMode.INTERIOR


func _set_cam_mode(mode: int) -> void:
	if mode == cam_mode and _chase_active:
		return
	cam_mode = mode
	_cam_yaw = get_heading()
	_apply_mode_flags()
	if _chase_active:
		_update_camera(1.0, true)
	camera_changed.emit(mode)


func _apply_mode_flags() -> void:
	_update_head_visibility()


## In the interior and dash views the camera sits inside Mani's head: hide the head (hair, scalp, glasses, hood...) from
## this camera only (render layer 2, the camera's cull mask drops it); the world and cutscene cameras still see him.
func _update_head_visibility() -> void:
	if not _head_meshes_tagged:
		_tag_head_meshes()
	var hide_head: bool = cam_mode == CamMode.INTERIOR or _dash_cam
	chase_cam.cull_mask = 0xFFFFF & ~2 if hide_head else 0xFFFFF


func _tag_head_meshes() -> void:
	var p: Node = null
	for c: Node in seat_anchor.get_children():
		if c is Node3D and c.find_child("Skeleton3D", true, false) != null:
			p = c
	if p == null:
		return
	_head_meshes_tagged = true
	for n: Node in p.find_children("Mani_*", "MeshInstance3D", true, false):
		var nm: String = String(n.name).to_lower()
		for k: String in ["hair", "scalp", "brows", "eyes", "glasses", "lenses", "hoops", "hood", "neckband", "drawstring"]:
			if nm.contains(k):
				(n as MeshInstance3D).layers |= 2
				break


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or k.physical_keycode != KEY_C:
		return
	if engine_on and _chase_active and not _dash_cam:
		toggle_camera()
		get_viewport().set_input_as_handled()


func _read_inputs() -> Vector3:
	## returns (throttle, steer, brake)
	if use_ai_inputs:
		return Vector3(ai_throttle, ai_steer, ai_brake)
	var thr: float = 0.0
	var brk: float = 0.0
	var fwd: float = get_forward_speed()
	if Input.is_action_pressed("move_forward"):
		thr = 1.0
	if Input.is_action_pressed("move_back"):
		if fwd > 0.8:
			brk = 1.0
		else:
			thr = -1.0
	if Input.is_physical_key_pressed(KEY_SPACE):
		brk = 1.0
	var steer: float = -Input.get_axis("move_left", "move_right")
	return Vector3(thr, steer, brk)


func _cruise_inputs() -> Vector3:
	var fwd: float = get_forward_speed()
	var steer: float = 0.0
	_route_kappa = 0.0
	if route.size() > 1:
		steer = _route_steer()
	# slow down for the bend ahead (pure-pursuit curvature) so the corner stays inside the steering limit
	var target: float = cruise_speed
	if absf(_route_kappa) > 0.01:
		target = minf(cruise_speed, maxf(sqrt(cruise_lat_accel / absf(_route_kappa)), 4.0))
	var thr: float = clampf((target - fwd) * 0.7, -0.2, 1.0)
	var brk: float = clampf((fwd - target) * 0.25, 0.0, 0.6)
	return Vector3(maxf(thr, 0.0), steer, brk)


## Pure pursuit toward a point on the route ahead of the car.
func _route_steer() -> float:
	var p: Vector3 = global_position
	# advance the index to the nearest point ahead
	var best: int = _route_idx
	var best_d: float = INF
	var hi: int = mini(route.size(), _route_idx + 60)
	for i: int in range(_route_idx, hi):
		var d: float = Vector2(route[i].x - p.x, route[i].z - p.z).length()
		if d < best_d:
			best_d = d
			best = i
	_route_idx = best
	var look: float = cruise_look_base + cruise_look_gain * maxf(get_forward_speed(), 0.0)
	var tgt: Vector3 = route[route.size() - 1]
	for i: int in range(best, route.size()):
		if Vector2(route[i].x - p.x, route[i].z - p.z).length() >= look:
			tgt = route[i]
			break
	var local: Vector3 = global_transform.affine_inverse() * tgt
	var ang: float = atan2(local.x, local.z)         # + = target on the car's left (+X)
	_route_kappa = 2.0 * local.x / maxf(local.length_squared(), 0.01)
	return clampf(ang * 1.8, -1.0, 1.0)


## Steering angle limit (rad) for a speed (m/s): the angle that still keeps the lateral acceleration near 0.7 g, so full
## lock in a parking lot and a few degrees at 50 km/h.
func steer_limit(speed: float) -> float:
	return clampf(atan(WHEELBASE * LAT_ACCEL_LIMIT / (speed * speed + 0.01)), steer_min, steer_max)


## The first time the vehicle is simulated the wheel nodes jump from the suspension origin to the hub: drop the offset then.
func _sync_wheel_meshes() -> void:
	if absf(wheels[0].position.y - _wheel_init_y) < 0.002:
		return
	_wheel_fix_pending = false
	for m: Node3D in _wheel_meshes:
		m.position = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _wheel_fix_pending and not wheels.is_empty():
		_sync_wheel_meshes()
	var fwd: float = get_forward_speed()
	var speed: float = absf(fwd)
	var input: Vector3 = Vector3.ZERO
	if engine_on:
		if auto_cruise and not use_ai_inputs:
			input = _cruise_inputs()
		elif use_ai_inputs or use_player_input:
			input = _read_inputs()
	var throttle: float = input.x
	var steer_in: float = input.y
	var brake_in: float = input.z
	# engine
	var f: float = 0.0
	if throttle > 0.0:
		f = throttle * max_engine_force * pow(clampf(1.0 - maxf(fwd, 0.0) / max_speed, 0.0, 1.0), 0.6)
	elif throttle < 0.0:
		f = throttle * max_engine_force * 0.55 * pow(clampf(1.0 - maxf(-fwd, 0.0) / reverse_speed, 0.0, 1.0), 0.6)
	engine_force = f
	# brakes: pedal, handbrake, engine braking when coasting
	var b: float = brake_in * brake_force
	if throttle == 0.0 and brake_in == 0.0:
		b = 1.2 if engine_on else 6.0
	brake = b
	# steering: less angle and a slower wheel at speed; the wheel returns to centre a little faster than it turns
	var limit: float = steer_limit(speed)
	var rate: float = steer_rate / (1.0 + speed * 0.12)
	if absf(steer_in) < 0.05:
		rate *= 1.5
	steering = move_toward(steering, steer_in * limit, rate * delta)
	if is_parked() or not engine_on:
		_update_visuals(delta, speed, throttle, brake_in)
		return
	# arcade assists
	var lat: float = linear_velocity.dot(global_basis.x)
	apply_central_force(-global_basis.x * lat * mass * lateral_grip * 0.5)
	apply_central_force(-linear_velocity.normalized() * speed * speed * 0.45)
	if global_basis.y.y < 0.3:
		_flip_time += delta
		if _flip_time > 1.5:
			var p: Vector3 = global_position + Vector3.UP * 0.6
			global_transform = Transform3D(Basis(Vector3.UP, get_heading()), p)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			_flip_time = 0.0
	else:
		_flip_time = 0.0
	_update_visuals(delta, speed, throttle, brake_in)


func _update_visuals(delta: float, speed: float, throttle: float, brake_in: float) -> void:
	# the wheel turns much more than the road wheels (left = counter-clockwise seen from the driver)
	_wheel_angle = steering * STEER_RATIO
	if steering_wheel != null:
		steering_wheel.transform.basis = _steer_wheel_base * Basis(_steer_wheel_base.inverse() * STEER_AXIS, _wheel_angle)
	_update_lamps(brake_in, throttle < 0.0 and get_forward_speed() < 0.5)
	_throttle_vis = move_toward(_throttle_vis, absf(throttle), delta * 3.0)
	if _idle != null and engine_on:
		var t: float = clampf(speed / max_speed, 0.0, 1.0)
		_idle.volume_db = lerpf(-9.0, -40.0, clampf(t * 4.0, 0.0, 1.0))
		_run.pitch_scale = lerpf(0.55, 1.9, t) + 0.12 * _throttle_vis
		_run.volume_db = lerpf(-26.0, -8.0, clampf(t * 2.0 + 0.5 * _throttle_vis, 0.0, 1.0))


func _process(delta: float) -> void:
	if _chase_active:
		_update_camera(delta, false)


func _update_camera(delta: float, snap: bool) -> void:
	if _dash_cam:
		_update_dash(delta, snap)
	elif cam_mode == CamMode.INTERIOR:
		_update_interior(delta, snap)
	else:
		_update_chase(delta, snap)


## Driver's eye: head height, looking a little ahead into the turn (steering and lateral g), a hint of pitch under
## braking / acceleration. The camera is parented in spirit to the car (follows its transform every frame).
func _update_interior(delta: float, snap: bool) -> void:
	var accel: Vector3 = (linear_velocity - _last_vel) / maxf(delta, 0.001) if not snap else Vector3.ZERO
	_last_vel = linear_velocity
	var lat_g: float = clampf(accel.dot(global_basis.x) / 9.8, -0.6, 0.6)
	var lon_g: float = clampf(accel.dot(global_basis.z) / 9.8, -0.6, 0.6)
	_lat_smooth = lerpf(_lat_smooth, lat_g, 1.0 - exp(-5.0 * delta)) if not snap else 0.0
	var spd: float = clampf(absf(get_forward_speed()) / 6.0, 0.0, 1.0)
	var want_yaw: float = steering * 0.9 * spd + _lat_smooth * 0.18
	var want_pitch: float = -0.085 - clampf(lon_g, -0.4, 0.4) * 0.05
	var k: float = 1.0 if snap else 1.0 - exp(-4.5 * delta)
	_look_yaw = lerpf(_look_yaw, want_yaw, k)
	_look_pitch = lerpf(_look_pitch, want_pitch, k)
	var head_sway: Vector3 = Vector3(-_lat_smooth * 0.05, 0.0, 0.0)
	var local: Transform3D = Transform3D(Basis(Vector3.UP, PI + _look_yaw) * Basis(Vector3.RIGHT, _look_pitch), EYE_POS + head_sway)
	var target: Transform3D = global_transform * local
	if snap:
		chase_cam.global_transform = target
	else:
		chase_cam.global_transform = Transform3D(chase_cam.global_basis.slerp(target.basis, 1.0 - exp(-14.0 * delta)), target.origin)
	chase_cam.fov = lerpf(chase_cam.fov, 68.0, 1.0 if snap else 1.0 - exp(-5.0 * delta))


func _update_dash(delta: float, snap: bool) -> void:
	var from: Vector3 = global_transform * DASH_CAM_POS
	var to: Vector3 = global_transform * DASH_CAM_TARGET
	var k: float = 1.0 if snap else 1.0 - exp(-6.0 * delta)
	chase_cam.global_position = from if snap else chase_cam.global_position.lerp(from, k)
	var look: Basis = Basis.looking_at(to - chase_cam.global_position, global_basis.y)
	chase_cam.global_basis = look if snap else chase_cam.global_basis.slerp(look, k)
	chase_cam.fov = lerpf(chase_cam.fov, 52.0, 1.0 if snap else k)


func _update_chase(delta: float, snap: bool) -> void:
	var v: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var target_yaw: float = get_heading()
	if v.length() > 3.0 and get_forward_speed() > 0.0:
		target_yaw = lerp_angle(get_heading(), atan2(v.x, v.z), 0.5)
	_cam_yaw = target_yaw if snap else lerp_angle(_cam_yaw, target_yaw, 1.0 - exp(-3.2 * delta))
	var fwd: Vector3 = Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
	var p: Vector3 = global_position
	var desired: Vector3 = p - fwd * 6.4 + Vector3.UP * 2.7
	var look: Vector3 = p + fwd * 2.5 + Vector3.UP * 1.1
	var pos: Vector3 = desired if snap else chase_cam.global_position.lerp(desired, 1.0 - exp(-6.0 * delta))
	# keep the camera out of walls and houses: pull it in along the line from the car to the wanted position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.3, pos, 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		pos = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.35
	chase_cam.global_position = pos
	chase_cam.look_at(look, Vector3.UP)
	chase_cam.fov = lerpf(chase_cam.fov, 68.0, 1.0 if snap else 1.0 - exp(-5.0 * delta))
