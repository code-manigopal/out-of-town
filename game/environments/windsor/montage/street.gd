class_name OOTMontageStreet
extends Node3D
## Montage shot (b): a busy Windsor road on a weekday morning, seen through a long lens from the sidewalk. Two lanes each
## way, parked cars, shops and houses on both sides (the exterior kit, read-only), street trees, lamps, a bus stop, moving
## traffic that loops. Local space: road centre line along x at z 0; westbound (toward -x) lanes at z < 0 (right-hand
## traffic), eastbound at z > 0.

const CARS: Array[String] = ["traffic_sedan.glb", "traffic_suv.glb", "traffic_hatchback.glb"]
const CAR_COLORS: Array[Color] = [
	Color(0.78, 0.78, 0.8), Color(0.12, 0.13, 0.15), Color(0.55, 0.1, 0.1), Color(0.14, 0.24, 0.42), Color(0.7, 0.7, 0.66),
	Color(0.2, 0.22, 0.2), Color(0.85, 0.85, 0.88), Color(0.3, 0.3, 0.33),
]
const LANES: Array = [[-5.7, -1.0], [-2.2, -1.0], [2.2, 1.0], [5.7, 1.0]]   # z, direction along x (-1 = toward -x)

var traffic: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _t: float = 0.0
var running: bool = false


func build(_cam: Camera3D) -> void:
	_rng.seed = 2024
	_build_road()
	_build_frontage()
	_build_furniture()
	_build_traffic()
	var leaves: GPUParticles3D = OOTMontageKit.leaf_particles(Vector3(25, 5, 9))
	leaves.position = Vector3(30, 4.0, 4.0)
	add_child(leaves)


func _build_road() -> void:
	var asph: StandardMaterial3D = OOTMontageKit.pbr("asphalt_01", 4.5, Color(0.8, 0.8, 0.82))
	var walk: StandardMaterial3D = OOTMontageKit.pbr("concrete_pavement", 2.4, Color(0.9, 0.88, 0.86))
	OOTMontageKit.ground(self, -260.0, 260.0, -8.0, 8.0, 0.0, asph, 4.5)
	OOTMontageKit.ground(self, -260.0, 260.0, 8.0, 12.5, 0.14, walk, 2.4)
	OOTMontageKit.ground(self, -260.0, 260.0, -12.5, -8.0, 0.14, walk, 2.4)
	OOTMontageKit.ground(self, -260.0, 260.0, 12.5, 60.0, 0.0, OOTMontageKit.pbr("grass_path_2", 3.0, Color(0.8, 0.76, 0.6)), 3.0)
	OOTMontageKit.ground(self, -260.0, 260.0, -60.0, -12.5, 0.0, OOTMontageKit.pbr("grass_path_2", 3.0, Color(0.8, 0.76, 0.6)), 3.0)
	OOTMontageKit.box(self, Vector3(0, 0.07, 8.1), Vector3(520, 0.14, 0.3), walk)
	OOTMontageKit.box(self, Vector3(0, 0.07, -8.1), Vector3(520, 0.14, 0.3), walk)
	var yellow: StandardMaterial3D = OOTMontageKit.flat(Color(0.85, 0.66, 0.1), 0.7)
	var white: StandardMaterial3D = OOTMontageKit.flat(Color(0.86, 0.86, 0.84), 0.7)
	for zz: float in [-0.12, 0.12]:
		OOTMontageKit.box(self, Vector3(0, 0.012, zz), Vector3(520, 0.012, 0.1), yellow)
	for zz: float in [-3.95, 3.95]:
		var x: float = -255.0
		while x < 255.0:
			OOTMontageKit.box(self, Vector3(x + 1.5, 0.012, zz), Vector3(3.0, 0.012, 0.12), white)
			x += 9.0
	for zz: float in [-7.7, 7.7]:
		OOTMontageKit.box(self, Vector3(0, 0.012, zz), Vector3(520, 0.012, 0.12), white)
	# crosswalk and stop lines
	for cx: float in [-34.0, 70.0]:
		for i: int in 11:
			var zc: float = -7.0 + i * 1.4
			OOTMontageKit.box(self, Vector3(cx, 0.014, zc), Vector3(3.0, 0.012, 0.6), white)
		OOTMontageKit.box(self, Vector3(cx + 3.0, 0.014, 3.9), Vector3(0.4, 0.012, 7.4), white)
		OOTMontageKit.box(self, Vector3(cx - 3.0, 0.014, -3.9), Vector3(0.4, 0.012, 7.4), white)


func _build_frontage() -> void:
	var shops: Array[String] = ["shop_a.glb", "shop_b.glb", "shop_c.glb", "shop_d.glb"]
	var houses: Array[String] = ["house_a.glb", "house_c.glb", "house_f.glb", "house_g.glb"]
	var widths: Dictionary = {"shop_a.glb": 8.2, "shop_b.glb": 7.2, "shop_c.glb": 9.2, "shop_d.glb": 7.7,
		"house_a.glb": 8.7, "house_c.glb": 9.4, "house_f.glb": 8.2, "house_g.glb": 8.0}
	# north side (z < 0): facades face +z; south side (z > 0): rotated to face -z
	for side: int in [-1, 1]:
		var x: float = -240.0
		var i: int = 0
		while x < 240.0:
			var use_shop: bool = absf(x) < 130.0 or _rng.randf() < 0.3
			var nm: String = (shops if use_shop else houses)[_rng.randi() % 4]
			var w: float = float(widths[nm])
			var zf: float = 15.1 if use_shop else 23.3   # shops face -z in the model (front at local z -1.5), houses face +z (front at +7.3)
			var yaw: float = (180.0 if side < 0 else 0.0) if use_shop else (0.0 if side < 0 else 180.0)
			var b: Node3D = OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + nm, self, Vector3(x + w * 0.5, 0.0, side * zf), yaw)
			if b != null and not use_shop:
				b.position.z = side * zf
			x += w + (0.6 if use_shop else _rng.randf_range(2.5, 6.0))
			i += 1
	# street trees along both sidewalks
	var tree_names: Array[String] = ["tree_a.glb", "tree_b.glb", "tree_c.glb", "tree_d.glb", "tree_e.glb"]
	for side2: int in [-1, 1]:
		var tx: float = -230.0
		while tx < 230.0:
			var tn: String = tree_names[_rng.randi() % 5]
			if side2 > 0 and tx > 14.0 and tx < 66.0:
				tx += 6.0
				continue                       # keep the camera's side of the road clear of trunks
			OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + tn, self, Vector3(tx, 0.0, side2 * 9.8), _rng.randf_range(0, 360), _rng.randf_range(0.85, 1.1))
			tx += _rng.randf_range(11.0, 18.0)


func _build_furniture() -> void:
	# lamps (the arm of streetlight.glb points to local -x: yaw +90 puts it over the road on the north side)
	var lx: float = -228.0
	while lx < 230.0:
		OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "streetlight.glb", self, Vector3(lx, 0.14, -8.9), 90.0)
		OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "streetlight.glb", self, Vector3(lx + 17.0, 0.14, 8.9), -90.0)
		lx += 34.0
	var px: float = -220.0
	while px < 230.0:
		OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "utility_pole.glb", self, Vector3(px, 0.14, -12.0), 0.0)
		px += 42.0
	OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "bus_shelter.glb", self, Vector3(24.0, 0.14, 10.8), 180.0)
	OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "person_a.glb", self, Vector3(23.2, 0.14, 10.6), 200.0)
	OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "person_c.glb", self, Vector3(24.6, 0.14, 10.9), 170.0)
	OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "person_b.glb", self, Vector3(-8.0, 0.14, 11.4), 90.0)
	OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "person_d.glb", self, Vector3(-40.0, 0.14, -10.5), 270.0)
	OOTMontageKit.spawn(OOTMontageKit.EXT_DIR + "hydrant.glb", self, Vector3(8.0, 0.14, 9.2), 0.0)
	# parked cars on the kerb side of both outer lanes
	for i: int in 14:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var cx: float = -170.0 + i * 24.0 + _rng.randf_range(-4, 4)
		if absf(cx - 24.0) < 14.0 or absf(cx + 34.0) < 12.0 or (side > 0.0 and cx > 8.0 and cx < 70.0):
			continue
		_spawn_car(Vector3(cx, 0.0, side * 7.0 - 0.0), 0.0 if side < 0.0 else 180.0, _rng.randi() % 3)


func _spawn_car(pos: Vector3, yaw_deg: float, kind: int) -> Node3D:
	var car: Node3D = OOTMontageKit.spawn(OOTMontageKit.SEDAN_DIR + CARS[kind], self, pos, yaw_deg, 1.0, false)
	if car == null:
		return null
	_tint_car(car, CAR_COLORS[_rng.randi() % CAR_COLORS.size()])
	return car


## The traffic GLBs have a body-paint material; give each car its own colour (duplicated so cars do not share one tint).
func _tint_car(car: Node3D, col: Color) -> void:
	for n: Node in car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m != null and m.resource_name.to_lower().contains("paint"):
				var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				if d != null:
					d.albedo_color = col
					mi.set_surface_override_material(s, d)


func _build_traffic() -> void:
	for lane: Array in LANES:
		var x: float = -170.0 + _rng.randf_range(0, 20)
		while x < 170.0:
			var kind: int = _rng.randi() % 3
			var dir: float = float(lane[1])
			var car: Node3D = _spawn_car(Vector3(x, 0.0, float(lane[0])), -90.0 if dir < 0.0 else 90.0, kind)
			if car != null:
				traffic.append({"node": car, "dir": dir, "speed": _rng.randf_range(5.0, 9.5)})
			x += _rng.randf_range(16.0, 34.0)


func _process(delta: float) -> void:
	if not visible:
		return
	for t: Dictionary in traffic:
		var n: Node3D = t["node"]
		n.position.x += float(t["dir"]) * float(t["speed"]) * delta
		if n.position.x < -175.0:
			n.position.x = 175.0
		elif n.position.x > 175.0:
			n.position.x = -175.0


## Advances the traffic by `seconds` (used when a shot is sought to a time instead of played).
func simulate(seconds: float) -> void:
	for t: Dictionary in traffic:
		var n: Node3D = t["node"]
		n.position.x += float(t["dir"]) * float(t["speed"]) * seconds
		n.position.x = wrapf(n.position.x, -175.0, 175.0)


## Slow dolly along the south sidewalk with a long lens, rising a little: parallax from the passing cars and lamps.
func camera_pose(u: float) -> Dictionary:
	var pos: Vector3 = Vector3(46.0, 1.5, 10.4).lerp(Vector3(26.0, 2.2, 10.4), u)
	var look: Vector3 = pos + Vector3(-13.0, 1.5 - 0.6 * u, -27.0)
	return {"pos": global_transform * pos, "look": global_transform * look, "fov": 30.0, "dof": true, "dof_distance": 30.0}
