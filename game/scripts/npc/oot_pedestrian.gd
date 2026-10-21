class_name OOTPedestrian
extends CharacterBody3D
## Background pedestrian: walks along a Path3D (loop or ping-pong) with the walk clip matched to the ground speed,
## turns smoothly at corners, waits briefly at crossings, stops (then steps around) a body that blocks the path,
## or stands idle at a bus stop.
##
## The six models (characters/pedestrians/ped_<n>.glb, tools/blender/build_pedestrians.py) share Mani's MPFB game-engine
## skeleton, so no animations are baked into them: the idle/walk clips are taken from characters/mani/mani.glb and
## re-targeted per model (rest-pose deltas, pelvis motion scaled by leg length). See [method _library_for].
##
## Route rules: the Path3D's Y is the ground height under the feet (the ped does not fall). A closed curve loops;
## an open curve ping-pongs (or wraps back to its start when [member ping_pong] is false). Child Node3Ds of the route
## whose name starts with "Wait" are crossing points: each pedestrian pauses there for [member crossing_wait] seconds.

enum Mode { WALK, IDLE_WAIT }
enum IdleStyle { IDLE, PHONE, MIXED }

const MANI_MODEL: String = "res://characters/mani/mani.glb"
## Ground speed the walk clip was authored for (Mani, 1.75 m).
const WALK_REF_SPEED: float = 1.33
const MANI_PELVIS_REST_HEIGHT: float = 0.9447
const WALK_THRESHOLD: float = 0.18
const CLIP_BLEND: float = 0.3
## Extra local rotations (degrees, XYZ euler, applied after the idle pose) for the "look at phone" pose: the right arm
## comes up to chest height and the head tips down. The rest of the body keeps the idle clip.
static var phone_pose: Dictionary = {
	"upperarm_r": Vector3(22.0, 0.0, 0.0),
	"lowerarm_r": Vector3(82.0, 0.0, 0.0),
	"hand_r": Vector3(0.0, 0.0, 0.0),
	"head": Vector3(22.0, 0.0, 0.0),
}

@export_file("*.glb", "*.tscn") var model_path: String = "res://characters/pedestrians/ped_1.glb"
@export var route: NodePath
@export var speed: float = 1.2
## Metres along the route where the pedestrian starts.
@export var start_offset: float = 0.0
@export var mode: Mode = Mode.WALK
## Open routes only: true = walk back and forth, false = jump back to the start at the end.
@export var ping_pong: bool = true
## Walk the route backwards.
@export var reverse: bool = false
@export var idle_style: IdleStyle = IdleStyle.MIXED
## IDLE_WAIT: direction to face (world, flattened). Zero = along the route tangent.
@export var face_direction: Vector3 = Vector3.ZERO
@export var crossing_wait: float = 2.0
@export var end_wait: float = 1.0
@export var turn_rate: float = 4.5
@export var acceleration: float = 3.0
@export var lookahead: float = 0.7
## Seconds a blocker is waited for before the pedestrian steps around it.
@export var patience: float = 1.2
@export var sidestep: float = 0.85
@export var avoid_distance: float = 0.85

signal blocked(by: Node3D)
signal waited_at_crossing(offset: float)

var route_path: Path3D
var current_speed: float = 0.0
var state: StringName = &"walk"
var offset: float = 0.0

var _curve: Curve3D
var _length: float = 0.0
var _closed: bool = false
var _dir: float = 1.0
var _facing: Vector3 = Vector3(0, 0, -1)
var _wait_left: float = 0.0
var _waits: PackedFloat32Array = PackedFloat32Array()
var _waited_at: float = -1000.0
var _blocked_time: float = 0.0
var _side: float = 0.0
var _want_side: float = 0.0
var _avoid_offset: float = 0.0
var _avoiding: bool = false
var _stuck_time: float = 0.0

var body: Node3D
var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var _leg_ratio: float = 1.0
var _clip: StringName = &""
var _idle_clip: StringName = &"idle"
var _idle_switch: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

static var _lib_cache: Dictionary = {}
static var _mani_cache: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build_body()
	if route_path == null and not route.is_empty():
		route_path = get_node_or_null(route) as Path3D
	if route_path != null:
		_attach_route(route_path)
	add_to_group(&"pedestrians")
	_play(&"idle", 1.0)


## Assign the route from code (spawner); call before or after adding to the tree.
func set_route(p: Path3D) -> void:
	route_path = p
	if is_inside_tree() and body != null:
		_attach_route(p)


func _attach_route(p: Path3D) -> void:
	route_path = p
	_curve = p.curve
	if _curve == null or _curve.get_baked_length() <= 0.01:
		push_warning("OOTPedestrian: route has no curve")
		return
	_length = _curve.get_baked_length()
	_closed = _curve.closed
	_dir = -1.0 if reverse else 1.0
	offset = _wrap(start_offset)
	_waits.clear()
	for c: Node in p.get_children():
		if c is Node3D and String(c.name).begins_with("Wait"):
			_waits.append(_curve.get_closest_offset(p.to_local((c as Node3D).global_position)))
	var pt: Vector3 = _point(offset)
	global_position = pt
	var tan: Vector3 = _tangent(offset) * _dir
	_facing = tan if tan.length() > 0.01 else Vector3(0, 0, -1)
	if mode == Mode.IDLE_WAIT and face_direction.length() > 0.01:
		_facing = Vector3(face_direction.x, 0, face_direction.z).normalized()
	_apply_yaw(true, 0.0)
	if mode == Mode.IDLE_WAIT:
		state = &"idle"
		_pick_idle()


func _build_body() -> void:
	if body != null:
		return
	if has_node("Collision") == false:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Collision"
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.26
		cap.height = 1.7
		cs.shape = cap
		cs.position = Vector3(0, 0.87, 0)
		add_child(cs)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var scene: PackedScene = load(model_path) as PackedScene
	if scene == null:
		push_error("OOTPedestrian: cannot load " + model_path)
		return
	model = scene.instantiate() as Node3D
	model.name = "Model"
	model.rotation.y = PI          # glTF fronts face +Z, the body faces -Z (same as the player's Mani)
	body.add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	model.add_child(anim)
	anim.root_node = anim.get_path_to(model)
	var lib: AnimationLibrary = _library_for(model_path, model, skeleton)
	if lib != null:
		anim.add_animation_library(&"", lib)
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim.playback_default_blend_time = CLIP_BLEND
	var pel: int = skeleton.find_bone("pelvis")
	if pel >= 0:
		_leg_ratio = skeleton.get_bone_global_rest(pel).origin.y / MANI_PELVIS_REST_HEIGHT
	if _leg_ratio <= 0.1:
		_leg_ratio = 1.0


# ---------------------------------------------------------------------------------------------
# animation: Mani's clips re-targeted onto this model's skeleton (cached per model)
# ---------------------------------------------------------------------------------------------
static func _mani_clips() -> Dictionary:
	if not _mani_cache.is_empty():
		return _mani_cache
	var scene: PackedScene = load(MANI_MODEL) as PackedScene
	if scene == null:
		return {}
	var inst: Node = scene.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if ap == null or sk == null:
		inst.free()
		return {}
	var rest_rot: Dictionary = {}
	var rest_pos: Dictionary = {}
	for i in sk.get_bone_count():
		var r: Transform3D = sk.get_bone_rest(i)
		rest_rot[sk.get_bone_name(i)] = r.basis.get_rotation_quaternion()
		rest_pos[sk.get_bone_name(i)] = r.origin
	var clips: Dictionary = {}
	for nm: StringName in [&"idle", &"walk"]:
		if ap.has_animation(nm):
			clips[nm] = ap.get_animation(nm).duplicate()
	_mani_cache = {"clips": clips, "rest_rot": rest_rot, "rest_pos": rest_pos}
	inst.free()
	return _mani_cache


static func _library_for(path: String, model_root: Node, sk: Skeleton3D) -> AnimationLibrary:
	if _lib_cache.has(path):
		return _lib_cache[path]
	var mani: Dictionary = _mani_clips()
	if mani.is_empty():
		return null
	var skel_path: String = str(model_root.get_path_to(sk))
	var clips: Dictionary = mani["clips"]
	var rest_rot: Dictionary = mani["rest_rot"]
	var rest_pos: Dictionary = mani["rest_pos"]
	var pel: int = sk.find_bone("pelvis")
	var ratio: float = sk.get_bone_global_rest(pel).origin.y / MANI_PELVIS_REST_HEIGHT if pel >= 0 else 1.0
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nm: StringName in clips:
		var src: Animation = clips[nm]
		var dst: Animation = Animation.new()
		dst.length = src.length
		dst.loop_mode = Animation.LOOP_LINEAR
		for t in src.get_track_count():
			var ty: int = src.track_get_type(t)
			if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
				continue
			var bone: String = str(src.track_get_path(t).get_subname(0))
			var bi: int = sk.find_bone(bone)
			if bi < 0 or not rest_rot.has(bone):
				continue
			var nt: int = dst.add_track(ty)
			dst.track_set_path(nt, NodePath(skel_path + ":" + bone))
			dst.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
			var ped_rest: Transform3D = sk.get_bone_rest(bi)
			for k in src.track_get_key_count(t):
				var time: float = src.track_get_key_time(t, k)
				var v: Variant = src.track_get_key_value(t, k)
				if ty == Animation.TYPE_ROTATION_3D:
					var q: Quaternion = v
					var delta: Quaternion = (rest_rot[bone] as Quaternion).inverse() * q
					dst.rotation_track_insert_key(nt, time, ped_rest.basis.get_rotation_quaternion() * delta)
				else:
					var d: Vector3 = (v as Vector3) - (rest_pos[bone] as Vector3)
					dst.position_track_insert_key(nt, time, ped_rest.origin + d * ratio)
		lib.add_animation(nm, dst)
	lib.add_animation(&"phone", _phone_clip(lib.get_animation(&"idle"), sk, skel_path))
	_lib_cache[path] = lib
	return lib


## Idle clip with the right arm raised to chest height and the head tipped down.
static func _phone_clip(idle: Animation, sk: Skeleton3D, skel_path: String) -> Animation:
	var a: Animation = idle.duplicate()
	var base: Dictionary = {}
	for t in range(a.get_track_count() - 1, -1, -1):
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone: String = str(a.track_get_path(t).get_subname(0))
		if phone_pose.has(bone):
			base[bone] = a.track_get_key_value(t, 0)
			a.remove_track(t)
	for bone: String in phone_pose:
		if not base.has(bone):
			continue
		var e: Vector3 = (phone_pose[bone] as Vector3) * (PI / 180.0)
		var q: Quaternion = (base[bone] as Quaternion) * Quaternion.from_euler(e)
		var nt: int = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(nt, NodePath(skel_path + ":" + bone))
		a.rotation_track_insert_key(nt, 0.0, q)
		a.rotation_track_insert_key(nt, a.length, q)
	return a


func _play(clip: StringName, clip_speed: float) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if _clip != clip:
		_clip = clip
		anim.play(clip, CLIP_BLEND)
	anim.speed_scale = clip_speed


## Playback rate that keeps the planted foot still for a ground speed (stride scales with leg length).
func walk_clip_rate(ground_speed: float) -> float:
	return ground_speed / (WALK_REF_SPEED * _leg_ratio)


func _pick_idle() -> void:
	match idle_style:
		IdleStyle.IDLE:
			_idle_clip = &"idle"
		IdleStyle.PHONE:
			_idle_clip = &"phone"
		_:
			_idle_clip = &"phone" if _rng.randf() < 0.5 else &"idle"
	_idle_switch = _rng.randf_range(8.0, 20.0)


# ---------------------------------------------------------------------------------------------
# route helpers
# ---------------------------------------------------------------------------------------------
func _wrap(o: float) -> float:
	if _closed:
		return fposmod(o, _length)
	return clampf(o, 0.0, _length)


func _point(o: float) -> Vector3:
	return route_path.to_global(_curve.sample_baked(_wrap(o), true))


func _tangent(o: float) -> Vector3:
	var a: Vector3 = _point(o - 0.25)
	var b: Vector3 = _point(o + 0.25)
	var d: Vector3 = b - a
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3(0, 0, -1)


## Offset of the route point nearest to [param p] within a window ahead of / behind the current offset (monotonic).
func _project(p: Vector3) -> float:
	var best: float = offset
	var best_d: float = INF
	var s: float = -0.4
	while s <= 1.3:
		var o: float = offset + s * _dir
		if not _closed and (o < 0.0 or o > _length):
			s += 0.1
			continue
		var d: float = _point(o).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = o
		s += 0.1
	return _wrap(best)


# ---------------------------------------------------------------------------------------------
# movement
# ---------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if mode == Mode.IDLE_WAIT:
		_idle_update(delta)
		return
	if route_path == null or _curve == null:
		return
	var pos: Vector3 = global_position
	var desired_speed: float = speed
	# ---- waiting at a crossing / route end
	if _wait_left > 0.0:
		_wait_left -= delta
		desired_speed = 0.0
	# ---- blocked ahead?
	var blocker: Node3D = _find_blocker()
	if blocker != null and desired_speed > 0.0:
		_blocked_time += delta
		desired_speed = 0.0
		if _blocked_time == delta:
			blocked.emit(blocker)
		if _blocked_time > patience and not _avoiding:
			_start_avoid(blocker)
		elif _blocked_time > patience * 3.0 and _avoiding:
			_want_side = -_want_side
			_blocked_time = 0.0
	elif blocker == null:
		_blocked_time = 0.0
	if _avoiding:
		_side = move_toward(_side, _want_side, 1.1 * delta)
		if (offset - _avoid_offset) * _dir > 1.4 and blocker == null:
			_want_side = 0.0
			if absf(_side) < 0.02:
				_avoiding = false
	# ---- steering: toward a point ahead on the (side-shifted) route
	var ahead: float = offset + _dir * lookahead
	var tgt: Vector3 = _point(ahead)
	var tan_a: Vector3 = _tangent(ahead) * _dir
	tgt += Vector3(-tan_a.z, 0, tan_a.x) * _side
	var to: Vector3 = tgt - pos
	to.y = 0.0
	if to.length() > 0.02:
		var want: Vector3 = to.normalized()
		var err: float = absf(_facing.signed_angle_to(want, Vector3.UP))
		if desired_speed > 0.0:
			desired_speed *= 1.0 - 0.55 * clampf(err / 1.2, 0.0, 1.0)
		var step: float = turn_rate * delta
		var ang: float = _facing.signed_angle_to(want, Vector3.UP)
		_facing = _facing.rotated(Vector3.UP, clampf(ang, -step, step)).normalized()
	_apply_yaw(false, delta)
	# ---- speed, motion
	var rate: float = acceleration if desired_speed > current_speed else acceleration * 1.8
	current_speed = move_toward(current_speed, desired_speed, rate * delta)
	velocity = _facing * current_speed
	move_and_slide()
	var gy: float = _point(offset).y
	global_position.y = gy
	var moved: float = (global_position - pos).length()
	if current_speed > 0.2 and moved < current_speed * delta * 0.25:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	# ---- progress along the route
	var prev: float = offset
	offset = _project(global_position)
	if _closed and absf(offset - prev) > _length * 0.5:
		pass
	_check_route_events(prev)
	_update_anim(delta)


func _check_route_events(prev: float) -> void:
	# crossings: pause at a "Wait*" point, once per visit
	if _waited_at > -999.0 and absf(offset - _waited_at) > 0.8:
		_waited_at = -1000.0
	if _wait_left <= 0.0 and _waited_at < -999.0:
		for w in _waits:
			if absf(offset - w) < 0.2:
				_waited_at = w
				_wait_left = crossing_wait * _rng.randf_range(0.8, 1.3)
				waited_at_crossing.emit(w)
				break
	# route end
	if not _closed:
		if _dir > 0.0 and offset >= _length - 0.2:
			if ping_pong:
				_dir = -1.0
				_wait_left = maxf(_wait_left, end_wait)
			else:
				offset = 0.0
				global_position = _point(0.0)
		elif _dir < 0.0 and offset <= 0.2:
			if ping_pong:
				_dir = 1.0
				_wait_left = maxf(_wait_left, end_wait)
			else:
				offset = _length
				global_position = _point(_length)


func _apply_yaw(snap: bool, delta: float) -> void:
	var target: float = atan2(-_facing.x, -_facing.z)
	body.rotation.y = target if snap else lerp_angle(body.rotation.y, target, minf(1.0, 14.0 * delta))


func _idle_update(delta: float) -> void:
	current_speed = 0.0
	_idle_switch -= delta
	if _idle_switch <= 0.0:
		_pick_idle()
	_play(_idle_clip, 1.0)


func _update_anim(delta: float) -> void:
	if current_speed > WALK_THRESHOLD:
		state = &"walk"
		_play(&"walk", walk_clip_rate(current_speed))
	else:
		state = &"idle"
		_idle_switch -= delta
		if _idle_switch <= 0.0:
			_pick_idle()
		_play(_idle_clip if _wait_left > 0.0 or _blocked_time > 0.0 else &"idle", 1.0)


## A non-static body (player, NPC, vehicle, anything with meta "ped_blocker") in the path of the next step.
func _find_blocker() -> Node3D:
	if not is_inside_tree():
		return null
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = 0.28
	q.shape = sph
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	for dist: float in [0.45, avoid_distance]:
		q.transform = Transform3D(Basis(), global_position + _facing * dist + Vector3(0, 0.95, 0))
		for hit: Dictionary in space.intersect_shape(q, 4):
			var c: Object = hit["collider"]
			if c is StaticBody3D and not (c as Node).has_meta("ped_blocker"):
				continue
			if c is Node3D:
				return c as Node3D
	return null


func _start_avoid(blocker: Node3D) -> void:
	_avoiding = true
	_avoid_offset = offset
	if blocker != null:
		_avoid_offset = _project(blocker.global_position)
	var right: Vector3 = _facing.cross(Vector3.UP)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = 0.3
	q.shape = sph
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	var order: Array[float] = [sidestep, -sidestep]      # keep to the right when both sides are free
	_want_side = order[0]
	for s: float in order:
		q.transform = Transform3D(Basis(), global_position + right * s + _facing * 0.7 + Vector3(0, 0.95, 0))
		var clear: bool = true
		for hit: Dictionary in space.intersect_shape(q, 4):
			var c: Object = hit["collider"]
			if not (c is StaticBody3D and not (c as Node).has_meta("ped_blocker")):
				clear = false
				break
		if clear:
			_want_side = s
			break
	_blocked_time = 0.0
