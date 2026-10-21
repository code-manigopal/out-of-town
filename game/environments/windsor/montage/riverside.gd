class_name OOTMontageRiverside
extends Node3D
## Montage shot (a): Windsor riverside on an early-November morning. The Detroit River with planar reflections, a paved
## riverside path with railing, lamp posts and benches, autumn trees, and the Detroit skyline across the water (a real
## backdrop only: generic towers, no logos). Local space: path at z -5..-1, water at y -2.4, the far shore at z -1000.

const WATER_Y: float = -2.4
const FAR_Z: float = -1010.0

var reflection: OOTPlanarReflection
var water: MeshInstance3D
var freighter: Node3D
var _t: float = 0.0


func build(cam: Camera3D) -> void:
	reflection = OOTPlanarReflection.new()
	reflection.name = "Reflection"
	reflection.main_camera = cam
	reflection.plane_y = global_position.y + WATER_Y
	add_child(reflection)
	_build_land()
	_build_water()
	_build_skyline()
	_build_props()
	_build_trees()
	_build_freighter()
	_build_leaves()


func _build_land() -> void:
	var lawn: StandardMaterial3D = OOTMontageKit.pbr("grass_path_2", 3.0, Color(0.88, 0.84, 0.66))
	var walk: StandardMaterial3D = OOTMontageKit.pbr("concrete_pavement", 2.4, Color(0.92, 0.9, 0.88))
	var rock: StandardMaterial3D = OOTMontageKit.pbr("dry_riverbed_rock", 2.2, Color(0.7, 0.7, 0.68))
	OOTMontageKit.ground(self, -420.0, 420.0, -1.0, 140.0, 0.0, lawn, 3.0)
	OOTMontageKit.ground(self, -420.0, 420.0, -5.0, -1.0, 0.012, walk, 2.4)
	OOTMontageKit.ground(self, -420.0, 420.0, -9.0, -5.0, 0.0, lawn, 3.0)
	OOTMontageKit.slope(self, -420.0, 420.0, -9.0, 0.0, -16.0, WATER_Y - 0.5, rock, 2.2)
	OOTMontageKit.ground(self, -420.0, 420.0, -16.0, -1200.0, WATER_Y - 0.6, OOTMontageKit.flat(Color(0.05, 0.07, 0.08), 0.9), 50.0)
	# a low concrete kerb along the path edge
	OOTMontageKit.box(self, Vector3(0, 0.08, -5.1), Vector3(840, 0.2, 0.25), walk)


func _build_water() -> void:
	water = MeshInstance3D.new()
	water.name = "Water"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(3200.0, 2300.0)
	pm.subdivide_width = 180
	pm.subdivide_depth = 120
	water.mesh = pm
	water.position = Vector3(0, WATER_Y, -1150.0 + 15.0)
	water.layers = OOTPlanarReflection.WATER_LAYER_BIT
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh: Shader = load("res://environments/windsor/montage/water.gdshader") as Shader
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("normal_a", OOTMontageKit.water_normal(11, 0.012, 2.0))
	m.set_shader_parameter("normal_b", OOTMontageKit.water_normal(23, 0.02, 1.4))
	m.set_shader_parameter("reflection_tex", reflection.texture())
	water.material_override = m
	add_child(water)


func _build_skyline() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4711
	var root: Node3D = Node3D.new()
	root.name = "Skyline"
	add_child(root)
	# the far shore: a dark low strip with trees and low-rise warehouses
	OOTMontageKit.ground(root, -900.0, 900.0, FAR_Z + 40.0, FAR_Z - 700.0, WATER_Y + 1.6, OOTMontageKit.flat(Color(0.1, 0.12, 0.1), 0.95), 50.0)
	var low: ShaderMaterial = _facade(Color(0.5, 0.48, 0.45), Color(0.18, 0.24, 0.3), 2.2, 3.0, 1.0, 0.62)
	var x: float = -720.0
	while x < 720.0:
		var w: float = rng.randf_range(20.0, 60.0)
		var h: float = rng.randf_range(8.0, 22.0)
		OOTMontageKit.box(root, Vector3(x + w * 0.5, WATER_Y + 1.6 + h * 0.5, FAR_Z - rng.randf_range(0, 25.0)), Vector3(w, h, rng.randf_range(20.0, 40.0)), low)
		x += w + rng.randf_range(2.0, 25.0)
	# generic towers: centre cluster tall, shoulders stepping down
	var mats: Array = [
		_facade(Color(0.62, 0.6, 0.56), Color(0.07, 0.12, 0.2), 3.4, 3.9, 11.0, 0.66),
		_facade(Color(0.5, 0.45, 0.4), Color(0.1, 0.15, 0.22), 3.0, 3.7, 12.0, 0.55),
		_facade(Color(0.68, 0.64, 0.58), Color(0.14, 0.22, 0.3), 3.6, 4.2, 13.0, 0.7),
		_facade(Color(0.34, 0.34, 0.36), Color(0.05, 0.09, 0.15), 3.2, 3.8, 14.0, 0.6),
	]
	var glass_band: ShaderMaterial = _facade(Color(0.35, 0.4, 0.45), Color(0.13, 0.22, 0.3), 3.4, 3.9, 15.0, 0.9)
	glass_band.set_shader_parameter("band", 1.0)
	var towers: Array = [
		# x, depth z, w, d, h, material, top
		[-520, -70, 34, 28, 70, 1, "flat"], [-470, -40, 40, 30, 96, 0, "flat"], [-420, -90, 30, 30, 140, 2, "setback"],
		[-370, -30, 44, 36, 84, 3, "flat"], [-330, -80, 36, 36, 176, 0, "setback"], [-285, -20, 38, 30, 110, 1, "flat"],
		[-240, -100, 32, 32, 214, 2, "spire"], [-205, -45, 42, 34, 128, 3, "flat"], [-165, -10, 36, 36, 160, 0, "setback"],
		[-120, -90, 46, 40, 232, 1, "flat"], [-62, -30, 30, 30, 120, 2, "flat"], [-20, -110, 40, 40, 252, 3, "setback"],
		[34, -60, 32, 32, 150, 0, "flat"], [76, -20, 44, 36, 104, 1, "flat"], [118, -95, 34, 34, 196, 2, "spire"],
		[160, -40, 40, 40, 134, 3, "setback"], [206, -75, 30, 30, 168, 0, "flat"], [250, -15, 44, 34, 92, 1, "flat"],
		[300, -90, 36, 36, 124, 2, "flat"], [346, -35, 40, 30, 74, 3, "flat"], [396, -70, 34, 34, 100, 0, "flat"],
		[450, -25, 46, 36, 66, 1, "flat"], [505, -60, 36, 30, 80, 2, "flat"], [560, -15, 40, 34, 52, 3, "flat"],
	]
	for t: Array in towers:
		var base_y: float = WATER_Y + 1.6
		var pos: Vector3 = Vector3(float(t[0]), base_y, FAR_Z - 80.0 + float(t[1]))
		var mat: ShaderMaterial = mats[int(t[5])]
		var w: float = float(t[2])
		var d: float = float(t[3])
		var h: float = float(t[4])
		OOTMontageKit.box(root, pos + Vector3(0, h * 0.5, 0), Vector3(w, h, d), mat)
		match String(t[6]):
			"setback":
				OOTMontageKit.box(root, pos + Vector3(0, h + h * 0.07, 0), Vector3(w * 0.72, h * 0.14, d * 0.72), mats[(int(t[5]) + 1) % 4])
				OOTMontageKit.box(root, pos + Vector3(0, h + h * 0.18, 0), Vector3(w * 0.4, h * 0.08, d * 0.4), mats[(int(t[5]) + 2) % 4])
			"spire":
				var pm: CylinderMesh = CylinderMesh.new()
				pm.top_radius = 0.0
				pm.bottom_radius = w * 0.34
				pm.height = h * 0.22
				pm.radial_segments = 4
				var mi: MeshInstance3D = MeshInstance3D.new()
				mi.mesh = pm
				mi.material_override = glass_band
				mi.position = pos + Vector3(0, h + h * 0.11, 0)
				mi.rotation_degrees.y = 45.0
				root.add_child(mi)
			_:
				OOTMontageKit.box(root, pos + Vector3(0, h + 3.0, 0), Vector3(w * 0.5, 6.0, d * 0.5), mats[(int(t[5]) + 3) % 4])
	# the round hotel-style cluster in the middle of the skyline (generic): five glass cylinders
	var cx: float = -72.0
	for i: int in 5:
		var cyl: CylinderMesh = CylinderMesh.new()
		var ang: float = TAU * i / 5.0 if i < 4 else 0.0
		cyl.top_radius = 15.0
		cyl.bottom_radius = 15.0
		cyl.height = 190.0 if i == 4 else 135.0
		cyl.radial_segments = 24
		var cm: MeshInstance3D = MeshInstance3D.new()
		cm.mesh = cyl
		cm.material_override = glass_band
		cm.position = Vector3(cx + (cos(ang) * 28.0 if i < 4 else 0.0), WATER_Y + 1.6 + cyl.height * 0.5, FAR_Z - 70.0 + (sin(ang) * 28.0 if i < 4 else 0.0))
		root.add_child(cm)
	# a long pale horizon band: distant buildings and the haze line beyond the river
	OOTMontageKit.box(root, Vector3(0, WATER_Y + 1.6 + 6.0, FAR_Z - 420.0), Vector3(2200, 12, 6), _facade(Color(0.55, 0.58, 0.62), Color(0.3, 0.38, 0.45), 4.0, 3.4, 2.0, 0.5))


func _facade(wall: Color, glass: Color, cx: float, cy: float, seed_v: float, fill: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://environments/windsor/montage/building_facade.gdshader") as Shader
	m.set_shader_parameter("wall_color", wall)
	m.set_shader_parameter("glass_color", glass)
	m.set_shader_parameter("cell", Vector2(cx, cy))
	m.set_shader_parameter("seed", seed_v)
	m.set_shader_parameter("glass_fill", fill)
	return m


func _build_props() -> void:
	var metal: StandardMaterial3D = OOTMontageKit.flat(Color(0.13, 0.15, 0.16), 0.45, 0.6)
	# railing along the top of the bank
	var x: float = -300.0
	while x <= 300.0:
		OOTMontageKit.box(self, Vector3(x, 0.52, -7.2), Vector3(0.07, 1.04, 0.07), metal)
		x += 2.6
	OOTMontageKit.box(self, Vector3(0, 1.02, -7.2), Vector3(600, 0.06, 0.07), metal)
	OOTMontageKit.box(self, Vector3(0, 0.62, -7.2), Vector3(600, 0.04, 0.04), metal)
	OOTMontageKit.box(self, Vector3(0, 0.24, -7.2), Vector3(600, 0.04, 0.04), metal)
	# lamp posts every 22 m: pole, arm, lamp head
	for i: int in range(-13, 14):
		var lx: float = i * 22.0
		OOTMontageKit.box(self, Vector3(lx, 2.35, -6.2), Vector3(0.13, 4.7, 0.13), metal)
		OOTMontageKit.box(self, Vector3(lx, 4.75, -6.45), Vector3(0.09, 0.09, 0.7), metal)
		OOTMontageKit.box(self, Vector3(lx, 4.68, -6.8), Vector3(0.28, 0.1, 0.5), OOTMontageKit.flat(Color(0.8, 0.8, 0.76), 0.6))
	# benches facing the river
	for bx: float in [-30.0, -9.0, 14.0, 41.0, 66.0, -52.0]:
		OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "bench.glb", self, Vector3(bx, 0.0, -6.0), 180.0)
	# bins and a few tufts of tall grass on the bank
	for bx: float in [-18.0, 28.0, 58.0]:
		OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "litter_bin.glb", self, Vector3(bx, 0.0, -2.0), 0.0)
	var grass: PackedScene = OOTMontageKit.scene("res://environments/windsor/montage/models/grass_medium_01/grass_medium_01.gltf")
	if grass != null:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5
		for i: int in 160:
			var g: Node3D = grass.instantiate() as Node3D
			add_child(g)
			g.position = Vector3(rng.randf_range(-70.0, 70.0), 0.0, rng.randf_range(-12.0, -8.0))
			g.rotation_degrees.y = rng.randf_range(0, 360)
			g.scale = Vector3.ONE * rng.randf_range(1.3, 2.2)


func _build_trees() -> void:
	var names: Array = ["oak_a", "maple_a", "beech_a", "maple_b", "oak_b", "birch_a"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 91
	for i: int in 70:
		var tx: float = rng.randf_range(-260.0, 260.0)
		var tz: float = rng.randf_range(5.0, 45.0)
		if absf(tx) < 6.0 and tz < 14.0:
			continue
		var n: String = String(names[rng.randi() % names.size()])
		OOTMontageKit.spawn(OOTMontageKit.TREES_DIR + n + ".glb", self, Vector3(tx, 0.0, tz), rng.randf_range(0, 360), rng.randf_range(0.7, 1.15), false)
	# two hero trees framing the foreground near the camera start
	OOTMontageKit.spawn(OOTMontageKit.TREES_DIR + "maple_a.glb", self, Vector3(-24.0, 0.0, 3.5), 40.0, 0.55, false)
	OOTMontageKit.spawn(OOTMontageKit.TREES_DIR + "oak_a.glb", self, Vector3(-3.0, 0.0, 6.5), 120.0, 0.6, false)


func _build_freighter() -> void:
	freighter = Node3D.new()
	freighter.name = "Freighter"
	add_child(freighter)
	var hull_m: StandardMaterial3D = OOTMontageKit.flat(Color(0.2, 0.06, 0.05), 0.7, 0.2)
	var white: StandardMaterial3D = OOTMontageKit.flat(Color(0.82, 0.82, 0.8), 0.7)
	var black: StandardMaterial3D = OOTMontageKit.flat(Color(0.05, 0.05, 0.06), 0.8)
	OOTMontageKit.box(freighter, Vector3(0, 3.0, 0), Vector3(150, 10, 19), hull_m)          # hull
	OOTMontageKit.box(freighter, Vector3(-4, 1.0, 0), Vector3(146, 3, 20), black)           # waterline
	OOTMontageKit.box(freighter, Vector3(62, 11.0, 0), Vector3(14, 14, 17), white)           # stern cabin
	OOTMontageKit.box(freighter, Vector3(66, 19.0, 0), Vector3(7, 4, 13), white)
	OOTMontageKit.box(freighter, Vector3(-68, 9.5, 0), Vector3(8, 6, 12), white)            # bow cabin
	var bow: PrismMesh = PrismMesh.new()
	bow.size = Vector3(19, 10, 22)
	var bmi: MeshInstance3D = MeshInstance3D.new()
	bmi.mesh = bow
	bmi.material_override = hull_m
	bmi.position = Vector3(-84.5, 3.0, 0)
	bmi.rotation_degrees = Vector3(0, 90, 0)
	freighter.add_child(bmi)
	var ch: StandardMaterial3D = OOTMontageKit.flat(Color(0.12, 0.12, 0.13), 0.6)
	for i: int in 4:
		OOTMontageKit.box(freighter, Vector3(-30 + i * 28, 9.0, 0), Vector3(14, 1.4, 14), ch)
	freighter.position = Vector3(-120.0, WATER_Y + 1.6, -430.0)
	freighter.rotation_degrees.y = 0.0


func _build_leaves() -> void:
	var p: GPUParticles3D = OOTMontageKit.leaf_particles(Vector3(26, 7, 30))
	p.position = Vector3(-8.0, 3.0, 0.0)
	add_child(p)


func _process(delta: float) -> void:
	_t += delta
	if freighter != null:
		freighter.position.x += delta * 2.2


## Camera for u in 0..1 (already eased): a slow crane up and dolly along the path, framing the skyline across the water.
func camera_pose(u: float) -> Dictionary:
	var pos: Vector3 = Vector3(-30.0, 1.35, 1.0).lerp(Vector3(-9.0, 3.2, -3.0), u)
	var look: Vector3 = Vector3(20.0, 60.0, FAR_Z).lerp(Vector3(-6.0, 46.0, FAR_Z), u)
	return {"pos": global_transform * pos, "look": global_transform * look, "fov": 46.0 - 6.0 * u}
