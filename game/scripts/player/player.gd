class_name OOTPlayer
extends CharacterBody3D
## Third-person player (Mani, characters/mani/mani.glb): walk, jog while Shift is held, over-the-shoulder camera
## (right shoulder, 2.2 m behind) with mouse look. Input can be locked (dialogue,
## inspect view); the mouse is released while locked.

@export var walk_speed: float = 1.4
@export var jog_speed: float = 2.8
@export var acceleration: float = 14.0
@export var mouse_sensitivity: float = 0.0025
@export var camera_height: float = 1.5
@export var camera_distance: float = 2.2
@export var shoulder_offset: float = 0.55
@export var pitch_min: float = -0.9
@export var pitch_max: float = 0.5
## Ground speed each clip was authored for (tools/blender/build_mani.py); the clip is
## played at speed / authored so the feet do not slide.
@export var walk_anim_speed: float = 1.33
@export var jog_anim_speed: float = 2.8
@export var turn_rate: float = 10.0

## Use a Phantom Camera (third-person follow mode, over the right shoulder) instead of the hand-built SpringArm rig.
## Set to false to fall back to the legacy rig (CameraPivot/SpringArm3D/Camera3D stay in the scene).
@export var use_phantom_camera: bool = true

@onready var body: Node3D = $Body
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var interactor: OOTInteractor = $Interactor

signal action_started(clip: StringName)
signal action_finished(clip: StringName)

const PCAM_SCRIPT: String = "res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd"
const PCAM_HOST_SCRIPT: String = "res://addons/phantom_camera/scripts/phantom_camera_host/phantom_camera_host.gd"
const ACTIONS_META: String = "res://characters/mani/mani_actions.json"
const FOLLOW_PRIORITY: int = 10
const SHOT_PRIORITY: int = 100
## Seconds to cut to / back from a fixed shot.
const SHOT_BLEND_TIME: float = 0.4
## One-shot full-body clips played by play_action(). Root motion is not baked: the body is moved along the clip's `root`
## track (see ACTIONS_META, written by tools/blender/anims_v5.py).
const ACTION_CLIPS: Array[StringName] = [&"reach_low", &"put_down", &"door_open_push", &"trunk_open", &"trunk_close",
	&"car_enter_driver", &"car_exit_driver"]
## Looping clips that replace the whole pose while set_pose_override() is active (seated driving...).
const POSE_CLIPS: Array[StringName] = [&"sit_drive"]
## Bones the carry clips drive (the arms and the upper spine). Everything else (pelvis, legs, feet, spine_01) must keep the
## locomotion pose: the exported carry clips contain a constant rest-pose track for EVERY bone, so the blend filter and the
## clip are trimmed to this list (this was the cause of the "skating" while carrying).
const UPPER_BONES: Array[String] = ["spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r", "upperarm_l",
	"upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]
const FINGER_KEYS: Array[String] = ["index_", "middle_", "ring_", "pinky_", "thumb_"]

## Seconds to blend the carry pose in/out.
const CARRY_BLEND_TIME: float = 0.25
const HAND_BONE: String = "hand_r"
## Per-item hold, fitted in Blender (tools/blender/grip_v4.py -> art_source/characters/mani/grip.json): each item has
## its own `carry_<item>` clip (arm spread, finger curls, thumb on top) so no finger intersects it. The visual is
## centred on its AABB and placed at `offset` (body space: +x right, -z forward, from the right wrist) with `rot`
## (degrees). Unknown ids use the default (generic two-hand box hold, clip `carry`).
const CARRY_DEFAULT: Dictionary = {"offset": Vector3(-0.1543, 0.0545, -0.1099), "rot": Vector3.ZERO}
const CARRY_ITEMS: Dictionary = {
	"sweets": {"offset": Vector3(-0.1543, 0.0545, -0.1099), "rot": Vector3.ZERO, "clip": "carry_sweets"},
	"diyas": {"offset": Vector3(-0.1603, 0.0304, -0.0824), "rot": Vector3.ZERO, "clip": "carry_diyas"},
	"radio": {"offset": Vector3(-0.0898, 0.0401, -0.0489), "rot": Vector3.ZERO, "clip": "carry_radio"},
}

## Two-hand items (metadata `carry_two_hand` = true, or item id `duffel`): clip carry_duffel. The offset is from the right
## wrist to the centre of the 0.75 m x 0.30 x 0.30 bag (tools/blender/anims_v5.py), the long axis runs left-right.
const CARRY_TWO_HAND: Dictionary = {"offset": Vector3(-0.1285, -0.2448, -0.0393), "rot": Vector3.ZERO, "clip": "carry_duffel"}

var anim: AnimationPlayer
var skeleton: Skeleton3D
var tree: AnimationTree
var hand_attachment: BoneAttachment3D
var carry_node: AnimationNodeAnimation
var pose_node: AnimationNodeAnimation
var action_node: AnimationNodeAnimation
var carry_holder: Node3D = null
var carry_offset: Vector3 = Vector3.ZERO
var carry_rot: Vector3 = Vector3.ZERO
var _carry_target: float = 0.0
var _carry_blend: float = 0.0
var _anim_state: StringName = &""
var pcam: Node3D = null
var pcam_host: Node = null
var shot_cam: Node3D = null
var _shoulder_target: Node3D = null
var _shot_active: bool = false
var _pcam_excluded: bool = false
var _action_clip: StringName = &""
var _action_time: float = 0.0
var _action_len: float = 0.0
var _action_info: Dictionary = {}
var _action_start_pos: Vector3 = Vector3.ZERO
var _action_start_yaw: float = 0.0
var _action_travel: bool = false
var _pose_clip: StringName = &""
var _stairs_down: bool = false
var _actions_meta: Dictionary = {}
var yaw: float = 0.0
var pitch: float = -0.15
var _lock_count: int = 0
var _unlock_frame: int = -1
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
## Footsteps: one step every half stride of the authored clips (walk 1.0 s at 1.33 m/s,
## jog 0.63 s at 2.8 m/s). The floor collider may carry a "surface" meta ("tile", "snow"…).
@export var default_surface: String = "wood"
## Ground speed stairs_down was authored for (0.56 m per 1.2 s); the root also descends 0.36 m per cycle.
const STAIRS_SPEED: float = 0.467
const WALK_STEP_LENGTH: float = 0.665
const JOG_STEP_LENGTH: float = 0.88
var _step_distance: float = 0.0
var _footstep_player: AudioStreamPlayer3D


func _ready() -> void:
	_load_actions_meta()
	_setup_camera()
	_setup_animation()
	interactor.carried_changed.connect(_on_carried_changed)
	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.name = "Footsteps"
	_footstep_player.bus = &"SFX"
	_footstep_player.volume_db = -8.0
	_footstep_player.unit_size = 4.0
	add_child(_footstep_player)
	_update_camera()
	_apply_mouse_mode()


func lock_input() -> void:
	_lock_count += 1
	_apply_mouse_mode()


func unlock_input() -> void:
	_lock_count = maxi(_lock_count - 1, 0)
	if _lock_count == 0:
		_unlock_frame = Engine.get_process_frames()
	_apply_mouse_mode()


func is_locked() -> bool:
	return _lock_count > 0


## True on the frame input was unlocked, so the key press that closed a dialogue
## is not also treated as a new interaction.
func just_unlocked() -> bool:
	return Engine.get_process_frames() == _unlock_frame


func _apply_mouse_mode() -> void:
	if not is_inside_tree():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _lock_count > 0 else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if is_locked():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: InputEventMouseMotion = event
		yaw -= m.relative.x * mouse_sensitivity
		pitch = clampf(pitch - m.relative.y * mouse_sensitivity, pitch_min, pitch_max)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_mode()


func _physics_process(delta: float) -> void:
	if not _action_clip.is_empty():
		_action_time += delta
	var dir: Vector3 = Vector3.ZERO
	var speed: float = walk_speed
	if not is_locked() and _pose_clip.is_empty():
		var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
		if Input.is_action_pressed("jog"):
			speed = jog_speed
	var target: Vector3 = dir * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	if _action_travel:
		var want: Vector3 = _action_target_position(_action_time + delta)
		velocity.x = (want.x - global_position.x) / delta
		velocity.z = (want.z - global_position.z) / delta
		body.rotation.y = _action_target_yaw(_action_time + delta)
	move_and_slide()
	if dir.length() > 0.1:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), turn_rate * delta)
	_update_footsteps(delta, speed)
	_update_animation()
	_update_camera()


func _update_footsteps(delta: float, speed: float) -> void:
	var ground_speed: float = Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or ground_speed < 0.3:
		_step_distance = 0.0
		return
	_step_distance += ground_speed * delta
	var step_length: float = JOG_STEP_LENGTH if speed > walk_speed else WALK_STEP_LENGTH
	if _step_distance >= step_length:
		_step_distance -= step_length
		var stream: AudioStream = OOTFootsteps.pick(_floor_surface())
		if stream != null:
			_footstep_player.stream = stream
			_footstep_player.pitch_scale = randf_range(0.95, 1.05)
			_footstep_player.play()


func _floor_surface() -> String:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.3, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider")
	if collider != null and collider.has_meta("surface"):
		return str(collider.get_meta("surface"))
	return default_surface


func _setup_animation() -> void:
	anim = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if anim == null:
		return
	var looping: Array[StringName] = [&"idle", &"walk", &"jog", &"stairs_down"]
	looping.append_array(_carry_clip_names())
	looping.append_array(POSE_CLIPS)
	for clip: StringName in looping:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip2: StringName in ACTION_CLIPS:
		if anim.has_animation(clip2):
			anim.get_animation(clip2).loop_mode = Animation.LOOP_NONE
	anim.playback_default_blend_time = 0.2
	_build_tree()
	_play(&"idle", 1.0)
	if skeleton != null and skeleton.find_bone(HAND_BONE) >= 0:
		hand_attachment = BoneAttachment3D.new()
		hand_attachment.name = "RightHandAttachment"
		hand_attachment.bone_name = HAND_BONE
		skeleton.add_child(hand_attachment)


## Locomotion (idle/walk/jog[/stairs_down], cross-faded) -> time scale -> filtered blend with the upper-body carry clip
## -> pose override (sit_drive) -> one-shot action (door, trunk, pick-up, car).
## The carry blend is filtered to the upper-body bones only, so the legs keep walking.
func _build_tree() -> void:
	if not (anim.has_animation(&"idle") and anim.has_animation(&"walk") and anim.has_animation(&"jog")):
		return
	_trim_upper_body_clips()
	var bt: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var loco: AnimationNodeTransition = AnimationNodeTransition.new()
	var names: Array[StringName] = [&"idle", &"walk", &"jog"]
	if anim.has_animation(&"stairs_down"):
		names.append(&"stairs_down")
	loco.input_count = names.size()
	loco.xfade_time = 0.2
	for i: int in names.size():
		loco.set_input_name(i, names[i])
		var n: AnimationNodeAnimation = AnimationNodeAnimation.new()
		n.animation = names[i]
		bt.add_node(StringName("A_" + names[i]), n)
	bt.add_node(&"Loco", loco)
	# connect_node needs both nodes present: wire the animation inputs after Loco exists
	for i: int in names.size():
		bt.connect_node(&"Loco", i, StringName("A_" + names[i]))
	bt.add_node(&"Speed", AnimationNodeTimeScale.new())
	bt.connect_node(&"Speed", 0, &"Loco")
	var out_node: StringName = &"Speed"
	if anim.has_animation(&"carry"):
		var cn: AnimationNodeAnimation = AnimationNodeAnimation.new()
		cn.animation = &"carry"
		bt.add_node(&"A_carry", cn)
		carry_node = cn
		var bl: AnimationNodeBlend2 = AnimationNodeBlend2.new()
		bl.filter_enabled = true
		for path: NodePath in _upper_bone_paths():
			bl.set_filter_path(path, true)
		bt.add_node(&"CarryBlend", bl)
		bt.connect_node(&"CarryBlend", 0, &"Speed")
		bt.connect_node(&"CarryBlend", 1, &"A_carry")
		out_node = &"CarryBlend"
	# pose override (sitting / driving): whole-pose clip
	if anim.has_animation(&"sit_drive"):
		var psel: AnimationNodeTransition = AnimationNodeTransition.new()
		psel.input_count = 2
		psel.xfade_time = 0.25
		psel.set_input_name(0, "loco")
		psel.set_input_name(1, "pose")
		bt.add_node(&"PoseSel", psel)
		var pn: AnimationNodeAnimation = AnimationNodeAnimation.new()
		pn.animation = &"sit_drive"
		bt.add_node(&"A_pose", pn)
		bt.connect_node(&"PoseSel", 0, out_node)
		bt.connect_node(&"PoseSel", 1, &"A_pose")
		pose_node = pn
		out_node = &"PoseSel"
	# one-shot actions
	if anim.has_animation(&"door_open_push"):
		var an: AnimationNodeAnimation = AnimationNodeAnimation.new()
		an.animation = &"door_open_push"
		bt.add_node(&"A_action", an)
		var os: AnimationNodeOneShot = AnimationNodeOneShot.new()
		os.fadein_time = 0.15
		os.fadeout_time = 0.2
		bt.add_node(&"Action", os)
		bt.connect_node(&"Action", 0, out_node)
		bt.connect_node(&"Action", 1, &"A_action")
		action_node = an
		out_node = &"Action"
	bt.connect_node(&"output", 0, out_node)
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	add_child(tree)
	tree.root_node = tree.get_path_to(anim.get_node(anim.root_node))
	tree.tree_root = bt
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true


func _is_upper_bone(bone: String) -> bool:
	if bone in UPPER_BONES:
		return true
	for k: String in FINGER_KEYS:
		if bone.begins_with(k):
			return true
	return false


## Track paths of the carry clip that belong to the upper body (the blend filter).
func _upper_bone_paths() -> Array[NodePath]:
	var out: Array[NodePath] = []
	var ref: Animation = anim.get_animation(&"carry") if anim.has_animation(&"carry") else null
	if ref == null:
		return out
	for t: int in ref.get_track_count():
		var path: NodePath = ref.track_get_path(t)
		if _is_upper_bone(str(path).get_slice(":", 1)) and not out.has(path):
			out.append(path)
	return out


## Keeps only the upper-body tracks of the carry clips (they were exported with a rest-pose track for every bone,
## including the legs and pelvis, which froze the legs while the blend was active).
func _trim_upper_body_clips() -> void:
	for clip: StringName in _carry_clip_names():
		if not anim.has_animation(clip):
			continue
		var a: Animation = anim.get_animation(clip)
		for t: int in range(a.get_track_count() - 1, -1, -1):
			var bone: String = str(a.track_get_path(t)).get_slice(":", 1)
			if not _is_upper_bone(bone):
				a.remove_track(t)


func _carry_clip_names() -> Array[StringName]:
	var out: Array[StringName] = [&"carry", &"carry_duffel"]
	for k: String in CARRY_ITEMS:
		var c: StringName = StringName(CARRY_ITEMS[k].get("clip", "carry"))
		if not out.has(c):
			out.append(c)
	return out


func _play(clip: StringName, speed: float) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if tree != null:
		if clip != _anim_state:
			_anim_state = clip
			tree.set("parameters/Loco/transition_request", String(clip))
		tree.set("parameters/Speed/scale", speed)
		return
	if clip != _anim_state:
		_anim_state = clip
		anim.play(clip, 0.2, speed)
	else:
		anim.speed_scale = speed


func _update_animation() -> void:
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if not _pose_clip.is_empty():
		return
	if _stairs_down and speed >= 0.15 and anim != null and anim.has_animation(&"stairs_down"):
		_play(&"stairs_down", clampf(speed / STAIRS_SPEED, 0.5, 1.6))
	elif speed < 0.15:
		_play(&"idle", 1.0)
	elif speed > (walk_speed + jog_speed) * 0.5:
		_play(&"jog", clampf(speed / jog_anim_speed, 0.6, 1.8))
	else:
		_play(&"walk", clampf(speed / walk_anim_speed, 0.5, 1.9))


# --- Carrying ------------------------------------------------------------------------

func is_carrying() -> bool:
	return carry_holder != null


func get_carry_holder() -> Node3D:
	return carry_holder


func _on_carried_changed(item: OOTInteractable) -> void:
	if item == null:
		_drop_carry_visual()
	else:
		_attach_carry_visual(item)


## Hold configuration for an item: two-hand items (meta carry_two_hand = true, or id "duffel") use carry_duffel.
func carry_config(item: OOTInteractable) -> Dictionary:
	if item.item_id == "duffel" or bool(item.get_meta("carry_two_hand", false)):
		return CARRY_TWO_HAND
	return CARRY_ITEMS.get(item.item_id, CARRY_DEFAULT)


## Copies the item's Visual onto a holder under the right-hand BoneAttachment3D and blends the carry pose in.
func _attach_carry_visual(item: OOTInteractable) -> void:
	_drop_carry_visual()
	if hand_attachment == null:
		return
	var visual: Node3D = item.get_visual()
	if visual == null:
		return
	var cfg: Dictionary = carry_config(item)
	carry_offset = cfg["offset"]
	carry_rot = cfg["rot"]
	if carry_node != null:
		var clip_name: StringName = StringName(cfg.get("clip", "carry"))
		carry_node.animation = clip_name if anim != null and anim.has_animation(clip_name) else &"carry"
	carry_holder = Node3D.new()
	carry_holder.name = "Carried_" + item.item_id
	hand_attachment.add_child(carry_holder)
	var dup: Node3D = visual.duplicate() as Node3D
	dup.transform = Transform3D.IDENTITY
	dup.visible = true
	carry_holder.add_child(dup)
	var box: AABB = _visual_aabb(dup, dup)
	dup.position = -(box.position + box.size * 0.5)
	_carry_target = 1.0
	_update_carry_holder()


func _drop_carry_visual() -> void:
	if carry_holder != null:
		if carry_holder.get_parent() != null:
			carry_holder.get_parent().remove_child(carry_holder)
		carry_holder.free()
		carry_holder = null
	_carry_target = 0.0


func _visual_aabb(n: Node, root_node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		stack.append_array(cur.get_children())
		if cur is MeshInstance3D and (cur as MeshInstance3D).mesh != null:
			var mi: MeshInstance3D = cur as MeshInstance3D
			var rel: Transform3D = root_node.global_transform.affine_inverse() * mi.global_transform if root_node.is_inside_tree() else _local_chain(mi, root_node)
			var b: AABB = rel * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box


func _local_chain(n: Node3D, until: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != until:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


func _update_carry_holder() -> void:
	if carry_holder == null or not carry_holder.is_inside_tree():
		return
	var b: Basis = body.global_transform.basis.orthonormalized()
	carry_holder.global_transform = Transform3D(
		b * Basis.from_euler(carry_rot * (PI / 180.0)),
		hand_attachment.global_position + b * carry_offset)


func _process(delta: float) -> void:
	_carry_blend = move_toward(_carry_blend, _carry_target, delta / CARRY_BLEND_TIME)
	if tree != null and anim != null and anim.has_animation(&"carry"):
		tree.set("parameters/CarryBlend/blend_amount", _carry_blend)
	_update_carry_holder()


# --- Camera ----------------------------------------------------------------------------

func _setup_camera() -> void:
	var mgr: Node = get_tree().root.get_node_or_null("PhantomCameraManager") if is_inside_tree() else null
	if not use_phantom_camera or mgr == null:
		use_phantom_camera = false
		pivot.top_level = true
		arm.spring_length = camera_distance
		arm.position.x = shoulder_offset
		arm.add_excluded_object(get_rid())
		return
	camera.reparent(self, false)
	camera.top_level = true
	camera.current = true
	pivot.queue_free()
	_shoulder_target = Node3D.new()
	_shoulder_target.name = "ShoulderTarget"
	_shoulder_target.top_level = true
	add_child(_shoulder_target)
	var host: Node = (load(PCAM_HOST_SCRIPT) as GDScript).new()
	host.name = "PhantomCameraHost"
	camera.add_child(host)
	pcam_host = host
	var script: GDScript = load(PCAM_SCRIPT) as GDScript
	pcam = script.new() as Node3D
	pcam.name = "FollowCam"
	pcam.set("follow_mode", script.FollowMode.THIRD_PERSON)
	pcam.set("follow_target", _shoulder_target)
	pcam.set("spring_length", camera_distance)
	pcam.set("collision_mask", 1)
	var ball: SphereShape3D = SphereShape3D.new()
	ball.radius = 0.2
	pcam.set("shape", ball)
	pcam.set("margin", 0.1)
	pcam.set("priority", FOLLOW_PRIORITY)
	pcam.set("tween_on_load", false)
	pcam.get("tween_resource").set("duration", SHOT_BLEND_TIME)
	add_child(pcam)
	pcam.top_level = true
	_update_camera()


func _camera_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0))


func _update_camera() -> void:
	if use_phantom_camera and _shoulder_target != null:
		_shoulder_target.global_position = global_position + Vector3(0, camera_height, 0) + _camera_basis() * Vector3(shoulder_offset, 0, 0)
		if pcam != null and bool(pcam.get("_has_follow_spring_arm")):
			var sa: SpringArm3D = pcam.get("_follow_spring_arm") as SpringArm3D
			if not _pcam_excluded and sa != null:
				sa.add_excluded_object(get_rid())
				_pcam_excluded = true
			pcam.call("set_third_person_rotation", Vector3(pitch, yaw, 0.0))
		return
	pivot.global_position = global_position + Vector3(0, camera_height, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)


## True once the Phantom follow camera has built its spring arm (a frame after _ready).
func phantom_camera_ready() -> bool:
	return use_phantom_camera and pcam != null and bool(pcam.get("_has_follow_spring_arm"))


## Cuts to a fixed shot: `node_path` names a PhantomCamera3D (used as is) or any Node3D / Camera3D marker (its transform,
## and fov for a Camera3D, is copied to a shared shot camera). Releases with release_shot(). Works for doors, mirrors, cutscenes.
func use_shot(node_path: Variant) -> bool:
	if not use_phantom_camera or pcam_host == null:
		return false
	var n: Node = node_path as Node if node_path is Node else get_node_or_null(NodePath(str(node_path)))
	if n == null and str(node_path).begins_with("/"):
		n = get_tree().root.get_node_or_null(NodePath(str(node_path)))
	if not (n is Node3D):
		push_warning("use_shot: no Node3D at %s" % [node_path])
		return false
	release_shot()
	var script: GDScript = load(PCAM_SCRIPT) as GDScript
	if n.get_script() == script:
		shot_cam = n as Node3D
		shot_cam.set("priority", SHOT_PRIORITY)
	else:
		var marker: Node3D = n as Node3D
		shot_cam = script.new() as Node3D
		shot_cam.name = "ShotCam"
		shot_cam.set("follow_mode", script.FollowMode.NONE)
		shot_cam.set("priority", SHOT_PRIORITY)
		(get_tree().current_scene if get_tree().current_scene != null else get_parent()).add_child(shot_cam)
		shot_cam.top_level = true
		shot_cam.global_transform = marker.global_transform
		shot_cam.set_meta("owned", true)
	_shot_active = true
	return true


func release_shot() -> void:
	if shot_cam != null and is_instance_valid(shot_cam):
		if shot_cam.has_meta("owned"):
			shot_cam.queue_free()
		else:
			shot_cam.set("priority", 0)
	shot_cam = null
	_shot_active = false


func is_shot_active() -> bool:
	return _shot_active


# --- Actions and pose override -------------------------------------------------------------

func _load_actions_meta() -> void:
	var res: Resource = load(ACTIONS_META)
	if res is JSON and (res as JSON).data is Dictionary:
		_actions_meta = (res as JSON).data


func has_action(clip: StringName) -> bool:
	return anim != null and anim.has_animation(clip) and action_node != null


func get_action_info(clip: StringName) -> Dictionary:
	return _actions_meta.get(String(clip), {})


func is_acting() -> bool:
	return not _action_clip.is_empty()


func get_action_clip() -> StringName:
	return _action_clip


## Plays a one-shot clip (reach_low, put_down, door_open_push, trunk_open, trunk_close, car_enter_driver,
## car_exit_driver). Use `await player.play_action(&"door_open_push")`; it returns when the clip has finished.
## lock_input: movement and interaction are locked meanwhile. apply_travel: the body follows the clip's root motion
## (door: 0.86 m forward, trunk: 0.22 m forward, car: 0.75 m to the seat and a 90 degree turn); pass false when the
## calling script (car, cutscene) positions the player itself.
func play_action(clip: StringName, lock_input: bool = true, apply_travel: bool = true) -> void:
	if not has_action(clip):
		push_warning("play_action: unknown clip %s" % clip)
		return
	if is_acting():
		push_warning("play_action: %s ignored, %s is playing" % [clip, _action_clip])
		return
	_action_clip = clip
	_action_len = anim.get_animation(clip).length
	_action_time = 0.0
	_action_info = get_action_info(clip)
	action_node.animation = clip
	tree.set("parameters/Action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if lock_input:
		self.lock_input()
	_action_travel = apply_travel and _action_info.has("root")
	_action_start_pos = global_position
	_action_start_yaw = body.rotation.y
	action_started.emit(clip)
	while _action_time < _action_len:
		await get_tree().physics_frame
	_action_travel = false
	_action_clip = &""
	if lock_input:
		unlock_input()
	action_finished.emit(clip)


## Aborts the running action (fades out).
func cancel_action() -> void:
	if is_acting() and tree != null:
		tree.set("parameters/Action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		_action_time = _action_len


func _root_sample(t: float) -> Array:
	var track: Array = _action_info.get("root", [])
	if track.is_empty():
		return [0.0, 0.0, 0.0, 0.0]
	var f: float = clampf(t * 30.0, 0.0, float(track.size() - 1))
	var i: int = int(floor(f))
	var j: int = mini(i + 1, track.size() - 1)
	var u: float = f - i
	var a: Array = track[i]
	var b: Array = track[j]
	return [lerpf(a[0], b[0], u), lerpf(a[1], b[1], u), lerpf(a[2], b[2], u), lerpf(a[3], b[3], u)]


## Root motion is authored with W = (x: character left, y: backwards, z: up); psi = turn to the left in degrees.
func _action_target_position(t: float) -> Vector3:
	var r: Array = _root_sample(t)
	var local: Vector3 = Vector3(-r[0], 0.0, r[1])
	var p: Vector3 = _action_start_pos + Basis(Vector3.UP, _action_start_yaw) * local
	p.y = global_position.y
	return p


func _action_target_yaw(t: float) -> float:
	return _action_start_yaw + deg_to_rad(float(_root_sample(t)[3]))


## Seated / driving pose: the whole body plays `clip` (sit_drive) in place of locomotion until clear_pose_override().
## `blend` is the cross-fade in seconds (0 right after car_enter_driver, whose last frame is sit_drive's first).
func set_pose_override(clip: StringName = &"sit_drive", blend: float = 0.25) -> void:
	if tree == null or pose_node == null or not anim.has_animation(clip):
		return
	_pose_clip = clip
	pose_node.animation = clip
	(tree.tree_root as AnimationNodeBlendTree).get_node(&"PoseSel").set("xfade_time", blend)
	tree.set("parameters/PoseSel/transition_request", "pose")
	velocity = Vector3.ZERO


func clear_pose_override(blend: float = 0.25) -> void:
	_pose_clip = &""
	if tree == null or pose_node == null:
		return
	(tree.tree_root as AnimationNodeBlendTree).get_node(&"PoseSel").set("xfade_time", blend)
	tree.set("parameters/PoseSel/transition_request", "loco")


func has_pose_override() -> bool:
	return not _pose_clip.is_empty()


## While true, locomotion plays stairs_down (the stairs script also moves the body down the steps).
func set_stairs_down(on: bool) -> void:
	_stairs_down = on
