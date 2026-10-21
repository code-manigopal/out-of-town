class_name OOTTrafficDriver
extends RefCounted
## A seated driver for a town car: one of the pedestrian models (characters/pedestrians/ped_N.glb, Mani's skeleton) frozen in
## Mani's `sit_drive` pose. The clip is re-targeted onto the model's rest pose once and cached; each driver is a static pose
## (no animation running), so it costs one skinned mesh.

const MANI_MODEL: String = "res://characters/mani/mani.glb"
const PEDS: Array[String] = ["res://characters/pedestrians/ped_1.glb", "res://characters/pedestrians/ped_2.glb",
	"res://characters/pedestrians/ped_3.glb", "res://characters/pedestrians/ped_4.glb",
	"res://characters/pedestrians/ped_5.glb", "res://characters/pedestrians/ped_6.glb"]
## Where Mani's hips sit in the sedan (OOTCar.SEAT_ANCHOR_POS): the driver's seat is the car's +X side.
const SEAT: Vector3 = Vector3(0.365, 0.2, 0.05)
const MANI_PELVIS_REST_HEIGHT: float = 0.9447

static var _mani: Dictionary = {}
static var _clips: Dictionary = {}


## Adds a seated driver to `car_model` (origin on the ground, forward +Z); returns the driver root or null.
static func add_driver(car_model: Node3D, ped_index: int, seat: Vector3 = SEAT) -> Node3D:
	var path: String = PEDS[ped_index % PEDS.size()]
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return null
	var holder: Node3D = Node3D.new()
	holder.name = "Driver"
	holder.position = seat
	# Same recline as Mani's seat (OOTCar.SEAT_ANCHOR_PITCH_DEG): upright, the seated head reaches the roof lining.
	holder.rotation.x = -deg_to_rad(OOTCar.SEAT_ANCHOR_PITCH_DEG)
	var model: Node3D = ps.instantiate() as Node3D
	holder.add_child(model)                     # glTF fronts face +Z = the car's forward
	car_model.add_child(holder)
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return holder
	var clip: Animation = _clip_for(path, model, sk)
	if clip != null:
		var ap: AnimationPlayer = AnimationPlayer.new()
		ap.name = "SitPose"
		model.add_child(ap)
		ap.root_node = ap.get_path_to(model)
		var lib: AnimationLibrary = AnimationLibrary.new()
		lib.add_animation(&"sit_drive", clip)
		ap.add_animation_library(&"", lib)
		ap.play(&"sit_drive")
		ap.advance(0.0)
		ap.pause()
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


static func _mani_data() -> Dictionary:
	if not _mani.is_empty():
		return _mani
	var scene: PackedScene = load(MANI_MODEL) as PackedScene
	if scene == null:
		return {}
	var inst: Node = scene.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if ap == null or sk == null or not ap.has_animation(&"sit_drive"):
		inst.free()
		return {}
	var rest_rot: Dictionary = {}
	var rest_pos: Dictionary = {}
	for i: int in sk.get_bone_count():
		var r: Transform3D = sk.get_bone_rest(i)
		rest_rot[sk.get_bone_name(i)] = r.basis.get_rotation_quaternion()
		rest_pos[sk.get_bone_name(i)] = r.origin
	_mani = {"clip": ap.get_animation(&"sit_drive").duplicate(), "rest_rot": rest_rot, "rest_pos": rest_pos}
	inst.free()
	return _mani


static func _clip_for(path: String, model_root: Node, sk: Skeleton3D) -> Animation:
	if _clips.has(path):
		return _clips[path]
	var mani: Dictionary = _mani_data()
	if mani.is_empty():
		return null
	var src: Animation = mani["clip"]
	var rest_rot: Dictionary = mani["rest_rot"]
	var rest_pos: Dictionary = mani["rest_pos"]
	var skel_path: String = str(model_root.get_path_to(sk))
	var pel: int = sk.find_bone("pelvis")
	var ratio: float = sk.get_bone_global_rest(pel).origin.y / MANI_PELVIS_REST_HEIGHT if pel >= 0 else 1.0
	var dst: Animation = Animation.new()
	dst.length = maxf(src.length, 0.1)
	dst.loop_mode = Animation.LOOP_LINEAR
	for t: int in src.get_track_count():
		var ty: int = src.track_get_type(t)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
			continue
		var bone: String = str(src.track_get_path(t).get_subname(0))
		var bi: int = sk.find_bone(bone)
		if bi < 0 or not rest_rot.has(bone):
			continue
		var nt: int = dst.add_track(ty)
		dst.track_set_path(nt, NodePath(skel_path + ":" + bone))
		var ped_rest: Transform3D = sk.get_bone_rest(bi)
		var time: float = 0.0
		var v: Variant = src.track_get_key_value(t, 0)            # the pose is held: first key only
		if ty == Animation.TYPE_ROTATION_3D:
			var delta: Quaternion = (rest_rot[bone] as Quaternion).inverse() * (v as Quaternion)
			dst.rotation_track_insert_key(nt, time, ped_rest.basis.get_rotation_quaternion() * delta)
		else:
			dst.position_track_insert_key(nt, time, ped_rest.origin + ((v as Vector3) - (rest_pos[bone] as Vector3)) * ratio)
	_clips[path] = dst
	return dst
