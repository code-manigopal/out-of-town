class_name OOTMaterialRemap
extends Node
## Swaps imported .glb surface materials for the project's shared materials.
## A surface whose material is named "mat_wood_oak" (the Blender slot name) gets
## res://materials/apartment/mat_wood_oak.tres when that file exists; otherwise
## the .glb material is kept. Glass surfaces stop casting shadows so sun beams
## pass through windows and picture frames.
##
## Drop this node anywhere: it remaps every MeshInstance3D under `target`
## (default: its parent) when it enters the tree. Call apply_to(node) for nodes
## added later.

@export var material_dir: String = "res://materials/apartment/"
@export var target: Node = null

static var _cache: Dictionary = {}


func _ready() -> void:
	apply_to(target if target != null else get_parent())


func apply_to(root: Node) -> int:
	var changed: int = 0
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i: int in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src == null or src.resource_name.is_empty():
				continue
			var slot: String = src.resource_name
			if slot.begins_with("mat_glass"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var repl: Material = _lookup(slot)
			if repl != null:
				mi.set_surface_override_material(i, repl)
				changed += 1
	return changed


func _lookup(slot: String) -> Material:
	if _cache.has(slot):
		return _cache[slot]
	var path: String = "%s%s.tres" % [material_dir, slot]
	var mat: Material = null
	if ResourceLoader.exists(path):
		mat = load(path) as Material
	_cache[slot] = mat
	return mat
