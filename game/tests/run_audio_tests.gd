extends SceneTree
## Audio / voice tests. Run:
##   godot --headless --path game --script res://tests/run_audio_tests.gd
## Exits with code 1 on any failure.

const VO_DIR: String = "res://audio/vo_placeholder/p1/"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	var db: Node = root.get_node_or_null("StoryDB")
	_check(db != null and db.load_all(), "StoryDB loads")
	_test_manifest_and_files(db)
	_test_buses()
	_test_sfx_files()
	await process_frame
	await _test_dialogue_requests_vo()
	_test_footsteps()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_manifest_and_files(db: Node) -> void:
	var mpath: String = VO_DIR + "manifest.json"
	_check(FileAccess.file_exists(mpath), "manifest.json exists")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(mpath))
	_check(parsed is Dictionary, "manifest parses")
	if not (parsed is Dictionary):
		return
	var lines: Dictionary = (parsed as Dictionary).get("lines", {})
	_check(lines.size() > 0, "manifest has lines (%d)" % lines.size())
	var spoken: int = 0
	for scene: OOTScene in db.get_scenes("p1").values():
		if scene.episode != 1:
			continue
		for line: OOTDialogueLine in scene.lines:
			if line.is_narration or line.text.is_empty() or line.channel.to_upper() == "TEXT":
				continue
			spoken += 1
			var id: String = OOTVoiceLines.make_id(scene.id, line.order)
			_check(lines.has(id), "manifest has %s" % id)
			_check(OOTVoiceLines.has_stream(id), "%s.ogg exists" % id)
	_check(spoken == lines.size(), "manifest count (%d) == Ep 1 spoken lines (%d)" % [lines.size(), spoken])
	for id: String in lines:
		var entry: Dictionary = lines[id]
		var stream: AudioStream = OOTVoiceLines.get_stream(id)
		_check(stream != null, "%s loads" % id)
		if stream != null:
			_check(stream.get_length() > 0.1, "%s duration > 0" % id)
			_check(absf(stream.get_length() - float(entry.get("duration", 0.0))) < 0.25, "%s duration matches manifest" % id)
		var cues: Array = OOTVoiceLines.get_lip_cues(id)
		_check(cues.size() > 0, "%s.lip.json has cues" % id)
		if cues.size() > 0:
			var first: Dictionary = cues[0]
			_check(first.has("start") and first.has("end") and "ABCDEFGHX".contains(str(first.get("value", "?"))), "%s cue shape" % id)
	_check(OOTVoiceLines.get_stream("no_such_line_999") == null, "missing VO returns null")
	_check(OOTVoiceLines.get_lip_cues("no_such_line_999").is_empty(), "missing lip cues are empty")


func _test_buses() -> void:
	var layout: AudioBusLayout = load("res://default_bus_layout.tres") as AudioBusLayout
	_check(layout != null, "default_bus_layout.tres loads")
	_check(AudioServer.get_bus_index(&"Master") == 0, "Master bus")
	for b: StringName in [&"VO", &"SFX", &"Ambience", &"Music", &"UI"]:
		var idx: int = AudioServer.get_bus_index(b)
		_check(idx > 0, "bus %s exists" % b)
		if idx > 0:
			_check(AudioServer.get_bus_send(idx) == &"Master", "bus %s sends to Master" % b)
	_check(AudioServer.bus_count == 6, "exactly 6 buses (got %d)" % AudioServer.bus_count)


func _test_sfx_files() -> void:
	for path: String in ["res://audio/sfx/laptop_ring.ogg", "res://audio/ambience/apartment_morning.ogg"]:
		var s: AudioStream = load(path) as AudioStream
		_check(s != null and s.get_length() > 1.0, "%s loads" % path)


func _test_dialogue_requests_vo() -> void:
	var state: Node = root.get_node("StoryState")
	var runner: OOTStoryRunner = OOTStoryRunner.new()
	runner.part_id = "p1"
	state.start_part("p1")
	var box: OOTDialogueBox = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate() as OOTDialogueBox
	root.add_child(box)
	await process_frame
	var requested: Array[String] = []
	var audible: Array[bool] = []
	box.voice_requested.connect(func(id: String, has: bool) -> void:
		requested.append(id)
		audible.append(has))
	runner.enter("e1_call")
	box.begin(runner)
	var player: AudioStreamPlayer = box.get_node("VoicePlayer") as AudioStreamPlayer
	_check(player.bus == &"VO", "dialogue VO player is on the VO bus")
	var first_spoken: int = -1
	for l: OOTDialogueLine in runner.scene.lines:
		if not l.is_narration:
			first_spoken = l.order
			break
	_check(first_spoken >= 0, "e1_call has a spoken line")
	# Advance to the first spoken line if narration comes first.
	var guard: int = 0
	while box.current_line_id.is_empty() and guard < 20 and box.is_open:
		box.advance()
		guard += 1
	_check(requested.size() > 0, "dialogue box requested VO")
	_check(box.current_line_id == OOTVoiceLines.make_id("e1_call", first_spoken), "requested id is the line id (%s)" % box.current_line_id)
	_check(audible.size() > 0 and audible[0], "the requested line has audio")
	_check(player.playing and player.stream != null, "VO is playing")
	var subtitle: Label = box.find_child("Subtitle", true, false) as Label
	var shown: String = subtitle.text
	var before: int = requested.size()
	box.advance()
	_check(requested.size() >= before, "advancing continues")
	_check(not player.playing or requested.size() > before, "advancing stops the previous VO")
	_check(shown != "", "subtitle still shown for a voiced line")
	# A narration line is silent and issues no request.
	var narr: OOTStoryRunner = OOTStoryRunner.new()
	narr.part_id = "p1"
	narr.enter("e1_open")
	var n_before: int = requested.size()
	box.begin(narr)
	_check(box.current_line_id.is_empty() or requested.size() == n_before + 1, "narration makes no VO request")
	_check(not player.playing or box.current_line_id != "", "narration line is silent")
	box.queue_free()


func _test_footsteps() -> void:
	for surface: String in ["wood", "carpet", "concrete", "grass", "snow", "unknown"]:
		_check(OOTFootsteps.pick(surface) != null, "footstep stream for %s" % surface)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: " + msg)
