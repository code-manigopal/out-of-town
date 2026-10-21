class_name OOTMontageHouse
extends Node3D
## Montage shot (d): Mani's house, the two-storey brick two-flat (upper flat 2), seen from the street. The camera cranes up
## from the road across the lawn and ends at the upper-flat window, facing the blinds, where the story continues inside
## (apartment.gd picks the move up from the other side of the glass). Uses the exterior kit read-only (building, neighbours,
## houses, trees, street furniture, cars); local space equals the exterior lot (building x -5..5, z -4.5..4.5, street at +z).

## Where the camera stops: just outside the upper-flat window pair (facing -z).
const WINDOW_POS: Vector3 = Vector3(-1.45, 4.35, 6.3)
const WINDOW_LOOK: Vector3 = Vector3(-1.45, 4.3, 0.0)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var traffic: Array = []


func build(_cam: Camera3D) -> void:
	_rng.seed = 77
	var ext: String = OOTMontageKit.EXT_DIR
	OOTMontageKit.spawn(ext + "building.glb", self)
	OOTMontageKit.spawn(ext + "neighbours.glb", self)
	var lawn: StandardMaterial3D = OOTMontageKit.pbr("grass_path_2", 3.0, Color(0.82, 0.74, 0.5))
	var walk: StandardMaterial3D = OOTMontageKit.pbr("concrete_pavement", 2.4, Color(0.88, 0.86, 0.84))
	var asph: StandardMaterial3D = OOTMontageKit.pbr("asphalt_01", 4.5, Color(0.78, 0.78, 0.8))
	OOTMontageKit.ground(self, -140.0, 140.0, -40.0, 12.6, -0.02, lawn, 3.0)
	OOTMontageKit.ground(self, -140.0, 140.0, 12.6, 15.4, 0.0, walk, 2.4)
	OOTMontageKit.ground(self, -140.0, 140.0, 15.4, 26.2, -0.12, asph, 4.5)
	OOTMontageKit.ground(self, -140.0, 140.0, 26.2, 29.0, 0.0, walk, 2.4)
	OOTMontageKit.ground(self, -140.0, 140.0, 29.0, 70.0, -0.02, lawn, 3.0)
	OOTMontageKit.box(self, Vector3(0, -0.06, 15.4), Vector3(280, 0.16, 0.25), walk)
	OOTMontageKit.box(self, Vector3(0, -0.06, 26.2), Vector3(280, 0.16, 0.25), walk)
	var yellow: StandardMaterial3D = OOTMontageKit.flat(Color(0.85, 0.66, 0.1), 0.7)
	var white: StandardMaterial3D = OOTMontageKit.flat(Color(0.86, 0.86, 0.84), 0.7)
	for zz: float in [20.65, 20.85]:
		OOTMontageKit.box(self, Vector3(0, -0.105, zz), Vector3(280, 0.012, 0.1), yellow)
	var x: float = -135.0
	while x < 135.0:
		OOTMontageKit.box(self, Vector3(x + 1.5, -0.105, 18.0), Vector3(3.0, 0.012, 0.12), white)
		OOTMontageKit.box(self, Vector3(x + 1.5, -0.105, 23.5), Vector3(3.0, 0.012, 0.12), white)
		x += 9.0
	_build_street_life()
	var leaves: GPUParticles3D = OOTMontageKit.leaf_particles(Vector3(20, 4, 14))
	leaves.position = Vector3(0.0, 3.5, 18.0)
	add_child(leaves)


func _build_street_life() -> void:
	var ext: String = OOTMontageKit.EXT_DIR
	# houses and shops opposite and along the street; the exterior's own facing convention: front toward +z, rotate 180 for the far side
	var far: Array[String] = ["house_a.glb", "house_c.glb", "house_f.glb", "house_g.glb", "shop_a.glb", "shop_c.glb", "house_a.glb", "house_c.glb"]
	var fx: float = -66.0
	var i: int = 0
	while fx < 80.0:
		var nm: String = far[i % far.size()]
		var w: float = 9.0
		if nm.begins_with("shop"):
			OOTMontageKit.spawn(ext + nm, self, Vector3(fx + w * 0.5, 0.0, 32.5), 0.0)
		else:
			OOTMontageKit.spawn(ext + nm, self, Vector3(fx + w * 0.5, 0.0, 41.0), 180.0)
		fx += w + _rng.randf_range(3.0, 6.0)
		i += 1
	var near_x: Array = [-66.0, -54.0, -42.0, -30.0, 22.0, 34.0, 46.0, 58.0, 70.0]
	var near: Array[String] = ["house_a.glb", "house_c.glb", "house_f.glb", "house_g.glb", "house_a.glb"]
	for k: int in near_x.size():
		OOTMontageKit.spawn(ext + near[k % near.size()], self, Vector3(float(near_x[k]), 0.0, -2.0), 0.0)
	# trees along the walk and in the yards
	var tree_names: Array[String] = ["tree_a.glb", "tree_b.glb", "tree_c.glb", "tree_d.glb", "tree_e.glb"]
	for tx: float in [-24.0, -10.5, 11.0, 19.0, 36.0, 52.0, -45.0, -60.0, 66.0]:
		OOTMontageKit.spawn(ext + tree_names[_rng.randi() % 5], self, Vector3(tx, 0.0, 11.4), _rng.randf_range(0, 360), _rng.randf_range(0.9, 1.15))
	for tx: float in [-30.0, -10.0, 8.0, 30.0, 50.0, -50.0]:
		OOTMontageKit.spawn(ext + tree_names[_rng.randi() % 5], self, Vector3(tx, 0.0, 27.8), _rng.randf_range(0, 360), _rng.randf_range(0.9, 1.15))
	for lx: float in [-32.0, 2.0, 36.0, -64.0]:
		OOTMontageKit.spawn(ext + "streetlight.glb", self, Vector3(lx, 0.0, 14.8), 90.0)
	OOTMontageKit.spawn(ext + "utility_pole.glb", self, Vector3(14.0, 0.0, 14.2), 0.0)
	OOTMontageKit.spawn(ext + "utility_pole.glb", self, Vector3(-38.0, 0.0, 14.2), 0.0)
	# cars: a few parked at the near kerb and a few moving
	var cars: Array[String] = ["traffic_sedan.glb", "traffic_suv.glb", "traffic_hatchback.glb"]
	var colors: Array[Color] = [Color(0.78, 0.78, 0.8), Color(0.12, 0.13, 0.15), Color(0.55, 0.1, 0.1), Color(0.14, 0.24, 0.42), Color(0.7, 0.7, 0.66)]
	for px: float in [-20.0, 14.0, -52.0, 40.0]:
		_car(cars[_rng.randi() % 3], Vector3(px, -0.12, 16.6), 90.0, colors[_rng.randi() % 5])
	for lane: Array in [[22.6, -1.0], [18.6, 1.0]]:
		var cx: float = -60.0 + _rng.randf_range(0, 30)
		while cx < 70.0:
			var d: float = float(lane[1])
			var c: Node3D = _car(cars[_rng.randi() % 3], Vector3(cx, -0.12, float(lane[0])), -90.0 if d < 0.0 else 90.0, colors[_rng.randi() % 5])
			if c != null:
				traffic.append({"node": c, "dir": d, "speed": _rng.randf_range(5.0, 8.0)})
			cx += _rng.randf_range(26.0, 48.0)


func _car(file: String, pos: Vector3, yaw: float, col: Color) -> Node3D:
	var car: Node3D = OOTMontageKit.spawn(OOTMontageKit.SEDAN_DIR + file, self, pos, yaw, 1.0, false)
	if car == null:
		return null
	for n: Node in car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m != null and m.resource_name.to_lower().contains("paint") and m is StandardMaterial3D:
				var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = col
				mi.set_surface_override_material(s, d)
	return car


func _process(delta: float) -> void:
	if not visible:
		return
	for t: Dictionary in traffic:
		var n: Node3D = t["node"]
		n.position.x = wrapf(n.position.x + float(t["dir"]) * float(t["speed"]) * delta, -80.0, 80.0)


func simulate(seconds: float) -> void:
	for t: Dictionary in traffic:
		var n: Node3D = t["node"]
		n.position.x = wrapf(n.position.x + float(t["dir"]) * float(t["speed"]) * seconds, -80.0, 80.0)


## Street-level start, then a crane up and a dolly across the lawn to the upper-flat window. u is already eased.
func camera_pose(u: float) -> Dictionary:
	var start: Vector3 = Vector3(7.0, 1.7, 28.3)
	var pos: Vector3 = start.lerp(WINDOW_POS, u)
	pos.y = lerpf(start.y, WINDOW_POS.y, pow(u, 1.5))                # the crane lags behind the dolly, then rises into the window
	var look: Vector3 = Vector3(-1.0, 3.6, 4.0).lerp(WINDOW_LOOK, u)
	return {"pos": global_transform * pos, "look": global_transform * look, "fov": lerpf(40.0, 52.0, u)}
