extends SceneTree
## Episode 1 opening tests: the montage timeline (three voicemail lines on shots a/b/c, the house last), skipping, the through-the-blinds
## intro path and handoff, the phone on P, and the title card moving to the drive's end. Run:
##   godot --headless --path game --script res://tests/run_opening_tests.gd
## Exits with code 1 on any failure. Scene tests are skipped when the .glb models are Git LFS pointers (CI).

var StoryState: Node
var _failures: int = 0
var _checks: int = 0


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
	_test_data()
	if FileAccess.get_file_as_string("res://characters/mani/mani.glb").begins_with("version https://git-lfs"):
		print("SKIPPED opening scene tests: Git LFS assets are not checked out (CI).")
	else:
		await _test_montage()
		await _test_intro()
		await _test_episode_flow()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_data() -> void:
	var f: Dictionary = OOTJournalData.get_entry("e1_goal_phone")
	_check(str(f.get("section", "")) == "goal" and f.get("title", "") == "Check the Phone", "journal has the goal 'Check the Phone'")
	_check(InputMap.has_action("phone"), "phone action exists")
	var keys: Array[int] = []
	var pad: bool = false
	for e: InputEvent in InputMap.action_get_events("phone"):
		if e is InputEventKey:
			keys.append((e as InputEventKey).physical_keycode)
		if e is InputEventJoypadButton:
			pad = true
	_check(keys == [KEY_P] and pad, "phone is P on the keyboard and Back on the gamepad")
	StoryState.start_part("p1")
	var lines: Array = OOTServices.db().get_scene("p1", "e1_thought_pack1").lines
	_check(lines.size() == 1 and (lines[0] as OOTDialogueLine).text == "Nila enna solla vandhaa? Oru vela edhavadhu prachanaiya?", "thought line text")
	_check((lines[0] as OOTDialogueLine).subtitle == "What was Nila trying to tell me? Is something wrong?", "thought line subtitle")
	var man: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://audio/vo_placeholder/p1/manifest.json")) as Dictionary)["lines"]
	var rec: Dictionary = man.get("e1_thought_pack1_000", {})
	_check(rec.get("speaker_id", "") == "hm_psi" and rec.get("filter", "") == "clean" and rec.get("channel", "") == "THOUGHT", "thought VO: Mani's voice, clean mic, no radio filter (%s)" % rec)
	var shots: Array[Dictionary] = OOTOpeningMontage.SHOTS
	_check(shots.size() == 4 and [shots[0]["line"], shots[1]["line"], shots[2]["line"]] == [1, 2, 3] and shots[3]["line"] == -1, "three voicemail lines on shots a, b, c; the house has none")
	for i: int in 3:
		var lid: String = OOTVoiceLines.make_id("e1_open", int(shots[i]["line"]))
		var len: float = OOTVoiceLines.get_stream(lid, "p1").get_length()
		_check(float(shots[i]["line_at"]) + len <= float(shots[i]["dur"]) + 0.05, "line %s (%.1f s) fits inside its shot" % [lid, len])
	_check(float(shots[2]["start"]) + float(shots[2]["line_at"]) + OOTVoiceLines.get_stream("e1_open_003", "p1").get_length() <= float(shots[3]["start"]) + 0.4, "the last line ends as the house shot begins")
	_check(String(shots[3]["out"]) == "flash", "the house shot ends on the light through the blinds")


func _test_montage() -> void:
	StoryState.start_part("p1")
	var m: OOTOpeningMontage = (load("res://scenes/p1/e1/opening_montage.tscn") as PackedScene).instantiate() as OOTOpeningMontage
	m.autoplay = false
	m.play_audio = false
	root.add_child(m)
	await process_frame
	_check(m.segments.size() == 4 and m.camera != null, "the montage builds riverside, street, forest and house")
	var forest: Node3D = m.segments["forest"]
	var scatters: int = forest.find_children("*", "ProtonScatter", true, false).size()
	_check(scatters >= 4, "the forest edge is built with Proton Scatter (%d scatters)" % scatters)
	var lines: Array[String] = []
	m.line_started.connect(func(id: String) -> void: lines.append(id))
	m.playing = true
	m.time = 0.0
	var order: Array[int] = []
	var t: float = 0.0
	while t < m.total_duration() - 0.1:
		m.time = t
		m.update_view()
		if order.is_empty() or order[order.size() - 1] != m.shot_index:
			order.append(m.shot_index)
		t += 0.25
	_check(order == [0, 1, 2, 3], "the shots play in order riverside, street, forest, house")
	_check(lines == ["e1_open_001", "e1_open_002", "e1_open_003"], "the three voicemail lines play once each, in order (%s)" % [lines])
	var water: MeshInstance3D = (m.segments["riverside"] as OOTMontageRiverside).water
	_check(water != null and water.material_override is ShaderMaterial and (water.material_override as ShaderMaterial).get_shader_parameter("reflection_tex") != null, "the river uses the water shader with a reflection")
	# skip
	var got: Array = []
	m.finished.connect(func(skipped: bool) -> void: got.append(skipped))
	var ev: InputEventAction = InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	m.allow_skip = true
	m._unhandled_input(ev)
	_check(got == [true] and m.is_done, "Enter skips the montage")
	m.queue_free()
	await process_frame
	var m2: OOTOpeningMontage = (load("res://scenes/p1/e1/opening_montage.tscn") as PackedScene).instantiate() as OOTOpeningMontage
	m2.autoplay = false
	m2.play_audio = false
	root.add_child(m2)
	await process_frame
	var done2: Array = []
	m2.finished.connect(func(skipped: bool) -> void: done2.append(skipped))
	m2.playing = true
	m2.time = m2.total_duration() - 0.01
	m2._process(0.1)
	_check(done2 == [false], "the montage finishes by itself at the end")
	m2.queue_free()
	await process_frame


func _test_intro() -> void:
	StoryState.start_part("p1")
	var apt: OOTApartment = (load("res://scenes/p1/e1/apartment.tscn") as PackedScene).instantiate() as OOTApartment
	apt.play_intro = false
	apt.intro_through_window = true
	root.add_child(apt)
	var finished: Array = []
	apt.intro_finished.connect(func() -> void: finished.append(true))
	for i: int in 30:
		await physics_frame
	_check(apt.intro_active and apt.player.is_locked(), "during the intro the camera moves and the player is locked")
	_check(StoryState.objective_current() != "e1_goal_phone", "no objective yet while the camera is moving")
	apt._intro_end = apt.player.camera.global_transform
	var start: Transform3D = apt.intro_pose(0.0)
	var blinds: Vector3 = apt.get_node("Geometry/Furniture/WindowBlinds0").global_position
	_check(start.origin.z < blinds.z - 2.0, "the move starts outside the window (z %.1f, blinds z %.1f)" % [start.origin.z, blinds.z])
	var crossed: bool = false
	for i: int in range(1, 41):
		if apt.intro_pose(i / 40.0).origin.z > blinds.z + 0.3:
			crossed = true
	_check(crossed, "the path crosses the blinds into the room")
	var end: Transform3D = apt.intro_pose(1.0)
	_check(end.origin.distance_to(apt._intro_end.origin) < 0.05 and (end.basis.z - apt._intro_end.basis.z).length() < 0.05, "the path ends exactly on the shoulder camera")
	# the orbit stays around Mani
	var around: bool = true
	for i: int in range(16, 40):
		if apt.intro_pose(i / 40.0).origin.distance_to(apt.player.global_position + Vector3(0, 1.4, 0)) > 3.6:
			around = false
	_check(around, "the camera orbits within a few metres of Mani")
	apt.skip_window_intro()
	await process_frame
	_check(not apt.intro_active and not apt.player.is_locked() and finished == [true] and not apt.player.is_shot_active(), "the handoff returns control on the shoulder view")
	_check(StoryState.objective_current() == "e1_goal_phone", "the Check the Phone objective starts when control returns")
	apt.queue_free()
	await process_frame


func _test_episode_flow() -> void:
	StoryState.start_part("p1")
	var ep: OOTEpisode01 = (load("res://scenes/p1/e1/episode_01.tscn") as PackedScene).instantiate() as OOTEpisode01
	root.add_child(ep)
	await process_frame
	_check(ep.stage == "cold_open" and ep.montage != null and ep.apartment == null, "the episode starts with the montage (no black cold open, no lock screen)")
	_check(ep.get_node_or_null("CanvasLayer") == null or ep.find_children("*", "OOTPhoneLockScreen", true, false).is_empty(), "no lock screen in the opening")
	ep.montage.skip()
	await process_frame
	await process_frame
	_check(ep.stage == "apartment" and ep.apartment != null and ep.apartment.intro_through_window, "after the montage the apartment starts with the window intro")
	_check(ep.runner.scene.id == "e1_apt" and OOTJournalData.get_entry("e1_voicemail").size() > 0 and StoryState.journal_has("e1_voicemail"), "the voicemail clue is granted and the story is at e1_apt")
	# the title card shows when the drive reaches the county road
	ep.stage = "exterior"
	ep._card.visible = false
	ep._on_drive_reached()
	_check(ep.stage == "title" and ep._card.visible and ep._card_title.text == "OUT OF TOWN: GREYHAVEN" and ep._card_sub.text == "EPISODE 1 — COUNTY ROADS", "the title card shows after the drive fade")
	ep.queue_free()
	await process_frame
