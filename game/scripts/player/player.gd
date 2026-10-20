class_name OOTPlayer
extends CharacterBody3D
## Third-person player: walk, jog while Shift is held, over-the-shoulder camera
## (right shoulder, 2.2 m behind) with mouse look. Input can be locked (dialogue,
## inspect view); the mouse is released while locked.

@export var walk_speed: float = 2.2
@export var jog_speed: float = 4.2
@export var acceleration: float = 14.0
@export var mouse_sensitivity: float = 0.0025
@export var camera_height: float = 1.55
@export var camera_distance: float = 2.2
@export var shoulder_offset: float = 0.55
@export var pitch_min: float = -0.9
@export var pitch_max: float = 0.5

@onready var body: Node3D = $Body
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var interactor: OOTInteractor = $Interactor

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
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
	_update_camera()


func _update_camera() -> void:
	pivot.global_position = global_position + Vector3(0, camera_height, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)
