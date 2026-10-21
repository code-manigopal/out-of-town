extends SceneTree
## Interactive-apartment tests (doors, taps, flush, mirror, fridge, keys, exit door). Run:
##   godot --headless --path game --script res://tests/run_apartment_tests.gd
## Exits with code 1 on any failure. Scene tests are skipped when the .glb models are Git LFS pointers (CI).

var StoryState: Node
var _failures: int = 0
var _checks: int = 0
var _exit_signals: int = 0


static func lfs_assets_present() -> bool:
	var f: FileAccess = FileAccess.open("res://characters/mani/mani.glb", FileAccess.READ)
	if f == null:
		return false
	return not f.get_buffer(24).get_string_from_ascii().begins_with("version https://git-lfs")


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
	await _test_door_unit()
	if lfs_assets_present():
		await _test_scene()
	else:
		print("SKIPPED apartment scene tests: Git LFS assets are not checked out (CI).")
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _capsule_hits(space: PhysicsDirectSpaceState3D, p: Vector3) -> int:
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), Vector3(p.x, 0.12 + 0.85, p.z))
	return space.intersect_shape(q, 8).size()


func _wait_door(d: OOTDoor) -> void:
	var n: int = 0
	while d.is_moving() and n < 120:
		await process_frame
		n += 1
	await physics_frame
	await physics_frame


# --- OOTDoor on its own (no models needed) --------------------------------------------

func _test_door_unit() -> void:
	var hinge: OOTDoor = OOTDoor.new()
	hinge.display_name = "test door"
	hinge.duration = 0.1
	hinge.open_angle_deg = 90.0
	hinge.body_center = Vector3(0.45, 1.0, 0.0)
	hinge.body_size = Vector3(0.9, 2.0, 0.05)
	hinge.position = Vector3(10, 0, 10)
	root.add_child(hinge)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = (root as Viewport).world_3d.direct_space_state
	# Closed leaf spans x 10..10.9 at z 10. A capsule centred in the doorway (10.45, 10) is blocked.
	_check(not hinge.is_open(), "door starts closed")
	_check(hinge.interactable != null and hinge.interactable.kind == OOTInteractable.Kind.USE, "door has a USE interactable")
	_check(hinge.interactable.get_prompt() == "Open the test door", "closed door prompt: %s" % hinge.interactable.get_prompt())
	_check(_capsule_hits(space, Vector3(10.45, 0, 10.0)) > 0, "closed door blocks the doorway")
	var opened_signals: Array[int] = [0]
	hinge.opened.connect(func() -> void: opened_signals[0] += 1)
	hinge.interactable.interacted.emit(null)           # the player pressing interact
	_check(hinge.is_moving(), "using the door starts the swing")
	await _wait_door(hinge)
	_check(hinge.is_open() and absf(hinge.get_angle() - 90.0) < 0.01, "door open at 90 degrees (%.1f)" % hinge.get_angle())
	_check(opened_signals[0] == 1, "opened signal emitted once")
	_check(hinge.interactable.get_prompt() == "Close the test door", "open door prompt flips")
	space = (root as Viewport).world_3d.direct_space_state
	_check(_capsule_hits(space, Vector3(10.45, 0, 10.0)) == 0, "open door leaves the doorway clear")
	_check(_capsule_hits(space, Vector3(10.0, 0, 9.55)) > 0, "open leaf now stands across the swing side (collision follows)")
	hinge.toggle()
	await _wait_door(hinge)
	_check(not hinge.is_open() and hinge.get_angle() < 0.01, "door closes again")
	space = (root as Viewport).world_3d.direct_space_state
	_check(_capsule_hits(space, Vector3(10.45, 0, 10.0)) > 0, "closed again: blocks")
	# locked door
	var reasons: Array[String] = []
	hinge.locked_attempt.connect(func(r: String) -> void: reasons.append(r))
	hinge.set_locked(true, "No key.")
	hinge.use()
	_check(not hinge.is_moving() and not hinge.is_open(), "locked door does not move")
	_check(reasons == ["No key."], "locked door reports its reason")
	_check(hinge.interactable.get_prompt() == "Try the test door", "locked prompt")
	hinge.set_locked(false)
	hinge.use()
	await _wait_door(hinge)
	_check(hinge.is_open(), "unlocked door opens")
	# direction: LEFT hinge + away from front swings the free end toward -Z; toward front toward +Z
	hinge.snap(true)
	var tip_away: Vector3 = hinge.global_transform * Vector3(0.9, 0, 0)
	_check(tip_away.z < 10.0 - 0.8, "away-from-front swing moves the free edge to -Z (%.2f)" % tip_away.z)
	hinge.open_toward_front = true
	hinge.snap(false)
	hinge.snap(true)
	var tip_toward: Vector3 = hinge.global_transform * Vector3(0.9, 0, 0)
	_check(tip_toward.z > 10.0 + 0.8, "toward-front swing moves the free edge to +Z (%.2f)" % tip_toward.z)
	var start_open: OOTDoor = OOTDoor.new()
	start_open.start_open = true
	start_open.position = Vector3(20, 0, 20)
	root.add_child(start_open)
	await process_frame
	_check(start_open.is_open() and absf(start_open.get_angle() - 90.0) < 0.01, "start_open door begins open")
	hinge.queue_free()
	start_open.queue_free()
	await process_frame


# --- The apartment scene ---------------------------------------------------------------

func _make_apartment() -> OOTApartment:
	StoryState.start_part("p1")
	var apt: OOTApartment = (load("res://scenes/p1/e1/apartment.tscn") as PackedScene).instantiate() as OOTApartment
	apt.play_intro = false
	root.add_child(apt)
	return apt


func _node_world_aabb(n: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _test_scene() -> void:
	var apt: OOTApartment = _make_apartment()
	for i: int in 6:
		await physics_frame
	await process_frame
	var space: PhysicsDirectSpaceState3D = (root as Viewport).world_3d.direct_space_state
	apt.exit_requested.connect(func() -> void: _exit_signals += 1)

	# bathroom door: closed at the doorway (x 0, z 1.15..2.05), blocks, opens, clears
	var bath: OOTDoor = apt.get_node("%BathroomDoor") as OOTDoor
	bath.duration = 0.1
	_check(not bath.is_open(), "bathroom door starts closed")
	_check(_capsule_hits(space, Vector3(0.0, 0, 1.6)) > 0, "closed bathroom door blocks the doorway")
	bath.use()
	await _wait_door(bath)
	space = (root as Viewport).world_3d.direct_space_state
	_check(bath.is_open(), "bathroom door opens")
	_check(_capsule_hits(space, Vector3(0.0, 0, 1.6)) == 0, "open bathroom door: doorway clear for the player")
	_check(_capsule_hits(space, Vector3(1.05, 0, 2.0)) == 0, "open bathroom door does not reach the bedroom path")

	# wardrobe doors
	for p: String in ["DoorL", "DoorR"]:
		var w: OOTDoor = apt.get_node("Geometry/Furniture/Wardrobe/%s" % p) as OOTDoor
		w.duration = 0.1
		w.use()
		await _wait_door(w)
		_check(w.is_open(), "wardrobe %s opens" % p)
	space = (root as Viewport).world_3d.direct_space_state
	_check(_capsule_hits(space, Vector3(0.7, 0, 3.0)) == 0, "open wardrobe doors leave the standing spot in front clear")

	# fridge: doors, light, contents inside the fridge bounds
	var kit: OOTFridge = apt.get_node("Geometry/Furniture/Fridge/Kit") as OOTFridge
	kit.fridge_door.duration = 0.1
	kit.freezer_door.duration = 0.1
	_check(not kit.is_any_open() and not kit.light.visible, "fridge closed: interior light off")
	kit.fridge_door.use()
	kit.freezer_door.use()
	await _wait_door(kit.fridge_door)
	await _wait_door(kit.freezer_door)
	await process_frame
	_check(kit.fridge_door.is_open() and kit.freezer_door.is_open(), "fridge and freezer doors both open")
	_check(kit.light.visible and kit.freezer_light.visible, "interior lights come on when the doors open")
	kit.fridge_door.use()
	await _wait_door(kit.fridge_door)
	await process_frame
	_check(not kit.light.visible and kit.freezer_light.visible, "fridge light goes off when its door closes")
	kit.freezer_door.use()
	await _wait_door(kit.freezer_door)
	var fridge: Node3D = apt.get_node("Geometry/Furniture/Fridge") as Node3D
	var bounds: AABB = fridge.global_transform * AABB(Vector3(-0.35, 0.0, -0.35), Vector3(0.7, 1.8, 0.7))
	bounds = bounds.grow(0.002)
	var items: Array[MeshInstance3D] = []
	for c: Node in kit.contents.find_children("*", "MeshInstance3D", true, false):
		items.append(c as MeshInstance3D)
	_check(items.size() >= 35, "fridge holds %d food items" % items.size())
	var outside: Array[String] = []
	var kinds: Dictionary = {}
	for mi: MeshInstance3D in items:
		var b: AABB = mi.global_transform * mi.get_aabb()
		if not bounds.encloses(b):
			outside.append(String(mi.name))
		var n: String = String(mi.name).to_lower()
		for k: String in ["tomato", "onion", "chilli", "cucumber", "curry", "carrot", "water", "soda", "milk", "egg", "takeaway", "icecream", "chocolate", "icetray", "paratha"]:
			if n.contains(k):
				kinds[k] = true
	_check(outside.is_empty(), "every fridge item is inside the fridge bounds (outside: %s)" % str(outside))
	for k: String in ["tomato", "onion", "chilli", "cucumber", "curry", "carrot", "water", "soda", "milk", "egg", "takeaway", "icecream", "chocolate", "icetray", "paratha"]:
		_check(kinds.has(k), "fridge contains %s" % k)
	# freezer items sit in the freezer compartment (above 1.3 m), the rest below
	var freezer_ok: bool = true
	for mi: MeshInstance3D in items:
		var n: String = String(mi.name).to_lower()
		var b: AABB = mi.global_transform * mi.get_aabb()
		var local_y: float = b.position.y - fridge.global_position.y
		if n.contains("icecream") or n.contains("chocolate") or n.contains("icetray") or n.contains("paratha"):
			freezer_ok = freezer_ok and local_y > 1.29
		else:
			freezer_ok = freezer_ok and local_y < 1.25
	_check(freezer_ok, "freezer food is in the freezer compartment, the rest in the fridge")
	var door_box: AABB = _node_world_aabb(kit.fridge_door.get_node("Leaf") as Node3D)
	_check(bounds.grow(0.1).encloses(door_box), "closed fridge door (handle, bins and bottles) stays within the fridge footprint")

	# taps
	var audio_ok: bool = false
	var f: FileAccess = FileAccess.open("res://audio/sfx/apartment/water_loop.ogg", FileAccess.READ)
	if f != null:
		audio_ok = f.get_buffer(4).get_string_from_ascii() == "OggS"
	for path: String in ["Geometry/Furniture/KitchenBase/Tap", "Interactive/BathTap"]:
		var tap: OOTWaterTap = apt.get_node(path) as OOTWaterTap
		_check(tap != null and not tap.is_on and not tap.stream.visible, "%s starts off" % path)
		tap.interactable.interacted.emit(null)
		await process_frame
		_check(tap.is_on and tap.stream.visible and tap.splash.emitting, "%s turns on: stream and splash show" % path)
		if audio_ok:
			_check(tap._loop != null and tap._loop.playing, "%s plays the running-water loop" % path)
		_check(tap.interactable.get_prompt().begins_with("Turn off"), "%s prompt offers turning it off" % path)
		tap.interactable.interacted.emit(null)
		await process_frame
		_check(not tap.is_on and not tap.stream.visible and not tap.splash.emitting, "%s turns off" % path)
		if audio_ok:
			_check(tap._loop != null and not tap._loop.playing, "%s stops the water loop" % path)

	# toilet
	var toilet: OOTToilet = apt.get_node("Interactive/Toilet") as OOTToilet
	var flushed: Array[int] = [0]
	toilet.flushed.connect(func() -> void: flushed[0] += 1)
	_check(not toilet.is_flushing, "toilet idle")
	toilet.interactable.interacted.emit(null)
	_check(toilet.is_flushing, "using the flush button flushes")
	_check(not toilet.flush(), "cannot flush again mid-flush")

	# mirror: renders only near it, temp camera and restore
	var mirror: OOTMirror = apt.mirror
	var main_cam: Camera3D = Camera3D.new()
	apt.add_child(main_cam)
	main_cam.global_position = Vector3(5.0, 1.6, -2.0)          # in the kitchen, far from the bathroom
	main_cam.make_current()
	await process_frame
	await process_frame
	_check(not mirror.rendering and mirror.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "mirror does not render when the camera is outside the bathroom")
	main_cam.global_position = Vector3(-0.5, 1.6, 1.2)
	await process_frame
	await process_frame
	_check(mirror.rendering and mirror.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "mirror renders while the camera is in the bathroom")
	var n: Vector3 = mirror.global_transform.basis.z
	var d: float = (main_cam.global_position - mirror.global_position).dot(n)
	var expect: Vector3 = main_cam.global_position - 2.0 * d * n
	_check(mirror.mirror_camera.global_position.distance_to(expect) < 0.001, "mirror camera is the viewer reflected across the glass")
	_check((-mirror.mirror_camera.global_transform.basis.z).dot(n) > 0.999, "mirror camera looks into the room along the glass normal")
	var locked_calls: Array[int] = [0, 0]
	mirror.view_entered.connect(func() -> void: locked_calls[0] += 1)
	mirror.view_exited.connect(func() -> void: locked_calls[1] += 1)
	mirror.interactable.interacted.emit(null)
	await process_frame
	_check(mirror.in_view and get_root_camera() == mirror._view_cam, "using the mirror switches to a temporary camera")
	_check(apt.player.is_locked(), "player input is locked during the mirror view")
	mirror.exit_view()
	await process_frame
	_check(not mirror.in_view and get_root_camera() == main_cam, "leaving the mirror restores the previous camera")
	_check(not apt.player.is_locked() and locked_calls == [1, 1], "player unlocked after the mirror view")

	# car keys -> flag, pocket, toast
	_check(not StoryState.has_flag("has_car_keys"), "no keys flag at the start")
	_check(apt.car_keys.kind == OOTInteractable.Kind.USE and apt.car_keys.get_meta("pocket_item", false), "keys are a pocket item, not carried in hands")
	_check(apt.car_keys.visible and apt.car_keys.enabled, "keys are on the desk")
	var kb: AABB = _node_world_aabb(apt.car_keys.get_node("Visual") as Node3D)
	_check(absf(kb.position.y - 0.75) < 0.005, "keys rest on the desk top (%.3f)" % kb.position.y)
	_check(absf(apt.car_keys.global_position.x - apt.laptop.global_position.x) < 0.6 and absf(apt.car_keys.global_position.z - apt.laptop.global_position.z) < 0.4, "keys are next to the laptop")

	# front door locked until keys + duffel
	var exit: OOTDoor = apt.exit_door
	var why: Array[String] = []
	exit.locked_attempt.connect(func(r: String) -> void: why.append(r))
	_check(exit.locked and not exit.lock_reason.is_empty(), "front door starts locked with a reason (%s)" % exit.lock_reason)
	exit.use()
	_check(why.size() == 1 and _exit_signals == 0 and not exit.is_open(), "locked front door: reason shown, no exit")
	apt.car_keys.interacted.emit(null)
	_check(StoryState.has_flag("has_car_keys") and apt.has_car_keys, "taking the keys sets has_car_keys")
	_check(not apt.car_keys.enabled and not apt.car_keys.visible, "keys leave the desk")
	_check(exit.locked, "front door still locked without the duffel")
	exit.use()
	_check(why.size() == 2 and why[1] != why[0] and _exit_signals == 0, "front door gives the duffel reason now (%s)" % why[1])
	# duffel becomes a pickup after the call
	_check(not apt.duffel_ready, "duffel is not yet a pickup")
	apt.pack_item("sweets")
	apt.pack_item("diyas")
	apt.pack_item("radio")
	_check(apt.is_ringing, "packing 3/3 still rings the laptop")
	apt._on_call_target_reached("e1_road")                    # the call is over
	_check(apt.duffel_ready and apt.duffel.kind == OOTInteractable.Kind.PICKUP, "after the call the duffel is a PICKUP")
	_check(apt.duffel.item_id == "duffel" and apt.duffel.get_meta("carry_two_hand", false) == true, "duffel item_id and carry_two_hand metadata")
	_check(exit.locked, "front door locked: keys but the bag is not carried")
	apt.player.interactor.carried = apt.duffel
	apt._on_carried_changed(apt.duffel)
	_check(not exit.locked, "front door unlocks with keys and the duffel carried")
	_check(apt.duffel.kind == OOTInteractable.Kind.PICKUP, "carrying the duffel does not turn it back into a packing target")
	exit.duration = 0.1
	exit.use()
	_check(_exit_signals == 1, "using the unlocked front door emits exit_requested")
	await _wait_door(exit)
	_check(exit.is_open(), "front door swings open on exit")
	apt.player.interactor.carried = null
	apt._on_carried_changed(null)
	_check(exit.locked, "setting the bag down locks the door again")
	apt.queue_free()
	await process_frame


func get_root_camera() -> Camera3D:
	return root.get_camera_3d()
