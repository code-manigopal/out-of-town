extends SceneTree
## Mani's grey sedan: API, model parts, ride height, steering wheel, brake lights, cameras and the seat fit. Run:
##   godot --headless --path game --script res://tests/run_vehicle_tests.gd
## Exits with code 1 on any failure. The model tests are skipped when the .glb files are Git LFS pointers (CI).

const CAR_SCENE: String = "res://scenes/vehicles/sedan.tscn"
const MODEL: String = "res://vehicles/sedan/sedan.glb"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const EXTERIOR_SCRIPT: String = "res://scripts/episodes/e1/windsor_exterior.gd"
const TRI_BUDGET: int = 60000

var StoryState: Node
var _failures: int = 0
var _checks: int = 0


static func lfs_assets_present() -> bool:
	for path: String in [MODEL, "res://characters/mani/mani.glb"]:
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
	_test_api()
	if lfs_assets_present():
		await _test_model()
		await _test_ride_and_steering()
		await _test_lamps()
		await _test_cruise_corner()
		await _test_cameras()
		await _test_seat_fit()
	else:
		print("SKIPPED vehicle model tests: Git LFS assets are not checked out (CI).")
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- API (no assets needed) ----------------------------------------------------------------

func _test_api() -> void:
	var cs: GDScript = load("res://scripts/vehicle/oot_car.gd") as GDScript
	_check(cs != null, "oot_car.gd loads")
	var names: Dictionary = {}
	for m: Dictionary in cs.get_script_method_list():
		names[m["name"]] = "method"
	for p: Dictionary in cs.get_script_property_list():
		names[p["name"]] = "property"
	for s: Dictionary in cs.get_script_signal_list():
		names[s["name"]] = "signal"
	for c: String in cs.get_script_constant_map():
		names[c] = "constant"
	var needed: Array[String] = [
		"open_trunk", "close_trunk", "open_door", "close_door", "snap_door", "snap_trunk", "is_trunk_open", "is_door_open",
		"start_engine", "stop_engine", "set_auto_cruise", "set_ai_inputs", "clear_ai_inputs", "set_dash_camera",
		"activate_chase_camera", "deactivate_chase_camera", "use_interior_camera", "use_chase_camera", "toggle_camera",
		"is_interior_camera", "is_dash_camera", "get_forward_speed", "get_heading", "get_speed_kmh", "park", "is_parked",
		"set_dash_lights", "set_headlights", "get_taillight_energy", "get_steering_wheel_angle", "steer_limit",
		"ignition", "trunk_use", "door_use", "seat_anchor", "trunk_cargo", "use_player_input", "chase_cam", "starting",
		"engine_on", "route", "auto_cruise", "play_audio", "SEAT_ANCHOR_POS", "SEAT_ANCHOR_PITCH_DEG", "REAR_Z",
		"TRUNK_CARGO_POS", "EYE_POS", "STEER_HUB", "STEER_AXIS", "engine_started", "engine_stopped", "trunk_changed",
		"door_changed", "camera_changed", "door", "trunk_lid", "steering_wheel"]
	var missing: Array[String] = []
	for n: String in needed:
		if not names.has(n):
			missing.append(n)
	_check(missing.is_empty(), "OOTCar has every required member (missing: %s)" % str(missing))
	# every `car.xxx` / `OOTCar.XXX` member windsor_exterior.gd uses must exist
	var f: FileAccess = FileAccess.open(EXTERIOR_SCRIPT, FileAccess.READ)
	if f == null:
		_check(false, "windsor_exterior.gd readable")
		return
	var src: String = f.get_as_text()
	var used: Dictionary = {}
	var rx: RegEx = RegEx.new()
	rx.compile("\\b(?:car|OOTCar)\\.([A-Za-z_][A-Za-z0-9_]*)")
	for m: RegExMatch in rx.search_all(src):
		used[m.get_string(1)] = true
	var absent: Array[String] = []
	var base_names: Dictionary = {"global_transform": 1, "global_position": 1, "global_basis": 1, "to_global": 1, "to_local": 1,
		"add_child": 1, "position": 1, "route": 1, "name": 1, "visible": 1}
	for u: String in used:
		if not names.has(u) and not base_names.has(u) and not ClassDB.class_has_method("VehicleBody3D", u) \
				and not ClassDB.class_has_method("Node3D", u) and not ClassDB.class_has_method("Node", u):
			absent.append(u)
	_check(absent.is_empty(), "every car member windsor_exterior.gd uses exists (%d used; absent: %s)" % [used.size(), str(absent)])


# --- model ---------------------------------------------------------------------------------

func _count_tris(root_node: Node) -> int:
	var tris: int = 0
	for n: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				tris += (idx as PackedInt32Array).size() / 3
			else:
				tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


func _union_aabb(node: Node3D, only_meshes: Array[String]) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		if not only_meshes.is_empty() and not only_meshes.has(String(mi.name)):
			continue
		var b: AABB = node.global_transform.affine_inverse() * (mi.global_transform * mi.get_aabb())
		box = b if first else box.merge(b)
		first = false
	return box


func _test_model() -> void:
	var m: Node3D = (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(m)
	await process_frame
	var parts: Array[String] = ["Body", "DriverDoor", "TrunkLid", "SteeringWheel", "Dash", "DashLights", "DashScreen", "Seats",
		"Headlights", "Taillights", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR", "InteriorTrim", "EngineBay", "Underbody"]
	var missing: Array[String] = []
	for p: String in parts:
		if m.find_child(p, true, false) == null:
			missing.append(p)
	_check(missing.is_empty(), "the model has every named part (missing: %s)" % str(missing))
	var tris: int = _count_tris(m)
	_check(tris > 15000 and tris <= TRI_BUDGET, "hero car is %d triangles (budget %d)" % [tris, TRI_BUDGET])
	var body: AABB = _union_aabb(m, ["Body", "Wheel_FL", "Wheel_RR"])
	var half_w: float = 0.0
	var roof_y: float = 0.0
	var bm: MeshInstance3D = m.find_child("Body", true, false) as MeshInstance3D
	for s: int in bm.mesh.get_surface_count():
		for v: Vector3 in (bm.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.y > 0.3 and v.y < 0.9 and absf(v.z) < 1.2:
				half_w = maxf(half_w, absf(v.x))
			if not (absf(v.x) < 0.03 and v.z > -1.0 and v.z < -0.8 and v.y > 1.48):          # skip the antenna fin
				roof_y = maxf(roof_y, v.y)
	_check(absf(body.size.z - 4.85) < 0.12 and absf(half_w * 2.0 - 1.85) < 0.06 and absf(roof_y - 1.46) < 0.03,
		"car is %.2f long, %.2f wide (mirrors excluded) and %.2f high (about 4.85 x 1.85 x 1.45)" % [body.size.z, half_w * 2.0, roof_y])
	var fl: Node3D = m.find_child("Wheel_FL", true, false) as Node3D
	var rl: Node3D = m.find_child("Wheel_RL", true, false) as Node3D
	var fr: Node3D = m.find_child("Wheel_FR", true, false) as Node3D
	_check(absf((fl.position.z - rl.position.z) - 2.83) < 0.02, "wheelbase is %.2f m (2.83)" % (fl.position.z - rl.position.z))
	_check(fl.position.x > 0.0 and fr.position.x < 0.0 and absf(fl.position.y - 0.334) < 0.01, "front wheels: hub height %.3f, left is +X" % fl.position.y)
	var door: Node3D = m.find_child("DriverDoor", true, false) as Node3D
	var lid: Node3D = m.find_child("TrunkLid", true, false) as Node3D
	_check(door.position.x > 0.85 and absf(door.position.z - 0.80) < 0.05, "door hinge origin at the front edge (%s)" % str(door.position))
	_check(lid.position.z < -1.5 and lid.position.y > 0.9 and absf(lid.position.x) < 0.01, "trunk hinge origin at the deck front edge (%s)" % str(lid.position))
	var wheel_aabb: AABB = _union_aabb(m, ["Wheel_FL"])
	_check(wheel_aabb.size.y > 0.62 and wheel_aabb.size.y < 0.72 and wheel_aabb.size.x > 0.2, "tyre + rim are %.2f m tall" % wheel_aabb.size.y)
	# materials: paint is grey, glass is transparent, lamp elements exist
	var mats: Dictionary = {}
	for n: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat != null:
				mats[mat.resource_name] = mat
	var paint: StandardMaterial3D = mats.get("CarPaint") as StandardMaterial3D
	_check(paint != null and absf(paint.albedo_color.r - paint.albedo_color.b) < 0.1 and paint.albedo_color.r < 0.7, "CarPaint is a grey metallic")
	var glass: StandardMaterial3D = mats.get("Glass") as StandardMaterial3D
	_check(glass != null and glass.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and glass.albedo_color.a < 0.6, "glass is transparent")
	for n: String in ["TailLamp", "Indicator", "Reverse", "TailLens", "Headlight", "HeadLens", "Plate", "PlateInk", "Rim", "Tire", "Chrome", "Screen", "DashLight"]:
		_check(mats.has(n), "material %s is in the model" % n)
	var tl: MeshInstance3D = m.find_child("Taillights", true, false) as MeshInstance3D
	_check(tl != null and tl.mesh.get_surface_count() >= 4, "tail light clusters have lens, lamp, indicator and reverse surfaces (%d)" % tl.mesh.get_surface_count())
	m.queue_free()
	await process_frame
	# the traffic variants: light, translucent glass over a cabin so a driver shows through the windows
	for t: String in ["traffic_sedan", "traffic_hatchback", "traffic_suv"]:
		var tm: Node3D = (load("res://vehicles/sedan/%s.glb" % t) as PackedScene).instantiate() as Node3D
		root.add_child(tm)
		await process_frame
		var tt: int = _count_tris(tm)
		var ta: AABB = _union_aabb(tm, [])
		var gl: StandardMaterial3D = null
		for n: Node in tm.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			for s: int in mi.mesh.get_surface_count():
				var mat: StandardMaterial3D = mi.mesh.surface_get_material(s) as StandardMaterial3D
				if mat != null and mat.resource_name == "GlassTraffic":
					gl = mat
		_check(tt > 8000 and tt < 30000 and ta.size.z > 4.0 and ta.size.z < 5.0 and ta.size.x > 1.7 and ta.size.x < 2.0,
			"%s is %d triangles, %.2f x %.2f x %.2f m" % [t, tt, ta.size.z, ta.size.x, ta.size.y])
		_check(gl != null and gl.albedo_color.a < 0.6, "%s has translucent glass (a driver shows through)" % t)
		tm.queue_free()
		await process_frame


# --- physics: ride height, steering ---------------------------------------------------------

func _floor() -> StaticBody3D:
	var fl: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = Vector3(800, 1, 800)
	cs.shape = bx
	fl.add_child(cs)
	fl.position.y = -0.5
	root.add_child(fl)
	return fl


func _new_car() -> OOTCar:
	var car: OOTCar = (load(CAR_SCENE) as PackedScene).instantiate() as OOTCar
	car.play_audio = false
	root.add_child(car)
	return car


func _test_ride_and_steering() -> void:
	var fl: StaticBody3D = _floor()
	var car: OOTCar = _new_car()
	await process_frame
	car.global_position = Vector3(0, 0.0, 0)
	for i: int in 5:
		await physics_frame
	var parked_hub: float = (car.wheels[0].get_child(0) as Node3D).global_position.y
	_check(car.is_parked() and absf(parked_hub - 0.334) < 0.01, "a parked (frozen) car stands on its tyres (wheel centre %.3f m)" % parked_hub)
	car.global_position = Vector3(0, 0.06, 0)
	await process_frame
	car.park(false)
	for i: int in 200:
		await physics_frame
	var hub: float = (car.wheels[0].get_child(0) as Node3D).global_position.y
	_check(absf(hub - 0.334) < 0.012 and absf(car.global_position.y) < 0.02,
		"soft suspension lands at ride height (wheel centre %.3f m, body %.3f m)" % [hub, car.global_position.y])
	_check(car.spring_stiffness < 80.0 and car.damp_compression > 0.8, "suspension is a comfort setup (stiffness %.0f)" % car.spring_stiffness)
	# a 6 cm drop settles within a second
	car.global_position = Vector3(0, 0.10, 0)
	car.linear_velocity = Vector3.ZERO
	var last_move: int = -1
	var prev: float = car.global_position.y
	for i: int in 150:
		await physics_frame
		if absf(car.global_position.y - 0.0) > 0.004:
			last_move = i
	_check(last_move < 100, "a 10 cm drop settles within %.1f s" % (float(last_move) / 60.0))
	# steering limit falls with speed
	_check(car.steer_limit(1.0) > 0.45 and car.steer_limit(12.0) < 0.18 and car.steer_limit(12.0) >= car.steer_min,
		"steering angle falls with speed (%.2f rad parked, %.2f at 12 m/s)" % [car.steer_limit(1.0), car.steer_limit(12.0)])
	# the steering wheel turns with input, left = counter-clockwise seen from the driver
	car.engine_on = true
	car.set_ai_inputs(0.0, 1.0, 0.0)
	var base: Basis = car.steering_wheel.transform.basis
	for i: int in 90:
		await physics_frame
	var ang_left: float = car.get_steering_wheel_angle()
	var turned: Basis = car.steering_wheel.transform.basis
	var q: Quaternion = (base.inverse() * turned).get_rotation_quaternion()
	var axis_local: Vector3 = base.inverse() * OOTCar.STEER_AXIS
	var measured: float = q.get_angle() * signf(q.get_axis().dot(axis_local))
	_check(ang_left > 1.5, "full left lock turns the wheel %.0f degrees" % rad_to_deg(ang_left))
	_check(absf(wrapf(measured - ang_left, -PI, PI)) < 0.05, "the mesh rotates by that angle about the tilted column axis (%.2f vs %.2f rad)" % [measured, ang_left])
	_check(car.steering > 0.1, "road wheels steer left (steering %.2f)" % car.steering)
	car.set_ai_inputs(0.0, -1.0, 0.0)
	for i: int in 150:
		await physics_frame
	_check(car.get_steering_wheel_angle() < -1.5, "full right lock turns it the other way (%.0f degrees)" % rad_to_deg(car.get_steering_wheel_angle()))
	car.set_ai_inputs(0.0, 0.0, 0.0)
	for i: int in 150:
		await physics_frame
	_check(absf(car.get_steering_wheel_angle()) < 0.05, "the wheel returns to centre")
	car.queue_free()
	fl.queue_free()
	await process_frame


# --- auto-cruise through the first bend of the Windsor route (steering limit + corner speed) ----------------

func _test_cruise_corner() -> void:
	var fl: StaticBody3D = _floor()
	var car: OOTCar = _new_car()
	await process_frame
	car.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-0.8, 0.02, -10.5))
	await process_frame
	car.route = OOTExteriorWorld.make_route(OOTExteriorWorld.ROUTE_CORNERS, OOTExteriorWorld.ROUTE_FILLET)
	car.engine_on = true
	car.park(false)
	car.set_auto_cruise(true, 9.0)
	var turned: bool = false
	var max_dev: float = 0.0
	var top: float = 0.0
	for i: int in 60 * 9:
		await physics_frame
		var p: Vector3 = car.global_position
		var best: float = INF
		for q: Vector3 in car.route:
			best = minf(best, Vector2(q.x - p.x, q.z - p.z).length())
		max_dev = maxf(max_dev, best)
		top = maxf(top, car.linear_velocity.length())
		if p.x < -20.0 and absf(p.z + 23.7) < 2.5:
			turned = true
			break
	_check(turned, "auto-cruise follows the route out of the lot and round the first left bend")
	_check(max_dev < 2.0, "it stays within 2 m of the route centre line through the gate and the bend (%.2f m, peak %.1f m/s)" % [max_dev, top])
	_check(car.steer_limit(top) < car.steer_max, "the steering limit has come down with speed (%.2f rad at %.1f m/s)" % [car.steer_limit(top), top])
	car.queue_free()
	fl.queue_free()
	await process_frame


# --- lamps ----------------------------------------------------------------------------------

func _test_lamps() -> void:
	var fl: StaticBody3D = _floor()
	var car: OOTCar = _new_car()
	await process_frame
	var paint_ok: bool = false
	for n: Node in car.model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var pm: StandardMaterial3D = mi.mesh.surface_get_material(s) as StandardMaterial3D
			if pm != null and pm.resource_name == "CarPaint" and pm.clearcoat_enabled:
				paint_ok = true
	_check(paint_ok, "the paint has a clear coat")
	var lamp: StandardMaterial3D = car._mats.get("TailLamp") as StandardMaterial3D
	_check(lamp != null, "the car owns a copy of the tail lamp material")
	car.engine_on = true
	car.park(false)
	car.set_ai_inputs(0.0, 0.0, 0.0)
	for i: int in 30:
		await physics_frame
	var tail: float = car.get_taillight_energy()
	_check(tail > 0.5, "tail lights are on with the engine (%.1f)" % tail)
	car.set_ai_inputs(0.0, 0.0, 1.0)
	for i: int in 10:
		await physics_frame
	var braking: float = car.get_taillight_energy()
	_check(braking > tail * 2.5 and lamp.emission_energy_multiplier > tail * 2.5,
		"brake lights brighten under the pedal (%.1f -> %.1f, material %.1f)" % [tail, braking, lamp.emission_energy_multiplier])
	car.set_ai_inputs(0.0, 0.0, 0.0)
	for i: int in 10:
		await physics_frame
	_check(car.get_taillight_energy() < braking * 0.5, "they dim again when the pedal is released")
	car.set_ai_inputs(-1.0, 0.0, 0.0)
	for i: int in 20:
		await physics_frame
	var rev: StandardMaterial3D = car._mats.get("Reverse") as StandardMaterial3D
	_check(rev != null and rev.emission_energy_multiplier > 1.0, "the white reverse lamps light in reverse")
	car.stop_engine()
	_check(car.get_taillight_energy() < 0.01, "everything is dark with the engine off")
	car.set_headlights(true)
	_check((car._mats.get("Headlight") as StandardMaterial3D).emission_energy_multiplier > 1.0, "headlights switch on")
	car.queue_free()
	fl.queue_free()
	await process_frame


# --- cameras --------------------------------------------------------------------------------

func _test_cameras() -> void:
	var fl: StaticBody3D = _floor()
	var car: OOTCar = _new_car()
	await process_frame
	car.global_transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(3.0, 0.02, -4.0))
	await process_frame
	car.engine_on = true
	car.activate_chase_camera()
	for i: int in 5:
		await process_frame
	_check(root.get_viewport().get_camera_3d() == car.chase_cam, "the car's camera is current after activate_chase_camera()")
	_check(car.is_interior_camera() and car.cam_mode == OOTCar.CamMode.INTERIOR, "the default view is the driver's-eye interior camera")
	var eye_err: float = car.to_local(car.chase_cam.global_position).distance_to(OOTCar.EYE_POS)
	_check(eye_err < 0.12, "the interior camera sits at the driver's head (%.2f m from the eye point)" % eye_err)
	var fwd: Vector3 = -car.chase_cam.global_basis.z
	_check(fwd.dot(car.global_basis.z) > 0.97, "it looks along the car's heading (dot %.3f)" % fwd.dot(car.global_basis.z))
	_check(car.chase_cam.cull_mask & 2 == 0, "Mani's head layer is hidden from the interior camera")
	var cam_changes: Array[int] = []
	car.camera_changed.connect(func(m: int) -> void: cam_changes.append(m))
	car.toggle_camera()
	for i: int in 5:
		await process_frame
	var d: float = car.chase_cam.global_position.distance_to(car.global_position)
	_check(not car.is_interior_camera() and d > 4.0 and d < 9.0, "toggle_camera() switches to the chase camera (%.1f m behind)" % d)
	_check(car.chase_cam.cull_mask & 2 != 0, "the chase camera sees the whole character")
	car.toggle_camera()
	for i: int in 5:
		await process_frame
	_check(car.is_interior_camera() and car.to_local(car.chase_cam.global_position).distance_to(OOTCar.EYE_POS) < 0.12, "toggling again returns to the interior view")
	car.use_chase_camera()
	_check(car.cam_mode == OOTCar.CamMode.CHASE, "use_chase_camera()")
	car.use_interior_camera()
	_check(car.cam_mode == OOTCar.CamMode.INTERIOR and cam_changes.size() >= 3, "use_interior_camera() (camera_changed fired %d times)" % cam_changes.size())
	# the C key toggles it too
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_C
	ev.pressed = true
	car._unhandled_input(ev)
	_check(car.cam_mode == OOTCar.CamMode.CHASE, "key C toggles the camera")
	car._unhandled_input(ev)
	_check(car.cam_mode == OOTCar.CamMode.INTERIOR, "key C toggles it back")
	# dash close-up for the radio
	car.set_dash_camera(true)
	for i: int in 90:
		await process_frame
	var dash_err: float = car.to_local(car.chase_cam.global_position).distance_to(OOTCar.DASH_CAM_POS)
	var target_dir: Vector3 = (car.to_global(OOTCar.DASH_CAM_TARGET) - car.chase_cam.global_position).normalized()
	_check(dash_err < 0.05 and (-car.chase_cam.global_basis.z).dot(target_dir) > 0.99,
		"set_dash_camera(true) frames the dash / radio (%.3f m off, looking at the centre stack)" % dash_err)
	car.set_dash_camera(false)
	for i: int in 120:
		await process_frame
	_check(car.to_local(car.chase_cam.global_position).distance_to(OOTCar.EYE_POS) < 0.12, "set_dash_camera(false) goes back to the driver's view")
	car.queue_free()
	fl.queue_free()
	await process_frame


# --- seat fit (A4 / A5) ---------------------------------------------------------------------

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF)
	return root.get_world_3d().direct_space_state.intersect_ray(q)


func _test_seat_fit() -> void:
	if StoryState != null:
		StoryState.start_part("p1")
	# the bare model (no vehicle physics) so the rays only meet the visible cabin
	var model: Node3D = (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	for nm: String in ["Body", "Seats", "InteriorTrim", "Dash"]:
		var mi: MeshInstance3D = model.find_child(nm, true, false) as MeshInstance3D
		mi.create_trimesh_collision()
	var anchor: Marker3D = Marker3D.new()
	anchor.position = OOTCar.SEAT_ANCHOR_POS
	anchor.rotation.x = -deg_to_rad(OOTCar.SEAT_ANCHOR_PITCH_DEG)
	model.add_child(anchor)
	var p: OOTPlayer = (load(PLAYER_SCENE) as PackedScene).instantiate() as OOTPlayer
	root.add_child(p)
	await process_frame
	p.lock_input()
	p.set_pose_override(&"sit_drive", 0.0)
	p.velocity = Vector3.ZERO
	p.collision_layer = 0
	p.collision_mask = 0
	p.set_physics_process(false)
	p.get_parent().remove_child(p)
	anchor.add_child(p)
	p.transform = Transform3D.IDENTITY
	p.body.rotation.y = PI
	p.body.position = Vector3.ZERO
	for i: int in 20:
		await physics_frame
	var sk: Skeleton3D = p.skeleton
	var bone: Callable = func(n: String) -> Vector3:
		return model.to_local((sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n))).origin)
	var pelvis: Vector3 = bone.call("pelvis")
	var hit: Dictionary = _ray(pelvis, pelvis + Vector3.DOWN * 0.6)
	var seat_gap: float = pelvis.y - ((hit["position"] as Vector3).y if not hit.is_empty() else -1.0)
	_check(not hit.is_empty() and seat_gap > 0.05 and seat_gap < 0.14,
		"hips sit on the cushion: pelvis is %.3f m above the seat surface (0.05..0.14)" % seat_gap)
	# feet: the sole is about 0.075 m under the ankle bone and must not be under the floor or pedals
	var worst: float = 9.0
	var best: float = 9.0
	for side: String in ["foot_l", "foot_r"]:
		var ank: Vector3 = bone.call(side)
		var h: Dictionary = _ray(ank + Vector3(0, 0.0, -0.02), ank + Vector3(0, -0.6, -0.02))
		var gap: float = ank.y - ((h["position"] as Vector3).y if not h.is_empty() else -1.0)
		worst = minf(worst, gap)
		best = minf(best, absf(gap - 0.075))
	_check(worst > 0.04, "feet are above the floor, not below it (ankle clearance %.3f m, sole about 0.075)" % worst)
	var ball: Vector3 = bone.call("ball_l")
	var hb: Dictionary = _ray(ball, ball + Vector3.DOWN * 0.5)
	var ball_gap: float = ball.y - ((hb["position"] as Vector3).y if not hb.is_empty() else -1.0)
	_check(ball_gap > 0.0 and ball_gap < 0.12, "toes are near the floor (%.3f m)" % ball_gap)
	var head: Vector3 = bone.call("head") + Vector3(0, 0.19, 0)
	var hr: Dictionary = _ray(head - Vector3(0, 0.05, 0), head + Vector3(0, 0.5, 0))
	var roof_gap: float = ((hr["position"] as Vector3).y if not hr.is_empty() else 9.0) - head.y
	_check(not hr.is_empty() and roof_gap > 0.01, "head clears the roof lining by %.3f m" % roof_gap)
	# hands vs the steering wheel rim (the pose's hands are fixed: report the offset)
	var hub: Vector3 = OOTCar.STEER_HUB
	var axis: Vector3 = OOTCar.STEER_AXIS
	var offs: Array[float] = []
	for side: String in ["hand_l", "hand_r"]:
		var hp: Vector3 = bone.call(side)
		var rel: Vector3 = hp - hub
		var in_plane: Vector3 = rel - axis * rel.dot(axis)
		var on_rim: Vector3 = hub + in_plane.normalized() * 0.19
		offs.append(hp.distance_to(on_rim))
	print("info hand (wrist) distance to the rim: left %.3f m, right %.3f m" % [offs[0], offs[1]])
	_check(offs[0] < 0.12 and offs[1] < 0.12, "wrists are within 12 cm of the wheel rim")
	# trunk floor holds the duffel
	var cargo: Vector3 = OOTCar.TRUNK_CARGO_POS
	var ht: Dictionary = _ray(cargo + Vector3(0, 0.4, 0), cargo + Vector3(0, -0.4, 0))
	_check(not ht.is_empty() and absf((ht["position"] as Vector3).y - cargo.y) < 0.03, "the trunk floor is at the duffel's resting height")
	p.queue_free()
	model.queue_free()
	await process_frame
