class_name OOTStoryTrigger
extends Node
## Starts a story scene through OOTStoryRunner and reports when the runner
## reaches a target scene (or the story ends). Presentation (dialogue box) is
## the listener's job: connect to `started`.

signal started(runner: OOTStoryRunner)
signal target_reached(scene_id: String)
signal story_ended(ending: String)

@export var part_id: String = "p1"
@export var scene_id: String = ""
## Scene that ends the sequence; the trigger emits target_reached when entered.
@export var stop_scene_id: String = ""

var runner: OOTStoryRunner = null
var active: bool = false


## Starts scene_id. If the runner is parked on a puzzle that leads to it, the
## puzzle is completed (its effects apply); otherwise the scene is entered directly.
func fire() -> bool:
	if scene_id.is_empty():
		return false
	if runner == null:
		runner = OOTStoryRunner.new()
		runner.part_id = part_id
	_connect()
	active = true
	var ok: bool
	if runner.scene != null and not runner.scene.puzzle.is_empty() \
			and str(runner.scene.puzzle.get("to", "")) == scene_id:
		ok = runner.continue_story()
	else:
		ok = runner.enter(scene_id)
	if ok and active:
		started.emit(runner)
	return ok


func _connect() -> void:
	if not runner.scene_entered.is_connected(_on_scene_entered):
		runner.scene_entered.connect(_on_scene_entered)
	if not runner.story_ended.is_connected(_on_story_ended):
		runner.story_ended.connect(_on_story_ended)


func _on_scene_entered(scene: OOTScene) -> void:
	if active and not stop_scene_id.is_empty() and scene.id == stop_scene_id:
		active = false
		target_reached.emit(scene.id)


func _on_story_ended(ending: String) -> void:
	if active:
		active = false
		story_ended.emit(ending)
