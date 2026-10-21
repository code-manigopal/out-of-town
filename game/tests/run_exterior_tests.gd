extends SceneTree
## Episode 1 exit-sequence tests (windsor_exterior.tscn, the sedan, the route and its arrows). Run:
##   godot --headless --path game --script res://tests/run_exterior_tests.gd
## Exits with code 1 on any failure. The scene tests are skipped when the .glb models are Git LFS pointers (CI).

const SCENE: String = "res://scenes/p1/e1/windsor_exterior.tscn"

var StoryState: Node
var _failures: int = 0
var _checks: int = 0


static func lfs_assets_present() -> bool:
	for path: String in ["res://characters/mani/mani.glb", "res://vehicles/sedan/sedan.glb", "res://environments/windsor/exterior/building.glb"]:
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			return false
		if f.get_buffer(24).get_string_from_ascii().begins_with("version https://git-lfs"):
			return false
	return true


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("ok   ", msg)
		return
	_failures += 1
	printerr("FAIL: " + msg)


func _initialize() -> void:
	StoryState = root.get_node_or_null("StoryState")
	await process_frame
	_test_pure()
	if lfs_assets_present():
		await _test_scene()
	else:
		print("SKIPPED exterior scene tests: Git LFS assets are not checked out (CI).")
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- no assets needed ----------------------------------------------------------------------

func _test_pure() -> void:
	var route: PackedVector3Array = OOTExteriorWorld.make_route(OOTExteriorWorld.ROUTE_CORNERS, OOTExteriorWorld.ROUTE_FILLET)
	_check(route.size() > 250, "drive route has %d points" % route.size())
	_check(route[0].is_equal_approx(OOTExteriorWorld.ROUTE_CORNERS[0]), "route starts at the car in the lot")
	_check(route[route.size() - 1].is_equal_approx(OOTExteriorWorld.ROUTE_CORNERS[OOTExteriorWorld.ROUTE_CORNERS.size() - 1]), "route ends at the last corner")
	# out of the lot north (-Z), then left = west (-X)
	var d0: Vector3 = (route[5] - route[0]).normalized()
	_check(d0.z < -0.99, "the route leaves the lot heading north")
	var turn_idx: int = -1
	for i: int in route.size():
		if route[i].x < -10.0:
			turn_idx = i
			break
	_check(turn_idx > 0 and absf(route[turn_idx].z - (-23.7)) < 0.6, "the first turn is left (west) onto the back street")
	var total: float = 0.0
	for i: int in range(1, route.size()):
		total += route[i - 1].distance_to(route[i])
	_check(total > 280.0 and total < 420.0, "route is a couple of blocks long (%.0f m)" % total)
	# stage classification
	_check(OOTWindsorExterior.stage_for(Vector3(2.0, 2.95, 5.25)) == &"verandah", "stage: verandah")
	_check(OOTWindsorExterior.stage_for(Vector3(-4.2, 1.5, 7.8)) == &"stairs", "stage: stairs")
	_check(OOTWindsorExterior.stage_for(Vector3(-3.9, 0.0, 10.4)) == &"lobby", "stage: lobby")
	_check(OOTWindsorExterior.stage_for(Vector3(0.0, 0.0, 13.3)) == &"street", "stage: street")
	_check(OOTWindsorExterior.stage_for(Vector3(6.8, 0.0, 2.0)) == &"alley", "stage: alley")
	_check(OOTWindsorExterior.stage_for(Vector3(-0.8, 0.0, -7.0)) == &"lot", "stage: lot")
	# placeholder graffiti
	var t1: ImageTexture = OOTWindsorExterior.make_tag_texture(1)
	var t2: ImageTexture = OOTWindsorExterior.make_tag_texture(2)
	_check(t1.get_width() == 768 and t1.get_height() == 384, "graffiti placeholder is 768x384")
	var i1: Image = t1.get_image()
	var opaque: int = 0
	for y: int in range(0, 384, 4):
		for x: int in range(0, 768, 4):
			if i1.get_pixel(x, y).a > 0.5:
				opaque += 1
	_check(opaque > 300, "graffiti placeholder has paint on it (%d samples)" % opaque)
	_check(t1.get_image().get_data() != t2.get_image().get_data(), "each graffiti slot has its own placeholder")
	# the car script keeps the auto-cruise hook
	var cs: GDScript = load("res://scripts/vehicle/oot_car.gd") as GDScript
	var has_cruise: bool = false
	for m: Dictionary in cs.get_script_method_list():
		if m["name"] == "set_auto_cruise":
			has_cruise = true
	_check(has_cruise, "OOTCar.set_auto_cruise(on) exists")
	var es: GDScript = load("res://scripts/episodes/e1/windsor_exterior.gd") as GDScript
	var has_sig: bool = false
	for s: Dictionary in es.get_script_signal_list():
		if s["name"] == "drive_reached_county_road":
			has_sig = true
	_check(has_sig, "windsor_exterior emits drive_reached_county_road")


# --- the scene ------------------------------------------------------------------------------

func _spawn() -> OOTWindsorExterior:
	if StoryState != null:
		StoryState.start_part("p1")
	var ext: OOTWindsorExterior = (load(SCENE) as PackedScene).instantiate() as OOTWindsorExterior
	ext.play_audio = false
	ext.show_hints = false
	root.add_child(ext)
	return ext


func _dt() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


## Game seconds simulated so far (physics ticks / tick rate; the tests run at Engine.time_scale 1).
func _sim() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


static func _center(n: Node3D) -> Vector3:
	var out: AABB = AABB()
	var first: bool = true
	var nodes: Array[Node] = [n]
	nodes.append_array(n.find_children("*", "MeshInstance3D", true, false))
	for c: Node in nodes:
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out.get_center() if not first else n.global_position


func _wait_frames(n: int) -> void:
	for i: int in n:
		await physics_frame


## Waits until `flag.call()` is true or `seconds` of game time pass. Returns whether it became true.
func _until(flag: Callable, seconds: float) -> bool:
	var t0: float = _sim()
	while _sim() - t0 < seconds:
		if flag.call():
			return true
		await physics_frame
	return flag.call()


func _test_scene() -> void:
	var ext: OOTWindsorExterior = _spawn()
	await _wait_frames(8)
	_check(ext.is_inside_tree() and ext.player != null and ext.car != null, "windsor_exterior.tscn loads")
	_check(ext.stage == &"verandah", "the sequence starts on the verandah")
	_check(StoryState.has_flag("has_car_keys"), "Mani has the car keys")
	_check(ext.is_carrying_duffel(), "Mani carries the duffel")
	_check(ext.world.house_count > 40 and ext.world.tree_count > 40, "the street world is built (%d houses, %d trees)" % [ext.world.house_count, ext.world.tree_count])
	await _test_props(ext)
	_test_world_materials(ext)
	_test_parking(ext)
	_test_graffiti_alpha(ext)
	_test_roadworks_static(ext)
	_test_pedestrian_hooks(ext)
	_test_drivers(ext)
	_test_bench(ext)
	_park_peds(ext)
	await _test_lamps(ext)
	await _test_traffic(ext)
	await _test_kerbs(ext)
	await _test_walkable(ext)
	await _test_arrows(ext)
	await _test_trunk_and_car(ext)
	await _test_drive_and_fade(ext)
	await _test_roadworks_block_car(ext)
	await _test_episode_wiring()
	ext.queue_free()
	await process_frame


func _test_props(ext: OOTWindsorExterior) -> void:
	for n: String in ["Mailbox_1", "Mailbox_2", "Mailbox_1_Number", "Mailbox_2_Number", "FlatNumber_1", "FlatNumber_2"]:
		_check(ext.find_child(n, true, false) != null, "%s exists" % n)
	var m1: Node3D = ext.find_child("Mailbox_1", true, false) as Node3D
	var m2: Node3D = ext.find_child("Mailbox_2", true, false) as Node3D
	var door: Node3D = ext.main_door
	_check(m1 != null and m2 != null and _center(m1).distance_to(door.global_position) < 2.0 and _center(m2).distance_to(door.global_position) < 2.0,
		"both mailboxes are beside the main door")
	var f1: Node3D = ext.find_child("FlatNumber_1", true, false) as Node3D
	var f2: Node3D = ext.find_child("FlatNumber_2", true, false) as Node3D
	_check(f1 != null and f2 != null and _center(f1).y < 2.0 and _center(f2).y > 3.5, "flat 1 is downstairs, flat 2 upstairs")
	_check(ext.main_door.interactable != null and ext.main_door.interactable.kind == OOTInteractable.Kind.USE, "the main door is a Use interactable")
	for i: int in range(1, 5):
		var d: Decal = ext.find_child("Graffiti_%d" % i, true, false) as Decal
		_check(d != null and d.texture_albedo != null, "decal slot Graffiti_%d has a texture" % i)
	_check(ext.find_child("Dumpster", true, false) != null, "the alley has a dumpster")
	_check(ext.world.find_child("Puddle_0", true, false) != null, "puddles exist")
	var poles: int = 0
	for n: Node in ext.find_children("*Pole*", "Node3D", true, false):
		poles += 1
	_check(poles >= 2, "utility poles exist (%d nodes)" % poles)
	_check(ext.find_child("BusShelter", true, false) != null, "the street has a bus stop")
	_check(ext.world.traffic.size() >= 6, "traffic cars loop on paths (%d)" % ext.world.traffic.size())
	_test_shop_signs(ext)
	var lot: Node = ext.get_node_or_null("LotCars")
	var lot_cars: int = 0
	if lot != null:
		for c: Node in lot.get_children():
			if c is Node3D and not (c is StaticBody3D):
				lot_cars += 1
	_check(lot_cars == 2 and ext.car != null and ext.car.global_position.z < -9.0, "three cars are parked in the back lot (his plus %d)" % lot_cars)
	var paint_ok: bool = false
	for n3: Node in ext.car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n3 as MeshInstance3D
		for i: int in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(i)
			if mat != null and mat.resource_name == "CarPaint":
				var c: Color = (mat as StandardMaterial3D).albedo_color
				paint_ok = absf(c.r - c.g) < 0.1 and c.r > 0.2 and c.r < 0.7
	_check(paint_ok, "Mani's car is grey")


## Walks a real 0.35 m capsule along the whole on-foot route.
func _test_walkable(ext: OOTWindsorExterior) -> void:
	ext.main_door.snap(true)
	var body: CharacterBody3D = CharacterBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0.0, 0.875, 0.0)
	body.add_child(cs)
	root.add_child(body)
	body.global_position = Vector3(2.0, 2.95, 7.0)       # parked out of the way first
	ext.player.global_position = Vector3(300.0, 0.0, 300.0)   # keep the real player's capsule out of the way
	body.global_position = Vector3(2.0, 2.95, 5.25)
	await _wait_frames(6)
	var legs: Array = [
		["verandah to its west end", Vector3(-4.2, 0.0, 5.25)],
		["onto the stairs", Vector3(-4.2, 0.0, 6.6)],
		["down the stairs", Vector3(-4.0, 0.0, 9.3)],
		["through the lobby to the main door", Vector3(-3.9, 0.0, 10.9)],
		["out of the main door", Vector3(-3.9, 0.0, 12.2)],
		["to the sidewalk", Vector3(-3.9, 0.0, 13.3)],
		["along the sidewalk to the alley", Vector3(6.8, 0.0, 13.3)],
		["up the alley to the dumpster", Vector3(6.4, 0.0, 2.0)],
		["past the dumpster", Vector3(6.3, 0.0, -3.0)],
		["into the lot", Vector3(5.0, 0.0, -6.0)],
		["to the trunk of his car", Vector3(-0.8, 0.0, -7.3)],
		["round the back of the car", Vector3(-2.4, 0.0, -7.3)],
		["to the driver's door", Vector3(-2.3, 0.0, -10.4)],
	]
	var ok_all: bool = true
	var min_y: float = 99.0
	for leg: Array in legs:
		var target: Vector3 = leg[1]
		var reached: bool = false
		var t: float = 0.0
		while t < 14.0:
			await physics_frame
			var dt: float = _dt()
			t += dt
			var d: Vector3 = target - body.global_position
			d.y = 0.0
			if d.length() < 0.3:
				reached = true
				break
			var v: Vector3 = d.normalized() * 1.4
			body.velocity.x = v.x
			body.velocity.z = v.z
			body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 * dt
			body.move_and_slide()
		_check(reached, "walkable: %s (at %s)" % [leg[0], str(body.global_position)])
		ok_all = ok_all and reached
		min_y = minf(min_y, body.global_position.y)
		if not reached:
			break
	if ok_all:
		_check(body.global_position.y < 0.2 and min_y > -0.15, "the walk ends on the ground and never falls through (min y %.2f)" % min_y)
	body.queue_free()
	ext.main_door.snap(false)
	ext.debug_teleport_player(Vector3(-0.8, 0.05, -6.7), 0.0)
	await _wait_frames(8)


func _test_arrows(ext: OOTWindsorExterior) -> void:
	var arrows: OOTNavArrows = ext.arrows
	_check(arrows.arrows.size() >= 25, "navigation arrows exist along the route (%d)" % arrows.arrows.size())
	var route: PackedVector3Array = ext.world.route
	var worst: float = 0.0
	for a: MeshInstance3D in arrows.arrows:
		var best: float = INF
		for p: Vector3 in route:
			best = minf(best, Vector2(p.x - a.global_position.x, p.z - a.global_position.z).length())
		worst = maxf(worst, best)
	_check(worst < 1.0, "every arrow lies on the route (worst offset %.2f m)" % worst)
	var last: float = arrows.arrow_distances[arrows.arrow_distances.size() - 1]
	_check(last > arrows.get_route_length() - 25.0 and arrows.arrow_distances[0] < 10.0, "arrows cover the whole route (%.0f of %.0f m)" % [last, arrows.get_route_length()])
	_check(ext.car.route.size() == route.size(), "the car knows the route (auto-cruise follows it)")


func _test_trunk_and_car(ext: OOTWindsorExterior) -> void:
	ext.debug_teleport_player(Vector3(-0.8, 0.05, -6.6), 0.0)
	await _wait_frames(10)
	_check(ext.stage == &"lot", "stage becomes lot at the cars")
	_check(ext.car.trunk_use.enabled, "the trunk is usable while carrying the duffel")
	var seq: Array[bool] = [false]
	ext.trunk_loaded.connect(func() -> void: seq[0] = true)
	ext._on_trunk_used(null)
	await _until(func() -> bool: return seq[0], 14.0)
	_check(seq[0], "the trunk sequence completes")
	_check(ext.player.interactor.carried == null, "the carry is cleared")
	_check(ext.bag != null and ext.bag.get_parent() == ext.car, "the duffel visual is now a child of the car")
	var lp: Vector3 = ext.bag.position if ext.bag != null else Vector3(9, 9, 9)
	_check(absf(lp.x) < 0.7 and lp.z < -0.9 and lp.z > -2.3 and lp.y > 0.3 and lp.y < 0.95, "the duffel rests inside the trunk (car-local %s)" % str(lp))
	_check(not ext.car.is_trunk_open(), "the trunk is closed again")
	_check(ext.car.door_use.enabled, "the driver's door becomes usable")
	# enter the car
	ext.debug_teleport_player(Vector3(-2.2, 0.05, -10.4), PI / 2.0)
	await _wait_frames(8)
	var seated: Array[bool] = [false]
	ext.seated.connect(func() -> void: seated[0] = true)
	ext._on_car_door_used(null)
	await _until(func() -> bool: return seated[0], 14.0)
	_check(seated[0], "the car-enter sequence completes")
	_check(ext.player.get_parent() == ext.car.seat_anchor, "Mani is parented to the seat")
	_check(ext.player.has_pose_override(), "Mani plays the seated driving pose")
	_check(not ext.engine_is_on, "the engine is off until the key is turned")
	_check(ext.car.ignition.enabled, "the ignition is usable")
	_check(ext.car.is_parked(), "the car is parked before the engine starts")
	var started: Array[bool] = [false]
	ext.engine_started.connect(func() -> void: started[0] = true)
	ext._on_ignition_used(null)
	await _until(func() -> bool: return started[0], 8.0)
	_check(started[0] and ext.car.engine_on, "the engine starts")
	_check(not ext.car.is_parked(), "the car is released when the engine is on")
	_check(root.get_viewport().get_camera_3d() == ext.car.chase_cam, "control (and camera) switch to the car")
	_check(ext.car.use_player_input, "the car takes the player's input")
	# drive with the real input actions (W for a second, then W + A)
	var p0: Vector3 = ext.car.global_position
	var max_speed: float = 0.0
	Input.action_press("move_forward")
	var t0: float = _sim()
	while _sim() - t0 < 1.0:
		await physics_frame
		max_speed = maxf(max_speed, ext.car.get_forward_speed())
	var h0: float = ext.car.get_heading()
	Input.action_press("move_left")
	t0 = _sim()
	while _sim() - t0 < 1.4:
		await physics_frame
		max_speed = maxf(max_speed, ext.car.get_forward_speed())

	Input.action_release("move_left")
	Input.action_release("move_forward")
	_check(max_speed > 3.0 and ext.car.global_position.distance_to(p0) > 4.0, "W drives the car (peak %.1f m/s, %.1f m)" % [max_speed, ext.car.global_position.distance_to(p0)])
	var dh: float = wrapf(ext.car.get_heading() - h0, -PI, PI)
	_check(dh > 0.15, "A turns the car left (heading change %.0f deg)" % rad_to_deg(dh))


## Resets the car onto the start of the route and lets auto-cruise (route following) drive all the way to the fade.
func _test_drive_and_fade(ext: OOTWindsorExterior) -> void:
	ext.car.set_ai_inputs(0.0, 0.0, 1.0)
	await _wait_frames(40)
	ext.car.clear_ai_inputs()
	ext.car.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-0.8, 0.05, -10.5))
	ext.car.linear_velocity = Vector3.ZERO
	ext.car.angular_velocity = Vector3.ZERO
	await _wait_frames(10)
	ext.car.set_auto_cruise(true, 9.0)
	var done: Array[bool] = [false]
	ext.drive_reached_county_road.connect(func() -> void: done[0] = true)
	var turned: bool = false
	var max_lat: float = 0.0
	var t0: float = _sim()
	while _sim() - t0 < 160.0 and not done[0]:
		await physics_frame
		var p: Vector3 = ext.car.global_position
		if p.x < -20.0 and absf(p.z + 23.7) < 2.5:
			turned = true
		if not ext.drive_finished:
			var idx_off: float = INF
			for q: Vector3 in ext.world.route:
				idx_off = minf(idx_off, Vector2(q.x - p.x, q.z - p.z).length())
			max_lat = maxf(max_lat, idx_off)
	_check(turned, "the car leaves the lot, turns left and follows the back street")
	_check(max_lat < 4.5, "the car stays within the road corridor (max %.1f m off the route)" % max_lat)
	_check(ext.drive_finished and done[0], "the fade finishes and drive_reached_county_road is emitted (%.0f s)" % (_sim() - t0))
	_check(ext._card_title.text == ext.road_card_text() and ext._card_title.text.contains("County Road 20, Essex County") and ext._card_title.text.contains("10:10"),
		"the card reads '%s'" % ext._card_title.text)
	_check(is_equal_approx(ext._card_fade.modulate.a, 1.0), "the screen is faded to black")


# --- v2: realism pass, shop signs, parked cars, graffiti, road works, traffic ------------------------

func _test_world_materials(ext: OOTWindsorExterior) -> void:
	for n: String in ["Asphalt", "Sidewalk", "Brick", "Siding", "Roof", "Grass", "Bark"]:
		var m: StandardMaterial3D = ext.world.mat(n) as StandardMaterial3D
		_check(m != null and m.albedo_texture != null and m.normal_enabled and m.normal_texture != null and m.roughness_texture != null,
			"%s is a PBR material (albedo, normal, roughness maps)" % n)
	var env: Environment = (load("res://scenes/common/env_exterior_morning.tres") as Environment)
	_check(env.sky != null and env.sky.sky_material is PanoramaSkyMaterial, "the sky is a Poly Haven HDRI panorama")
	var kerbs: int = 0
	for n2: Node in ext.world.find_children("Kerb_*", "MeshInstance3D", true, false):
		kerbs += 1
	_check(kerbs >= 8, "roads have kerbs (%d kerb runs)" % kerbs)
	var road: MeshInstance3D = ext.world.find_child("Road_front", true, false) as MeshInstance3D
	var walk: MeshInstance3D = ext.world.find_child("Walk_front_-1_0", true, false) as MeshInstance3D
	_check(road != null and walk != null and walk.global_position.y - road.global_position.y > 0.0 and OOTExteriorWorld.road_y() < -0.05,
		"the road lies a kerb step below the sidewalk (%.2f m)" % -OOTExteriorWorld.road_y())
	var markings: int = 0
	for n3: Node in ext.world.find_children("Zebra_*", "MeshInstance3D", true, false):
		markings += 1
	_check(markings >= 20, "crosswalks are marked (%d bars)" % markings)
	var props: int = 0
	for nm: String in ["hydrant", "litter_bin", "bench", "stop_sign", "speed_sign", "parking_sign", "storm_drain", "manhole", "streetlight", "bike_ring"]:
		if ext.world.scene_of(nm) != null:
			props += 1
	_check(props == 10, "street furniture models exist (%d of 10)" % props)
	for t: String in OOTExteriorWorld.TREES:
		_check(ext.world.scene_of(t) != null, "street tree model %s exists" % t)


func _test_shop_signs(ext: OOTWindsorExterior) -> void:
	var signs: Array[MeshInstance3D] = ext.world.shop_signs
	_check(signs.size() == OOTExteriorWorld.SHOPS.size() and signs.size() >= 10, "every shop has its own sign slot (%d)" % signs.size())
	var all_ok: bool = true
	var all_png: bool = true
	var aspect_ok: bool = true
	for sm: MeshInstance3D in signs:
		var id: String = str(sm.get_meta("shop_id"))
		var mat: StandardMaterial3D = sm.material_override as StandardMaterial3D
		all_ok = all_ok and sm.mesh is QuadMesh and mat != null and mat.albedo_texture != null
		var path: String = "res://environments/windsor/exterior/signs/%s.png" % id
		all_png = all_png and FileAccess.file_exists(path)
		if mat != null and mat.albedo_texture != null:
			var q: Vector2 = (sm.mesh as QuadMesh).size
			var ratio_px: float = float(mat.albedo_texture.get_width()) / float(mat.albedo_texture.get_height())
			aspect_ok = aspect_ok and absf(ratio_px - q.x / q.y) < 0.02 and absf(float(mat.albedo_texture.get_height()) - q.y * OOTExteriorWorld.SIGN_PX_PER_M) < 1.0
	_check(all_ok, "each shop sign is a separate textured quad")
	_check(all_png, "each sign loads signs/<shop_id>.png")
	_check(aspect_ok, "each sign picture has the pixel size of its quad (300 px per metre)")
	var names: Dictionary = {}
	for sm2: MeshInstance3D in signs:
		names[str(sm2.get_meta("shop_name"))] = true
	_check(names.size() == signs.size(), "every shop has its own name")
	_check(FileAccess.file_exists("res://../docs/art/prompts-shop-signs.md") or FileAccess.file_exists(ProjectSettings.globalize_path("res://").path_join("../docs/art/prompts-shop-signs.md")),
		"docs/art/prompts-shop-signs.md exists")


func _test_parking(ext: OOTWindsorExterior) -> void:
	var cars: Array[Dictionary] = ext.world.parked_cars
	_check(cars.size() >= 20, "cars are parked along the kerbs (%d)" % cars.size())
	var bad_head: int = 0
	var bad_gap: int = 0
	var in_lane: int = 0
	var worst_gap: float = 0.0
	var best_gap: float = 9.0
	for c: Dictionary in cars:
		var n: Node3D = c["node"]
		var d: Vector3 = c["dims"]
		var face: Vector3 = c["face"]
		var fwd: Vector3 = n.global_basis.z
		fwd.y = 0.0
		if fwd.normalized().angle_to(face) > deg_to_rad(1.0):
			bad_head += 1
		var horiz: bool = c["horiz"]
		var inward: float = c["inward"]
		var lateral: float = (n.global_position.z - float(c["kerb"])) if horiz else (n.global_position.x - float(c["kerb"]))
		var gap: float = lateral * inward - d.x * 0.5
		worst_gap = maxf(worst_gap, gap)
		best_gap = minf(best_gap, gap)
		if absf(gap - OOTExteriorWorld.PARK_KERB_GAP) > 0.05:
			bad_gap += 1
		var far: float = lateral * inward + d.x * 0.5            # the far side's distance from the kerb
		if far > 5.4 - 2.0 and (horiz and absf(float(c["kerb"]) - 20.6) < 6.0) == true:
			in_lane += 1
	_check(bad_head == 0, "every parked car points along its kerb (%d off)" % bad_head)
	_check(bad_gap == 0, "every parked car is %.2f m from the kerb (gaps %.2f..%.2f m, %d off)" % [OOTExteriorWorld.PARK_KERB_GAP, best_gap, worst_gap, bad_gap])
	_check(in_lane == 0, "no parked car reaches into a traffic lane (%d)" % in_lane)
	# spacing: neighbours along a kerb never overlap
	var overlap: int = 0
	for i: int in cars.size():
		for j: int in range(i + 1, cars.size()):
			var a: Dictionary = cars[i]
			var b: Dictionary = cars[j]
			if a["horiz"] != b["horiz"] or absf(float(a["kerb"]) - float(b["kerb"])) > 0.1:
				continue
			var pa: Vector3 = (a["node"] as Node3D).global_position
			var pb: Vector3 = (b["node"] as Node3D).global_position
			var along: float = absf(pa.x - pb.x) if a["horiz"] else absf(pa.z - pb.z)
			if along < ((a["dims"] as Vector3).z + (b["dims"] as Vector3).z) * 0.5 + 0.3:
				overlap += 1
	_check(overlap == 0, "parked cars keep a gap between bumpers (%d overlaps)" % overlap)
	# none on a sidewalk or inside a crosswalk
	var on_walk: int = 0
	for c2: Dictionary in cars:
		var p: Vector3 = (c2["node"] as Node3D).global_position
		if p.y > -0.05:
			on_walk += 1
		if absf(p.z - 20.6) < 6.0 and p.x > 14.0 and p.x < 21.0:
			on_walk += 1
	_check(on_walk == 0, "no parked car stands on a sidewalk or crosswalk (%d)" % on_walk)
	# back lot: nose-in bays
	var lot: Node = ext.get_node_or_null("LotCars")
	var bays_ok: bool = lot != null
	if lot != null:
		for ch: Node in lot.get_children():
			var n3: Node3D = ch as Node3D
			if n3 == null or n3 is StaticBody3D:
				continue
			var k: float = (n3.global_position.x - (-0.8)) / OOTExteriorWorld.LOT_BAY_W
			bays_ok = bays_ok and absf(k - roundf(k)) < 0.05 and absf(n3.global_basis.z.dot(Vector3(0, 0, -1)) - 1.0) < 0.01
	_check(bays_ok, "back-lot cars stand in the middle of their marked bays, nose-in")
	_check(ext.world.find_child("BayLine_0", true, false) != null and ext.world.find_child("BayLine_5", true, false) != null, "the back lot has marked bays")


func _test_graffiti_alpha(ext: OOTWindsorExterior) -> void:
	var zs: Array[Vector2] = []
	for i: int in range(1, 5):
		var d: Decal = ext.find_child("Graffiti_%d" % i, true, false) as Decal
		_check(d != null and bool(d.get_meta("alpha_cut", false)), "Graffiti_%d uses the alpha cut-out graffiti_%d_alpha.png" % [i, i])
		if d == null or d.texture_albedo == null:
			continue
		var img: Image = d.texture_albedo.get_image()
		if img.is_compressed():
			img.decompress()
		var corner_clear: bool = img.get_pixel(2, 2).a < 0.05 and img.get_pixel(img.get_width() - 3, img.get_height() - 3).a < 0.05
		var paint: int = 0
		for y: int in range(0, img.get_height(), 8):
			for x: int in range(0, img.get_width(), 8):
				if img.get_pixel(x, y).a > 0.9:
					paint += 1
		_check(corner_clear and paint > 500, "graffiti_%d_alpha has a transparent border and solid paint (%d samples)" % [i, paint])
		# mural size: 1.5..3 m wide, on the wall (z -4.5..4.5), clear of the ground, never overlapping its neighbour
		var wide: float = d.size.x
		var high: float = d.size.z
		var z0: float = d.global_position.z - wide * 0.5
		var z1: float = d.global_position.z + wide * 0.5
		_check(wide >= 1.5 and wide <= 3.0 and high > 1.0 and high < 2.4 and z0 >= -4.5 and z1 <= 4.5 and d.global_position.y - high * 0.5 > 0.5,
			"graffiti_%d is a mural on the wall (%.1f x %.1f m)" % [i, wide, high])
		_check(d.size.y < 0.3 and absf(d.global_position.x - 8.6) < 0.05, "graffiti_%d is a thin decal on the alley wall face" % i)
		for o: Vector2 in zs:
			_check(z1 <= o.x + 0.01 or z0 >= o.y - 0.01, "graffiti_%d does not overlap another mural" % i)
		zs.append(Vector2(z0, z1))


func _test_roadworks_static(ext: OOTWindsorExterior) -> void:
	var cl: Array[OOTRoadworks] = ext.world.closures
	_check(cl.size() == OOTExteriorWorld.ROADWORKS.size() and cl.size() >= 5, "a road-works closure at each wrong turn (%d)" % cl.size())
	var route: PackedVector3Array = ext.world.route
	var min_route: float = INF
	for c: OOTRoadworks in cl:
		var kinds: Dictionary = {}
		for n: Node in c.get_children():
			if n.has_meta("rw_kind"):
				kinds[n.get_meta("rw_kind")] = int(kinds.get(n.get_meta("rw_kind"), 0)) + 1
		_check(int(kinds.get("barricade", 0)) >= 3 and int(kinds.get("cone", 0)) >= 5 and kinds.has("sign_road_closed") and kinds.has("sign_road_work") and kinds.has("drum"),
			"%s has barricades, cones, drums and both signs (%s)" % [c.closure_id, str(kinds)])
		var bs: Vector3 = ((c.blocker.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
		_check(maxf(bs.x, bs.z) >= c.half_width * 2.0 + 0.5 and bs.y >= 1.0, "%s blocks the whole road (%.1f m of collision)" % [c.closure_id, maxf(bs.x, bs.z)])
		var lamp_meshes: int = c.find_children("*Lamps*", "MeshInstance3D", true, false).size()
		_check(lamp_meshes >= 3, "%s has flashing amber lamps (%d)" % [c.closure_id, lamp_meshes])
		# the drive route never goes through (or near) a closure
		var box: AABB = AABB(c.global_position + Vector3(-bs.x * 0.5, 0.0, -bs.z * 0.5), bs)
		for p: Vector3 in route:
			var dx: float = maxf(maxf(box.position.x - p.x, 0.0), p.x - box.end.x)
			var dz: float = maxf(maxf(box.position.z - p.z, 0.0), p.z - box.end.z)
			min_route = minf(min_route, sqrt(dx * dx + dz * dz))
	_check(min_route > 3.0, "the intended route stays clear of every closure (%.1f m at the nearest)" % min_route)
	# every wrong turn at the junctions on the route is closed: the lot's right turn, the first cross street, straight on at the
	# second cross street, the boulevard to the right and straight on past it
	var ids: Array[String] = []
	for c2: OOTRoadworks in cl:
		ids.append(c2.closure_id)
	for want: String in ["rw_back_east", "rw_cross1_north", "rw_back_west", "rw_blvd_east", "rw_cross2_north"]:
		_check(ids.has(want), "closure %s exists" % want)


func _test_pedestrian_hooks(ext: OOTWindsorExterior) -> void:
	var spawns: Array[Marker3D] = ext.world.ped_spawns
	_check(spawns.size() >= 4 and spawns.size() <= 6, "pedestrian spawn points: %d Marker3D" % spawns.size())
	var routes: Array[Path3D] = ext.world.ped_routes
	var linked: bool = true
	var named: bool = true
	var long_enough: bool = true
	for m: Marker3D in spawns:
		named = named and String(m.name).begins_with("PedSpawn_")
		var rn: String = str(m.get_meta("route", ""))
		var path: Path3D = ext.world.find_child(rn, true, false) as Path3D
		linked = linked and path != null and m.global_position.distance_to(path.global_position + path.curve.get_point_position(0)) < 0.1
	for pth: Path3D in routes:
		named = named and String(pth.name).begins_with("PedRoute_")
		long_enough = long_enough and pth.curve.get_baked_length() > 2.0
	_check(named and linked, "each PedSpawn_* is at the start of its PedRoute_* path")
	_check(routes.size() >= 4 and long_enough and ext.get_tree().get_nodes_in_group(&"ped_route").size() >= 4, "sidewalk waypoint paths exist (%d)" % routes.size())
	var walking: int = 0
	var standing: int = 0
	for ped: Node3D in ext.world.pedestrians:
		if ped is OOTPedestrian:
			if (ped as OOTPedestrian).mode == OOTPedestrian.Mode.IDLE_WAIT:
				standing += 1
			else:
				walking += 1
	_check(walking + standing >= 6 and walking + standing <= 10 and standing >= 1, "pedestrians are spawned on the PedRoute_* paths (%d walking, %d at the bus stop)" % [walking, standing])
	for r: Path3D in routes:
		_check(String(r.name).begins_with("PedRoute_"), "route %s is named PedRoute_*" % r.name)
	_check(ext.world.find_child("Mannequin", true, false) == null and ext.world.find_child("person_a", true, false) == null, "the old mannequins are gone")


## Moves the pedestrians out of the way (they would block the test bodies and the traffic test).
func _park_peds(ext: OOTWindsorExterior) -> void:
	for p: Node3D in ext.world.pedestrians:
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.global_position = Vector3(500.0, 0.0, 500.0)
		p.remove_from_group(&"traffic_obstacle")


func _test_drivers(ext: OOTWindsorExterior) -> void:
	var with_driver: int = 0
	var posed: int = 0
	for c: OOTTrafficCar in ext.world.traffic:
		var d: Node3D = c.find_child("Driver", true, false) as Node3D
		if d != null:
			with_driver += 1
			var sk: Skeleton3D = d.find_child("Skeleton3D", true, false) as Skeleton3D
			var ap: AnimationPlayer = d.find_child("SitPose", true, false) as AnimationPlayer
			if sk != null and ap != null and ap.has_animation(&"sit_drive"):
				posed += 1
	_check(with_driver == ext.world.traffic.size(), "every moving car has a driver (%d of %d)" % [with_driver, ext.world.traffic.size()])
	_check(posed == with_driver, "the drivers are posed with Mani's sit_drive clip (%d)" % posed)
	var parked_drivers: int = 0
	for pc: Dictionary in ext.world.parked_cars:
		if (pc["node"] as Node3D).has_meta("driver"):
			parked_drivers += 1
	_check(parked_drivers >= 1, "a parked car has a driver waiting (%d)" % parked_drivers)


func _test_bench(ext: OOTWindsorExterior) -> void:
	var door: Vector3 = ext.main_door.global_position
	var worst: float = INF
	var n: int = 0
	for b: Node in ext.world.find_children("bench*", "Node3D", true, false):
		var bp: Vector3 = (b as Node3D).global_position
		n += 1
		worst = minf(worst, Vector2(bp.x - door.x, bp.z - door.z).length())
	for b2: Node in ext.world.find_children("Bench*", "Node3D", true, false):
		n += 1
		worst = minf(worst, Vector2((b2 as Node3D).global_position.x - door.x, (b2 as Node3D).global_position.z - door.z).length())
	_check(n >= 1 and worst > 8.0, "no bench blocks the main door (%d benches, nearest %.1f m)" % [n, worst])


## Mani can climb every kerb: a capsule is walked from the road onto the sidewalk (and verge) at many points.
func _test_kerbs(ext: OOTWindsorExterior) -> void:
	var body: CharacterBody3D = CharacterBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0.0, 0.875, 0.0)
	body.add_child(cs)
	root.add_child(body)
	ext.player.global_position = Vector3(300.0, 0.0, 300.0)
	# from (road point) to (sidewalk point)
	var legs: Array[Array] = [
		[Vector3(6.5, -0.1, 16.5), Vector3(6.5, 0.0, 13.3), "front street, north kerb"],
		[Vector3(-8.5, -0.1, 16.5), Vector3(-8.5, 0.0, 13.3), "front street, north kerb (bus stop)"],
		[Vector3(-17.0, -0.1, 24.8), Vector3(-17.0, 0.0, 27.8), "front street, south kerb"],
		[Vector3(22.0, -0.1, 24.8), Vector3(22.0, 0.0, 27.8), "front street, south kerb (east)"],
		[Vector3(17.5, -0.1, 16.5), Vector3(17.5, 0.0, 13.3), "at the crosswalk"],
		[Vector3(-60.0, -0.1, -24.5), Vector3(-60.0, 0.0, -27.3), "back street, north kerb"],
		[Vector3(-45.0, -0.1, -35.0), Vector3(-49.5, 0.0, -35.0), "first cross street, west kerb"],
		[Vector3(-45.0, -0.1, -35.0), Vector3(-40.5, 0.0, -35.0), "first cross street, east kerb"],
		[Vector3(-40.0, -0.1, -23.5), Vector3(-40.0, 0.0, -27.3), "junction corner"],
		[Vector3(-1.0, -0.12, -21.0), Vector3(-1.0, 0.0, -16.5), "the lot's drop kerb"],
	]
	var all_ok: bool = true
	for leg: Array in legs:
		var from: Vector3 = leg[0]
		var to: Vector3 = leg[1]
		body.global_position = from
		body.velocity = Vector3.ZERO
		await _wait_frames(8)
		var reached: bool = false
		var t: float = 0.0
		while t < 6.0:
			await physics_frame
			t += _dt()
			var d: Vector3 = to - body.global_position
			d.y = 0.0
			if d.length() < 0.35:
				reached = true
				break
			var v: Vector3 = d.normalized() * 1.4
			body.velocity.x = v.x
			body.velocity.z = v.z
			body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 * _dt()
			body.move_and_slide()
		_check(reached and body.global_position.y > -0.05, "kerb is walkable, road to sidewalk: %s (stopped at %s)" % [leg[2], str(body.global_position)])
		all_ok = all_ok and reached
	# and back down onto the road
	body.global_position = Vector3(6.5, 0.0, 13.3)
	await _wait_frames(8)
	var t2: float = 0.0
	while t2 < 6.0 and body.global_position.z < 17.0:
		await physics_frame
		t2 += _dt()
		body.velocity.x = 0.0
		body.velocity.z = 1.4
		body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 * _dt()
		body.move_and_slide()
	_check(body.global_position.z >= 17.0 and body.global_position.y < -0.05, "and he can step back down onto the road")
	body.queue_free()
	await _wait_frames(2)


## The amber lamps on the barricades flash.
func _test_lamps(ext: OOTWindsorExterior) -> void:
	var cl: OOTRoadworks = ext.world.closures[0]
	var seen_on: bool = false
	var seen_off: bool = false
	var t0: float = _sim()
	while _sim() - t0 < 1.6:
		await physics_frame
		await process_frame
		if cl.lamps_lit():
			seen_on = true
		else:
			seen_off = true
	_check(seen_on and seen_off, "the amber lamps flash (on and off within 1.6 s)")
	for f: String in ["horn_a_short", "horn_a_long", "horn_b_short", "horn_b_long", "brake_squeal"]:
		_check(FileAccess.file_exists("res://audio/sfx/exterior/%s.ogg" % f), "traffic sound %s exists" % f)


## Traffic yields: put Mani in a lane and watch the cars stop 4-6 m short, honk, queue and move off again.
func _test_traffic(ext: OOTWindsorExterior) -> void:
	var lane: OOTTrafficLane = ext.world.lanes[0]
	var cars: Array[OOTTrafficCar] = []
	for c: OOTTrafficCar in lane.cars:
		cars.append(c)
	cars.sort_custom(func(a: OOTTrafficCar, b: OOTTrafficCar) -> bool: return a.s > b.s)
	# the car with the longest free road ahead of it; Mani steps in 45 % of the way to the next car
	var lead: OOTTrafficCar = null
	var best_gap: float = 0.0
	for c2: OOTTrafficCar in cars:
		var nxt: OOTTrafficCar = lane.car_ahead(c2)
		var free: float = (nxt.s - c2.s) if nxt != null else (lane.length() - c2.s - 10.0)
		if free > best_gap and c2.s + free * 0.45 < lane.length() - 12.0:
			best_gap = free
			lead = c2
	_check(lead != null and cars.size() >= 4, "a lane of traffic with %d cars" % cars.size())
	if lead == null:
		return
	var player: Node3D = ext.player
	var spot: Vector3 = lane.pos_at(lead.s + best_gap * 0.45)
	spot.y = 0.0
	player.global_position = spot
	# watch every car pair and the player for the whole episode
	var min_gap_cars: float = INF
	var min_player: float = INF
	var behind: OOTTrafficCar = null
	for c3: OOTTrafficCar in cars:
		if c3.s < lead.s and (behind == null or c3.s > behind.s):
			behind = c3
	var stopped: bool = false
	var t0: float = _sim()
	while _sim() - t0 < 40.0:
		await physics_frame
		for a: OOTTrafficCar in lane.cars:
			var b: OOTTrafficCar = lane.car_ahead(a)
			if b != null:
				min_gap_cars = minf(min_gap_cars, (b.s - a.s) - (a.length + b.length) * 0.5)
			var dirv: Vector3 = lane.dir_at(a.s)
			var rel: Vector3 = player.global_position - a.global_position
			rel.y = 0.0
			if rel.dot(dirv) > 0.0:
				min_player = minf(min_player, rel.dot(dirv) - a.length * 0.5)
		player.global_position = spot
		if lead.speed < 0.05 and lead.state == &"stopped" and lead.honks_long >= 1 and behind != null and behind.speed < 0.05 and (behind.honks_short + behind.honks_long) >= 1:
			stopped = true
			break
	_check(lead.speed < 0.05, "the lead car stops for Mani (speed %.2f)" % lead.speed)
	var gap: float = (spot - lead.global_position).dot(lane.dir_at(lead.s)) - lead.length * 0.5
	_check(gap >= 4.0 and gap <= 6.5, "it stops %.1f m short of him (4-6 m)" % gap)
	_check(min_player >= 3.9, "no car came closer than %.1f m to him (front bumper)" % min_player)
	_check(lead.honks_short >= 1, "the lead car honked a short horn (%d)" % lead.honks_short)
	_check(lead.honks_long >= 1, "and a longer one when he stayed (%d)" % lead.honks_long)
	_check(behind != null and behind.speed < 0.05, "the car behind queues up")
	if behind != null:
		var qgap: float = (lead.s - behind.s) - (lead.length + behind.length) * 0.5
		_check(qgap >= 1.5 and qgap <= 4.5, "the queued car keeps a safe gap of %.1f m" % qgap)
		_check((behind.honks_short + behind.honks_long) >= 1, "the car behind honks too (%d short, %d long)" % [behind.honks_short, behind.honks_long])
	_check(min_gap_cars > 0.3, "cars never touch each other (closest gap %.2f m)" % min_gap_cars)
	_check(stopped, "the queue formed within 40 s")
	# he steps out of the lane: the queue moves off
	player.global_position = Vector3(spot.x, 0.0, 13.4)
	var moving: bool = await _until(func() -> bool: return lead.speed > 2.0, 12.0)
	_check(moving, "the lead car moves off when the way is clear (%.1f m/s)" % lead.speed)
	await _wait_frames(240)
	_check(behind != null and behind.speed > 1.0, "and so does the queue (%.1f m/s)" % (behind.speed if behind != null else 0.0))
	# somebody steps out right in front of a moving car: it stops without touching him
	var runner: OOTTrafficCar = null
	for c4: OOTTrafficCar in ext.world.lanes[1].cars:
		if c4.speed > 4.0 and c4.s < ext.world.lanes[1].length() - 60.0:
			runner = c4
			break
	if runner != null:
		var lane2: OOTTrafficLane = ext.world.lanes[1]
		var p2: Vector3 = lane2.pos_at(runner.s + 12.0)
		p2.y = 0.0
		player.global_position = p2
		var closest: float = INF
		var t1: float = _sim()
		while _sim() - t1 < 8.0:
			await physics_frame
			var rel2: Vector3 = p2 - runner.global_position
			rel2.y = 0.0
			closest = minf(closest, rel2.dot(lane2.dir_at(runner.s)) - runner.length * 0.5)
			player.global_position = p2
		_check(closest > 0.4 and runner.speed < 0.2, "a car that was moving stops without touching somebody who steps out (%.1f m left)" % closest)
	player.global_position = Vector3(300.0, 0.0, 300.0)
	await _wait_frames(4)


## The real sedan, driven at a closure, is stopped by it (a few wrong turns).
func _test_roadworks_block_car(ext: OOTWindsorExterior) -> void:
	ext.car.auto_cruise = false
	ext.car.use_player_input = false
	var cases: Array[Dictionary] = [
		{"id": "rw_back_east", "from": Vector3(1.0, 0.0, -20.3), "yaw": PI / 2.0, "axis": 0, "limit": 12.0 - 2.4, "sign": 1.0},
		{"id": "rw_cross1_north", "from": Vector3(-45.0, 0.0, -22.5), "yaw": PI, "axis": 2, "limit": -29.0 + 2.4, "sign": -1.0},
	]
	for cs: Dictionary in cases:
		var cl: OOTRoadworks = null
		for c: OOTRoadworks in ext.world.closures:
			if c.closure_id == cs["id"]:
				cl = c
		var from: Vector3 = cs["from"]
		ext.car.global_transform = Transform3D(Basis(Vector3.UP, float(cs["yaw"])), Vector3(from.x, -0.05, from.z))
		ext.car.linear_velocity = Vector3.ZERO
		ext.car.angular_velocity = Vector3.ZERO
		await _wait_frames(20)
		ext.car.set_ai_inputs(1.0, 0.0, 0.0)
		var t0: float = _sim()
		var farthest: float = -INF
		while _sim() - t0 < 9.0:
			await physics_frame
			var p: Vector3 = ext.car.global_position
			var along: float = p.x if int(cs["axis"]) == 0 else p.z
			farthest = maxf(farthest, along * float(cs["sign"]))
		ext.car.clear_ai_inputs()
		_check(cl != null and farthest < float(cs["limit"]) * float(cs["sign"]) + 0.6,
			"the sedan driven into %s is stopped by the barricades (got to %.1f, barrier line at %.1f)" % [cs["id"], farthest * float(cs["sign"]), (cl.global_position.x if int(cs["axis"]) == 0 else cl.global_position.z) if cl != null else 0.0])
	ext.car.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-0.8, 0.05, -10.5))
	ext.car.linear_velocity = Vector3.ZERO


## Leaving the apartment hands the duffel and the keys flag to the exterior.
func _test_episode_wiring() -> void:
	StoryState.start_part("p1")
	var ep: OOTEpisode01 = OOTEpisode01.new()
	root.add_child(ep)
	await process_frame
	ep.stage = "cold_open"  # the apartment now follows the opening montage, not the title card
	ep._start_apartment()
	await process_frame
	var apt: OOTApartment = ep.apartment
	_check(apt != null, "the episode flow starts the apartment")
	if apt == null:
		return
	apt.take_car_keys()
	apt.duffel_ready = true
	apt.duffel.kind = OOTInteractable.Kind.PICKUP
	apt.duffel.set_meta("carry_two_hand", true)
	apt.player.interactor.carried = apt.duffel
	apt.player.interactor.carried_changed.emit(apt.duffel)
	var bag: OOTInteractable = apt.duffel
	apt._on_exit_door_used()
	await create_timer(1.6).timeout
	_check(ep.exterior != null, "leaving the apartment loads the building exterior")
	if ep.exterior != null:
		_check(ep.exterior.duffel == bag and ep.exterior.player.interactor.carried == bag, "the duffel goes out with Mani")
		_check(ep.stage == "exterior" and StoryState.has_flag("has_car_keys"), "the keys flag is preserved")
		var reached: Array[bool] = [false]
		ep.flow_finished.connect(func() -> void: reached[0] = true)
		ep.exterior.drive_reached_county_road.emit()
		await process_frame
		_check(ep.stage == "title" and ep._card_title.text == ep.title_text(), "after the drive the episode title card shows")
		await create_timer(OOTEpisode01.TITLE_SECONDS + 0.5).timeout
		_check(reached[0] and ep.stage == "end", "after the title card the episode falls back to the end card")
	ep.queue_free()
	await process_frame
