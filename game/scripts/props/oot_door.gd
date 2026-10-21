class_name OOTDoor
extends Node3D
## A hinged door leaf. Put this node ON the hinge axis (bottom, mid-thickness) with local +Z = the door's front;
## add the leaf model as a child that extends from the hinge along +X (hinge_side LEFT) or -X (RIGHT).
## The node builds one OOTInteractable ("Use", a StaticBody3D) at the leaf centre that carries the collision,
## so the collision swings with the door and the closed door blocks the player.
##
## Opening direction: `open_toward_front` swings the free edge toward +Z (the front), otherwise away from it.
## States: open()/close()/toggle() tween the angle over `duration` seconds with a creak/click. set_locked() makes
## use() emit locked_attempt(reason) (and rattle) instead of moving.

signal opened
signal closed
signal state_changed(is_open: bool)
signal locked_attempt(reason: String)
## Emitted whenever the player uses an unlocked door (even when toggles_on_use is false, e.g. the exit door).
signal activated

enum HingeSide { LEFT, RIGHT }

@export var display_name: String = "door"
@export var hinge_side: HingeSide = HingeSide.LEFT
@export var open_toward_front: bool = false
@export_range(10.0, 175.0) var open_angle_deg: float = 90.0
@export var duration: float = 0.6
@export var start_open: bool = false
@export var locked: bool = false
@export var lock_reason: String = ""
## When false, use() does not move the door; the owner decides (see `activated`).
@export var toggles_on_use: bool = true
## Leaf collision / interaction body, in this node's local space (relative to the hinge).
@export var body_center: Vector3 = Vector3(0.45, 1.0, 0.0)
@export var body_size: Vector3 = Vector3(0.9, 2.0, 0.04)
@export var open_sound: String = "door_open.ogg"
@export var close_sound: String = "door_close.ogg"
@export var locked_sound: String = "door_locked.ogg"
@export var prompt_open: String = "Open"
@export var prompt_close: String = "Close"

var interactable: OOTInteractable = null
var _open: bool = false
var _angle: float = 0.0          # current opening, degrees (0 = closed)
var _base_basis: Basis = Basis.IDENTITY
var _tween: Tween = null


func _ready() -> void:
	_base_basis = transform.basis
	_build_interactable()
	_open = start_open
	_set_angle(open_angle_deg if _open else 0.0)
	_refresh_prompt()


func _build_interactable() -> void:
	interactable = get_node_or_null("Use") as OOTInteractable
	if interactable == null:
		interactable = OOTInteractable.new()
		interactable.name = "Use"
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = body_size
		shape.shape = box
		interactable.add_child(shape)
		add_child(interactable)
	interactable.position = body_center
	interactable.item_id = String(name).to_snake_case()
	interactable.display_name = display_name
	interactable.kind = OOTInteractable.Kind.USE
	interactable.interacted.connect(_on_interacted)


func is_open() -> bool:
	return _open


func is_moving() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Current opening in degrees (0 closed .. open_angle_deg).
func get_angle() -> float:
	return _angle


func open() -> bool:
	if _open or locked:
		return false
	_move(true)
	return true


func close() -> bool:
	if not _open:
		return false
	_move(false)
	return true


func toggle() -> bool:
	return close() if _open else open()


## Jumps to open/closed without sound or animation (scene setup, tests, renders).
func snap(open_now: bool) -> void:
	_kill_tween()
	_open = open_now
	_set_angle(open_angle_deg if open_now else 0.0)
	_refresh_prompt()


func set_locked(is_locked: bool, reason: String = "") -> void:
	locked = is_locked
	lock_reason = reason if is_locked else ""
	_refresh_prompt()


## What the player pressing "interact" on the leaf does (the interactable's `interacted` signal calls this).
func use() -> void:
	if is_moving():
		return
	if locked:
		locked_attempt.emit(lock_reason)
		OOTSfx.play_at(self, locked_sound, -2.0)
		return
	activated.emit()
	if toggles_on_use:
		toggle()


func _on_interacted(_by: Node) -> void:
	use()


func _move(to_open: bool) -> void:
	_kill_tween()
	_open = to_open
	OOTSfx.play_at(self, open_sound if to_open else close_sound, -3.0)
	var target: float = open_angle_deg if to_open else 0.0
	if duration <= 0.0 or not is_inside_tree():
		_set_angle(target)
		_finish(to_open)
		return
	_tween = create_tween()
	_tween.tween_method(_set_angle, _angle, target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_finish.bind(to_open))
	_refresh_prompt()


func _finish(to_open: bool) -> void:
	_refresh_prompt()
	if to_open:
		opened.emit()
	else:
		closed.emit()
	state_changed.emit(to_open)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _sign() -> float:
	var toward: float = -1.0 if open_toward_front else 1.0
	return toward * (1.0 if hinge_side == HingeSide.LEFT else -1.0)


func _set_angle(deg: float) -> void:
	_angle = deg
	transform.basis = _base_basis * Basis(Vector3.UP, deg_to_rad(deg) * _sign())


func _refresh_prompt() -> void:
	if interactable == null:
		return
	if locked:
		interactable.prompt_text = "Try the %s" % display_name
	elif _open:
		interactable.prompt_text = "%s the %s" % [prompt_close, display_name]
	else:
		interactable.prompt_text = "%s the %s" % [prompt_open, display_name]
