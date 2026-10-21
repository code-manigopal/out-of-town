class_name OOTExteriorWorld
extends Node3D
## The Windsor street world around Mani's building, built in code from the Blender kit in
## res://environments/windsor/exterior/ (tools/blender/build_windsor_exterior.py): ground, streets and sidewalks, the
## front street's traffic and parked cars, shops across the street (invented names), bus stop, trees, houses, poles,
## puddles, the drive route and its invisible guard rails. The authored, hand-placed pieces (building, alley props,
## doors, stairs, graffiti slots, car) live in windsor_exterior.tscn.
##
## Layout (Godot metres, x east, z south toward the front street; see the Blender script header):
##   front street z 15.2..26.0 (westbound lane z 19.0, eastbound z 22.2), sidewalks z 12.6..14.1 / 27.0..28.5
##   side alley x 5.1..8.5, back lot z -4.5..-18.5, back street z -25.5..-18.5 and the blocks west of it.

const DIR: String = "res://environments/windsor/exterior/"
const MAT_DIR: String = DIR + "materials/"
const SND_TRAFFIC: String = "res://audio/sfx/exterior/traffic_car_loop.ogg"

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

const SHOP_NAMES: Array[String] = ["BRINDLE & WICK CAFE", "QUILL BOOKS", "TAMSIN'S BAKERY", "KELLERMAN DRY CLEANING",
	"HOLLOWAY HARDWARE", "NIMBUS BARBER", "FERNWOOD FLORIST", "ORCHARD ROW PHARMACY"]
const CAR_COLOURS: Array[Color] = [Color(0.62, 0.12, 0.12), Color(0.85, 0.85, 0.82), Color(0.13, 0.2, 0.36),
	Color(0.12, 0.13, 0.14), Color(0.55, 0.55, 0.12), Color(0.2, 0.36, 0.28), Color(0.78, 0.5, 0.15), Color(0.5, 0.52, 0.56)]

var route: PackedVector3Array = PackedVector3Array()
var traffic: Array[Node3D] = []
var pedestrians: Array[Node3D] = []
var house_count: int = 0
var tree_count: int = 0
var detail: bool = true

var _mats: Dictionary = {}
var _scenes: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rects: Array[Rect2] = []
var _walkers: Array[Dictionary] = []
var _t: float = 0.0


func _ready() -> void:
	_rng.seed = 41
	route = make_route(ROUTE_CORNERS, ROUTE_FILLET)
	build_ground()
	build_streets()
	if detail:
		build_front_street()
		build_blocks()
	build_route_rails()
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
		if "Windows" in mi.name or "Glass" in mi.name:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i: int in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if src == null or src.resource_name.is_empty():
				continue
			var repl: Material = mat(src.resource_name)
			if repl != null:
				mi.set_surface_override_material(i, repl)


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


func _group(nm: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = nm
	add_child(n)
	return n


# --- ground and streets -------------------------------------------------------------------------

func build_ground() -> void:
	var g: Node3D = _group("Ground")
	# big lawn: mesh a hair below the slabs, collision top at y = 0
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Lawn"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(900.0, 900.0)
	mi.mesh = pm
	mi.material_override = mat("Grass")
	mi.position = Vector3(-30.0, -0.03, -30.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "LawnCol"
	body.set_meta("surface", "grass")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(900.0, 2.0, 900.0)
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3(-30.0, -1.0, -30.0)
	g.add_child(body)


func build_streets() -> void:
	var s: Node3D = _group("Streets")
	for road: Dictionary in ROADS:
		var a: Vector2 = road["a"]
		var b: Vector2 = road["b"]
		var half: float = road["half"]
		var horiz: bool = absf(a.y - b.y) < 0.01
		var lo: float = minf(a.x, b.x) if horiz else minf(a.y, b.y)
		var hi: float = maxf(a.x, b.x) if horiz else maxf(a.y, b.y)
		var c: float = a.y if horiz else a.x
		var r: Rect2 = Rect2(lo, c - half, hi - lo, half * 2.0) if horiz else Rect2(c - half, lo, half * 2.0, hi - lo)
		var mi: MeshInstance3D = slab(s, "Road_" + str(road["id"]), r, -0.004, 0.2, "Asphalt", "asphalt", true)
		mi.material_override = mat("Asphalt")
		# sidewalks, cut where another road crosses
		for sgn: float in [-1.0, 1.0]:
			var inner: float = float(road["walk_in"])
			var w: float = float(road["walk_w"])
			var c0: float = c + sgn * inner
			var c1: float = c + sgn * (inner + w)
			var cuts: Array[Vector2] = _cuts_for(road, lo, hi)
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
				slab(s, "Walk_%s_%d_%d" % [road["id"], int(sgn), k], wr, 0.0, 0.2, "Sidewalk", "concrete", true)
				k += 1
		_markings(s, road, lo, hi, c, horiz)
	# lot, alley, driveway walk to the main door
	slab(s, "BackLot", Rect2(-8.5, -18.5, 17.1, 14.0), 0.0, 0.2, "LotAsphalt", "asphalt", true)
	slab(s, "Alley", Rect2(5.1, -4.5, 3.4, 17.1), 0.0, 0.2, "AlleyConcrete", "concrete", true)
	slab(s, "FrontWalk", Rect2(-4.7, 11.6, 1.6, 1.0), 0.0, 0.2, "Sidewalk", "concrete", true)
	slab(s, "Apron", Rect2(5.1, 12.6, 3.4, 1.5), 0.0, 0.2, "AlleyConcrete", "concrete", true)
	slab(s, "LobbyFloorOutside", Rect2(-5.4, 9.6, 2.4, 2.0), 0.0, 0.2, "Concrete", "concrete", true)
	_puddles(s)


## Intervals along a road where a different road crosses it (plus the other road's half width and its sidewalks).
func _cuts_for(road: Dictionary, lo: float, hi: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a: Vector2 = road["a"]
	var b: Vector2 = road["b"]
	var horiz: bool = absf(a.y - b.y) < 0.01
	for other: Dictionary in ROADS:
		if other["id"] == road["id"]:
			continue
		var oa: Vector2 = other["a"]
		var ob: Vector2 = other["b"]
		var ohoriz: bool = absf(oa.y - ob.y) < 0.01
		if ohoriz == horiz:
			continue
		var oc: float = oa.y if ohoriz else oa.x
		var span: float = float(other["half"]) + 0.2
		# does the other road reach across this one's footprint?
		var my_c: float = a.y if horiz else a.x
		var olo: float = minf(oa.x, ob.x) if ohoriz else minf(oa.y, ob.y)
		var ohi: float = maxf(oa.x, ob.x) if ohoriz else maxf(oa.y, ob.y)
		var reach: float = float(road["walk_in"]) + float(road["walk_w"])
		if my_c + reach < olo or my_c - reach > ohi:
			continue
		if oc + span < lo or oc - span > hi:
			continue
		out.append(Vector2(oc - span, oc + span))
	out.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	return out


func _markings(parent: Node, road: Dictionary, lo: float, hi: float, c: float, horiz: bool) -> void:
	var cuts: Array[Vector2] = []
	for other: Dictionary in ROADS:
		if other["id"] == road["id"]:
			continue
		var oa: Vector2 = other["a"]
		var ob: Vector2 = other["b"]
		if (absf(oa.y - ob.y) < 0.01) == horiz:
			continue
		var oc: float = oa.y if horiz else oa.x
		cuts.append(Vector2(oc - float(other["half"]) - 0.5, oc + float(other["half"]) + 0.5))
	cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var pos: float = lo
	var spans: Array[Vector2] = []
	for cut: Vector2 in cuts:
		if cut.x > pos:
			spans.append(Vector2(pos, cut.x))
		pos = maxf(pos, cut.y)
	spans.append(Vector2(pos, hi))
	var big: bool = float(road["half"]) > 4.5
	for sp: Vector2 in spans:
		var len_: float = sp.y - sp.x
		if len_ < 1.0:
			continue
		var offs: Array[float] = []
		if big:
			offs.append(-0.12)
			offs.append(0.12)
		else:
			offs.append(0.0)
		for o: float in offs:
			var r: Rect2 = Rect2(sp.x, c + o - 0.05, len_, 0.1) if horiz else Rect2(c + o - 0.05, sp.x, 0.1, len_)
			if not big:
				_dashes(parent, road["id"], sp, c, horiz)
				break
			slab(parent, "Line_%s_%d" % [road["id"], int(sp.x)], r, 0.003, 0.01, "LaneYellow", "", false)
	# zebra crossing on the front street, east of the shops' middle
	if road["id"] == "front":
		for k: int in 8:
			var cx: float = 16.0 + float(k) * 0.9
			slab(parent, "Zebra_%d" % k, Rect2(cx, 15.4, 0.5, 10.4), 0.003, 0.01, "LaneWhite", "", false)


func _dashes(parent: Node, id: String, sp: Vector2, c: float, horiz: bool) -> void:
	var x: float = sp.x + 1.0
	var k: int = 0
	while x < sp.y - 3.0:
		var r: Rect2 = Rect2(x, c - 0.06, 3.0, 0.12) if horiz else Rect2(c - 0.06, x, 0.12, 3.0)
		slab(parent, "Dash_%s_%d_%d" % [id, int(sp.x), k], r, 0.003, 0.01, "LaneYellow", "", false)
		x += 7.0
		k += 1


func _puddles(parent: Node) -> void:
	var spots: Array[Vector4] = [Vector4(6.6, 9.0, 0.8, 1.4), Vector4(7.4, 4.4, 0.9, 1.2), Vector4(6.0, -1.0, 0.6, 1.5),
		Vector4(5.9, 2.8, 0.5, 0.8), Vector4(-0.2, -6.2, 1.1, 0.8), Vector4(2.0, -13.5, 1.4, 1.8), Vector4(-6.0, -15.5, 0.9, 1.2),
		Vector4(-3.9, 12.2, 0.8, 0.5), Vector4(1.0, 15.9, 2.5, 0.8)]
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


# --- the front street: shops, traffic, bus stop, lights ----------------------------------------------

func build_front_street() -> void:
	var f: Node3D = _group("FrontStreet")
	# shops across the street: contiguous row from x = -66 to +66, front on z = 28.5, facing -Z
	var kit: Array[String] = ["shop_a", "shop_b", "shop_c", "shop_d"]
	var widths: Dictionary = {"shop_a": 8.0, "shop_b": 7.0, "shop_c": 9.0, "shop_d": 7.5}
	var x: float = -66.0
	var i: int = 0
	while x < 66.0:
		var k: String = kit[(i * 3 + i / 2) % kit.size()]
		var w: float = widths[k]
		var n: Node3D = place(k, Vector3(x + w * 0.5, 0.0, 28.5), 0.0, f)
		if n != null:
			box_body(f, "ShopCol_%d" % i, Vector3(x + w * 0.5, 3.5, 33.5), Vector3(w, 7.0, 10.0))
			var lab: Label3D = Label3D.new()
			lab.name = "ShopSign_%d" % i
			lab.text = SHOP_NAMES[i % SHOP_NAMES.size()]
			lab.font_size = 96
			lab.pixel_size = 0.0042 if lab.text.length() < 17 else 0.0034
			lab.modulate = Color(0.95, 0.9, 0.78)
			lab.outline_size = 8
			lab.outline_modulate = Color(0.05, 0.05, 0.06)
			lab.position = Vector3(x + w * 0.5, 3.7, 28.34)
			lab.rotation.y = PI
			lab.shaded = false
			lab.double_sided = false
			f.add_child(lab)
		x += w + 0.25
		i += 1
	# houses on the same side beyond the shop row, and along the building's side of the street
	var hx: float = 70.0
	var hs: Array[String] = ["house_a", "house_b", "house_c", "house_d", "house_e"]
	var j: int = 0
	while hx < 148.0:
		_house_front(f, hs[j % hs.size()], hx, 29.0, 180.0)
		_house_front(f, hs[(j + 2) % hs.size()], -hx, 29.0, 180.0)
		hx += 11.0
		j += 1
	var nx: float = 24.0
	j = 1
	while nx < 148.0:
		_house_front(f, hs[j % hs.size()], nx + 4.0, 4.5, 0.0)
		_house_front(f, hs[(j + 3) % hs.size()], -nx - 4.0 - 4.0, 4.5, 0.0)
		nx += 11.0
		j += 1
	# street trees on both boulevards (autumn colours), lights, poles
	var tx: float = -140.0
	var ti: int = 0
	while tx < 141.0:
		if not (tx > 0.0 and tx < 12.0) and not (tx > -17.0 and tx < -7.0):
			place(["tree_a", "tree_b", "tree_c"][ti % 3], Vector3(tx, 0.0, 14.65), float(ti * 47 % 360), f)
			tree_count += 1
		place(["tree_b", "tree_c", "tree_a"][ti % 3], Vector3(tx + 5.0, 0.0, 26.5), float(ti * 31 % 360), f)
		tree_count += 1
		tx += 11.0
		ti += 1
	var lx: float = -135.0
	while lx < 136.0:
		place("streetlight", Vector3(lx, 0.0, 15.05), 90.0, f)
		place("streetlight", Vector3(lx + 12.0, 0.0, 26.1), -90.0, f)
		lx += 24.0
	place("utility_pole", Vector3(-30.0, 0.0, 14.7), 90.0, f)
	place("utility_pole", Vector3(55.0, 0.0, 14.7), 90.0, f)
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
	# parked cars along both kerbs, static
	var pcs: Array[Vector3] = [Vector3(-34.0, 0.0, 16.4), Vector3(-21.0, 0.0, 16.4), Vector3(26.0, 0.0, 16.4),
		Vector3(40.0, 0.0, 16.4), Vector3(-30.0, 0.0, 24.8), Vector3(-4.0, 0.0, 24.8), Vector3(12.0, 0.0, 24.8), Vector3(48.0, 0.0, 24.8)]
	var pi: int = 0
	for p: Vector3 in pcs:
		_parked_car(f, p, -90.0 if p.z < 20.0 else 90.0, pi)
		pi += 1
	_build_traffic(f)
	_build_people(f)


func _house_front(parent: Node, file: String, x: float, z_front: float, yaw: float) -> void:
	var depths: Dictionary = {"house_a": 9.5, "house_b": 8.5, "house_c": 9.0, "house_d": 8.0, "house_e": 9.0}
	var d: float = depths[file]
	var zc: float = z_front - d * 0.5 if yaw == 0.0 else z_front + d * 0.5
	var r: Rect2 = Rect2(x - 5.0, zc - d * 0.5, 10.0, d)
	for q: Rect2 in _rects:
		if q.intersects(r):
			return
	_rects.append(r)
	place(file, Vector3(x, 0.0, zc), yaw, parent)
	box_body(parent, "HouseCol_%d" % house_count, Vector3(x, 2.7, zc), Vector3(8.0, 5.4, d - 0.4))
	house_count += 1


func _parked_car(parent: Node, pos: Vector3, yaw: float, idx: int) -> void:
	var kit: Array[String] = ["traffic_sedan", "traffic_hatchback", "traffic_suv"]
	var n: Node3D = place(kit[idx % 3], pos, yaw, parent)
	if n == null:
		return
	paint(n, CAR_COLOURS[(idx * 3 + 1) % CAR_COLOURS.size()])
	box_body(parent, "ParkedCol_%d" % idx, pos + Vector3(0.0, 0.8, 0.0), Vector3(1.9, 1.6, 4.7) if yaw == 0.0 or yaw == 180.0 else Vector3(4.7, 1.6, 1.9))


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
	var lanes: Array[Dictionary] = [
		{"z": 19.0, "dir": -1.0, "n": 5, "name": "LaneWest"}, {"z": 22.2, "dir": 1.0, "n": 4, "name": "LaneEast"}]
	var kit: Array[String] = ["traffic_sedan", "traffic_hatchback", "traffic_suv"]
	var ci: int = 0
	for lane: Dictionary in lanes:
		var path: Path3D = Path3D.new()
		path.name = str(lane["name"])
		var curve: Curve3D = Curve3D.new()
		var dir: float = lane["dir"]
		curve.add_point(Vector3(-140.0 * dir, 0.0, lane["z"]))
		curve.add_point(Vector3(140.0 * dir, 0.0, lane["z"]))
		path.curve = curve
		parent.add_child(path)
		var length: float = curve.get_baked_length()
		for k: int in int(lane["n"]):
			var pf: PathFollow3D = PathFollow3D.new()
			pf.name = "Car_%d" % ci
			pf.loop = true
			pf.rotation_mode = PathFollow3D.ROTATION_ORIENTED
			pf.use_model_front = true
			path.add_child(pf)
			pf.progress = length * (float(k) + _rng.randf_range(0.0, 0.5)) / float(lane["n"])
			var car: Node3D = place(kit[(ci + k) % 3], Vector3.ZERO, 0.0, pf)
			if car != null:
				paint(car, CAR_COLOURS[(ci * 5 + 2) % CAR_COLOURS.size()])
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
				car.add_child(snd)
			traffic.append(pf)
			pf.set_meta("speed", _rng.randf_range(6.5, 9.5))
			ci += 1


func _build_people(parent: Node) -> void:
	for spec: Array in [["person_a", Vector3(-12.9, 0.0, 13.2), 160.0], ["person_b", Vector3(-11.4, 0.0, 13.0), 200.0],
			["person_c", Vector3(34.0, 0.0, 27.6), 90.0]]:
		var p: Node3D = place(spec[0], spec[1], spec[2], parent)
		if p != null:
			pedestrians.append(p)
	# two walkers pacing the far sidewalk and ours
	for spec2: Array in [["person_d", 27.7, -40.0, 20.0, 1.25], ["person_a", 13.35, 30.0, 70.0, 1.4]]:
		var w: Node3D = place(spec2[0], Vector3(spec2[2], 0.0, spec2[1]), 90.0, parent)
		if w != null:
			pedestrians.append(w)
			_walkers.append({"node": w, "z": spec2[1], "x0": spec2[2], "x1": spec2[3], "speed": spec2[4], "dir": 1.0})


# --- blocks along the back streets ----------------------------------------------------------------

func build_blocks() -> void:
	var b: Node3D = _group("Blocks")
	var hs: Array[String] = ["house_a", "house_b", "house_c", "house_d", "house_e"]
	var depths: Dictionary = {"house_a": 9.5, "house_b": 8.5, "house_c": 9.0, "house_d": 8.0, "house_e": 9.0}
	var idx: int = 0
	for road: Dictionary in ROADS:
		if road["id"] == "front":
			continue
		var a: Vector2 = road["a"]
		var e: Vector2 = road["b"]
		var horiz: bool = absf(a.y - e.y) < 0.01
		var lo: float = (minf(a.x, e.x) if horiz else minf(a.y, e.y)) + 14.0
		var hi: float = (maxf(a.x, e.x) if horiz else maxf(a.y, e.y)) - 14.0
		var c: float = a.y if horiz else a.x
		var along: float = lo
		while along < hi:
			for sgn: float in [-1.0, 1.0]:
				var file: String = hs[(idx * 2 + int(sgn + 1.0)) % hs.size()]
				var d: float = depths[file]
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
					place(["tree_a", "tree_b", "tree_c"][(idx + int(sgn2 + 1.0)) % 3], tp, float(idx * 53 % 360), b)
					tree_count += 1
			along += 12.5
	# a few parked cars along the quiet kerbs (never in the route's lane)
	var spots: Array[Array] = [[Vector3(-20.0, 0.0, -20.0), 180.0], [Vector3(-66.0, 0.0, -20.1), 180.0],
		[Vector3(-84.0, 0.0, -20.1), 0.0], [Vector3(-111.9, 0.0, -50.0), 0.0], [Vector3(-111.9, 0.0, -78.0), 180.0],
		[Vector3(-160.0, 0.0, -108.4), 0.0], [Vector3(-142.0, 0.0, -108.4), 180.0]]
	var si: int = 0
	for s: Array in spots:
		var yaw: float = s[1]
		var p: Vector3 = s[0]
		var n: Node3D = place(["traffic_hatchback", "traffic_sedan", "traffic_suv"][si % 3], p, yaw, b)
		if n != null:
			paint(n, CAR_COLOURS[(si * 3 + 4) % CAR_COLOURS.size()])
			box_body(b, "ParkedBlockCol_%d" % si, p + Vector3(0.0, 0.8, 0.0), Vector3(1.9, 1.6, 4.7) if (p.x == -111.9) else Vector3(4.7, 1.6, 1.9))
		si += 1


var _house_rects: Array[Rect2] = []


func _house_ok(pos: Vector3, horiz: bool, d: float) -> bool:
	var r: Rect2 = _hr(pos, horiz, d)
	for q: Rect2 in _house_rects:
		if q.intersects(r):
			return false
	# keep clear of every road's asphalt + sidewalks
	for road: Dictionary in ROADS:
		var a: Vector2 = road["a"]
		var e: Vector2 = road["b"]
		var h: bool = absf(a.y - e.y) < 0.01
		var m: float = float(road["walk_in"]) + float(road["walk_w"]) + 2.0
		var rr: Rect2
		if h:
			rr = Rect2(minf(a.x, e.x), a.y - m, absf(e.x - a.x), m * 2.0)
		else:
			rr = Rect2(a.x - m, minf(a.y, e.y), m * 2.0, absf(e.y - a.y))
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
		var a: Vector2 = road["a"]
		var e: Vector2 = road["b"]
		var h: bool = absf(a.y - e.y) < 0.01
		var m: float = float(road["walk_in"]) + float(road["walk_w"]) + 3.0
		if h:
			if p.x > minf(a.x, e.x) - 2.0 and p.x < maxf(a.x, e.x) + 2.0 and absf(p.z - a.y) < m:
				return false
		else:
			if p.z > minf(a.y, e.y) - 2.0 and p.z < maxf(a.y, e.y) + 2.0 and absf(p.x - a.x) < m:
				return false
	return true


# --- route, rails, boundaries -----------------------------------------------------------------

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


func build_route_rails() -> void:
	var r: Node3D = _group("RouteRails")
	var i: int = 0
	var step: int = 3
	var k: int = 0
	while k < route.size() - step:
		var a: Vector3 = route[k]
		var b: Vector3 = route[k + step]
		var d: Vector3 = b - a
		d.y = 0.0
		var len_: float = d.length()
		if len_ < 0.1:
			k += step
			continue
		var dir: Vector3 = d / len_
		var side: Vector3 = Vector3(dir.z, 0.0, -dir.x)
		for sgn: float in [-1.0, 1.0]:
			var c: Vector3 = (a + b) * 0.5 + side * sgn * 5.4 + Vector3(0.0, 0.9, 0.0)
			var body: StaticBody3D = box_body(r, "Rail_%d" % i, c, Vector3(0.4, 1.8, len_ + 0.8))
			body.rotation.y = atan2(dir.x, dir.z)
			i += 1
		k += step


func build_boundaries() -> void:
	var b: Node3D = _group("Boundaries")
	# keep walkers on the front street's neighbourhood: end caps and a back wall behind the lot
	box_body(b, "EndEast", Vector3(152.0, 3.0, 12.0), Vector3(1.0, 8.0, 60.0))
	box_body(b, "EndWest", Vector3(-152.0, 3.0, 12.0), Vector3(1.0, 8.0, 60.0))
	box_body(b, "SouthEdge", Vector3(0.0, 3.0, 40.0), Vector3(310.0, 8.0, 1.0))


func _physics_process(delta: float) -> void:
	for t: Node3D in traffic:
		var pf: PathFollow3D = t as PathFollow3D
		if pf != null:
			pf.progress += float(pf.get_meta("speed", 8.0)) * delta
	_t += delta
	for w: Dictionary in _walkers:
		var n: Node3D = w["node"]
		var dir: float = w["dir"]
		n.position.x += dir * float(w["speed"]) * delta
		if n.position.x > float(w["x1"]):
			w["dir"] = -1.0
			n.rotation.y = -PI / 2.0
		elif n.position.x < float(w["x0"]):
			w["dir"] = 1.0
			n.rotation.y = PI / 2.0
		n.position.y = absf(sin(_t * 5.2 + float(n.get_instance_id() % 7))) * 0.035
