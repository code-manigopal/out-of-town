class_name OOTStoryRunner
extends RefCounted
## Walks the scene graph: enters scenes (applying scene effects), takes choices
## (applying choice effects), and resolves where a scene continues to.
## Used by the dialogue UI and the headless tests.

signal scene_entered(scene: OOTScene)
signal story_ended(ending: String)

var part_id: String = ""
var scene: OOTScene = null
var finished: bool = false

# Autoloads are looked up at runtime (not as compile-time identifiers) so this
# class also compiles inside a --script SceneTree such as tests/run_tests.gd.
var _state: Node
var _db: Node


func _init() -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	_state = root.get_node("StoryState")
	_db = root.get_node("StoryDB")


## Starts a fresh playthrough of a part at the start of an episode.
func start(p_part_id: String, episode: int = 1) -> bool:
	part_id = p_part_id
	finished = false
	_state.start_part(p_part_id)
	return enter(_db.get_episode_start(p_part_id, episode))


## Enters a scene without resetting state (e.g. after load_game).
func enter(scene_id: String) -> bool:
	var s: OOTScene = _db.get_scene(part_id, scene_id)
	if s == null:
		push_error("OOTStoryRunner: missing scene '%s'" % scene_id)
		return false
	scene = s
	_state.set_scene(s.id)
	_state.apply_fx(s.fx)
	scene_entered.emit(s)
	if s.is_ending():
		finished = true
		story_ended.emit(s.ending)
	return true


## Takes a choice: marks once-choices, applies effects, follows the target.
func choose(choice: OOTChoice) -> bool:
	if not _db.is_choice_available(choice):
		return false
	if not choice.once.is_empty():
		_state.set_flag("once_" + choice.once)
	_state.apply_fx(choice.fx)
	return enter(choice.target_scene)


## Timer expiry: applies the timer effects and follows the timeout target.
func time_out() -> bool:
	if scene == null or scene.timer_target.is_empty():
		return false
	_state.apply_fx(scene.timer_fx)
	return enter(scene.timer_target)


## Where the scene goes when it offers no choice (puzzle skip, combat win,
## next, or the following episode's start). Empty string means the story ends here.
func get_continue_target() -> String:
	if scene == null:
		return ""
	if not scene.puzzle.is_empty():
		return str(scene.puzzle.get("to", ""))
	if not scene.combat.is_empty():
		return str(scene.combat.get("to", ""))
	if scene.is_episode_end:
		return _db.get_episode_start(part_id, scene.episode + 1)
	return scene.next_scene


## Puzzle effects (applied when the puzzle is passed or skipped).
func continue_story() -> bool:
	var target: String = get_continue_target()
	if target.is_empty():
		finished = true
		story_ended.emit(scene.ending if scene != null else "")
		return false
	if scene != null and not scene.puzzle.is_empty():
		_state.apply_fx(scene.puzzle.get("fx"))
	return enter(target)


## Choices to show. Puzzles and combat replace choices, as in the prototype.
func get_choices() -> Array[OOTChoice]:
	if scene == null or not scene.puzzle.is_empty() or not scene.combat.is_empty():
		return []
	return _db.get_visible_choices(scene)
