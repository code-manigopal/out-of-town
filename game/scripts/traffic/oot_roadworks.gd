class_name OOTRoadworks
extends Node3D
## A road-works closure: the barricades, cones, drums and signs of one closed road mouth, plus the flashing amber lamps
## (the "*_Lamps" meshes pulse their emission) and the collision that stops a car. Built by OOTExteriorWorld.

const FLASH_HZ: float = 1.4

var closure_id: String = ""
var half_width: float = 3.5
## Unit vector pointing out toward the traffic that approaches the closure.
var approach: Vector3 = Vector3.BACK
var blocker: StaticBody3D = null

var _lamp_mats: Array[StandardMaterial3D] = []
var _t: float = 0.0


func collect_lamps() -> void:
	_lamp_mats.clear()
	for n: Node in find_children("*Lamps*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.emission_enabled = true
				d.emission = Color(1.0, 0.62, 0.05)
				mi.set_surface_override_material(i, d)
				_lamp_mats.append(d)


func lamps_lit() -> bool:
	return not _lamp_mats.is_empty() and _lamp_mats[0].emission_energy_multiplier > 1.0


func _process(delta: float) -> void:
	_t += delta
	var on: bool = fmod(_t * FLASH_HZ, 1.0) < 0.5
	for m: StandardMaterial3D in _lamp_mats:
		m.emission_energy_multiplier = 5.0 if on else 0.1
