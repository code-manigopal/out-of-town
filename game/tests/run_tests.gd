extends SceneTree
## Headless tests. Run:
##   godot --headless --path game --script res://tests/run_tests.gd
## Exits with code 1 on any failure.

const MAX_STEPS: int = 5000

# Autoload singletons are not compile-time identifiers in a --script SceneTree,
# so fetch them from the tree (untyped Node, dynamic calls).
var StoryState: Node
var StoryDB: Node
var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	var state: Node = root.get_node_or_null("StoryState")
	var db: Node = root.get_node_or_null("StoryDB")
	StoryState = state
	StoryDB = db
	_check(state != null and db != null, "autoloads StoryState and StoryDB are registered")
	if state != null and db != null:
		# Autoload _ready() may not have run yet inside _initialize(); loading is idempotent.
		_check(StoryDB.load_all(), "StoryDB.load_all")
		_test_loading()
		_test_targets()
		_test_state()
		_test_conditions()
		_test_save_load()
		_test_walk()
		# Scene tests need nodes to be ready, which happens once the tree runs a frame.
		await process_frame
		_test_g1_apartment()
		_test_g1_call()
		_test_g1_inputs_and_flow()
		_test_mani_model()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		return
	_failures += 1
	printerr("FAIL: " + msg)


func _test_loading() -> void:
	for pid: String in ["p1", "p2"]:
		_check(StoryDB.has_part(pid), "%s loaded" % pid)
		_check(StoryDB.get_scene_count(pid) > 0, "%s has scenes (%d)" % [pid, StoryDB.get_scene_count(pid)])
		_check(StoryDB.get_episodes(pid).size() == 8, "%s has 8 episodes" % pid)
		for ep: int in range(1, 9):
			_check(StoryDB.has_scene(pid, StoryDB.get_episode_start(pid, ep)), "%s ep %d start resolves" % [pid, ep])
	var open: OOTScene = StoryDB.get_scene("p1", "e1_open")
	_check(open != null and open.lines.size() > 0, "e1_open has lines")
	var tanglish: OOTDialogueLine = open.lines[1]
	_check(not tanglish.text.is_empty() and not tanglish.subtitle.is_empty(), "Tanglish line has text and subtitle")
	var narr: OOTDialogueLine = open.lines[0]
	_check(narr.is_narration and narr.get_subtitle().is_empty(), "narration has no subtitle")
	var plain: OOTDialogueLine = OOTDialogueLine.new()
	plain.text = "Hello."
	_check(plain.get_subtitle() == "Hello.", "spoken line with empty subtitle falls back to text")


func _test_targets() -> void:
	for pid: String in ["p1", "p2"]:
		for sid: String in StoryDB.get_scenes(pid):
			var s: OOTScene = StoryDB.get_scene(pid, sid)
			var targets: Array[String] = []
			for c: OOTChoice in s.choices:
				if not c.dynamic_target:
					targets.append(c.target_scene)
			targets.append_array([s.next_scene, s.timer_target, str(s.puzzle.get("to", "")), str(s.combat.get("to", "")), str(s.combat.get("cleanTo", "") if s.combat.get("cleanTo") != null else "")])
			for t: String in targets:
				if t.is_empty():
					continue
				_check(StoryDB.has_scene(pid, t), "%s: %s -> %s resolves" % [pid, sid, t])


func _test_state() -> void:
	StoryState.start_part("p1")
	_check(StoryState.get_part() == "p1", "start_part sets part")
	StoryState.set_flag("x")
	_check(StoryState.has_flag("x"), "set_flag")
	StoryState.set_flag("x", false)
	_check(not StoryState.has_flag("x"), "clear flag")
	StoryState.add_trust("ruth", 5)
	_check(StoryState.get_trust("ruth") == 3, "trust clamps at 3")
	StoryState.add_trust("ruth", -9)
	_check(StoryState.get_trust("ruth") == -3, "trust clamps at -3")
	StoryState.add_danger(9)
	_check(StoryState.get_danger() == 5, "danger clamps at 5")
	StoryState.add_danger(-9)
	_check(StoryState.get_danger() == 0, "danger clamps at 0")
	_check(StoryState.add_clue("voicemail"), "add_clue first time")
	_check(not StoryState.add_clue("voicemail"), "add_clue duplicate returns false")
	_check(StoryState.has_clue("voicemail"), "has_clue")
	StoryState.set_nila_health(250)
	_check(StoryState.get_nila_health() == 100, "nila health clamps")
	StoryState.apply_fx({"flag": "f1", "clue": ["cooler"], "trust": {"ruth": 1}, "danger": 1, "set": {"a": "b"}, "add": {"n": 2}})
	_check(StoryState.has_flag("f1") and StoryState.has_clue("cooler") and StoryState.get_danger() == 1, "apply_fx")
	_check(StoryState.get_var("a") == "b" and StoryState.get_var("n") == 2, "apply_fx vars")
	var seen: Array[String] = []
	StoryState.clue_added.connect(func(id: String) -> void: seen.append(id))
	StoryState.add_clue("lab")
	_check(seen == ["lab"], "clue_added signal")
	StoryState.start_part("p1")
	_check(StoryState.clues.is_empty() and StoryState.flags.is_empty() and StoryState.get_danger() == 0, "start_part resets")


func _test_conditions() -> void:
	StoryState.start_part("p1")
	var req: Dictionary = {"flags": ["a"], "clues": ["voicemail"], "notFlags": ["b"]}
	_check(not StoryDB.evaluate_requirements(req), "requirements unmet")
	StoryState.set_flag("a")
	StoryState.add_clue("voicemail")
	_check(StoryDB.evaluate_requirements(req), "requirements met")
	StoryState.set_flag("b")
	_check(not StoryDB.evaluate_requirements(req), "notFlags blocks")


func _test_save_load() -> void:
	StoryState.start_part("p2")
	StoryState.set_flag("saved_flag")
	StoryState.add_trust("preethi", 2)
	StoryState.add_danger(3)
	StoryState.add_clue("c1")
	StoryState.set_nila_health(42)
	StoryState.set_var("k", 7)
	StoryState.set_scene("some_scene")
	_check(StoryState.save_game("test") == OK, "save_game")
	StoryState.start_part("p1")
	_check(StoryState.load_game("test") == OK, "load_game")
	_check(StoryState.get_part() == "p2" and StoryState.scene == "some_scene", "round-trip part/scene")
	_check(StoryState.has_flag("saved_flag") and StoryState.get_trust("preethi") == 2, "round-trip flags/trust")
	_check(StoryState.get_danger() == 3 and StoryState.has_clue("c1") and StoryState.get_nila_health() == 42, "round-trip danger/clues/health")
	_check(int(StoryState.get_var("k")) == 7, "round-trip vars")
	StoryState.delete_save("test")
	_check(not StoryState.has_save("test"), "delete_save")


func _test_walk() -> void:
	for pid: String in ["p1", "p2"]:
		var runner: OOTStoryRunner = OOTStoryRunner.new()
		var start_id: String = "e1_open" if pid == "p1" else StoryDB.get_episode_start(pid, 1)
		_check(runner.start(pid, 1), "%s: start" % pid)
		_check(runner.scene.id == start_id, "%s: starts at %s" % [pid, start_id])
		var steps: int = 0
		var reached_later: bool = false
		while steps < MAX_STEPS and not runner.finished:
			steps += 1
			if runner.scene.episode > 1:
				reached_later = true
				break
			var ok: bool = false
			var avail: Array[OOTChoice] = []
			for c: OOTChoice in runner.get_choices():
				if StoryDB.is_choice_available(c):
					avail.append(c)
			if not avail.is_empty():
				ok = runner.choose(avail[0])
			else:
				ok = runner.continue_story()
			if not ok:
				break
		_check(reached_later or runner.finished, "%s: walk reached a later episode or an end (%d steps, at %s)" % [pid, steps, runner.scene.id])
		_check(steps < MAX_STEPS, "%s: walk finished under step cap" % pid)


# --- G1: Mani's apartment -----------------------------------------------------

func _make_apartment() -> OOTApartment:
	var packed: PackedScene = load("res://scenes/p1/e1/apartment.tscn")
	var apt: OOTApartment = packed.instantiate() as OOTApartment
	apt.play_intro = false
	root.add_child(apt)
	return apt


func _test_g1_apartment() -> void:
	StoryState.start_part("p1")
	var apt: OOTApartment = _make_apartment()
	_check(apt != null, "apartment.tscn instantiates")
	if apt == null:
		return
	_check(apt.player != null and apt.laptop != null and apt.duffel != null, "apartment has player, laptop and duffel")
	var puzzle: Dictionary = StoryDB.get_scene("p1", "e1_apt").puzzle
	_check(str(puzzle.get("type")) == "search" and str(puzzle.get("title")) == "Pack for Greyhaven", "e1_apt is the Pack for Greyhaven search puzzle")
	_check(str(puzzle.get("to")) == "e1_call", "e1_apt puzzle leads to e1_call")
	var items: Array[OOTInteractable] = apt.get_pack_items()
	var need: int = int(puzzle.get("need", 3))
	_check(items.size() == 3 and items.size() == need, "3 packing targets exist (puzzle need = %d)" % need)
	var ids: Array[String] = []
	for it: OOTInteractable in items:
		ids.append(it.item_id)
		_check(it.kind == OOTInteractable.Kind.PICKUP, "%s is a pickup" % it.item_id)
	ids.sort()
	_check(ids == ["diyas", "radio", "sweets"], "packing targets are sweets, diyas, radio")
	if puzzle.get("spots") is Array:
		for it: OOTInteractable in items:
			_check(not it.get_caption().is_empty(), "%s caption comes from e1_apt spots" % it.item_id)
	# Packing API and the ring.
	var rings: Array[int] = [0]
	apt.laptop_ringing.connect(func() -> void: rings[0] += 1)
	_check(not apt.is_ringing, "laptop is quiet before packing")
	_check(apt.pack_item("sweets") and apt.get_packed_count() == 1, "pack sweets 1/3")
	_check(not apt.pack_item("sweets"), "cannot pack the same item twice")
	_check(not apt.pack_item("nothing"), "unknown item is rejected")
	_check(apt.pack_item("diyas") and not apt.is_ringing, "pack diyas 2/3, still quiet")
	_check(apt.pack_item("radio") and apt.get_packed_count() == 3, "pack radio 3/3")
	_check(apt.is_ringing and rings[0] == 1, "third item makes the laptop ring (once)")
	_check(apt.laptop.kind == OOTInteractable.Kind.USE, "ringing laptop can be answered")
	_check(apt.auto_answer_seconds == 90.0, "laptop auto-answers after 90 s")
	apt.queue_free()


func _test_g1_call() -> void:
	for option: int in [0, 1]:
		StoryState.start_part("p1")
		var runner: OOTStoryRunner = OOTStoryRunner.new()
		runner.part_id = "p1"
		runner.enter("e1_apt")
		var trigger: OOTStoryTrigger = OOTStoryTrigger.new()
		trigger.runner = runner
		trigger.scene_id = "e1_call"
		trigger.stop_scene_id = "e1_road"
		var reached: Array[String] = []
		trigger.target_reached.connect(func(id: String) -> void: reached.append(id))
		_check(trigger.fire() and runner.scene.id == "e1_call", "trigger starts e1_call from the puzzle (option %d)" % option)
		var choices: Array[OOTChoice] = runner.get_choices()
		_check(choices.size() == 2, "e1_call offers two honesty choices")
		_check(runner.choose(choices[option]) and runner.scene.id == "e1_call2", "choice %d leads to e1_call2" % option)
		_check(runner.continue_story() and runner.scene.id == "e1_road", "e1_call2 continues to e1_road")
		_check(reached == ["e1_road"], "trigger reports e1_road reached")
		var expected: String = "reassure" if option == 0 else "half"
		_check(str(StoryState.get_var("call1")) == expected, "call1 = %s stored" % expected)
		_check(StoryState.has_flag("honest1") == (option == 1), "honest1 flag matches option %d" % option)
		trigger.free()


func _test_g1_inputs_and_flow() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "jog", "interact", "journal", "pause"]:
		_check(InputMap.has_action(action), "input action %s exists" % action)
	_check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/p1/e1/episode_01.tscn", "main scene is episode_01")
	_check(load("res://ui/dialogue/dialogue_test.tscn") != null, "dialogue_test.tscn still loads")
	# Dialogue box drives the call to the stop scene without input.
	StoryState.start_part("p1")
	var runner: OOTStoryRunner = OOTStoryRunner.new()
	runner.part_id = "p1"
	runner.enter("e1_call")
	var box: OOTDialogueBox = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate() as OOTDialogueBox
	root.add_child(box)
	var done: Array[String] = []
	box.finished.connect(func(id: String) -> void: done.append(id))
	box.begin(runner, "e1_road")
	_check(box.is_open, "dialogue box opens")
	var guard: int = 0
	while box.is_open and runner.scene.id == "e1_call" and guard < 50:
		box.advance()
		guard += 1
	_check(runner.scene.id == "e1_call" and box.is_open, "dialogue box waits on the honesty choice")
	runner.choose(runner.get_choices()[1])
	guard = 0
	while box.is_open and guard < 50:
		box.advance()
		guard += 1
	_check(done == ["e1_road"] and not box.is_open, "dialogue box closes at e1_road")
	box.queue_free()
	# Episode flow starts on the cold open.
	var ep: OOTEpisode01 = (load("res://scenes/p1/e1/episode_01.tscn") as PackedScene).instantiate() as OOTEpisode01
	root.add_child(ep)
	_check(ep.stage == "cold_open" and ep.runner.scene.id == "e1_open", "episode_01 starts at e1_open")
	_check(ep.title_text() == "OUT OF TOWN: GREYHAVEN", "title card text")
	_check(ep.episode_text() == "EPISODE 1 \u2014 COUNTY ROADS", "episode card text")
	ep.queue_free()


func _test_mani_model() -> void:
	var packed: PackedScene = load("res://characters/mani/mani.glb") as PackedScene
	_check(packed != null, "mani.glb loads as a PackedScene")
	if packed == null:
		return
	var inst: Node3D = packed.instantiate() as Node3D
	_check(inst != null, "mani.glb instantiates")
	if inst == null:
		return
	root.add_child(inst)
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(skel != null and skel.get_bone_count() >= 50, "mani has a skeleton (game-engine rig)")
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check(ap != null, "mani has an AnimationPlayer")
	if ap != null:
		for clip: String in ["idle", "walk", "jog"]:
			_check(ap.has_animation(clip), "mani has the %s animation" % clip)
		if ap.has_animation("walk"):
			var len: float = ap.get_animation("walk").length
			_check(absf(len - 1.0) < 0.05, "walk loop is 1.0 s (%.3f)" % len)
		if ap.has_animation("idle"):
			_check(absf(ap.get_animation("idle").length - 4.0) < 0.05, "idle loop is 4 s")
	inst.queue_free()
	var player_scene: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	var pl: OOTPlayer = player_scene.instantiate() as OOTPlayer
	root.add_child(pl)
	await process_frame
	_check(pl.anim != null, "player finds Mani's AnimationPlayer")
	pl.queue_free()
