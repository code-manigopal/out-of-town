extends SceneTree
## Player animation tests (skating regression, new clips, actions, pose override, camera). Run:
##   godot --headless --path game --script res://tests/run_player_tests.gd
## Exits with code 1 on any failure. Asset checks are skipped when mani.glb is a Git LFS pointer (CI).

const MANI: String = "res://characters/mani/mani.glb"
const CLIP_LENGTHS: Dictionary = {
	"carry_duffel": 4.0, "reach_low": 1.0, "put_down": 0.8, "door_open_push": 1.0, "trunk_open": 1.2,
	"trunk_close": 1.0, "car_enter_driver": 2.0, "sit_drive": 4.0, "car_exit_driver": 2.0, "stairs_down": 1.2,
}
var _failures: int = 0
var _checks: int = 0


static func _lfs_pointer() -> bool:
	var f: FileAccess = FileAccess.open(MANI, FileAccess.READ)
	if f == null:
		return true
	return f.get_buffer(24).get_string_from_ascii().begins_with("version https://git-lfs")


func _initialize() -> void:
	if _lfs_pointer():
		print("SKIPPED player animation tests: Git LFS assets are not checked out (CI).")
		print("0 checks, 0 failures")
		quit(0)
		return
	await process_frame
	_test_clips()
	await _test_skating()
	await _test_actions()
	await _test_pose_and_stairs()
	await _test_carry_selection()
	await _test_camera()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("ok   - " + what)
	else:
		_failures += 1
		print("FAIL - " + what)


func _make_player() -> OOTPlayer:
	var pl: OOTPlayer = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as OOTPlayer
	root.add_child(pl)
	return pl


func _test_clips() -> void:
	var inst: Node = (load(MANI) as PackedScene).instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: String in CLIP_LENGTHS:
		var ok: bool = ap.has_animation(clip) and absf(ap.get_animation(clip).length - float(CLIP_LENGTHS[clip])) < 0.05
		_check(ok, "clip %s exists, length %.1f s" % [clip, CLIP_LENGTHS[clip]])
	for clip: String in ["idle", "walk", "jog", "carry", "carry_sweets", "carry_diyas", "carry_radio"]:
		_check(ap.has_animation(clip), "existing clip %s still present" % clip)
	inst.free()


## Rotation of a bone (as a quaternion in the skeleton's pose) in the player's skeleton.
func _bone_rot(pl: OOTPlayer, bone: String) -> Quaternion:
	return pl.skeleton.get_bone_pose_rotation(pl.skeleton.find_bone(bone))


func _step(n: int) -> void:
	for i: int in n:
		await physics_frame


## Regression: while carrying, the legs must keep walking (the carry clip used to freeze every bone).
func _test_skating() -> void:
	var pl: OOTPlayer = _make_player()
	await process_frame
	var carry: Animation = pl.anim.get_animation(&"carry")
	var leg_tracks: int = 0
	var upper_tracks: int = 0
	for t: int in carry.get_track_count():
		var bone: String = str(carry.track_get_path(t)).get_slice(":", 1)
		if bone.begins_with("thigh") or bone.begins_with("calf") or bone.begins_with("foot") or bone == "pelvis" or bone == "ball_l" or bone == "ball_r":
			leg_tracks += 1
		if bone.begins_with("upperarm"):
			upper_tracks += 1
	_check(leg_tracks == 0, "carry clip has no leg or pelvis tracks (%d)" % leg_tracks)
	_check(upper_tracks > 0, "carry clip still drives the arms")
	pl._carry_target = 1.0
	pl._carry_blend = 1.0
	pl.tree.set("parameters/CarryBlend/blend_amount", 1.0)
	pl.tree.advance(0.1)
	# walk: drive the animation directly (no input in headless): velocity > 0
	pl.velocity = Vector3(0, 0, -1.33)
	pl._update_animation()
	var samples: Array[float] = []
	var base: Quaternion = Quaternion.IDENTITY
	var first: bool = true
	for i: int in 20:
		pl.tree.advance(0.05)
		pl.skeleton.force_update_all_bone_transforms()
		var q: Quaternion = _bone_rot(pl, "thigh_l")
		if first:
			base = q
			first = false
		samples.append(rad_to_deg(base.angle_to(q)))
	var swing: float = samples.max()
	_check(swing > 15.0, "thigh_l rotation changes while carry blend = 1 and velocity > 0 (%.1f deg swing)" % swing)
	var calf: Quaternion = _bone_rot(pl, "calf_r")
	pl.tree.advance(0.25)
	pl.skeleton.force_update_all_bone_transforms()
	_check(rad_to_deg(calf.angle_to(_bone_rot(pl, "calf_r"))) > 3.0, "calf_r also moves while carrying")
	# the arms hold the carry pose instead of swinging with the walk
	var arm0: Quaternion = _bone_rot(pl, "upperarm_l")
	var varied: float = 0.0
	for i: int in 10:
		pl.tree.advance(0.05)
		pl.skeleton.force_update_all_bone_transforms()
		varied = maxf(varied, rad_to_deg(arm0.angle_to(_bone_rot(pl, "upperarm_l"))))
	_check(varied < 4.0, "arms stay in the carry pose while walking (%.1f deg drift)" % varied)
	pl.queue_free()
	await process_frame


func _test_actions() -> void:
	var pl: OOTPlayer = _make_player()
	await process_frame
	_check(pl.has_action(&"door_open_push") and pl.has_action(&"trunk_open"), "player reports the new actions")
	var t0: int = Time.get_ticks_msec()
	var finished: Array = []
	pl.action_finished.connect(func(c: StringName) -> void: finished.append(c))
	pl.global_position = Vector3.ZERO
	await pl.play_action(&"door_open_push", true, false)
	var dt: float = (Time.get_ticks_msec() - t0) / 1000.0
	_check(dt > 0.9 and dt < 1.6, "play_action awaits the clip (%.2f s for a 1.0 s clip)" % dt)
	_check(finished == [&"door_open_push"] and not pl.is_acting(), "action_finished emitted, player free")
	_check(not pl.is_locked(), "input unlocked after the action")
	# input lock while acting
	var running: Callable = func() -> void: await pl.play_action(&"trunk_close")
	running.call()
	await physics_frame
	_check(pl.is_locked() and pl.is_acting(), "input locked while the action plays")
	await create_timer(1.3).timeout
	_check(not pl.is_locked(), "lock released after trunk_close")
	# root motion: the door push moves the body ~0.86 m forward (-Z)
	pl.global_position = Vector3.ZERO
	pl.body.rotation.y = 0.0
	await pl.play_action(&"door_open_push")
	_check(absf(pl.global_position.z - (-0.86)) < 0.12 and absf(pl.global_position.x) < 0.05,
		"door_open_push travel 0.86 m forward (z=%.2f)" % pl.global_position.z)
	pl.queue_free()
	await process_frame


func _test_pose_and_stairs() -> void:
	var pl: OOTPlayer = _make_player()
	await process_frame
	pl.set_pose_override(&"sit_drive", 0.0)
	await _step(10)
	pl.tree.advance(0.6)
	pl.skeleton.force_update_all_bone_transforms()
	_check(pl.has_pose_override(), "pose override active")
	var pelvis_y: float = pl.skeleton.get_bone_global_pose(pl.skeleton.find_bone("pelvis")).origin.y
	# seated pelvis is much lower than standing (0.945 m)
	_check(pelvis_y < 0.75, "seated pelvis height %.2f m" % pelvis_y)
	pl.clear_pose_override(0.0)
	_check(not pl.has_pose_override(), "pose override cleared")
	pl.set_stairs_down(true)
	pl.velocity = Vector3(0, 0, -0.467)
	pl._update_animation()
	_check(pl._anim_state == &"stairs_down", "stairs_down selected while moving on stairs")
	pl.set_stairs_down(false)
	pl.velocity = Vector3(0, 0, -1.33)
	pl._update_animation()
	_check(pl._anim_state == &"walk", "walk selected again off the stairs")
	pl.queue_free()
	await process_frame


class FakeItem extends OOTInteractable:
	pass


func _test_carry_selection() -> void:
	var pl: OOTPlayer = _make_player()
	await process_frame
	var it: OOTInteractable = OOTInteractable.new()
	it.item_id = "box"
	_check(pl.carry_config(it).get("clip", "carry") != "carry_duffel", "ordinary item does not use carry_duffel")
	it.set_meta("carry_two_hand", true)
	_check(pl.carry_config(it).get("clip") == "carry_duffel", "meta carry_two_hand selects carry_duffel")
	var it2: OOTInteractable = OOTInteractable.new()
	it2.item_id = "duffel"
	_check(pl.carry_config(it2).get("clip") == "carry_duffel", "item id duffel selects carry_duffel")
	it.free()
	it2.free()
	pl.queue_free()
	await process_frame


func _test_camera() -> void:
	var pl: OOTPlayer = _make_player()
	await process_frame
	await _step(3)
	_check(pl.use_phantom_camera and pl.pcam != null, "player uses a PhantomCamera3D")
	_check(pl.phantom_camera_ready(), "phantom third-person spring arm is built")
	_check(pl.pcam.get("follow_mode") == pl.pcam.get_script().FollowMode.THIRD_PERSON, "follow mode is third person")
	_check(absf(float(pl.pcam.get("spring_length")) - 2.2) < 0.01, "camera distance 2.2 m")
	# a wall behind the shoulder pulls the camera in (collision)
	var wall: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6, 4, 0.2)
	cs.shape = box
	wall.add_child(cs)
	root.add_child(wall)
	wall.global_position = Vector3(0, 1.5, 1.0)       # behind the player (camera looks to -Z, sits at +Z)
	pl.yaw = 0.0
	pl.pitch = 0.0
	await _step(6)
	await process_frame
	var cam: Camera3D = pl.camera
	var d: float = cam.global_position.distance_to(pl.global_position + Vector3(0, 1.5, 0))
	_check(d < 1.6, "camera collides with the wall behind (distance %.2f m)" % d)
	wall.queue_free()
	# look: yaw rotates the camera
	pl.yaw = 1.0
	await _step(4)
	await process_frame
	var fwd: Vector3 = -cam.global_transform.basis.z
	_check(absf(fwd.x - (-sin(1.0))) < 0.1, "camera yaw follows the look input")
	# fixed shot
	var marker: Node3D = Node3D.new()
	root.add_child(marker)
	marker.global_position = Vector3(5, 2, 5)
	marker.look_at_from_position(Vector3(5, 2, 5), Vector3(5, 1, 0))
	_check(pl.use_shot(marker), "use_shot accepts a marker node")
	await create_timer(1.6).timeout
	_check(cam.global_position.distance_to(Vector3(5, 2, 5)) < 0.3, "camera cut to the fixed shot")
	pl.release_shot()
	await create_timer(1.6).timeout
	_check(cam.global_position.distance_to(pl.global_position) < 4.0, "release_shot returns to the follow camera")
	marker.queue_free()
	pl.queue_free()
	await process_frame
