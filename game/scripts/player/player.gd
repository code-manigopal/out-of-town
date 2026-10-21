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

@onready var body: Node3D = $Body
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var interactor: OOTInteractor = $Interactor

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

var anim: AnimationPlayer
var skeleton: Skeleton3D
var tree: AnimationTree
var hand_attachment: BoneAttachment3D
var carry_node: AnimationNodeAnimation
var carry_holder: Node3D = null
var carry_offset: Vector3 = Vector3.ZERO
var carry_rot: Vector3 = Vector3.ZERO
var _carry_target: float = 0.0
var _carry_blend: float = 0.0
var _anim_state: StringName = &""
var yaw: float = 0.0
var pitch: float = -0.15
var _lock_count: int = 0
var _unlock_frame: int = -1
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
## Footsteps: one step every half stride of the authored clips (walk 1.0 s at 1.33 m/s,
## jog 0.63 s at 2.8 m/s). The floor collider may carry a "surface" meta ("tile", "snow"…).
@export var default_surface: String = "wood"
const WALK_STEP_LENGTH: float = 0.665
const JOG_STEP_LENGTH: float = 0.88
var _step_distance: float = 0.0
var _footstep_player: AudioStreamPlayer3D


func _ready() -> void:
	pivot.top_level = true
	arm.spring_length = camera_distance
	arm.position.x = shoulder_offset
	arm.add_excluded_object(get_rid())
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
	var dir: Vector3 = Vector3.ZERO
	var speed: float = walk_speed
	if not is_locked():
		var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
		if Input.is_action_pressed("jog"):
			speed = jog_speed
	var target: Vector3 = dir * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
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
	for clip: StringName in [&"idle", &"walk", &"jog", &"carry", &"carry_sweets", &"carry_diyas", &"carry_radio"]:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.playback_default_blend_time = 0.2
	_build_tree()
	_play(&"idle", 1.0)
	if skeleton != null and skeleton.find_bone(HAND_BONE) >= 0:
		hand_attachment = BoneAttachment3D.new()
		hand_attachment.name = "RightHandAttachment"
		hand_attachment.bone_name = HAND_BONE
		skeleton.add_child(hand_attachment)


## Locomotion (idle/walk/jog, cross-faded) -> time scale -> filtered blend with the upper-body carry clip.
## The blend is filtered to exactly the bones the carry clip animates, so the legs keep walking.
func _build_tree() -> void:
	if not (anim.has_animation(&"idle") and anim.has_animation(&"walk") and anim.has_animation(&"jog")):
		return
	var bt: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var loco: AnimationNodeTransition = AnimationNodeTransition.new()
	loco.input_count = 3
	loco.xfade_time = 0.2
	for i: int in 3:
		var clip: StringName = [&"idle", &"walk", &"jog"][i]
		loco.set_input_name(i, clip)
		var n: AnimationNodeAnimation = AnimationNodeAnimation.new()
		n.animation = clip
		bt.add_node(StringName("A_" + clip), n)
	bt.add_node(&"Loco", loco)
	# connect_node needs both nodes present: wire the animation inputs after Loco exists
	for i: int in 3:
		var clip2: StringName = [&"idle", &"walk", &"jog"][i]
		bt.connect_node(&"Loco", i, StringName("A_" + clip2))
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
		var carry_anim: Animation = anim.get_animation(&"carry")
		for t: int in carry_anim.get_track_count():
			bl.set_filter_path(carry_anim.track_get_path(t), true)
		bt.add_node(&"CarryBlend", bl)
		bt.connect_node(&"CarryBlend", 0, &"Speed")
		bt.connect_node(&"CarryBlend", 1, &"A_carry")
		out_node = &"CarryBlend"
	bt.connect_node(&"output", 0, out_node)
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	add_child(tree)
	tree.root_node = tree.get_path_to(anim.get_node(anim.root_node))
	tree.tree_root = bt
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true


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
	if speed < 0.15:
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


## Copies the item's Visual onto a holder under the right-hand BoneAttachment3D and blends the carry pose in.
func _attach_carry_visual(item: OOTInteractable) -> void:
	_drop_carry_visual()
	if hand_attachment == null:
		return
	var visual: Node3D = item.get_visual()
	if visual == null:
		return
	var cfg: Dictionary = CARRY_ITEMS.get(item.item_id, CARRY_DEFAULT)
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


func _update_camera() -> void:
	pivot.global_position = global_position + Vector3(0, camera_height, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)
