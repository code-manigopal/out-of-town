class_name OOTInteractor
extends Node3D
## Lives on the player. Picks the nearest facing interactable within range,
## reports a prompt, and handles the single Interact action.

signal prompt_changed(text: String)
signal pickup_taken(target: OOTInteractable)
signal inspect_requested(target: OOTInteractable)
signal used(target: OOTInteractable)
signal carried_changed(item: OOTInteractable)
## Emitted when the targeted interactable changes (null = nothing in reach).
signal target_changed(target: OOTInteractable)

@export var reach: float = 2.0
@export var min_facing_dot: float = 0.2

var target: OOTInteractable = null
var carried: OOTInteractable = null
var enabled: bool = true
var _last_prompt: String = ""
var _prompt_sent: bool = false


func _ready() -> void:
	add_to_group("oot_interactor")


func _physics_process(_delta: float) -> void:
	var best: OOTInteractable = null
	if enabled:
		best = _find_target()
	if best != target:
		target = best
		target_changed.emit(best)
	var text: String = best.get_prompt() if best != null else ""
	if text != _last_prompt or not _prompt_sent:
		_prompt_sent = true
		_last_prompt = text
		prompt_changed.emit(text)


func _find_target() -> OOTInteractable:
	var origin: Vector3 = global_position + Vector3(0, 1.0, 0)
	var forward: Vector3 = _aim_forward()
	var best: OOTInteractable = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group("oot_interactable"):
		var it: OOTInteractable = n as OOTInteractable
		if it == null or not it.enabled or not it.is_inside_tree():
			continue
		var to: Vector3 = it.global_position - origin
		var d: float = to.length()
		if d > reach or d >= best_d:
			continue
		var flat: Vector3 = Vector3(to.x, 0, to.z)
		if flat.length() > 0.6 and flat.normalized().dot(forward) < min_facing_dot:
			continue
		best = it
		best_d = d
	return best


func _aim_forward() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.FORWARD
	var f: Vector3 = -cam.global_transform.basis.z
	f.y = 0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


## Performs the interaction on the current target. Returns true if something happened.
func interact() -> bool:
	if not enabled or target == null:
		return false
	var t: OOTInteractable = target
	match t.kind:
		OOTInteractable.Kind.PICKUP:
			if carried != null:
				return false
			carried = t
			t.set_active(false)
			carried_changed.emit(carried)
			pickup_taken.emit(t)
		OOTInteractable.Kind.INSPECT:
			inspect_requested.emit(t)
		OOTInteractable.Kind.USE:
			used.emit(t)
	t.interacted.emit(self)
	return true


func clear_carried() -> void:
	carried = null
	carried_changed.emit(null)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var player: OOTPlayer = get_parent() as OOTPlayer
		if player != null and (player.is_locked() or player.just_unlocked()):
			return
		if interact():
			get_viewport().set_input_as_handled()
