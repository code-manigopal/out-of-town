class_name OOTMontageForest
extends Node3D
## Montage shot (c): the dense forest and tree-lined edge of the city. A county road runs along x; a wall of mixed
## deciduous and spruce forest (Proton Scatter, multimesh instancing, trees from tools/blender/build_montage_trees.py)
## stands to the north with ferns and shrubs along its foot; the low sun comes through it as light shafts.
## Local space: road centre at z 0, forest edge at z -9 going back to z -70.

const SCATTER_MOD: String = "res://addons/proton_scatter/src/modifiers/"
const FOREST_X: Vector2 = Vector2(-90.0, 150.0)

var _fern: String = "res://environments/windsor/montage/models/fern_02/fern_02.gltf"
var scatters: Array = []


func build(_cam: Camera3D) -> void:
	_build_ground()
	_build_forest()
	var leaves: GPUParticles3D = OOTMontageKit.leaf_particles(Vector3(18, 6, 8))
	leaves.position = Vector3(-6.0, 4.0, 2.0)
	add_child(leaves)


func _build_ground() -> void:
	var litter: StandardMaterial3D = OOTMontageKit.pbr("forest_leaves_04", 3.0, Color(0.95, 0.85, 0.7))
	var grass: StandardMaterial3D = OOTMontageKit.pbr("grass_path_2", 3.0, Color(0.85, 0.78, 0.55))
	var asph: StandardMaterial3D = OOTMontageKit.pbr("asphalt_01", 4.5, Color(0.72, 0.72, 0.74))
	OOTMontageKit.ground(self, -300.0, 300.0, -140.0, -9.0, 0.0, litter, 3.0)
	OOTMontageKit.ground(self, -300.0, 300.0, -9.0, -4.6, 0.0, grass, 3.0)
	OOTMontageKit.ground(self, -300.0, 300.0, -4.6, 4.6, 0.02, asph, 4.5)
	OOTMontageKit.ground(self, -300.0, 300.0, 4.6, 9.0, 0.0, grass, 3.0)
	OOTMontageKit.ground(self, -300.0, 300.0, 9.0, 140.0, 0.0, grass, 3.0)
	var yellow: StandardMaterial3D = OOTMontageKit.flat(Color(0.8, 0.62, 0.1), 0.7)
	var white: StandardMaterial3D = OOTMontageKit.flat(Color(0.84, 0.84, 0.8), 0.7)
	var x: float = -295.0
	while x < 295.0:
		OOTMontageKit.box(self, Vector3(x + 2.0, 0.035, 0.0), Vector3(4.0, 0.012, 0.12), yellow)
		x += 12.0
	for zz: float in [-4.3, 4.3]:
		OOTMontageKit.box(self, Vector3(0, 0.035, zz), Vector3(600, 0.012, 0.12), white)
	# a low wooden fence line and a ditch edge on the south side
	var wood: StandardMaterial3D = OOTMontageKit.flat(Color(0.3, 0.24, 0.18), 0.9)
	var fx: float = -140.0
	while fx < 150.0:
		OOTMontageKit.box(self, Vector3(fx, 0.5, 8.4), Vector3(0.1, 1.0, 0.1), wood)
		fx += 3.0
	OOTMontageKit.box(self, Vector3(5, 0.85, 8.4), Vector3(290, 0.06, 0.05), wood)
	OOTMontageKit.box(self, Vector3(5, 0.5, 8.4), Vector3(290, 0.06, 0.05), wood)


func _modifiers(amount: int, seed_v: int) -> ProtonScatterModifierStack:
	var create: Script = load(SCATTER_MOD + "create_inside_random.gd") as Script
	var rand: Script = load(SCATTER_MOD + "randomize_transforms.gd") as Script
	var stack: ProtonScatterModifierStack = ProtonScatterModifierStack.new()
	var c: ScatterBaseModifier = create.new() as ScatterBaseModifier
	c.set("amount", amount)
	var r: ScatterBaseModifier = rand.new() as ScatterBaseModifier
	r.set("rotation", Vector3(2.0, 360.0, 2.0))
	r.set("scale", Vector3(0.28, 0.28, 0.28))
	stack.stack = [c, r]
	return stack


func _scatter(sname: String, items: Array, center: Vector3, size: Vector2, amount: int, seed_v: int, range_end: float = 0.0) -> ProtonScatter:
	var sc: ProtonScatter = ProtonScatter.new()
	sc.name = sname
	sc.global_seed = seed_v
	sc.dbg_disable_thread = true
	sc.use_chunks = false
	sc.modifier_stack = _modifiers(amount, seed_v)
	for it: Array in items:
		var item: ProtonScatterItem = ProtonScatterItem.new()
		item.name = "Item_" + String(it[0]).get_file().get_basename()
		item.source = 1
		item.path = String(it[0])
		item.proportion = int(it[1])
		item.lod_generate = false
		if range_end > 0.0:
			item.visibility_range_end = range_end
			item.visibility_range_end_margin = 10.0
			item.visibility_range_fade_mode = 1
		sc.add_child(item)
	var shape: ProtonScatterShape = ProtonScatterShape.new()
	var box: ProtonScatterBoxShape = ProtonScatterBoxShape.new()
	box.size = Vector3(size.x, 0.05, size.y)
	shape.shape = box
	sc.add_child(shape)
	shape.position = Vector3.ZERO
	add_child(sc)
	sc.position = center
	scatters.append(sc)
	return sc


func _build_forest() -> void:
	var t: String = OOTMontageKit.TREES_DIR
	var trees: Array = [
		[t + "oak_a.glb", 14], [t + "oak_b.glb", 12], [t + "maple_a.glb", 15], [t + "maple_b.glb", 13],
		[t + "beech_a.glb", 11], [t + "birch_a.glb", 9], [t + "spruce_a.glb", 15], [t + "spruce_b.glb", 11],
	]
	var wx: float = FOREST_X.y - FOREST_X.x
	var cx: float = (FOREST_X.x + FOREST_X.y) * 0.5
	# the wall: three depth bands so the nearest band (the edge) is the densest and cheapest to see
	_scatter("ForestEdge", trees, Vector3(cx, 0.0, -14.0), Vector2(wx, 10.0), 110, 11, 170.0)
	_scatter("ForestMid", trees, Vector3(cx, 0.0, -34.0), Vector2(wx, 28.0), 260, 21, 150.0)
	_scatter("ForestDeep", trees, Vector3(cx, 0.0, -66.0), Vector2(wx, 34.0), 190, 31, 130.0)
	var under: Array = [[t + "shrub_a.glb", 50], [t + "shrub_b.glb", 50]]
	_scatter("Shrubs", under, Vector3(cx, 0.0, -10.5), Vector2(wx, 5.0), 170, 41, 90.0)
	if ResourceLoader.exists(_fern):
		_scatter("Ferns", [[_fern, 100]], Vector3(cx, 0.0, -11.0), Vector2(wx, 7.0), 700, 51, 55.0)
	# the other side of the road: a thin, lighter tree line
	var light: Array = [[t + "maple_b.glb", 20], [t + "oak_b.glb", 20], [t + "birch_a.glb", 20], [t + "spruce_b.glb", 15]]
	_scatter("SouthLine", light, Vector3(cx, 0.0, 22.0), Vector2(wx, 14.0), 45, 61, 140.0)


## Slow dolly down the road with the camera low, the forest wall on the left, rising a little as the light breaks through.
func camera_pose(u: float) -> Dictionary:
	var pos: Vector3 = Vector3(-46.0, 1.35, 2.4).lerp(Vector3(-24.0, 2.3, 1.6), u)
	var look: Vector3 = Vector3(30.0, 6.0, -14.0).lerp(Vector3(26.0, 8.0, -16.0), u)
	return {"pos": global_transform * pos, "look": global_transform * look, "fov": 38.0, "volumetric": true}
