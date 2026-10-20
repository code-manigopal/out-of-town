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

var anim: AnimationPlayer
var _anim_state: StringName = &""
var yaw: float = 0.0
var pitch: float = -0.15
var _lock_count: int = 0
var _unlock_frame: int = -1
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	pivot.top_level = true
	arm.spring_length = camera_distance
	arm.position.x = shoulder_offset
	arm.add_excluded_object(get_rid())
	_setup_animation()
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
	_update_animation()
	_update_camera()


func _setup_animation() -> void:
	anim = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return
	for clip: StringName in [&"idle", &"walk", &"jog"]:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.playback_default_blend_time = 0.2
	_play(&"idle", 1.0)


func _play(clip: StringName, speed: float) -> void:
	if anim == null or not anim.has_animation(clip):
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


func _update_camera() -> void:
	pivot.global_position = global_position + Vector3(0, camera_height, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)
