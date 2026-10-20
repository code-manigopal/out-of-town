class_name OOTInteractable
extends StaticBody3D
## Something the player can pick up, inspect or use. Visuals go under a child
## node named "Visual" (shown large in the inspect view); a CollisionShape3D
## child gives it a body. Story text is never stored here: captions come from
## the story data (search-puzzle spots) via spot_title.

enum Kind { PICKUP, INSPECT, USE }

signal interacted(interactor: Node)

@export var item_id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.INSPECT
## Overrides the default prompt ("Pick up X" / "Look at X" / "Use X").
@export var prompt_text: String = ""
## Scene whose puzzle "spots" supply the inspect caption, and the spot's title.
@export var spots_scene: String = "e1_apt"
@export var spot_title: String = ""
## Mani's inner-voice line id (not written yet; see design doc section 11).
@export var thought_line_id: String = ""
## Counts toward the packing task.
@export var pack_item: bool = false
@export var enabled: bool = true

var _inspected: bool = false


func _ready() -> void:
	add_to_group("oot_interactable")
	if pack_item:
		add_to_group("oot_pack_item")


func get_prompt() -> String:
	if not prompt_text.is_empty():
		return prompt_text
	match kind:
		Kind.PICKUP:
			return "Pick up %s" % display_name
		Kind.USE:
			return "Use %s" % display_name
	return "Look at %s" % display_name


## Caption from the story data, or "" when the data has none (never invented).
func get_caption() -> String:
	if spot_title.is_empty():
		return ""
	var db: Node = OOTServices.db()
	if db == null:
		return ""
	var scene: OOTScene = db.get_scene("p1", spots_scene)
	if scene == null:
		return ""
	var spots: Variant = scene.puzzle.get("spots")
	if not spots is Array:
		return ""
	for spot: Variant in spots:
		if spot is Dictionary and str(spot.get("t", "")) == spot_title:
			return str(spot.get("text", ""))
	return ""


func mark_inspected() -> bool:
	var first: bool = not _inspected
	_inspected = true
	return first


func set_active(active: bool) -> void:
	enabled = active
	visible = active
	for c: Node in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", not active)


func get_visual() -> Node3D:
	return get_node_or_null("Visual") as Node3D
