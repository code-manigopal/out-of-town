class_name OOTToilet
extends Node3D
## Toilet fittings: a seat, water in the bowl and a flush button on the cistern. Place this node at the bowl's
## centre on the floor (bowl top at `bowl_top`, button at `button_pos`, both local). Using the button flushes:
## button presses, flush sound, and the bowl water swirls away and refills.

signal flushed

@export var bowl_top: float = 0.4
@export var button_pos: Vector3 = Vector3(0, 0.75, 0.23)
@export var water_size: Vector2 = Vector2(0.22, 0.3)
@export var flush_sound: String = "flush.ogg"
@export var flush_seconds: float = 4.2

var interactable: OOTInteractable = null
var water: MeshInstance3D = null
var is_flushing: bool = false
var _button: Node3D = null
var _mat: ShaderMaterial = null


func _ready() -> void:
	_button = get_node_or_null("Button") as Node3D
	water = MeshInstance3D.new()
	water.name = "BowlWater"
	var disc: QuadMesh = QuadMesh.new()
	disc.size = water_size
	disc.orientation = PlaneMesh.FACE_Y
	water.mesh = disc
	water.position = Vector3(0, bowl_top + 0.004, -0.08)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://materials/apartment/toilet_water.gdshader") as Shader
	water.material_override = _mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	interactable = OOTInteractable.new()
	interactable.name = "Use"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.1, 0.06, 0.1)
	shape.shape = box
	interactable.add_child(shape)
	interactable.position = button_pos
	interactable.item_id = "toilet_flush"
	interactable.display_name = "toilet"
	interactable.kind = OOTInteractable.Kind.USE
	interactable.prompt_text = "Flush the toilet"
	interactable.interacted.connect(func(_by: Node) -> void: flush())
	add_child(interactable)


func flush() -> bool:
	if is_flushing:
		return false
	is_flushing = true
	OOTSfx.play_at(self, flush_sound, -2.0, 6.0)
	var tw: Tween = create_tween()
	if _button != null:
		tw.tween_property(_button, "position:y", button_pos.y - 0.005, 0.08)
		tw.tween_property(_button, "position:y", button_pos.y, 0.15)
	tw.tween_method(_set_flush, 0.0, 1.0, 0.7)
	tw.tween_interval(flush_seconds - 2.2)
	tw.tween_method(_set_flush, 1.0, 0.0, 1.5)
	tw.finished.connect(_done)
	return true


func _set_flush(v: float) -> void:
	_mat.set_shader_parameter("flush", v)
	water.position.y = bowl_top + 0.004 - 0.012 * v


func _done() -> void:
	is_flushing = false
	flushed.emit()
