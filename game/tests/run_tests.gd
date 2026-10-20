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
