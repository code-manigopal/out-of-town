class_name OOTFridge
extends Node3D
## Top-freezer fridge. Children: two OOTDoor nodes ("FreezerDoor", "FridgeDoor"), the "Contents" model, and this
## node adds the interior light (on while any door is open) and the compressor hum.

signal door_changed(which: String, is_open: bool)

@export var light_color: Color = Color(1.0, 0.97, 0.9)
@export var light_energy: float = 0.22
## Interior light position in fridge-model space (Godot axes): middle of the lower compartment.
@export var light_pos: Vector3 = Vector3(0.0, 0.8, 0.0)
@export var hum_sound: String = "fridge_hum.ogg"

var freezer_door: OOTDoor = null
var fridge_door: OOTDoor = null
var light: OmniLight3D = null
var freezer_light: OmniLight3D = null
var contents: Node3D = null
var _hum: AudioStreamPlayer3D = null


func _ready() -> void:
	freezer_door = get_node_or_null("FreezerDoor") as OOTDoor
	fridge_door = get_node_or_null("FridgeDoor") as OOTDoor
	contents = get_node_or_null("Contents") as Node3D
	light = _make_light("FridgeLight", light_pos, 1.1)
	freezer_light = _make_light("FreezerLight", Vector3(0.0, 1.55, 0.0), 0.8)
	for pair: Array in [["fridge", fridge_door], ["freezer", freezer_door]]:
		var d: OOTDoor = pair[1] as OOTDoor
		if d != null:
			d.state_changed.connect(_on_door.bind(pair[0] as String))
	_hum = OOTSfx.make_loop(self, hum_sound, &"Ambience", -14.0, 3.0)
	if _hum != null:
		_hum.position = Vector3(0, 0.9, 0)
		_hum.play()
	_update_lights()


func _make_light(n: String, p: Vector3, rng: float) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.name = n
	l.position = p
	l.light_color = light_color
	l.light_energy = light_energy
	l.omni_range = rng
	l.omni_attenuation = 1.0
	l.shadow_enabled = false
	l.light_specular = 0.2
	l.visible = false
	add_child(l)
	return l


func is_any_open() -> bool:
	return (fridge_door != null and fridge_door.is_open()) or (freezer_door != null and freezer_door.is_open())


func _on_door(is_open: bool, which: String) -> void:
	door_changed.emit(which, is_open)


func _update_lights() -> void:
	light.visible = fridge_door != null and fridge_door.is_open()
	freezer_light.visible = freezer_door != null and freezer_door.is_open()


func _process(_delta: float) -> void:
	# lit as soon as the door starts to open, off once it is fully closed
	if fridge_door != null:
		light.visible = fridge_door.get_angle() > 1.0
	if freezer_door != null:
		freezer_light.visible = freezer_door.get_angle() > 1.0
