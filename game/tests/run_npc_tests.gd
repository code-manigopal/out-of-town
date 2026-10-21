extends SceneTree
## Pedestrian tests (models, walk clip, foot slide, route following, crossings, blocking, bus stop, spawner). Run:
##   godot --headless --path game --script res://tests/run_npc_tests.gd
## Exits with code 1 on any failure. Asset checks are skipped when mani.glb is a Git LFS pointer (CI).

const MANI: String = "res://characters/mani/mani.glb"
const SLIDE_LIMIT: float = 0.22      # m/s: mean world speed of a planted foot
var _failures: int = 0
var _checks: int = 0
var _world: Node3D


static func _lfs_pointer() -> bool:
	var f: FileAccess = FileAccess.open(MANI, FileAccess.READ)
	if f == null:
		return true
	return f.get_buffer(24).get_string_from_ascii().begins_with("version https://git-lfs")


func _initialize() -> void:
	if _lfs_pointer():
		print("SKIPPED pedestrian tests: Git LFS assets are not checked out (CI).")
		print("0 checks, 0 failures")
		quit(0)
		return
	await process_frame
	_test_models()
	await _test_walk_and_slide()
	await _test_route_follow()
	await _test_blocker()
	await _test_idle_and_spawner()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("ok   - " + what)
	else:
		_failures += 1
		print("FAIL - " + what)


func _new_world() -> Node3D:
	if _world != null:
		_world.queue_free()
		await process_frame
	_world = Node3D.new()
	root.add_child(_world)
	var g: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(100, 0.2, 100)
	cs.shape = bs
	cs.position = Vector3(0, -0.1, 0)
	g.add_child(cs)
	_world.add_child(g)
	return _world


func _route(pts: Array, closed: bool = false, nm: String = "PedRoute_T") -> Path3D:
	var p: Path3D = Path3D.new()
	p.name = nm
	var c: Curve3D = Curve3D.new()
	c.bake_interval = 0.1
	for v: Vector3 in pts:
		c.add_point(v)
	c.closed = closed
	p.curve = c
	_world.add_child(p)
	return p


func _ped(model: int, path: Path3D, spd: float, off: float = 0.0) -> OOTPedestrian:
	var p: OOTPedestrian = (load("res://scenes/npc/pedestrian.tscn") as PackedScene).instantiate() as OOTPedestrian
	p.model_path = "res://characters/pedestrians/ped_%d.glb" % model
	p.speed = spd
	p.start_offset = off
	p.route_path = path
	_world.add_child(p)
	return p


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _test_models() -> void:
	for i in range(1, 7):
		var path: String = "res://characters/pedestrians/ped_%d.glb" % i
		var scene: PackedScene = load(path) as PackedScene
		_check(scene != null, "ped_%d.glb loads" % i)
		if scene == null:
			continue
		var inst: Node = scene.instantiate()
		var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
		_check(sk != null and sk.get_bone_count() == 53 and sk.find_bone("pelvis") >= 0 and sk.find_bone("foot_l") >= 0,
			"ped_%d has Mani's 53-bone skeleton" % i)
		var size_mb: float = FileAccess.get_file_as_bytes(path).size() / 1.0e6
		_check(size_mb < 5.0, "ped_%d.glb is %.2f MB (< 5)" % [i, size_mb])
		var tris: int = 0
		for m: Node in inst.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (m as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				tris += mesh.surface_get_array_index_len(s) / 3
		_check(tris <= 15000, "ped_%d has %d triangles (<= 15000)" % [i, tris])
		inst.free()


func _foot_pos(p: OOTPedestrian, bone: String) -> Vector3:
	var sk: Skeleton3D = p.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


func _test_walk_and_slide() -> void:
	await _new_world()
	var path: Path3D = _route([Vector3(-40, 0, 0), Vector3(40, 0, 0)])
	var peds: Array[OOTPedestrian] = []
	var speeds: Array[float] = [0.9, 1.4, 1.1, 1.25, 1.0, 1.35]
	for i in 6:
		var p: OOTPedestrian = _ped(i + 1, path, speeds[i], 5.0 + 10.0 * i)
		peds.append(p)
	await _frames(90)
	for i in 6:
		var p: OOTPedestrian = peds[i]
		_check(p.anim != null and p.anim.current_animation == "walk", "ped_%d plays the walk clip while moving" % (i + 1))
		_check(absf(p.anim.speed_scale - p.walk_clip_rate(p.current_speed)) < 0.02 and p.current_speed > speeds[i] * 0.95,
			"ped_%d clip rate follows ground speed (%.2f m/s -> x%.2f)" % [i + 1, p.current_speed, p.anim.speed_scale])
	# foot slide: world speed of each foot while it is planted (lowest 25% of its height range)
	var feet: Array = []
	for i in 6:
		feet.append({"l": [], "r": []})
	var prev: Array = []
	for i in 6:
		prev.append({"l": _foot_pos(peds[i], "foot_l"), "r": _foot_pos(peds[i], "foot_r")})
	for f in 150:
		await physics_frame
		for i in 6:
			for side: String in ["l", "r"]:
				var cur: Vector3 = _foot_pos(peds[i], "foot_" + side)
				var v: Vector3 = (cur - (prev[i][side] as Vector3)) * 60.0
				prev[i][side] = cur
				(feet[i][side] as Array).append([cur.y, Vector2(v.x, v.z).length()])
	for i in 6:
		var worst: float = 0.0
		for side: String in ["l", "r"]:
			var arr: Array = feet[i][side]
			var ymin: float = 1e9
			var ymax: float = -1e9
			for e: Array in arr:
				ymin = minf(ymin, e[0])
				ymax = maxf(ymax, e[0])
			var sum: float = 0.0
			var n: int = 0
			for e: Array in arr:
				if e[0] < ymin + (ymax - ymin) * 0.2:
					sum += e[1]
					n += 1
			worst = maxf(worst, sum / maxf(n, 1))
		_check(worst < SLIDE_LIMIT, "ped_%d planted-foot slide %.3f m/s at %.2f m/s (< %.2f)" % [i + 1, worst, speeds[i], SLIDE_LIMIT])


func _min_dist_to_path(path: Path3D, pos: Vector3) -> float:
	var local: Vector3 = path.to_local(pos)
	var c: Vector3 = path.curve.get_closest_point(local)
	return Vector2(c.x - local.x, c.z - local.z).length()


func _test_route_follow() -> void:
	await _new_world()
	var path: Path3D = _route([Vector3(0, 0, 0), Vector3(8, 0, 0), Vector3(8, 0, -8)])
	var wait: Node3D = Node3D.new()
	wait.name = "Wait_X"
	wait.position = Vector3(4, 0, 0)
	path.add_child(wait)
	var p: OOTPedestrian = _ped(2, path, 1.3, 0.0)
	var worst: float = 0.0
	var max_turn: float = 0.0
	var prev_yaw: float = 0.0
	var waited: float = 0.0
	var best_wait: float = 0.0
	var passed_corner: bool = false
	var end_reached: bool = false
	for f in 60 * 22:
		await physics_frame
		worst = maxf(worst, _min_dist_to_path(path, p.global_position))
		var yaw: float = p.body.rotation.y
		if f > 5:
			max_turn = maxf(max_turn, absf(angle_difference(prev_yaw, yaw)) * 60.0)
		prev_yaw = yaw
		if absf(p.global_position.x - 4.0) < 1.0 and p.global_position.z > -0.5 and p.current_speed < 0.05:
			waited += 1.0 / 60.0
			best_wait = maxf(best_wait, waited)
		else:
			waited = 0.0
		if p.global_position.x > 7.0 and p.global_position.z < -1.0:
			passed_corner = true
		if p.global_position.z < -7.0:
			end_reached = true
	_check(worst < 0.55, "follows the path (max deviation %.2f m)" % worst)
	_check(passed_corner and end_reached, "turns the corner and reaches the end of the route")
	_check(max_turn < 6.5, "turns smoothly (max yaw rate %.1f rad/s)" % max_turn)
	_check(best_wait > 1.2, "waits at the crossing (%.1f s)" % best_wait)
	_check(p.global_position.y == 0.0, "stays at route height")


func _test_blocker() -> void:
	await _new_world()
	var path: Path3D = _route([Vector3(-20, 0, 0), Vector3(20, 0, 0)])
	var blocker: CharacterBody3D = CharacterBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	blocker.add_child(cs)
	blocker.position = Vector3(0, 0, 0)
	_world.add_child(blocker)
	var p: OOTPedestrian = _ped(3, path, 1.3, 14.0)      # starts at x = -6, walking +x toward the blocker
	var stopped_at: float = 99.0
	var min_gap: float = 99.0
	var max_side: float = 0.0
	var stop_time: float = 0.0
	var passed: bool = false
	var t_pass: float = 0.0
	for f in 60 * 20:
		await physics_frame
		var gap: float = Vector2(p.global_position.x - blocker.global_position.x, p.global_position.z - blocker.global_position.z).length()
		min_gap = minf(min_gap, gap)
		max_side = maxf(max_side, absf(p.global_position.z))
		if p.current_speed < 0.05 and p.global_position.x < -0.3:
			stop_time += 1.0 / 60.0
			stopped_at = minf(stopped_at, gap)
		if p.global_position.x > 1.5 and not passed:
			passed = true
			t_pass = f / 60.0
	_check(stop_time > 0.5 and stopped_at > 0.45 and stopped_at < 1.6,
		"stops short of a blocking body (%.1f s standing, %.2f m away)" % [stop_time, stopped_at])
	_check(min_gap > 0.45, "never walks into the body (closest %.2f m)" % min_gap)
	_check(passed and max_side > 0.4, "steps around it and carries on (sidestep %.2f m, past at %.1f s)" % [max_side, t_pass])
	# opposite directions on one pavement: both get by
	await _new_world()
	var path2: Path3D = _route([Vector3(-20, 0, 0), Vector3(20, 0, 0)])
	var a: OOTPedestrian = _ped(1, path2, 1.2, 10.0)
	var b: OOTPedestrian = _ped(4, path2, 1.2, 30.0)
	b.reverse = true
	b._dir = -1.0
	var swapped: bool = false
	for f in 60 * 25:
		await physics_frame
		if a.global_position.x > b.global_position.x + 0.3:
			swapped = true
			break
	_check(swapped, "two pedestrians walking toward each other get past one another")


func _test_idle_and_spawner() -> void:
	await _new_world()
	var path: Path3D = _route([Vector3(2, 0, 2), Vector3(4, 0, 2)], false, "PedRoute_BusStop")
	var p: OOTPedestrian = (load("res://scenes/npc/pedestrian.tscn") as PackedScene).instantiate() as OOTPedestrian
	p.model_path = "res://characters/pedestrians/ped_5.glb"
	p.mode = OOTPedestrian.Mode.IDLE_WAIT
	p.idle_style = OOTPedestrian.IdleStyle.PHONE
	p.start_offset = 1.0
	p.route_path = path
	_world.add_child(p)
	var start: Vector3 = Vector3.ZERO
	await _frames(30)
	start = p.global_position
	await _frames(120)
	_check(p.global_position.distance_to(start) < 0.01 and absf(start.x - 3.0) < 0.05, "bus-stop pedestrian stands still at its place")
	_check(p.anim.current_animation == "phone", "bus-stop pedestrian plays the phone idle")
	_check(p.anim.has_animation("idle") and p.anim.has_animation("walk"), "idle and walk clips are present on the model")
	# spawner
	await _new_world()
	var routes: Array[Path3D] = [
		_route([Vector3(0, 0, 0), Vector3(20, 0, 0)], false, "PedRoute_A"),
		_route([Vector3(0, 0, 5), Vector3(10, 0, 5), Vector3(10, 0, 15), Vector3(0, 0, 15)], true, "PedRoute_B"),
		_route([Vector3(-5, 0, 0), Vector3(-3, 0, 0)], false, "PedRoute_BusStop"),
	]
	var peds: Array[OOTPedestrian] = OOTPedestrianSpawner.spawn_along(routes, 9, _world, 7)
	_check(peds.size() == 9, "spawner creates the requested number (%d)" % peds.size())
	await _frames(120)
	var walkers: int = 0
	var ok: bool = true
	for q: OOTPedestrian in peds:
		if q.mode == OOTPedestrian.Mode.WALK:
			walkers += 1
			ok = ok and q.speed >= 0.9 and q.speed <= 1.4 and q.skeleton != null and q.anim != null
	_check(ok and walkers == 6, "spawned walkers have a route, model, skeleton and a 0.9-1.4 m/s speed (%d walkers)" % walkers)
	var moving: int = 0
	for q: OOTPedestrian in peds:
		if q.state == &"walk":
			moving += 1
	_check(moving >= 4, "most spawned walkers are walking after 2 s (%d)" % moving)
	var model_set: Dictionary = {}
	for q: OOTPedestrian in peds:
		model_set[q.model_path] = true
	_check(model_set.size() >= 5, "spawner mixes models (%d distinct)" % model_set.size())
