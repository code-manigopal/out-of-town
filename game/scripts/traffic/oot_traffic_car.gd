class_name OOTTrafficCar
extends AnimatableBody3D
## A town car that drives along an OOTTrafficLane and yields to whatever is in front of it: the car ahead (it queues at a
## safe gap) and anything in the "traffic_obstacle" group (Mani on foot, his car) that stands in its lane-aligned sensor.
## It brakes smoothly to stop STOP_GAP_MIN..STOP_GAP_MAX metres short of a person, honks a short horn when it has to
## stop for them and a longer one if they stay, and sets off again a moment after the way is clear. Cars queued behind
## also honk. It never moves into an obstacle: the step is capped at the free gap.

signal honked(kind: StringName)
signal state_changed(new_state: StringName)

const STOP_GAP_MIN: float = 4.4        # bumper to a person, metres
const STOP_GAP_MAX: float = 5.6
const CAR_GAP_MIN: float = 2.0         # bumper to bumper when queued
const CAR_GAP_MAX: float = 3.0
const SENSE_LENGTH: float = 55.0
const COMFORT_DECEL: float = 3.6
const REACTION_TIME: float = 0.45
const HORN_SHORT: Array[String] = ["res://audio/sfx/exterior/horn_a_short.ogg", "res://audio/sfx/exterior/horn_b_short.ogg"]
const HORN_LONG: Array[String] = ["res://audio/sfx/exterior/horn_a_long.ogg", "res://audio/sfx/exterior/horn_b_long.ogg"]
const SND_BRAKE: String = "res://audio/sfx/exterior/brake_squeal.ogg"
const MAX_HORNS_AT_ONCE: int = 3

static var _horn_ends: Array[float] = []        # physics-time at which each horn that is sounding ends
static var _streams: Dictionary = {}

var lane: OOTTrafficLane = null
var s: float = 0.0                       # distance along the lane of the car's centre
var speed: float = 0.0
var desired_speed: float = 8.0
var accel: float = 2.2
var length: float = 4.6
var width: float = 1.9
var stop_gap: float = 5.0                # this car's own stopping distance for a person
var car_gap: float = 2.5
var state: StringName = &"cruising"      # cruising | braking | stopped | waiting_clear
var blocked_by: StringName = &""         # &"player" | &"car" | &""
var last_gap: float = INF                # free metres to whatever is ahead
var honks_short: int = 0
var honks_long: int = 0
var honk_pitch: float = 1.0
var brake_lights: bool = false
var enabled: bool = true

var _body: Node3D = null                 # the visual model (pitches when braking)
var _taillight_mats: Array[StandardMaterial3D] = []
var _engine: AudioStreamPlayer3D = null
var _horn_player: AudioStreamPlayer3D = null
var _brake_player: AudioStreamPlayer3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _stopped_for: float = 0.0
var _clear_for: float = 0.0
var _honk_timer: float = 0.0
var _honk_stage: int = 0
var _pitch: float = 0.0
var _prev_speed: float = 0.0
var _brake_cd: float = 0.0
var _horn_active_until: float = 0.0
## True when this car is stopped for a person, directly or through the cars ahead of it.
var queue_root_player: bool = false


## Builds the car: `model` is the visual (origin on the ground, forward +Z), `size` its width/height/length.
func setup(p_lane: OOTTrafficLane, p_s: float, model: Node3D, size: Vector3, seed_value: int = 0, p_speed: float = 8.0) -> void:
	lane = p_lane
	s = p_s
	desired_speed = p_speed
	width = size.x
	length = size.z
	_rng.seed = seed_value
	stop_gap = _rng.randf_range(STOP_GAP_MIN, STOP_GAP_MAX)
	car_gap = _rng.randf_range(CAR_GAP_MIN, CAR_GAP_MAX)
	honk_pitch = _rng.randf_range(0.92, 1.1)
	accel = _rng.randf_range(1.9, 2.6)
	speed = p_speed * _rng.randf_range(0.8, 1.0)
	add_to_group(&"traffic_car")
	sync_to_physics = true
	_body = model
	add_child(_body)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(size.x, size.y * 0.85, size.z)
	cs.shape = bs
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(cs)
	_horn_player = AudioStreamPlayer3D.new()
	_horn_player.name = "Horn"
	_horn_player.bus = &"SFX"
	_horn_player.unit_size = 14.0
	_horn_player.max_distance = 140.0
	_horn_player.volume_db = -4.0
	_horn_player.position = Vector3(0.0, 0.7, length * 0.5)
	add_child(_horn_player)
	_brake_player = AudioStreamPlayer3D.new()
	_brake_player.name = "Brake"
	_brake_player.bus = &"SFX"
	_brake_player.unit_size = 8.0
	_brake_player.max_distance = 70.0
	_brake_player.volume_db = -6.0
	add_child(_brake_player)
	_collect_taillights()
	lane.register(self)
	_apply_pose(0.0)


func set_engine_player(p: AudioStreamPlayer3D) -> void:
	_engine = p
	add_child(p)


func _collect_taillights() -> void:
	_taillight_mats.clear()
	for n: Node in _body.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(i)
			if m != null and (m.resource_name == "Taillight" or m.resource_name == "TailLamp") and m is StandardMaterial3D:
				var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.emission_enabled = false
				d.emission = Color(1.0, 0.05, 0.03)
				mi.set_surface_override_material(i, d)
				_taillight_mats.append(d)


func _physics_process(delta: float) -> void:
	if lane == null or not enabled:
		return
	var dir: Vector3 = lane.dir_at(s)
	var sense: Dictionary = _sense(dir)
	var gap: float = sense["gap"]
	var kind: StringName = sense["kind"]
	var blocker_speed: float = sense["speed"]
	last_gap = gap
	blocked_by = kind
	var want_gap: float = stop_gap if kind == &"player" else car_gap
	var v_allowed: float = desired_speed
	if gap < INF:
		var avail: float = gap - want_gap
		if avail <= 0.0:
			v_allowed = 0.0
		else:
			var b: float = COMFORT_DECEL
			var tau: float = REACTION_TIME
			v_allowed = -b * tau + sqrt(b * b * tau * tau + 2.0 * b * avail)
			if kind == &"car":
				v_allowed = maxf(v_allowed, 0.0) + blocker_speed * 0.5       # follow a moving car, not only a wall
	var v_target: float = minf(desired_speed, v_allowed)
	# resume a moment after the way is clear
	if v_target > 0.3 and speed < 0.3:
		_clear_for += delta
		if _clear_for < 0.7:
			v_target = 0.0
	else:
		_clear_for = 0.0
	if v_target >= speed:
		speed = minf(v_target, speed + accel * delta)
	else:
		var rate: float = clampf((speed - v_target) / 0.35, 2.5, 9.0)
		speed = maxf(v_target, speed - rate * delta)
	# hard guard: never move into what is ahead
	var step: float = speed * delta
	if gap < INF:
		step = minf(step, maxf(gap - 0.35, 0.0))
		if step <= 0.0:
			speed = 0.0
	s += step
	if lane.looped and s >= lane.length():
		if lane.is_start_clear(length + 8.0):
			s = 0.0
		else:
			s = lane.length()
			speed = 0.0
	var decel: float = (_prev_speed - speed) / maxf(delta, 0.0001)
	_prev_speed = speed
	_update_state(delta, kind, decel, v_target)
	_update_horn(delta, kind, sense["root_player"])
	_apply_pose(delta, decel)
	if _engine != null:
		_engine.pitch_scale = lerpf(0.75, 1.35, clampf(speed / 10.0, 0.0, 1.0))
		_engine.volume_db = lerpf(-22.0, -14.0, clampf(speed / 4.0, 0.0, 1.0))


## The nearest thing in front: {gap (bumper to the obstacle's near edge), kind, speed, root_player (a person is the cause)}.
func _sense(dir: Vector3) -> Dictionary:
	var gap: float = INF
	var kind: StringName = &""
	var bspeed: float = 0.0
	var root_player: bool = false
	var pos: Vector3 = lane.pos_at(s)
	var side: Vector3 = Vector3(dir.z, 0.0, -dir.x)
	var ahead: OOTTrafficCar = lane.car_ahead(self)
	if ahead != null:
		var g: float = (ahead.s - s) - (length + ahead.length) * 0.5
		if g < SENSE_LENGTH:
			gap = g
			kind = &"car"
			bspeed = ahead.speed
			root_player = ahead.queue_root_player
	for n: Node in get_tree().get_nodes_in_group(&"traffic_obstacle"):
		var o: Node3D = n as Node3D
		if o == null or not o.is_visible_in_tree():
			continue
		var rel: Vector3 = o.global_position - pos
		rel.y = 0.0
		var f: float = rel.dot(dir)
		var l: float = rel.dot(side)
		var r: float = float(o.get_meta("traffic_radius", 0.45))
		if f <= 0.0 or f > SENSE_LENGTH:
			continue
		if absf(l) > width * 0.5 + r + 0.55:
			continue
		var g2: float = f - length * 0.5 - r
		if g2 < gap:
			gap = g2
			kind = &"player"
			bspeed = 0.0
			root_player = true
	queue_root_player = root_player
	return {"gap": gap, "kind": kind, "speed": bspeed, "root_player": root_player}


func _update_state(delta: float, kind: StringName, decel: float, v_target: float) -> void:
	var new_state: StringName = &"cruising"
	if speed < 0.15 and v_target < 0.3:
		new_state = &"stopped"
	elif speed < 0.3 and v_target > 0.3:
		new_state = &"waiting_clear"
	elif decel > 0.6 or (v_target < speed - 0.4):
		new_state = &"braking"
	if new_state != state:
		state = new_state
		state_changed.emit(state)
	var lights: bool = state == &"braking" or state == &"stopped"
	if lights != brake_lights:
		brake_lights = lights
		for m: StandardMaterial3D in _taillight_mats:
			m.emission_enabled = lights
			m.emission_energy_multiplier = 3.0
	if state == &"stopped":
		_stopped_for += delta
	else:
		_stopped_for = 0.0
	_brake_cd = maxf(_brake_cd - delta, 0.0)
	if decel > 4.2 and speed > 1.5 and _brake_cd <= 0.0 and _brake_player != null:
		_brake_player.stream = _stream(SND_BRAKE)
		_brake_player.pitch_scale = _rng.randf_range(0.9, 1.15)
		_brake_player.play()
		_brake_cd = 2.5


func _update_horn(delta: float, kind: StringName, root_player: bool) -> void:
	if kind == &"":
		_honk_stage = 0
		_honk_timer = 0.0
		return
	if state != &"stopped" and state != &"braking":
		return
	if kind == &"player":
		# a short honk as it brakes for him, a long one if he stays, then a long one every few seconds
		if _honk_stage == 0 and last_gap < 20.0:
			_honk_stage = 1
			_honk_timer = _rng.randf_range(0.15, 0.5)
		elif _honk_stage == 1:
			_honk_timer -= delta
			if _honk_timer <= 0.0:
				honk(&"short")
				_honk_stage = 2
				_honk_timer = _rng.randf_range(2.2, 3.0)
		elif _honk_stage >= 2 and state == &"stopped":
			_honk_timer -= delta
			if _honk_timer <= 0.0:
				honk(&"long")
				_honk_stage += 1
				_honk_timer = _rng.randf_range(4.5, 7.0)
	elif kind == &"car" and root_player and state == &"stopped":
		# queued behind a car that is waiting for a person: impatient honks, farther back less often
		if _honk_stage == 0:
			_honk_stage = 1
			_honk_timer = _rng.randf_range(1.4, 3.2)
		_honk_timer -= delta
		if _honk_timer <= 0.0:
			honk(&"short" if _honk_stage == 1 or _rng.randf() < 0.55 else &"long")
			_honk_stage += 1
			_honk_timer = _rng.randf_range(3.5, 7.5)


## Sounds the horn: &"short" (about a third of a second) or &"long" (over a second). Limited to a few at a time.
func honk(kind: StringName) -> void:
	if _horn_player == null:
		return
	var now: float = _now()
	_horn_ends = _horn_ends.filter(func(t: float) -> bool: return t > now)
	if _horn_ends.size() >= MAX_HORNS_AT_ONCE or now < _horn_active_until:
		return
	var pool: Array[String] = HORN_SHORT if kind == &"short" else HORN_LONG
	var i: int = int(honk_pitch * 10.0) % pool.size()
	_horn_player.stream = _stream(pool[i])
	_horn_player.pitch_scale = honk_pitch
	_horn_player.play()
	var dur: float = _horn_player.stream.get_length() if _horn_player.stream != null else (0.3 if kind == &"short" else 1.2)
	_horn_active_until = now + dur
	_horn_ends.append(now + dur)
	if kind == &"short":
		honks_short += 1
	else:
		honks_long += 1
	honked.emit(kind)


static func _now() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


static func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[path]


func _apply_pose(delta: float, decel: float = 0.0) -> void:
	var dir: Vector3 = lane.dir_at(s)
	var p: Vector3 = lane.pos_at(s)
	global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), p)
	var target: float = clampf(decel * 0.004, -0.02, 0.035)
	_pitch = lerpf(_pitch, target, clampf(delta * 6.0, 0.0, 1.0))
	if _body != null:
		_body.rotation.x = _pitch


## The point on the ground at the middle of the car's front bumper.
func front_point() -> Vector3:
	return global_position + global_basis.z * (length * 0.5)
