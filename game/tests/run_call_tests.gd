extends SceneTree
## Video-call cinematic tests (OOTCallCinematic, OOTCallScreen, OOTCallImages). Run:
##   godot --headless --path game --script res://tests/run_call_tests.gd
## Exits with code 1 on any failure. Scene tests are skipped when the .glb models are Git LFS pointers (CI).

const TMP_DIR: String = "user://call_test_images/"

var StoryState: Node
var _failures: int = 0
var _checks: int = 0


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
	_test_images()
	await _test_screen()
	if lfs_assets_present():
		await _test_call()
	else:
		print("SKIPPED call scene tests: Git LFS assets are not checked out (CI).")
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _write_png(path: String, color: Color) -> void:
	var img: Image = Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(color)
	img.save_png(ProjectSettings.globalize_path(path))


func _test_images() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_DIR))
	var key: String = "amma_close"
	var none: Dictionary = OOTCallImages.find(key, TMP_DIR)
	_check(none["texture"] == null and bool(none["placeholder"]), "no files at all: null texture (the screen draws its procedural placeholder)")
	_write_png(OOTCallImages.placeholder_path(key, TMP_DIR), Color.RED)
	var ph: Dictionary = OOTCallImages.find(key, TMP_DIR)
	_check(ph["texture"] != null and bool(ph["placeholder"]) and str(ph["path"]).ends_with("amma_close_placeholder.png"), "only a placeholder file: the placeholder is used")
	_write_png(OOTCallImages.real_path(key, TMP_DIR), Color.GREEN)
	var real: Dictionary = OOTCallImages.find(key, TMP_DIR)
	_check(real["texture"] != null and not bool(real["placeholder"]) and str(real["path"]).ends_with("amma_close.png"), "real image present: preferred over the placeholder")
	var px: Color = (real["texture"] as Texture2D).get_image().get_pixel(1, 1)
	_check(px.g > 0.5 and px.r < 0.3, "the loaded texture is the real (green) image, not the placeholder (red)")
	for k: String in OOTCallImages.KEYS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OOTCallImages.real_path(k, TMP_DIR)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OOTCallImages.placeholder_path(k, TMP_DIR)))
	if not lfs_assets_present():
		return
	for k: String in OOTCallImages.KEYS:
		var d: Dictionary = OOTCallImages.find(k)
		_check(d["texture"] != null, "project has an image for %s (%s)" % [k, d["path"]])


func _test_screen() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = OOTCallScreen.SCREEN_SIZE
	root.add_child(vp)
	var scr: OOTCallScreen = OOTCallScreen.new()
	vp.add_child(scr)
	await process_frame
	scr.set_speaker("AMMA")
	_check(scr.tile == "amma" and scr.tile_key == "amma_close", "call screen shows Amma's close-up when Amma speaks")
	var want: bool = bool(OOTCallImages.find("amma_close")["placeholder"])
	_check(scr.tile_is_placeholder == want, "the tile uses the same image OOTCallImages picks (placeholder=%s)" % want)
	scr.set_speaker("APPA")
	_check(scr.tile == "appa" and scr.tile_key == "appa_close", "call screen shows Appa's close-up when Appa speaks")
	scr.set_speaker("MANI")
	_check(scr.tile == "wide" and scr.tile_key == "amma_appa_wide", "Mani speaking: the wide shot of both parents")
	scr.set_speaker("")
	_check(scr.tile == "wide", "narration: the wide shot")
	for i: int in 5:
		await process_frame
	_check(scr.elapsed > 0.0, "the call timer runs")
	scr.end_call()
	_check(scr.ended and scr._ended_overlay.visible, "end_call shows 'Call ended'")
	vp.queue_free()
	await process_frame


func _shot_group(shot: StringName, group: Array[StringName]) -> bool:
	return group.has(shot)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _test_call() -> void:
	StoryState.start_part("p1")
	var apt: OOTApartment = (load("res://scenes/p1/e1/apartment.tscn") as PackedScene).instantiate() as OOTApartment
	apt.play_intro = false
	root.add_child(apt)
	for i: int in 6:
		await physics_frame
	await process_frame
	var player: OOTPlayer = apt.player
	var d: OOTDialogueBox = apt.dialogue
	var lights_before: float = (apt.get_node("MorningSun") as DirectionalLight3D).light_energy

	apt._start_ringing()
	apt._answer_laptop()
	await process_frame
	var c: OOTCallCinematic = apt.call_cinematic
	_check(c != null and c.active, "the cinematic starts with the call")
	# Narration is no longer shown in the dialogue box, so the call opens on Amma's first line (a screen shot).
	_check(c.SCREEN_SHOTS.has(c.current_shot), "opening shot favours the screen: Amma's first line (%s)" % c.current_shot)
	_check(player.is_shot_active() or c._fallback_cam != null, "a fixed camera shot is active")
	_check(player.is_locked(), "player input is locked during the call")
	_check(c.seated == player.has_pose_override(), "Mani is in the seated pose when available (seated=%s)" % c.seated)
	_check(absf(player.global_position.x) < 0.01 and player.global_position.z < -2.7 and player.global_position.z > -3.1, "Mani is at the desk (%s)" % player.global_position)
	_check(c.screen != null and c.screen.is_inside_tree(), "the call screen exists")
	_check(c.screen_quad != null and c.screen_quad.is_inside_tree(), "a call-screen quad sits on the laptop")
	var q: Vector3 = c.screen_quad.global_position
	_check(q.distance_to(Vector3(0, 0.874, -3.767)) < 0.03, "the quad covers the laptop's screen surface (%s)" % q)
	_check(c.screen_light != null and c.screen_light.is_inside_tree(), "a screen light exists")
	_check(c.screen_light.light_color.r > 0.9 and c.screen_light.light_color.b < c.screen_light.light_color.r, "the screen light is warm white")

	await _wait(1.8)
	_check(c.screen_light.light_energy > 1.0, "the screen glow lights up (%.2f)" % c.screen_light.light_energy)
	_check((apt.get_node("MorningSun") as DirectionalLight3D).light_energy < lights_before * 0.7, "the room dims during the call")

	# (narration line 0 is skipped) Amma -> Mani -> Appa -> Mani -> Amma + choices
	var shots: Array[StringName] = [c.current_shot]
	var tiles: Array[String] = [c.screen.tile]
	var speakers: Array[String] = [c.current_speaker]
	for n: int in 4:
		d.advance()
		await process_frame
		await process_frame
		shots.append(c.current_shot)
		tiles.append(c.screen.tile)
		speakers.append(c.current_speaker)
	print("shots ", shots, " speakers ", speakers, " tiles ", tiles)
	_check(speakers == ["AMMA", "MANI", "APPA", "MANI", "AMMA"], "line speakers followed: %s" % [speakers])
	_check(shots[1] != shots[0], "the shot changes when the first line is advanced to")
	for i: int in range(1, 4):
		_check(shots[i] != shots[i - 1], "shot changes on each line advance (line %d: %s -> %s)" % [i, shots[i - 1], shots[i]])
	_check(c.SCREEN_SHOTS.has(shots[0]) and c.SCREEN_SHOTS.has(shots[2]), "Amma and Appa lines use screen-favouring shots")
	_check(c.FACE_SHOTS.has(shots[1]) and c.FACE_SHOTS.has(shots[3]), "Mani lines use face shots")
	_check(tiles[0] == "amma" and tiles[1] == "wide" and tiles[2] == "appa" and tiles[3] == "wide", "the call screen shows the speaker's tile (%s)" % [tiles])
	# the last line is shown together with the choices: the calm hold
	_check(c.holding_choice and c.current_shot == &"choice_hold", "with the choice on screen the camera holds the calm shot (%s)" % c.current_shot)
	_check(tiles[4] == "amma", "the remote tile stays on Amma while her question is up")
	var hold_xf: Transform3D = c._cam().global_transform
	await _wait(0.6)
	_check(c._cam().global_transform.origin.is_equal_approx(hold_xf.origin), "the choice hold does not move")
	_check(d._choices.get_child_count() == 2, "the choice buttons work normally (2 shown)")
	(d._choices.get_child(1) as Button).pressed.emit()  # the half-truth
	await process_frame
	await process_frame
	_check(StoryState.has_flag("honest1"), "honesty flag set by the choice (unchanged call logic)")
	_check(not c.holding_choice and apt.runner.scene.id == "e1_call2", "back to cinematic shots after the choice (%s)" % c.current_shot)
	var fin: Array[bool] = [false]
	c.finished.connect(func() -> void: fin[0] = true)
	var guard: int = 0
	while d.is_open and guard < 20:
		d.advance()
		await process_frame
		guard += 1
	_check(not d.is_open, "the dialogue closed at the end of the call")
	_check(c.screen.ended, "the call screen says the call ended")
	await _wait(1.4)
	_check(fin[0], "the cinematic finished")
	_check(not is_instance_valid(c) or c.is_queued_for_deletion(), "the cinematic cleaned itself up")
	_check(not player.is_shot_active(), "the shot is released after the call")
	_check(not player.has_pose_override(), "Mani stands up after the call")
	_check(not player.is_locked(), "control returns to the player after the call")
	_check(absf((apt.get_node("MorningSun") as DirectionalLight3D).light_energy - lights_before) < 0.001, "room lighting is restored")
	_check(apt.get_node("Geometry/Furniture/OfficeChairBody/Shape").disabled == false, "the chair collision is back")
	_check(apt.duffel_ready, "the duffel becomes pickable after the call (existing logic)")
	apt.queue_free()
	await process_frame
