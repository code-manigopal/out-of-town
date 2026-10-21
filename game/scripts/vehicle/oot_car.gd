class_name OOTCar
extends VehicleBody3D
## Mani's grey sedan (vehicles/sedan/sedan.glb). A VehicleBody3D under Jolt with arcade handling: speed-limited engine,
## speed-sensitive steering, lateral-grip assist and a low centre of mass so it cannot flip on a city street.
##
## The model faces +Z (the glTF front), which is also the VehicleBody3D forward. The driver (left) side is +X.
## Parts found by name in the model: Body, DriverDoor (hinge origin), TrunkLid (hinge origin), Wheel_FL/FR/RL/RR,
## SteeringWheel, DashLights, Headlights, Taillights. Child markers the episode script uses: SeatAnchor (root of
## the seated Mani), TrunkCargo (where the duffel rests), plus three OOTInteractables (TrunkUse, DoorUse, Ignition).
##
## Controls (while the engine is on and use_player_input): W throttle, S brake / reverse, A / D steer, Space handbrake.
## Auto-cruise (set_auto_cruise) is the agreed design for "phone or radio open": the car holds its lane and speed.

signal engine_started
signal engine_stopped
signal trunk_changed(is_open: bool)
signal door_changed(is_open: bool)

const MODEL_SCENE: String = "res://vehicles/sedan/sedan.glb"
const SND_DIR: String = "res://audio/sfx/exterior/"
## Physics radius is a touch larger than the 0.325 m tyre mesh: with the very stiff springs the arcade handling needs,
## Jolt's reported wheel centre then lands on the design hub height (see tools/blender/build_sedan.py).
const WHEEL_RADIUS: float = 0.335
## Model-space hub heights/positions come from the Wheel_* nodes; the suspension origin sits this far above the hub.
const WHEEL_REST_LENGTH: float = 0.10
## Where the seated driver's root (feet plane, under the pelvis) sits in car space.
const SEAT_ANCHOR_POS: Vector3 = Vector3(0.36, -0.02, 0.23)
const TRUNK_CARGO_POS: Vector3 = Vector3(0.0, 0.42, -1.65)
const TRUNK_OPEN_DEG: float = 62.0
const DOOR_OPEN_DEG: float = 62.0
const REAR_Z: float = -2.36

## Jolt applies this per driven wheel (all four): 0 to 10 m/s in about 4.5 s for the 1450 kg car.
@export var max_engine_force: float = 1600.0
## m/s (about 58 km/h): a city street, not a highway.
@export var max_speed: float = 16.0
@export var reverse_speed: float = 4.5
@export var brake_force: float = 38.0
@export var steer_max: float = 0.62
@export var steer_min: float = 0.16
@export var steer_rate: float = 3.4
## Extra sideways grip (1/s of lateral velocity removed): keeps the car on rails like an arcade game.
@export var lateral_grip: float = 5.5
@export var use_player_input: bool = true
@export var play_audio: bool = true

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
var chase_cam: Camera3D
var wheels: Array[VehicleWheel3D] = []

var _door_open: bool = false
var _trunk_open: bool = false
var _door_tween: Tween
var _trunk_tween: Tween
var _steer_wheel_base: Basis = Basis.IDENTITY
var _dash_mat: StandardMaterial3D
var _tail_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _idle: AudioStreamPlayer
var _run: AudioStreamPlayer
var _cam_yaw: float = 0.0
var _chase_active: bool = false
var _dash_cam: bool = false
var _flip_time: float = 0.0
var _throttle_vis: float = 0.0
var _route_idx: int = 0


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
	_dash_mat = _own_material(model.find_child("DashLights", true, false), "DashLight")
	_tail_mat = _own_material(model.find_child("Taillights", true, false), "Taillight")
	_head_mat = _own_material(model.find_child("Headlights", true, false), "Headlight")


## Duplicates the named material on a part so toggling its emission does not touch other cars.
func _own_material(part: Node, slot: String) -> StandardMaterial3D:
	var mi: MeshInstance3D = part as MeshInstance3D
	if mi == null or mi.mesh == null:
		return null
	for i: int in mi.mesh.get_surface_count():
		var m: StandardMaterial3D = mi.mesh.surface_get_material(i) as StandardMaterial3D
		if m != null and (m.resource_name == slot or i == 0):
			var d: StandardMaterial3D = m.duplicate() as StandardMaterial3D
			d.emission_enabled = true
			mi.set_surface_override_material(i, d)
			return d
	return null


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
	b2.size = Vector3(1.5, 0.55, 2.2)
	cab.shape = b2
	cab.position = Vector3(0.0, 1.12, -0.1)
	add_child(cab)


func _build_wheels() -> void:
	var specs: Dictionary = {
		"Wheel_FL": [true, true], "Wheel_FR": [true, true], "Wheel_RL": [false, false], "Wheel_RR": [false, false]}
	for key: String in specs:
		var mesh_node: Node3D = model.find_child(key, true, false) as Node3D
		var hub: Vector3 = mesh_node.position if mesh_node != null else Vector3(0.8 * (1 if key.ends_with("L") else -1), WHEEL_RADIUS, 1.4 * (1 if key.begins_with("Wheel_F") else -1))
		var w: VehicleWheel3D = VehicleWheel3D.new()
		w.name = key.replace("Wheel_", "Wheel")
		w.position = hub + Vector3(0.0, WHEEL_REST_LENGTH, 0.0)
		w.wheel_radius = WHEEL_RADIUS
		w.wheel_rest_length = WHEEL_REST_LENGTH
		w.suspension_travel = 0.15
		w.suspension_stiffness = 260.0
		w.suspension_max_force = 14000.0
		w.damping_compression = 0.95
		w.damping_relaxation = 1.2
		w.wheel_friction_slip = 4.5
		w.wheel_roll_influence = 0.15
		w.use_as_traction = true
		w.use_as_steering = bool(specs[key][0])
		add_child(w)
		wheels.append(w)
		if mesh_node != null:
			mesh_node.get_parent().remove_child(mesh_node)
			w.add_child(mesh_node)
			mesh_node.transform = Transform3D.IDENTITY


func _build_markers() -> void:
	seat_anchor = Marker3D.new()
	seat_anchor.name = "SeatAnchor"
	seat_anchor.position = SEAT_ANCHOR_POS
	add_child(seat_anchor)
	trunk_cargo = Marker3D.new()
	trunk_cargo.name = "TrunkCargo"
	trunk_cargo.position = TRUNK_CARGO_POS
	add_child(trunk_cargo)
	trunk_use = _make_interactable("TrunkUse", "trunk", "Open the trunk", Vector3(0.0, 0.85, REAR_Z - 0.1))
	door_use = _make_interactable("DoorUse", "car door", "Get in", Vector3(0.95, 0.9, 0.0))
	door_use.reticle_hint = OOTInteractable.HINT_DOOR
	ignition = _make_interactable("Ignition", "ignition", "Start the engine", SEAT_ANCHOR_POS + Vector3(0.0, 0.85, 0.35))
	ignition.set_active(false)
	door_use.set_active(false)
	trunk_use.set_active(false)


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
	chase_cam.near = 0.1
	chase_cam.far = 600.0
	add_child(chase_cam)


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


func _set_door(open: bool, seconds: float) -> void:
	if door == null or _door_open == open:
		return
	_door_open = open
	if _door_tween != null and _door_tween.is_valid():
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_property(door, "rotation:y", deg_to_rad(DOOR_OPEN_DEG) if open else 0.0, seconds) \
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
	door.rotation.y = deg_to_rad(DOOR_OPEN_DEG) if open else 0.0


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


# --- engine, dash ---------------------------------------------------------------------

func set_dash_lights(on: bool, energy: float = 1.6) -> void:
	if _dash_mat != null:
		_dash_mat.emission = Color(0.55, 0.9, 1.0) if on else Color.BLACK
		_dash_mat.emission_energy_multiplier = energy if on else 0.0
		_dash_mat.albedo_color = Color(0.55, 0.9, 1.0) if on else Color(0.13, 0.13, 0.13)


func set_headlights(on: bool) -> void:
	if _head_mat != null:
		_head_mat.emission = Color(1.0, 0.95, 0.8)
		_head_mat.emission_energy_multiplier = 2.0 if on else 0.0


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


## Dash camera (phone / radio open): a stub that moves the chase camera into the driver's eye line.
func set_dash_camera(on: bool) -> void:
	_dash_cam = on


func activate_chase_camera() -> void:
	_chase_active = true
	_cam_yaw = get_heading()
	_update_chase(1.0, true)
	chase_cam.make_current()


func deactivate_chase_camera() -> void:
	_chase_active = false


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
	var thr: float = clampf((cruise_speed - fwd) * 0.7, -0.2, 1.0)
	var brk: float = clampf((fwd - cruise_speed) * 0.25, 0.0, 0.6)
	var steer: float = 0.0
	if route.size() > 1:
		steer = _route_steer()
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
	var look: float = 5.0 + 0.7 * maxf(get_forward_speed(), 0.0)
	var tgt: Vector3 = route[route.size() - 1]
	for i: int in range(best, route.size()):
		if Vector2(route[i].x - p.x, route[i].z - p.z).length() >= look:
			tgt = route[i]
			break
	var local: Vector3 = global_transform.affine_inverse() * tgt
	var ang: float = atan2(local.x, local.z)         # + = target on the car's left (+X)
	return clampf(ang * 1.8, -1.0, 1.0)


func _physics_process(delta: float) -> void:
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
	# steering: less angle and slower rate at speed
	var limit: float = lerpf(steer_max, steer_min, clampf(speed / 14.0, 0.0, 1.0))
	steering = move_toward(steering, steer_in * limit, steer_rate * (1.0 - 0.5 * clampf(speed / 14.0, 0.0, 1.0)) * delta)
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
	if steering_wheel != null:
		var ang: float = -steering * 7.0     # wheel turns more than the road wheels
		steering_wheel.transform.basis = _steer_wheel_base * Basis(Vector3(0, 0, 1), ang)
	if _tail_mat != null:
		_tail_mat.emission = Color(1.0, 0.1, 0.1)
		_tail_mat.emission_energy_multiplier = 3.0 if (brake_in > 0.1 and engine_on) else 0.0
	_throttle_vis = move_toward(_throttle_vis, absf(throttle), delta * 3.0)
	if _idle != null and engine_on:
		var t: float = clampf(speed / max_speed, 0.0, 1.0)
		_idle.volume_db = lerpf(-9.0, -40.0, clampf(t * 4.0, 0.0, 1.0))
		_run.pitch_scale = lerpf(0.55, 1.9, t) + 0.12 * _throttle_vis
		_run.volume_db = lerpf(-26.0, -8.0, clampf(t * 2.0 + 0.5 * _throttle_vis, 0.0, 1.0))


func _process(delta: float) -> void:
	if _chase_active:
		_update_chase(delta, false)


func _update_chase(delta: float, snap: bool) -> void:
	var v: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var target_yaw: float = get_heading()
	if v.length() > 3.0 and get_forward_speed() > 0.0:
		target_yaw = lerp_angle(get_heading(), atan2(v.x, v.z), 0.5)
	_cam_yaw = target_yaw if snap else lerp_angle(_cam_yaw, target_yaw, 1.0 - exp(-3.2 * delta))
	var fwd: Vector3 = Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
	var p: Vector3 = global_position
	var desired: Vector3
	var look: Vector3
	if _dash_cam:
		desired = global_transform * Vector3(0.36, 1.2, 0.2)
		look = p + fwd * 12.0 + Vector3.UP * 1.1
	else:
		desired = p - fwd * 6.4 + Vector3.UP * 2.7
		look = p + fwd * 2.5 + Vector3.UP * 1.1
	var pos: Vector3 = desired if snap else chase_cam.global_position.lerp(desired, 1.0 - exp(-6.0 * delta))
	if not _dash_cam:
		# keep the camera out of walls and houses: pull it in along the line from the car to the wanted position
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.3, pos, 1, [get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			pos = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.35
	chase_cam.global_position = pos
	chase_cam.look_at(look, Vector3.UP)
