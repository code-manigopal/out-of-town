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
	await _test_walkable(ext)
	await _test_arrows(ext)
	await _test_trunk_and_car(ext)
	await _test_drive_and_fade(ext)
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
	var shops: int = 0
	for n2: Node in ext.world.find_children("ShopSign_*", "Label3D", true, false):
		shops += 1
	_check(shops >= 6, "shops across the street have signs (%d)" % shops)
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


## Leaving the apartment hands the duffel and the keys flag to the exterior.
func _test_episode_wiring() -> void:
	StoryState.start_part("p1")
	var ep: OOTEpisode01 = OOTEpisode01.new()
	root.add_child(ep)
	await process_frame
	ep.stage = "title"
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
		_check(reached[0] and ep.stage == "end", "after the drive the episode falls back to the end card")
	ep.queue_free()
	await process_frame
