class_name OOTExteriorWorld
extends Node3D
## The Windsor street world around Mani's building, built in code from the Blender kit in
## res://environments/windsor/exterior/ (tools/blender/build_windsor_exterior.py, build_roadworks.py): ground, streets with
## kerbs, markings, crosswalks and drains, sidewalks, the front street's traffic (OOTTrafficCar: yields to Mani and to the
## car ahead) and kerb-parked cars, shops across the street with their sign slots (signs/<shop_id>.png), bus stop, street
## trees, houses, lamp posts, hydrants and bins, puddles, the drive route, the road-works closures at every wrong turn, and
## the spawn points / sidewalk routes for the pedestrian system. The authored, hand-placed pieces (building, alley props,
## doors, stairs, graffiti slots, car) live in windsor_exterior.tscn.
##
## Layout (Godot metres, x east, z south toward the front street; see the Blender script header):
##   front street z 15.2..26.0 (westbound lane z 19.0, eastbound z 22.2), sidewalks z 12.6..14.1 / 27.0..28.5
##   side alley x 5.1..8.5, back lot z -4.5..-18.5, back street z -25.5..-18.5 and the blocks west of it.
## Roads lie ROAD_DROP below the sidewalks; kerbs are the step between.

const DIR: String = "res://environments/windsor/exterior/"
const MAT_DIR: String = DIR + "materials/"
const SIGN_DIR: String = DIR + "signs/"
const SND_TRAFFIC: String = "res://audio/sfx/exterior/traffic_car_loop.ogg"
const ROAD_DROP: float = 0.12
## Far kit pieces (houses, trees, cars) are culled beyond this distance; the fog has swallowed them by then.
const VISIBLE_RANGE: float = 210.0
## Collision at every road edge slopes up over this run (about 17 degrees) so people and cars can climb the kerb.
const RAMP_RUN: float = 0.4
## Length of the asphalt ramp from the lot down to the street (gentle enough for a low car).
const DRIVE_RAMP_RUN: float = 4.0
const KERB_W: float = 0.2
const PARK_KERB_GAP: float = 0.25

## Corners of the drive: out of the lot, north, left (west) along the back street, right at the second cross street,
## left again. The car starts at the first corner facing north.
const ROUTE_CORNERS: Array[Vector3] = [
	Vector3(-0.8, 0.0, -10.5), Vector3(-0.8, 0.0, -23.7), Vector3(-108.2, 0.0, -23.7), Vector3(-108.2, 0.0, -111.8),
	Vector3(-198.0, 0.0, -111.8)]
const ROUTE_FILLET: float = 8.0

## Roads: a (start), b (end) on the centre line (x, z), asphalt half width, sidewalk inner offset from the centre, sidewalk
## width. All axis-aligned.
const ROADS: Array[Dictionary] = [
	{"id": "front", "a": Vector2(-150.0, 20.6), "b": Vector2(150.0, 20.6), "half": 5.4, "walk_in": 6.5, "walk_w": 1.5, "yellow": true},
	{"id": "back", "a": Vector2(-215.0, -22.0), "b": Vector2(45.0, -22.0), "half": 3.5, "walk_in": 4.5, "walk_w": 1.5, "yellow": true},
	{"id": "cross1", "a": Vector2(-45.0, -150.0), "b": Vector2(-45.0, -22.0), "half": 3.5, "walk_in": 4.5, "walk_w": 1.5, "yellow": true},
	{"id": "cross2", "a": Vector2(-110.0, -150.0), "b": Vector2(-110.0, -22.0), "half": 3.5, "walk_in": 4.5, "walk_w": 1.5, "yellow": true},
	{"id": "blvd", "a": Vector2(-215.0, -110.0), "b": Vector2(-40.0, -110.0), "half": 3.5, "walk_in": 4.5, "walk_w": 1.5, "yellow": true},
]

## The shops across the front street, west to east: id (= signs/<id>.png), name, kit model, awning. The sign quad of a
## shop of width W is (W - 1.3) x 0.9 m, 300 px per metre (see docs/art/prompts-shop-signs.md).
const SHOPS: Array[Dictionary] = [
	{"id": "brindle_wick_cafe", "name": "Brindle & Wick Café", "kit": "shop_a"},
	{"id": "quill_books", "name": "Quill Books", "kit": "shop_b"},
	{"id": "tamsins_bakery", "name": "Tamsin's Bakery", "kit": "shop_c"},
	{"id": "kellerman_dry_cleaning", "name": "Kellerman Dry Cleaning", "kit": "shop_d"},
	{"id": "holloway_hardware", "name": "Holloway Hardware", "kit": "shop_b"},
	{"id": "nimbus_barber", "name": "Nimbus Barber", "kit": "shop_a"},
	{"id": "fernwood_florist", "name": "Fernwood Florist", "kit": "shop_d"},
	{"id": "orchard_row_pharmacy", "name": "Orchard Row Pharmacy", "kit": "shop_c"},
	{"id": "lakeshore_vinyl", "name": "Lakeshore Vinyl & Records", "kit": "shop_b"},
	{"id": "halloran_and_sons_butcher", "name": "Halloran & Sons Butcher", "kit": "shop_d"},
	{"id": "corner_slice_pizzeria", "name": "Corner Slice Pizzeria", "kit": "shop_a"},
	{"id": "ironbridge_tailors", "name": "Ironbridge Tailors", "kit": "shop_c"},
]
const SHOP_WIDTHS: Dictionary = {"shop_a": 8.0, "shop_b": 7.0, "shop_c": 9.0, "shop_d": 7.5}
const SHOP_ROW_X0: float = -50.0
const SHOP_FRONT_Z: float = 28.5
const SIGN_PX_PER_M: float = 300.0
const SIGN_HEIGHT: float = 0.9
const SIGN_CENTER_Y: float = 3.85

## Road-works closures, one at every wrong turn off the drive. pos = centre of the closed road mouth, along = unit vector
## across the road (the line of barricades), approach = unit vector toward the traffic that arrives, half = road half
## width. The invisible blocker spans the road plus its verges and sidewalks.
const ROADWORKS: Array[Dictionary] = [
	{"id": "rw_back_east", "pos": Vector3(12.0, 0.0, -22.0), "along": Vector3(0, 0, 1), "approach": Vector3(-1, 0, 0), "half": 3.5,
		"what": "back street east of the lot (a right turn out of the lot)"},
	{"id": "rw_cross1_north", "pos": Vector3(-45.0, 0.0, -29.0), "along": Vector3(1, 0, 0), "approach": Vector3(0, 0, 1), "half": 3.5,
		"what": "the first cross street, straight ahead on the left"},
	{"id": "rw_back_west", "pos": Vector3(-113.6, 0.0, -22.0), "along": Vector3(0, 0, 1), "approach": Vector3(1, 0, 0), "half": 3.5,
		"what": "back street straight on past the second cross street"},
	{"id": "rw_blvd_east", "pos": Vector3(-103.6, 0.0, -110.0), "along": Vector3(0, 0, 1), "approach": Vector3(-1, 0, 0), "half": 3.5,
		"what": "the boulevard to the right"},
	{"id": "rw_cross2_north", "pos": Vector3(-110.0, 0.0, -117.0), "along": Vector3(1, 0, 0), "approach": Vector3(0, 0, 1), "half": 3.5,
		"what": "the second cross street straight on past the boulevard"},
]

## Proton Scatter litter: fallen leaves over the verges and front yards (ProtonScatter box areas, random placement).
const SCATTER_DIR: String = "res://environments/windsor/exterior/scatter/"
const SCATTER_MOD: String = "res://addons/proton_scatter/src/modifiers/"
## x, z of the box centre, size x, size z, Poisson radius.
const LITTER_AREAS: Array[Vector4] = [Vector4(0.0, 14.7, 200.0, 0.9), Vector4(0.0, 26.6, 200.0, 0.9), Vector4(40.0, 8.0, 80.0, 6.0),
	Vector4(-40.0, 8.0, 60.0, 6.0), Vector4(-60.0, -16.0, 120.0, 1.0), Vector4(-110.0, -70.0, 1.0, 90.0)]
const CAR_KIT: Array[String] = ["traffic_sedan", "traffic_hatchback", "traffic_suv"]
const CAR_COLOURS: Array[Color] = [Color(0.62, 0.12, 0.12), Color(0.85, 0.85, 0.82), Color(0.13, 0.2, 0.36),
	Color(0.12, 0.13, 0.14), Color(0.55, 0.55, 0.12), Color(0.2, 0.36, 0.28), Color(0.78, 0.5, 0.15), Color(0.5, 0.52, 0.56)]
const TREES: Array[String] = ["tree_a", "tree_b", "tree_c", "tree_d", "tree_e"]
const HOUSES: Array[String] = ["house_a", "house_b", "house_c", "house_d", "house_e", "house_f", "house_g"]
const HOUSE_DEPTH: Dictionary = {"house_a": 9.5, "house_b": 8.5, "house_c": 9.0, "house_d": 8.0, "house_e": 9.0, "house_f": 9.0, "house_g": 8.0}
const LOT_BAY_W: float = 2.8
## Hydrants on the front street verges: x, side (-1 north verge, +1 south verge).
const HYDRANTS: Array[Vector2] = [Vector2(-38.0, -1.0), Vector2(33.0, -1.0), Vector2(-20.0, 1.0), Vector2(52.0, 1.0)]

var route: PackedVector3Array = PackedVector3Array()
var traffic: Array[OOTTrafficCar] = []
var lanes: Array[OOTTrafficLane] = []
var pedestrians: Array[Node3D] = []
var parked_cars: Array[Dictionary] = []      # {node, kerb, horiz, inward, dims, face}
var closures: Array[OOTRoadworks] = []
var shop_signs: Array[MeshInstance3D] = []
var ped_spawns: Array[Marker3D] = []
var ped_routes: Array[Path3D] = []
var house_count: int = 0
var tree_count: int = 0
var detail: bool = true
## Fallen-leaf litter with Proton Scatter (off in the quick test worlds).
var scatter_litter: bool = true
var spawn_peds: bool = true
var scatters: Array[Node3D] = []

var _mats: Dictionary = {}
var _scenes: Dictionary = {}
var _dims_cache: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rects: Array[Rect2] = []
var _house_rects: Array[Rect2] = []


func _ready() -> void:
	_rng.seed = 41
	route = make_route(ROUTE_CORNERS, ROUTE_FILLET)
	_snap_route_to_ground()
	build_ground()
	build_streets()
	if detail:
		build_front_street()
		build_blocks()
		build_roadworks()
		build_pedestrian_hooks()
		if spawn_peds:
			spawn_pedestrians()
		if scatter_litter:
			build_litter()
	build_boundaries()


# --- helpers ---------------------------------------------------------------------------------

func mat(n: String) -> Material:
	if not _mats.has(n):
		var p: String = MAT_DIR + n + ".tres"
		_mats[n] = load(p) as Material if ResourceLoader.exists(p) else null
	return _mats[n]


func scene_of(file: String) -> PackedScene:
	if not _scenes.has(file):
		var p: String = ("res://vehicles/sedan/" if file.begins_with("traffic_") else DIR) + file + ".glb"
		_scenes[file] = load(p) as PackedScene if ResourceLoader.exists(p) else null
	return _scenes[file]


func place(file: String, pos: Vector3, yaw_deg: float = 0.0, parent: Node = null) -> Node3D:
	var ps: PackedScene = scene_of(file)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	(parent if parent != null else self).add_child(n)
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	_remap(n)
	return n


## Swaps the kit's textured slots for the .tres materials in MAT_DIR; glass stops casting shadows.
func _remap(root: Node) -> void:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		if "Windows" in mi.name or "Glass" in mi.name or "Lamps" in mi.name:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = VISIBLE_RANGE
		mi.visibility_range_end_margin = 25.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		for i: int in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src == null or src.resource_name.is_empty():
				continue
			var repl: Material = mat(src.resource_name)
			if repl != null:
				mi.set_surface_override_material(i, repl)


## Width (x), height (y) and length (z) of a kit model, measured from its meshes (origin on the ground, centred).
func model_dims(file: String) -> Vector3:
	if _dims_cache.has(file):
		return _dims_cache[file]
	var ps: PackedScene = scene_of(file)
	var out: Vector3 = Vector3(1.9, 1.5, 4.6)
	if ps != null:
		var n: Node3D = ps.instantiate() as Node3D
		var boxes: Array[AABB] = []
		_collect_aabbs(n, Transform3D.IDENTITY, boxes)
		if not boxes.is_empty():
			var merged: AABB = boxes[0]
			for bx: AABB in boxes:
				merged = merged.merge(bx)
			out = merged.size
		n.free()
	_dims_cache[file] = out
	return out


func _collect_aabbs(n: Node, xf: Transform3D, out: Array[AABB]) -> void:
	var t: Transform3D = xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(t * (n as MeshInstance3D).get_aabb())
	for c: Node in n.get_children():
		_collect_aabbs(c, t, out)


## A flat slab (top at y_top) over the XZ rect; optionally with collision tagged with a footstep surface.
func slab(parent: Node, nm: String, r: Rect2, y_top: float, thick: float, material: String, surface: String = "", collide: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(r.size.x, thick, r.size.y)
	mi.mesh = bm
	mi.material_override = mat(material)
	mi.position = Vector3(r.position.x + r.size.x * 0.5, y_top - thick * 0.5, r.position.y + r.size.y * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if collide:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = nm + "_Col"
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(r.size.x, 0.2, r.size.y)
		cs.shape = bs
		body.position = Vector3(r.position.x + r.size.x * 0.5, y_top + 0.002 - 0.1, r.position.y + r.size.y * 0.5)
		if not surface.is_empty():
			body.set_meta("surface", surface)
		body.add_child(cs)
		parent.add_child(body)
	return mi


func box_body(parent: Node, nm: String, center: Vector3, size: Vector3, yaw_deg: float = 0.0) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)
	body.position = center
	body.rotation.y = deg_to_rad(yaw_deg)
	return body


func cyl_body(parent: Node, nm: String, center: Vector3, radius: float, height: float) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.position = center
	return body


func _group(nm: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = nm
	add_child(n)
	return n


## The road's geometry: horizontal flag, extent lo..hi along it, centre-line coordinate c.
func _geo(road: Dictionary) -> Dictionary:
	var a: Vector2 = road["a"]
	var b: Vector2 = road["b"]
	var horiz: bool = absf(a.y - b.y) < 0.01
	return {"horiz": horiz, "lo": minf(a.x, b.x) if horiz else minf(a.y, b.y), "hi": maxf(a.x, b.x) if horiz else maxf(a.y, b.y),
		"c": a.y if horiz else a.x}


## Road surface height (the kerb step below the sidewalks).
static func road_y() -> float:
	return -ROAD_DROP


## The route sampled on the ground: on the lot's asphalt it is at 0, on the streets it is ROAD_DROP lower.
func _snap_route_to_ground() -> void:
	for i: int in route.size():
		var p: Vector3 = route[i]
		if p.z > -18.5:
			p.y = 0.0
		elif p.z < -18.5 - DRIVE_RAMP_RUN:
			p.y = -ROAD_DROP
		else:
			p.y = -ROAD_DROP * (-18.5 - p.z) / DRIVE_RAMP_RUN
		route[i] = p


# --- ground and streets -------------------------------------------------------------------------

func build_ground() -> void:
	var g: Node3D = _group("Ground")
	# the lawn is a grid of slabs with the road footprints left out (the roads sit ROAD_DROP below it): mesh a hair below
	# the sidewalks, collision top at y = 0
	var xs: Array[float] = [-480.0, 420.0]
	var zs: Array[float] = [-480.0, 420.0]
	var holes: Array[Rect2] = []
	for road: Dictionary in ROADS:
		var rg: Dictionary = _geo(road)
		var half: float = road["half"]
		var c: float = rg["c"]
		var r: Rect2 = Rect2(float(rg["lo"]), c - half, float(rg["hi"]) - float(rg["lo"]), half * 2.0) if bool(rg["horiz"]) \
			else Rect2(c - half, float(rg["lo"]), half * 2.0, float(rg["hi"]) - float(rg["lo"]))
		holes.append(r)
		for v: float in [r.position.x, r.end.x]:
			if not xs.has(v):
				xs.append(v)
		for v2: float in [r.position.y, r.end.y]:
			if not zs.has(v2):
				zs.append(v2)
	xs.sort()
	zs.sort()
	var k: int = 0
	for i: int in range(xs.size() - 1):
		for j: int in range(zs.size() - 1):
			var cell: Rect2 = Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
			var centre: Vector2 = cell.get_center()
			var inside: bool = false
			for h: Rect2 in holes:
				if h.has_point(centre):
					inside = true
					break
			if inside or cell.size.x < 0.01 or cell.size.y < 0.01:
				continue
			var mi: MeshInstance3D = slab(g, "Lawn_%d" % k, cell, -0.03, 0.4, "Grass", "", false)
			var body: StaticBody3D = StaticBody3D.new()
			body.name = "LawnCol_%d" % k
			body.set_meta("surface", "grass")
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = _lawn_shape(cell, holes)
			body.add_child(cs)
			g.add_child(body)
			mi.set_meta("lawn", true)
			k += 1


## Convex collision for a lawn cell: its top at y = 0, and along every side that borders a road a ramp that comes down to
## the road surface over RAMP_RUN metres, so the road edge is always walkable (crossings and corners included).
func _lawn_shape(cell: Rect2, holes: Array[Rect2]) -> ConvexPolygonShape3D:
	var x0: float = cell.position.x
	var x1: float = cell.end.x
	var z0: float = cell.position.y
	var z1: float = cell.end.y
	var pts: PackedVector3Array = PackedVector3Array()
	for x: float in [x0, x1]:
		for z: float in [z0, z1]:
			pts.append(Vector3(x, 0.0, z))
			pts.append(Vector3(x, -2.0, z))
	var probes: Array[Dictionary] = [
		{"p": Vector2(x0 - 0.5, (z0 + z1) * 0.5), "a": Vector3(-RAMP_RUN, 0, 0), "side": 0},
		{"p": Vector2(x1 + 0.5, (z0 + z1) * 0.5), "a": Vector3(RAMP_RUN, 0, 0), "side": 1},
		{"p": Vector2((x0 + x1) * 0.5, z0 - 0.5), "a": Vector3(0, 0, -RAMP_RUN), "side": 2},
		{"p": Vector2((x0 + x1) * 0.5, z1 + 0.5), "a": Vector3(0, 0, RAMP_RUN), "side": 3}]
	for pr: Dictionary in probes:
		var hit: bool = false
		for h: Rect2 in holes:
			if h.has_point(pr["p"]):
				hit = true
		if not hit:
			continue
		var off: Vector3 = pr["a"]
		var side: int = pr["side"]
		var edge_x: float = x0 if side == 0 else x1
		var edge_z: float = z0 if side == 2 else z1
		if side < 2:
			pts.append(Vector3(edge_x + off.x, -ROAD_DROP, z0))
			pts.append(Vector3(edge_x + off.x, -ROAD_DROP, z1))
		else:
			pts.append(Vector3(x0, -ROAD_DROP, edge_z + off.z))
			pts.append(Vector3(x1, -ROAD_DROP, edge_z + off.z))
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = pts
	return shape


func build_streets() -> void:
	var s: Node3D = _group("Streets")
	for road: Dictionary in ROADS:
		var g: Dictionary = _geo(road)
		var half: float = road["half"]
		var horiz: bool = g["horiz"]
		var lo: float = g["lo"]
		var hi: float = g["hi"]
		var c: float = g["c"]
		var r: Rect2 = Rect2(lo, c - half, hi - lo, half * 2.0) if horiz else Rect2(c - half, lo, half * 2.0, hi - lo)
		slab(s, "Road_" + str(road["id"]), r, -ROAD_DROP, 0.3, "Asphalt", "asphalt", true)
		# sidewalks, cut where another road crosses (and across the back lot's mouth)
		for sgn: float in [-1.0, 1.0]:
			var inner: float = float(road["walk_in"])
			var w: float = float(road["walk_w"])
			var c0: float = c + sgn * inner
			var c1: float = c + sgn * (inner + w)
			var cuts: Array[Vector2] = _cuts_for(road, lo, hi)
			if road["id"] == "back" and sgn > 0.0:
				cuts.append(Vector2(-8.7, 8.8))
				cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
			var pos: float = lo
			var spans: Array[Vector2] = []
			for cut: Vector2 in cuts:
				if cut.x > pos:
					spans.append(Vector2(pos, cut.x))
				pos = maxf(pos, cut.y)
			if pos < hi:
				spans.append(Vector2(pos, hi))
			var k: int = 0
			for sp: Vector2 in spans:
				var wr: Rect2 = Rect2(sp.x, minf(c0, c1), sp.y - sp.x, w) if horiz else Rect2(minf(c0, c1), sp.x, w, sp.y - sp.x)
				slab(s, "Walk_%s_%d_%d" % [road["id"], int(sgn), k], wr, 0.0, 0.3, "Sidewalk", "concrete", true)
				k += 1
			_kerb_edge(s, road, g, sgn)
		_markings(s, road, lo, hi, c, horiz)
	_junction_crossings(s)
	# lot, alley, driveway walk to the main door
	slab(s, "BackLot", Rect2(-8.5, -18.5, 17.1, 14.0), 0.0, 0.3, "LotAsphalt", "asphalt", true)
	slab(s, "Alley", Rect2(5.1, -4.5, 3.4, 17.1), 0.0, 0.3, "AlleyConcrete", "concrete", true)
	slab(s, "FrontWalk", Rect2(-4.7, 11.6, 1.6, 1.0), 0.0, 0.3, "Sidewalk", "concrete", true)
	slab(s, "Apron", Rect2(5.1, 12.6, 3.4, 1.5), 0.0, 0.3, "AlleyConcrete", "concrete", true)
	slab(s, "LobbyFloorOutside", Rect2(-5.4, 9.6, 2.4, 2.0), 0.0, 0.3, "Concrete", "concrete", true)
	_driveway_ramp(s)
	_lot_markings(s)
	_puddles(s)
	_street_details(s)


## Intervals along a road where a different road crosses it (plus the other road's half width and its sidewalks).
func _cuts_for(road: Dictionary, lo: float, hi: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var horiz: bool = _geo(road)["horiz"]
	var my_c: float = _geo(road)["c"]
	for other: Dictionary in ROADS:
		if other["id"] == road["id"]:
			continue
		var og: Dictionary = _geo(other)
		if og["horiz"] == horiz:
			continue
		var oc: float = og["c"]
		var span: float = float(other["half"]) + 0.2
		var reach: float = float(road["walk_in"]) + float(road["walk_w"])
		if my_c + reach < float(og["lo"]) or my_c - reach > float(og["hi"]):
			continue
		if oc + span < lo or oc - span > hi:
			continue
		out.append(Vector2(oc - span, oc + span))
	out.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	return out


## Crossing roads' spans along `road` between lo and hi, widened by `extra` (for markings and parking).
func _crossings(road: Dictionary, extra: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var g: Dictionary = _geo(road)
	for other: Dictionary in ROADS:
		if other["id"] == road["id"]:
			continue
		var og: Dictionary = _geo(other)
		if og["horiz"] == g["horiz"]:
			continue
		var reach: float = float(road["walk_in"]) + float(road["walk_w"])
		if float(g["c"]) + reach < float(og["lo"]) or float(g["c"]) - reach > float(og["hi"]):
			continue
		var oc: float = og["c"]
		out.append(Vector2(oc - float(other["half"]) - extra, oc + float(other["half"]) + extra))
	out.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	return out


## The part of lo..hi not covered by the cut intervals.
static func _spans(lo: float, hi: float, cuts: Array[Vector2]) -> Array[Vector2]:
	var pos: float = lo
	var out: Array[Vector2] = []
	for cut: Vector2 in cuts:
		if cut.x > pos:
			out.append(Vector2(pos, cut.x))
		pos = maxf(pos, cut.y)
	if pos < hi:
		out.append(Vector2(pos, hi))
	return out


## The concrete kerb along one edge of a road: from the road surface up to just above the verge.
func _kerb_edge(parent: Node, road: Dictionary, g: Dictionary, sgn: float) -> void:
	var half: float = road["half"]
	var c: float = g["c"]
	var horiz: bool = g["horiz"]
	var cuts: Array[Vector2] = _crossings(road, 0.0)
	if road["id"] == "back" and sgn > 0.0:
		cuts.append(Vector2(-8.8, 8.9))
		cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var e0: float = c + sgn * half
	var e1: float = e0 + sgn * KERB_W
	var k: int = 0
	for sp: Vector2 in _spans(float(g["lo"]), float(g["hi"]), cuts):
		if sp.y - sp.x < 0.5:
			continue
		var r: Rect2 = Rect2(sp.x, minf(e0, e1), sp.y - sp.x, KERB_W) if horiz else Rect2(minf(e0, e1), sp.x, KERB_W, sp.y - sp.x)
		slab(parent, "Kerb_%s_%d_%d" % [road["id"], int(sgn), k], r, 0.02, ROAD_DROP + 0.12, "Sidewalk", "concrete", false)
		_kerb_collider(parent, "KerbCol_%s_%d_%d" % [road["id"], int(sgn), k], horiz, sgn, e0, sp.x, sp.y)
		k += 1


## Kerb collision with a gentle road-side ramp (the mesh is a plain block): a car that drifts onto the kerb rides up it
## instead of stopping dead against a vertical lip, and Mani can walk from the road back onto the sidewalk.
func _kerb_collider(parent: Node, nm: String, horiz: bool, sgn: float, e0: float, a: float, b: float) -> void:
	var section: Array[Vector2] = [Vector2(-RAMP_RUN, -ROAD_DROP), Vector2(0.1, 0.02), Vector2(KERB_W, 0.02),
		Vector2(KERB_W, -0.22), Vector2(-RAMP_RUN, -0.22)]
	var pts: PackedVector3Array = PackedVector3Array()
	for v: Vector2 in section:
		var lat: float = e0 + sgn * v.x
		for u: float in [a, b]:
			pts.append(Vector3(u, v.y, lat) if horiz else Vector3(lat, v.y, u))
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = pts
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.set_meta("surface", "concrete")
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


## Drop-kerb ramp from the lot (y 0) down to the back street (y -ROAD_DROP) across the driveway gap in the fence.
func _driveway_ramp(parent: Node) -> void:
	var x0: float = -3.2
	var x1: float = 3.6
	var run: float = DRIVE_RAMP_RUN
	var ang: float = atan2(ROAD_DROP, run)
	var length: float = run / cos(ang)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "DrivewayRamp"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(x1 - x0, 0.2, length)
	mi.mesh = bm
	mi.material_override = mat("LotAsphalt")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var centre: Vector3 = Vector3((x0 + x1) * 0.5, -ROAD_DROP * 0.5 - 0.1 * cos(ang), -18.5 - run * 0.5)
	mi.position = centre
	mi.rotation.x = -ang
	parent.add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "DrivewayRamp_Col"
	body.set_meta("surface", "concrete")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(x1 - x0, 0.2, length)
	cs.shape = bs
	body.add_child(cs)
	body.position = centre
	body.rotation.x = -ang
	parent.add_child(body)


func _markings(parent: Node, road: Dictionary, lo: float, hi: float, c: float, horiz: bool) -> void:
	var y: float = -ROAD_DROP + 0.003
	var cuts: Array[Vector2] = _crossings(road, 0.5)
	var big: bool = float(road["half"]) > 4.5
	var half: float = road["half"]
	for sp: Vector2 in _spans(lo, hi, cuts):
		var len_: float = sp.y - sp.x
		if len_ < 1.0:
			continue
		if big:
			for o: float in [-0.12, 0.12]:
				var r: Rect2 = Rect2(sp.x, c + o - 0.05, len_, 0.1) if horiz else Rect2(c + o - 0.05, sp.x, 0.1, len_)
				slab(parent, "Line_%s_%d" % [road["id"], int(sp.x)], r, y, 0.01, "LaneYellow", "", false)
			# white parking-lane lines (solid) and a clear gap at the crosswalk
			for side: float in [-1.0, 1.0]:
				var pc: float = c + side * (half - 2.1 - 0.05)
				var pcuts: Array[Vector2] = []
				if road["id"] == "front":
					pcuts.append(Vector2(12.5, 22.5))
				for ps2: Vector2 in _spans(sp.x, sp.y, pcuts):
					var r2: Rect2 = Rect2(ps2.x, pc - 0.06, ps2.y - ps2.x, 0.12) if horiz else Rect2(pc - 0.06, ps2.x, 0.12, ps2.y - ps2.x)
					slab(parent, "ParkLine_%s_%d_%d_%d" % [road["id"], int(ps2.x), int(side), int(sp.x)], r2, y, 0.01, "LaneWhite", "", false)
		else:
			_dashes(parent, road["id"], sp, c, horiz, y)
	if road["id"] == "front":
		_crosswalk(parent, true, 17.5, 20.6, half, 3.0, "Zebra_front")
		# stop bars before the crosswalk: westbound arrives from +x, eastbound from -x
		slab(parent, "StopBar_W", Rect2(20.4, 15.7, 0.4, 4.8), y, 0.01, "LaneWhite", "", false)
		slab(parent, "StopBar_E", Rect2(14.6, 20.8, 0.4, 4.8), y, 0.01, "LaneWhite", "", false)


func _dashes(parent: Node, id: String, sp: Vector2, c: float, horiz: bool, y: float) -> void:
	var x: float = sp.x + 1.0
	var k: int = 0
	while x < sp.y - 3.0:
		var r: Rect2 = Rect2(x, c - 0.06, 3.0, 0.12) if horiz else Rect2(c - 0.06, x, 0.12, 3.0)
		slab(parent, "Dash_%s_%d_%d" % [id, int(sp.x), k], r, y, 0.01, "LaneYellow", "", false)
		x += 7.0
		k += 1


## A continental ("zebra") crosswalk: bars parallel to the traffic, spaced across the road. `u` is the centre along the
## road, `c` the road's centre line, `half` its half width, `wid` the crossing's width along the road.
func _crosswalk(parent: Node, horiz: bool, u: float, c: float, half: float, wid: float, nm: String) -> void:
	var y: float = -ROAD_DROP + 0.003
	var bars: int = int((half * 2.0 - 0.8) / 1.0)
	var start: float = c - half + 0.5 + ((half * 2.0 - 0.8) - float(bars) * 1.0) * 0.5
	for k: int in bars:
		var p: float = start + float(k) * 1.0
		var r: Rect2 = Rect2(u - wid * 0.5, p, wid, 0.5) if horiz else Rect2(p, u - wid * 0.5, 0.5, wid)
		slab(parent, "%s_%d" % [nm, k], r, y, 0.01, "LaneWhite", "", false)


## Crosswalks and stop bars on the side streets where they meet a through street, lined up with its sidewalk.
func _junction_crossings(parent: Node) -> void:
	for b: Dictionary in ROADS:
		var bg: Dictionary = _geo(b)
		for a: Dictionary in ROADS:
			var ag: Dictionary = _geo(a)
			if a["id"] == b["id"] or ag["horiz"] == bg["horiz"]:
				continue
			var reach: float = float(b["walk_in"]) + float(b["walk_w"])
			if float(ag["c"]) < float(bg["lo"]) - 1.0 or float(ag["c"]) > float(bg["hi"]) + 1.0:
				continue
			if float(bg["c"]) < float(ag["lo"]) - 0.1 or float(bg["c"]) > float(ag["hi"]) + 0.1:
				continue
			for sgn: float in [-1.0, 1.0]:
				# does the side street continue on this side of the through street?
				var edge: float = float(bg["c"]) + sgn * reach
				if (sgn < 0.0 and float(ag["lo"]) > edge - 8.0) or (sgn > 0.0 and float(ag["hi"]) < edge + 8.0):
					continue
				var cw: float = float(bg["c"]) + sgn * (float(b["walk_in"]) + float(b["walk_w"]) * 0.5)
				var ahalf: float = a["half"]
				_crosswalk(parent, bool(ag["horiz"]), cw, float(ag["c"]), ahalf, 2.4, "Zebra_%s_%s_%d" % [a["id"], b["id"], int(sgn)])
				# stop bar across the lane that arrives at the junction (right-hand traffic)
				var sb: float = float(bg["c"]) + sgn * (float(b["walk_in"]) + float(b["walk_w"]) + 1.3)
				var y2: float = -ROAD_DROP + 0.003
				var rr: Rect2
				if bool(ag["horiz"]):
					var lane_c: float = float(ag["c"]) - sgn * ahalf * 0.5
					rr = Rect2(sb - 0.2, lane_c - ahalf * 0.5, 0.4, ahalf)
				else:
					var lane_c2: float = float(ag["c"]) + sgn * ahalf * 0.5
					rr = Rect2(lane_c2 - ahalf * 0.5, sb - 0.2, ahalf, 0.4)
				slab(parent, "StopBar_%s_%s_%d" % [a["id"], b["id"], int(sgn)], rr, y2, 0.01, "LaneWhite", "", false)


func _lot_markings(parent: Node) -> void:
	# parking bays: white lines 2.8 m apart across the nose-in row (bay centres -6.4 .. 4.8, Mani's car at x -0.8)
	var y: float = 0.003
	var x: float = -7.8
	for k: int in 6:
		slab(parent, "BayLine_%d" % k, Rect2(x + float(k) * LOT_BAY_W - 0.05, -13.1, 0.1, 5.2), y, 0.01, "LaneWhite", "", false)
	slab(parent, "BayBack", Rect2(-7.85, -13.15, 14.1, 0.1), y, 0.01, "LaneWhite", "", false)
	# oil stains where cars usually stand
	for sx: float in [-6.4, -0.8, 4.8]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "OilStain_%d" % int(sx * 10.0)
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.6
		cm.bottom_radius = 0.6
		cm.height = 0.002
		cm.radial_segments = 14
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mat("OilStain")
		mi.position = Vector3(sx + 0.1, 0.004, -9.2)
		mi.scale = Vector3(1.0, 1.0, 1.4)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


func _puddles(parent: Node) -> void:
	var spots: Array[Vector4] = [Vector4(6.6, 9.0, 0.8, 1.4), Vector4(7.4, 4.4, 0.9, 1.2), Vector4(6.0, -1.0, 0.6, 1.5),
		Vector4(5.9, 2.8, 0.5, 0.8), Vector4(-0.2, -6.2, 1.1, 0.8), Vector4(2.0, -13.5, 1.4, 1.8), Vector4(-6.0, -15.5, 0.9, 1.2),
		Vector4(-3.9, 12.2, 0.8, 0.5)]
	var i: int = 0
	for s: Vector4 in spots:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Puddle_%d" % i
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.002
		cm.radial_segments = 20
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mat("Puddle")
		mi.position = Vector3(s.x, 0.006, s.y)
		mi.scale = Vector3(s.z, 1.0, s.w)
		mi.rotation.y = float(i) * 0.7
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		i += 1
	# one by the kerb on the front street
	var mi2: MeshInstance3D = MeshInstance3D.new()
	mi2.name = "Puddle_%d" % i
	var cm2: CylinderMesh = CylinderMesh.new()
	cm2.height = 0.002
	cm2.radial_segments = 20
	cm2.rings = 1
	mi2.mesh = cm2
	mi2.material_override = mat("Puddle")
	mi2.position = Vector3(1.0, -ROAD_DROP + 0.006, 16.1)
	mi2.scale = Vector3(2.5, 1.0, 0.8)
	mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi2)


## Storm drains at the kerbs and manhole covers in the lanes.
func _street_details(parent: Node) -> void:
	var ry: float = -ROAD_DROP
	for x: float in [-62.0, -28.0, 30.0, 64.0]:
		place("storm_drain", Vector3(x, ry, 15.45), 0.0, parent)
	for x2: float in [-46.0, -6.0, 21.5, 56.0]:
		place("storm_drain", Vector3(x2, ry, 25.75), 0.0, parent)
	for spec: Vector3 in [Vector3(-70.0, ry, 19.0), Vector3(-10.0, ry, 22.2), Vector3(45.0, ry, 19.0), Vector3(72.0, ry, 22.2),
			Vector3(-80.0, ry, -23.7), Vector3(-30.0, ry, -20.3), Vector3(-108.2, ry, -70.0)]:
		place("manhole", spec, 0.0, parent)
	for spec2: Vector3 in [Vector3(-30.0, ry, -25.2), Vector3(-90.0, ry, -25.0), Vector3(-111.0, ry, -60.0)]:
		place("storm_drain", spec2, 0.0, parent)


# --- the front street: shops, traffic, bus stop, lights ----------------------------------------------

func build_front_street() -> void:
	var f: Node3D = _group("FrontStreet")
	_build_shops(f)
	# houses on the same side beyond the shop row, and along the building's side of the street
	var hx: float = 52.0
	var j: int = 0
	while hx < 148.0:
		_house_front(f, HOUSES[j % HOUSES.size()], hx + 8.0, 29.0, 180.0)
		_house_front(f, HOUSES[(j + 2) % HOUSES.size()], -hx - 8.0, 29.0, 180.0)
		hx += 11.0
		j += 1
	var nx: float = 24.0
	j = 1
	while nx < 148.0:
		_house_front(f, HOUSES[j % HOUSES.size()], nx + 4.0, 4.5, 0.0)
		_house_front(f, HOUSES[(j + 3) % HOUSES.size()], -nx - 8.0, 4.5, 0.0)
		nx += 11.0
		j += 1
	_front_street_trees(f)
	_front_street_furniture(f)
	_build_parking(f)
	_build_traffic(f)
	_build_people(f)


func _build_shops(f: Node3D) -> void:
	var x: float = SHOP_ROW_X0
	for i: int in SHOPS.size():
		var shop: Dictionary = SHOPS[i]
		var kit: String = shop["kit"]
		var w: float = SHOP_WIDTHS[kit]
		var n: Node3D = place(kit, Vector3(x + w * 0.5, 0.0, SHOP_FRONT_Z), 0.0, f)
		if n != null:
			n.name = "Shop_" + str(shop["id"])
			box_body(f, "ShopCol_%d" % i, Vector3(x + w * 0.5, 3.5, SHOP_FRONT_Z + 5.0), Vector3(w, 7.0, 10.0))
			shop_signs.append(_shop_sign(f, shop, x + w * 0.5, w))
		x += w + 0.25
	# houses fill the rest of the shop side
	# (see build_front_street)


## The sign slot of one shop: a quad above the awning showing signs/<shop_id>.png (placeholder typography until the real
## picture is dropped in). Size (W - 1.3) x 0.9 m.
func _shop_sign(parent: Node, shop: Dictionary, cx: float, w: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "ShopSign_" + str(shop["id"])
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(w - 1.3, SIGN_HEIGHT)
	mi.mesh = qm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.resource_name = "SignPicture_" + str(shop["id"])
	m.albedo_texture = load_sign_texture(str(shop["id"]))
	m.roughness = 0.55
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(cx, SIGN_CENTER_Y, SHOP_FRONT_Z - 0.13)
	mi.rotation.y = PI                    # the quad faces +Z; the shop front faces -Z (the street)
	mi.set_meta("shop_id", str(shop["id"]))
	mi.set_meta("shop_name", str(shop["name"]))
	parent.add_child(mi)
	return mi


## signs/<id>.png as a texture; works for an imported file and for one just dropped in the folder.
func load_sign_texture(shop_id: String) -> Texture2D:
	var path: String = SIGN_DIR + shop_id + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(path)
		if img != null:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null


func _front_street_trees(f: Node3D) -> void:
	var tx: float = -140.0
	var ti: int = 0
	while tx < 141.0:
		if not (tx > 0.0 and tx < 12.0) and not (tx > -17.0 and tx < -7.0):
			_street_tree(f, Vector3(tx, 0.0, 14.65), ti)
		_street_tree(f, Vector3(tx + 5.0, 0.0, 26.5), ti + 2)
		tx += 11.0
		ti += 1
	var lx: float = -135.0
	while lx < 136.0:
		place("streetlight", Vector3(lx, 0.0, 15.05), 90.0, f)
		place("streetlight", Vector3(lx + 12.0, 0.0, 26.1), -90.0, f)
		lx += 24.0
	place("utility_pole", Vector3(-30.0, 0.0, 14.7), 90.0, f)
	place("utility_pole", Vector3(55.0, 0.0, 14.7), 90.0, f)


func _street_tree(parent: Node, pos: Vector3, idx: int, collide: bool = true) -> void:
	var t: Node3D = place(TREES[idx % TREES.size()], pos, float(idx * 47 % 360), parent)
	if t != null:
		tree_count += 1
		if collide and absf(pos.x) < 100.0:
			cyl_body(parent, "TreeCol_%d" % tree_count, pos + Vector3(0.0, 1.2, 0.0), 0.24, 2.4)


func _front_street_furniture(f: Node3D) -> void:
	# bus stop on our side of the street
	var shelter: Node3D = place("bus_shelter", Vector3(-12.0, 0.0, 13.35), 180.0, f)
	if shelter != null:
		shelter.name = "BusShelter"
		box_body(f, "BusShelterCol", Vector3(-12.0, 1.2, 14.1), Vector3(3.0, 2.4, 0.2))
	var sign_pole: Node3D = place("signs", Vector3(-8.0, 0.0, 14.4), 180.0, f)
	if sign_pole != null:
		sign_pole.name = "BusStopSigns"
		var bl: Label3D = Label3D.new()
		bl.text = "BUS STOP"
		bl.font_size = 64
		bl.pixel_size = 0.0045
		bl.modulate = Color(0.1, 0.1, 0.12)
		bl.position = Vector3(-8.0, 2.72, 14.36)
		bl.shaded = false
		f.add_child(bl)
		var br: Label3D = bl.duplicate() as Label3D
		br.position = Vector3(-8.0, 2.72, 14.44)
		br.rotation.y = PI
		f.add_child(br)
		var st: Label3D = Label3D.new()
		st.text = "LINDEN ST"
		st.font_size = 64
		st.pixel_size = 0.005
		st.modulate = Color(0.95, 0.95, 0.9)
		st.position = Vector3(30.0, 2.35, 14.36)
		st.shaded = false
		f.add_child(st)
		var pole2: Node3D = place("signs", Vector3(30.0, 0.0, 14.4), 180.0, f)
		if pole2 != null:
			pole2.name = "StreetNameSigns"
	# hydrants, bins, benches, bike rings, generic signs
	for h: Vector2 in HYDRANTS:
		place("hydrant", Vector3(h.x, 0.0, 14.7 if h.y < 0.0 else 26.6), 0.0 if h.y < 0.0 else 180.0, f)
	for bx: float in [-5.5, 14.5, -44.0]:
		place("litter_bin", Vector3(bx, 0.0, 13.8), 0.0, f)
	for bx2: float in [-25.0, 5.0, 36.0]:
		place("litter_bin", Vector3(bx2, 0.0, 27.35), 0.0, f)
	# benches stand on the verges, clear of doors and the walking line: one at the bus stop, one opposite
	place("bench", Vector3(-17.5, 0.0, 14.7), 0.0, f)
	place("bench", Vector3(-6.0, 0.0, 26.65), 180.0, f)
	for rx: float in [-28.6, -28.0, 30.0, 30.6]:
		place("bike_ring", Vector3(rx, 0.0, 27.4), 90.0, f)
	place("speed_sign", Vector3(62.0, 0.0, 14.8), 90.0, f)
	place("speed_sign", Vector3(-62.0, 0.0, 26.3), -90.0, f)
	place("parking_sign", Vector3(-70.0, 0.0, 14.8), 90.0, f)
	place("parking_sign", Vector3(-14.0, 0.0, 14.8), 90.0, f)
	place("parking_sign", Vector3(70.0, 0.0, 26.3), -90.0, f)
	place("parking_sign", Vector3(-20.0, 0.0, 26.3), -90.0, f)
	place("stop_sign", Vector3(4.3, 0.0, -17.6), 0.0, f)


func _house_front(parent: Node, file: String, x: float, z_front: float, yaw: float) -> void:
	var d: float = HOUSE_DEPTH[file]
	var zc: float = z_front - d * 0.5 if yaw == 0.0 else z_front + d * 0.5
	var r: Rect2 = Rect2(x - 5.0, zc - d * 0.5, 10.0, d)
	for q: Rect2 in _rects:
		if q.intersects(r):
			return
	_rects.append(r)
	place(file, Vector3(x, 0.0, zc), yaw, parent)
	box_body(parent, "HouseCol_%d" % house_count, Vector3(x, 2.7, zc), Vector3(8.0, 5.4, d - 0.4))
	house_count += 1


# --- parked cars ---------------------------------------------------------------------------------

## Fills one kerb with parallel-parked cars facing `face`, nearest side PARK_KERB_GAP from the kerb, never inside `skips`
## (intervals along the road: crosswalks, junctions, hydrants, bus stop, driveways). `fill` is the share of slots taken.
func _park_row(parent: Node, horiz: bool, kerb: float, inward: float, lo: float, hi: float, face: Vector3, skips: Array[Vector2],
		seed_off: int, fill: float, tag: String) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 700 + seed_off
	var cursor: float = lo + rng.randf_range(0.0, 6.0)
	var count: int = 0
	var guard: int = 0
	while cursor < hi and guard < 400:
		guard += 1
		var file: String = CAR_KIT[rng.randi() % CAR_KIT.size()]
		var d: Vector3 = model_dims(file)
		var half: float = d.z * 0.5
		var centre: float = cursor + half
		if centre + half > hi:
			break
		var hit: bool = false
		for sk: Vector2 in skips:
			if centre + half > sk.x - 0.6 and centre - half < sk.y + 0.6:
				cursor = sk.y + 0.8
				hit = true
				break
		if hit:
			continue
		if rng.randf() < fill:
			var lateral: float = kerb + inward * (PARK_KERB_GAP + d.x * 0.5)
			var pos: Vector3 = Vector3(centre, road_y(), lateral) if horiz else Vector3(lateral, road_y(), centre)
			var yaw: float = rad_to_deg(atan2(face.x, face.z))
			var n: Node3D = place(file, pos, yaw, parent)
			if n != null:
				paint(n, CAR_COLOURS[rng.randi() % CAR_COLOURS.size()])
				if parked_cars.size() == 3 or parked_cars.size() == 10:
					OOTTrafficDriver.add_driver(n, parked_cars.size() + 2)      # somebody waiting in the car
					n.set_meta("driver", true)
				var col_size: Vector3 = Vector3(d.z, d.y * 0.95, d.x) if horiz else Vector3(d.x, d.y * 0.95, d.z)
				box_body(parent, "ParkedCol_%s_%d" % [tag, count], pos + Vector3(0.0, d.y * 0.5, 0.0), col_size)
				n.set_meta("parked", true)
				parked_cars.append({"node": n, "kerb": kerb, "horiz": horiz, "inward": inward, "dims": d, "face": face})
				count += 1
			cursor = centre + half + rng.randf_range(0.5, 1.6)
		else:
			cursor += rng.randf_range(5.0, 9.0)
	return count


func _build_parking(f: Node3D) -> void:
	var north_skips: Array[Vector2] = [Vector2(-18.0, -6.0), Vector2(3.0, 11.0), Vector2(13.0, 26.0)]
	var south_skips: Array[Vector2] = [Vector2(13.0, 26.0)]
	for h: Vector2 in HYDRANTS:
		(north_skips if h.y < 0.0 else south_skips).append(Vector2(h.x - 5.0, h.x + 5.0))
	_park_row(f, true, 15.2, 1.0, -105.0, 105.0, Vector3(-1, 0, 0), north_skips, 1, 0.5, "FN")
	_park_row(f, true, 26.0, -1.0, -105.0, 105.0, Vector3(1, 0, 0), south_skips, 2, 0.5, "FS")


# --- cars --------------------------------------------------------------------------------------

## Recolours the body paint of a kit car (the slot named CarPaint).
func paint(root: Node, colour: Color) -> void:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "CarPaint":
				var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = colour
				mi.set_surface_override_material(i, d)


func _build_traffic(parent: Node) -> void:
	var specs: Array[Dictionary] = [
		{"z": 19.0, "dir": -1.0, "n": 5, "name": "LaneWest"}, {"z": 22.2, "dir": 1.0, "n": 4, "name": "LaneEast"}]
	var ci: int = 0
	for spec: Dictionary in specs:
		var lane: OOTTrafficLane = OOTTrafficLane.new()
		lane.name = str(spec["name"])
		parent.add_child(lane)
		var dir: float = spec["dir"]
		lane.setup(PackedVector3Array([Vector3(-140.0 * dir, road_y(), spec["z"]), Vector3(140.0 * dir, road_y(), spec["z"])]), 9.0, true)
		lanes.append(lane)
		var length: float = lane.length()
		for k: int in int(spec["n"]):
			var file: String = CAR_KIT[(ci + k) % CAR_KIT.size()]
			var model: Node3D = scene_of(file).instantiate() as Node3D if scene_of(file) != null else Node3D.new()
			_remap(model)
			paint(model, CAR_COLOURS[(ci * 5 + 2) % CAR_COLOURS.size()])
			OOTTrafficDriver.add_driver(model, ci)
			var car: OOTTrafficCar = OOTTrafficCar.new()
			car.name = "Car_%d" % ci
			parent.add_child(car)
			car.setup(lane, length * (float(k) + _rng.randf_range(0.05, 0.5)) / float(spec["n"]), model, model_dims(file),
				900 + ci, _rng.randf_range(6.5, 9.5))
			var snd: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			snd.name = "Engine"
			snd.bus = &"SFX"
			if ResourceLoader.exists(SND_TRAFFIC):
				var s: AudioStream = (load(SND_TRAFFIC) as AudioStream).duplicate() as AudioStream
				if s is AudioStreamOggVorbis:
					(s as AudioStreamOggVorbis).loop = true
				snd.stream = s
			snd.unit_size = 9.0
			snd.max_distance = 90.0
			snd.volume_db = -14.0
			snd.pitch_scale = _rng.randf_range(0.8, 1.3)
			snd.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
			snd.autoplay = true
			car.set_engine_player(snd)
			traffic.append(car)
			ci += 1


## The pedestrians (OOTPedestrianSpawner) walk the PedRoute_* paths; two stand at the bus stop. They count as obstacles for
## the traffic, so cars give way at the crosswalk.
func _build_people(_parent: Node) -> void:
	pass


func spawn_pedestrians() -> void:
	var walk: Array[Path3D] = []
	var order: Array[String] = ["front_north", "front_south", "back_north", "crosswalk", "BusStop", "front_south", "front_north", "cross2_east"]
	for nm: String in order:
		for r: Path3D in ped_routes:
			if String(r.name) == "PedRoute_" + nm:
				walk.append(r)
	if walk.is_empty():
		return
	var peds: Array[OOTPedestrian] = OOTPedestrianSpawner.spawn_along(walk, 9, self, 77)
	for p: OOTPedestrian in peds:
		p.add_to_group(&"traffic_obstacle")
		p.set_meta("traffic_radius", 0.35)
		pedestrians.append(p)


# --- blocks along the back streets ----------------------------------------------------------------

func build_blocks() -> void:
	var b: Node3D = _group("Blocks")
	var idx: int = 0
	for road: Dictionary in ROADS:
		if road["id"] == "front":
			continue
		var g: Dictionary = _geo(road)
		var horiz: bool = g["horiz"]
		var lo: float = float(g["lo"]) + 14.0
		var hi: float = float(g["hi"]) - 14.0
		var c: float = g["c"]
		var along: float = lo
		while along < hi:
			for sgn: float in [-1.0, 1.0]:
				var file: String = HOUSES[(idx * 2 + int(sgn + 1.0)) % HOUSES.size()]
				var d: float = HOUSE_DEPTH[file]
				var off: float = float(road["walk_in"]) + float(road["walk_w"]) + 4.5 + d * 0.5
				var pos: Vector3 = Vector3(along, 0.0, c + sgn * off) if horiz else Vector3(c + sgn * off, 0.0, along)
				# face the road: house front is +Z
				var yaw: float = (0.0 if sgn < 0.0 else 180.0) if horiz else (-90.0 if sgn < 0.0 else 90.0)
				if not _house_ok(pos, horiz, d):
					continue
				_house_rect_add(pos, horiz, d)
				place(file, pos, yaw, b)
				box_body(b, "HouseCol_%d" % house_count, pos + Vector3(0.0, 2.7, 0.0),
					Vector3(8.0, 5.4, d - 0.4) if horiz else Vector3(d - 0.4, 5.4, 8.0))
				house_count += 1
				idx += 1
			# street trees
			for sgn2: float in [-1.0, 1.0]:
				var toff: float = float(road["walk_in"]) - 0.5
				var tp: Vector3 = Vector3(along + 4.0, 0.0, c + sgn2 * toff) if horiz else Vector3(c + sgn2 * toff, 0.0, along + 4.0)
				if _clear_of_roads(tp, road["id"]):
					_street_tree(b, tp, idx + int(sgn2 + 1.0), false)
			along += 12.5
	_build_block_parking(b)
	_build_lamps(b)


## Parked cars along the quiet kerbs; never on the side of the route's lane (right-hand traffic: the route runs on the
## north half of the back street and the boulevard and the east half of the second cross street).
func _build_block_parking(b: Node3D) -> void:
	var back: Dictionary = ROADS[1]
	var skips: Array[Vector2] = _crossings(back, 6.0)
	skips.append(Vector2(-9.5, 10.5))
	_park_row(b, true, -18.5, -1.0, -206.0, 38.0, Vector3(1, 0, 0), skips, 3, 0.4, "BS")
	var blvd: Dictionary = ROADS[4]
	_park_row(b, true, -106.5, -1.0, -206.0, -48.0, Vector3(1, 0, 0), _crossings(blvd, 6.0), 4, 0.4, "BL")
	var c1: Array[Vector2] = _crossings(ROADS[2], 6.0)
	c1.append(Vector2(-31.0, -21.0))
	_park_row(b, false, -48.5, 1.0, -148.0, -30.0, Vector3(0, 0, 1), c1, 5, 0.4, "C1W")
	_park_row(b, false, -41.5, -1.0, -148.0, -30.0, Vector3(0, 0, -1), c1, 6, 0.4, "C1E")
	var c2: Array[Vector2] = _crossings(ROADS[3], 6.0)
	c2.append(Vector2(-31.0, -21.0))
	_park_row(b, false, -113.5, 1.0, -148.0, -30.0, Vector3(0, 0, 1), c2, 7, 0.4, "C2W")


func _build_lamps(b: Node3D) -> void:
	for road: Dictionary in ROADS:
		if road["id"] == "front":
			continue
		var g: Dictionary = _geo(road)
		var u: float = float(g["lo"]) + 20.0
		var toggle: float = 1.0
		while u < float(g["hi"]) - 20.0:
			var near_cross: bool = false
			for sp: Vector2 in _crossings(road, 8.0):
				if u > sp.x and u < sp.y:
					near_cross = true
			if not near_cross:
				var side: float = toggle
				var off: float = float(road["walk_in"]) - 0.4
				if bool(g["horiz"]):
					place("streetlight", Vector3(u, 0.0, float(g["c"]) + side * off), 90.0 if side < 0.0 else -90.0, b)
				else:
					place("streetlight", Vector3(float(g["c"]) + side * off, 0.0, u), 180.0 if side < 0.0 else 0.0, b)
			toggle = -toggle
			u += 36.0


func _house_ok(pos: Vector3, horiz: bool, d: float) -> bool:
	var r: Rect2 = _hr(pos, horiz, d)
	for q: Rect2 in _house_rects:
		if q.intersects(r):
			return false
	# keep clear of every road's asphalt + sidewalks
	for road: Dictionary in ROADS:
		var g: Dictionary = _geo(road)
		var m: float = float(road["walk_in"]) + float(road["walk_w"]) + 2.0
		var rr: Rect2
		if bool(g["horiz"]):
			rr = Rect2(float(g["lo"]), float(g["c"]) - m, float(g["hi"]) - float(g["lo"]), m * 2.0)
		else:
			rr = Rect2(float(g["c"]) - m, float(g["lo"]), m * 2.0, float(g["hi"]) - float(g["lo"]))
		if rr.intersects(r):
			return false
	# our own lot / building
	if Rect2(-20.0, -19.0, 40.0, 40.0).intersects(r):
		return false
	return true


func _hr(pos: Vector3, horiz: bool, d: float) -> Rect2:
	return Rect2(pos.x - 5.2, pos.z - d * 0.5 - 0.5, 10.4, d + 1.0) if horiz else Rect2(pos.x - d * 0.5 - 0.5, pos.z - 5.2, d + 1.0, 10.4)


func _house_rect_add(pos: Vector3, horiz: bool, d: float) -> void:
	_house_rects.append(_hr(pos, horiz, d))


func _clear_of_roads(p: Vector3, own_id: String) -> bool:
	for road: Dictionary in ROADS:
		if road["id"] == own_id:
			continue
		var g: Dictionary = _geo(road)
		var m: float = float(road["walk_in"]) + float(road["walk_w"]) + 3.0
		if bool(g["horiz"]):
			if p.x > float(g["lo"]) - 2.0 and p.x < float(g["hi"]) + 2.0 and absf(p.z - float(g["c"])) < m:
				return false
		else:
			if p.z > float(g["lo"]) - 2.0 and p.z < float(g["hi"]) + 2.0 and absf(p.x - float(g["c"])) < m:
				return false
	return true


# --- road works ------------------------------------------------------------------------------------

## A closure at every wrong turn: barricades across the road mouth with flashing lamps, a taper of cones and drums, "ROAD
## WORK" ahead and "ROAD CLOSED" signs, and an invisible blocker that stops a car (and keeps it off the verges).
func build_roadworks() -> void:
	var rw: Node3D = _group("Roadworks")
	for def: Dictionary in ROADWORKS:
		var c: OOTRoadworks = OOTRoadworks.new()
		c.name = str(def["id"])
		c.closure_id = str(def["id"])
		c.half_width = float(def["half"])
		var along: Vector3 = def["along"]
		var approach: Vector3 = def["approach"]
		c.approach = approach
		var centre: Vector3 = def["pos"]
		centre.y = road_y()
		rw.add_child(c)
		c.position = centre
		var yaw: float = rad_to_deg(atan2(approach.x, approach.z))      # the barricade front (+Z) faces the traffic
		var half: float = c.half_width
		var n: int = int(ceil(half * 2.0 / 2.4))
		var pitch: float = half * 2.0 / float(n)
		for i: int in n:
			var off: float = -half + pitch * (float(i) + 0.5)
			var p: Node3D = _rw_place("barricade", along * off, yaw, c)
			if p != null and absf(pitch - 2.4) > 0.01:
				p.scale = Vector3(pitch / 2.4, 1.0, 1.0)
		# cones: a taper that leads the eye to the barricade line, drums at the road edges
		for k: int in 5:
			var d: float = 2.0 + float(k) * 2.4
			var lat: float = half * 0.9 * (1.0 - float(k) / 6.0) * (1.0 if k % 2 == 0 else -1.0)
			_rw_place("cone", approach * d + along * lat, float(k * 37), c)
		for sgn: float in [-1.0, 1.0]:
			_rw_place("drum", approach * 1.6 + along * (half - 0.35) * sgn, 0.0, c)
			_rw_place("cone", approach * 1.6 + along * (half * 0.5) * sgn, 0.0, c)
		# signs: ROAD CLOSED right in front, ROAD WORK further out on the driver's side (right-hand traffic)
		var right: Vector3 = (-approach).cross(Vector3.UP)
		_rw_place("sign_road_closed", approach * 2.6, yaw, c)
		_rw_place("sign_road_work", approach * 13.0 + right * (half - 0.9), yaw, c)
		c.collect_lamps()
		# the blocker: road + verges + sidewalks wide, 0.6 m deep, 1.4 m tall
		var span: float = half + 5.0
		var size: Vector3 = Vector3(absf(along.x) * span * 2.0 + absf(along.z) * 0.6, 1.4, absf(along.z) * span * 2.0 + absf(along.x) * 0.6)
		c.blocker = box_body(c, "Blocker", Vector3(0.0, 0.7, 0.0), size)
		c.blocker.set_meta("surface", "metal")
		closures.append(c)


func _rw_place(kind: String, pos: Vector3, yaw_deg: float, parent: Node3D) -> Node3D:
	var n: Node3D = place("roadworks/" + kind, pos, yaw_deg, parent)
	if n != null:
		n.set_meta("rw_kind", kind)
	return n


# --- pedestrian hooks ---------------------------------------------------------------------------------

## Spawn points (Marker3D, group "ped_spawn", meta "route" = name of its PedRoute_* path) and sidewalk waypoint paths
## (Path3D, group "ped_route") for the pedestrian system, which is built elsewhere. The mannequins stay until then.
func build_pedestrian_hooks() -> void:
	var root: Node3D = _group("Pedestrians")
	var defs: Array[Dictionary] = [
		{"name": "front_north", "pts": [Vector3(-62.0, 0.0, 13.35), Vector3(-30.0, 0.0, 13.35), Vector3(0.0, 0.0, 13.35), Vector3(30.0, 0.0, 13.35), Vector3(62.0, 0.0, 13.35)]},
		{"name": "front_south", "pts": [Vector3(62.0, 0.0, 27.8), Vector3(30.0, 0.0, 27.8), Vector3(0.0, 0.0, 27.8), Vector3(-30.0, 0.0, 27.8), Vector3(-62.0, 0.0, 27.8)]},
		{"name": "crosswalk", "pts": [Vector3(17.5, 0.0, 13.6), Vector3(17.5, -ROAD_DROP, 15.6), Vector3(17.5, -ROAD_DROP, 25.6), Vector3(17.5, 0.0, 27.6)]},
		{"name": "alley_mouth", "pts": [Vector3(6.8, 0.0, 12.9), Vector3(6.8, 0.0, 6.0)]},
		{"name": "back_north", "pts": [Vector3(-100.0, 0.0, -27.2), Vector3(-60.0, 0.0, -27.2), Vector3(-20.0, 0.0, -27.2), Vector3(30.0, 0.0, -27.2)]},
		{"name": "BusStop", "pts": [Vector3(-13.6, 0.0, 13.15), Vector3(-10.4, 0.0, 13.15)], "marker": false},
		{"name": "cross2_east", "pts": [Vector3(-104.8, 0.0, -30.0), Vector3(-104.8, 0.0, -70.0), Vector3(-104.8, 0.0, -105.0)]},
	]
	for d: Dictionary in defs:
		var path: Path3D = Path3D.new()
		path.name = "PedRoute_" + str(d["name"])
		var curve: Curve3D = Curve3D.new()
		for p: Vector3 in d["pts"]:
			curve.add_point(p)
		path.curve = curve
		root.add_child(path)
		path.add_to_group(&"ped_route")
		ped_routes.append(path)
		if str(d["name"]) == "crosswalk":
			for wp: Vector3 in [Vector3(17.5, 0.0, 14.0), Vector3(17.5, 0.0, 27.3)]:
				var w: Node3D = Node3D.new()
				w.name = "Wait_%d" % int(wp.z)
				path.add_child(w)
				w.position = wp
		if d.has("marker"):
			continue
		var m: Marker3D = Marker3D.new()
		m.name = "PedSpawn_" + str(d["name"])
		root.add_child(m)
		m.position = (d["pts"] as Array)[0] as Vector3
		m.set_meta("route", path.name)
		m.set_meta("route_offset", 0.0)
		m.add_to_group(&"ped_spawn")
		ped_spawns.append(m)


# --- Proton Scatter litter ------------------------------------------------------------------------

## Fallen leaves: one ProtonScatter per area, three leaf items, random placement and yaw, rendered as MultiMeshes.
func build_litter() -> void:
	var poisson_script: Script = load(SCATTER_MOD + "create_inside_random.gd") as Script
	var random_script: Script = load(SCATTER_MOD + "randomize_transforms.gd") as Script
	if poisson_script == null or random_script == null or not ClassDB.class_exists(&"Node3D"):
		return
	var root: Node3D = _group("Litter")
	var k: int = 0
	for area: Vector4 in LITTER_AREAS:
		var sc: ProtonScatter = ProtonScatter.new()
		sc.name = "Litter_%d" % k
		sc.global_seed = 100 + k
		sc.dbg_disable_thread = true
		sc.use_chunks = true
		var stack: ProtonScatterModifierStack = ProtonScatterModifierStack.new()
		var pz: ScatterBaseModifier = poisson_script.new() as ScatterBaseModifier
		pz.set("amount", clampi(int(area.z * area.w * 1.6), 60, 420))
		var rz: ScatterBaseModifier = random_script.new() as ScatterBaseModifier
		rz.set("rotation", Vector3(0.0, 360.0, 0.0))
		rz.set("scale", Vector3(0.5, 0.0, 0.5))
		stack.stack = [pz, rz]
		sc.modifier_stack = stack
		var tints: Array[String] = ["orange", "yellow", "rust"]
		var ok: bool = false
		for t: String in tints:
			var path: String = SCATTER_DIR + "leaf_litter_%s.tscn" % t
			if not ResourceLoader.exists(path):
				continue
			var item: ProtonScatterItem = ProtonScatterItem.new()
			item.name = "Item_" + t
			item.source = 1
			item.path = path
			item.proportion = 100
			sc.add_child(item)
			ok = true
		var shape: ProtonScatterShape = ProtonScatterShape.new()
		var box: ProtonScatterBoxShape = ProtonScatterBoxShape.new()
		box.size = Vector3(area.z, 0.04, area.w)
		shape.shape = box
		sc.add_child(shape)
		if ok:
			root.add_child(sc)
			sc.position = Vector3(area.x, 0.015, area.y)
			scatters.append(sc)
		else:
			sc.free()
		k += 1


# --- boundaries ------------------------------------------------------------------------------------

## Rounds the corners of a polyline with quadratic Beziers and samples it every `step` metres.
static func make_route(corners: Array[Vector3], radius: float, step: float = 1.0) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if corners.size() < 2:
		return out
	var pts: Array[Vector3] = [corners[0]]
	for i: int in range(1, corners.size() - 1):
		var p: Vector3 = corners[i]
		var din: Vector3 = (p - corners[i - 1]).normalized()
		var dout: Vector3 = (corners[i + 1] - p).normalized()
		var r: float = minf(radius, minf(p.distance_to(corners[i - 1]), p.distance_to(corners[i + 1])) * 0.45)
		var a: Vector3 = p - din * r
		var b: Vector3 = p + dout * r
		pts.append(a)
		for k: int in range(1, 8):
			var t: float = float(k) / 8.0
			pts.append((a * (1 - t) + p * t) * (1 - t) + (p * (1 - t) + b * t) * t)
		pts.append(b)
	pts.append(corners[corners.size() - 1])
	out.append(pts[0])
	for i: int in range(1, pts.size()):
		var seg: float = pts[i - 1].distance_to(pts[i])
		var n: int = maxi(1, int(ceil(seg / step)))
		for k: int in range(1, n + 1):
			out.append(pts[i - 1].lerp(pts[i], float(k) / float(n)))
	return out


func build_boundaries() -> void:
	var b: Node3D = _group("Boundaries")
	# keep walkers on the front street's neighbourhood: end caps and a back wall behind the lot
	box_body(b, "EndEast", Vector3(152.0, 3.0, 12.0), Vector3(1.0, 8.0, 60.0))
	box_body(b, "EndWest", Vector3(-152.0, 3.0, 12.0), Vector3(1.0, 8.0, 60.0))
	box_body(b, "SouthEdge", Vector3(0.0, 3.0, 40.0), Vector3(310.0, 8.0, 1.0))
