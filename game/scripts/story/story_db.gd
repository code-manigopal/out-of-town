extends Node
## Loads the exported story JSON (res://data/story/pN_scenes.json) and answers
## queries about parts, episodes, scenes, lines and choices. Choice conditions
## are evaluated against StoryState. Autoload name: StoryDB.

const PART_IDS: Array[String] = ["p1", "p2"]
const DATA_DIR: String = "res://data/story/"

var _parts: Dictionary = {}    # part_id -> meta Dictionary (name, episodes, people, clues)
var _scenes: Dictionary = {}   # part_id -> { scene_id -> OOTScene }


func _ready() -> void:
	load_all()


## Loads every part. Returns true when all parts loaded.
func load_all() -> bool:
	var ok: bool = true
	for pid: String in PART_IDS:
		ok = load_part(pid) and ok
	return ok


func load_part(part_id: String) -> bool:
	var path: String = "%s%s_scenes.json" % [DATA_DIR, part_id]
	if not FileAccess.file_exists(path):
		push_error("StoryDB: missing %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("StoryDB: cannot parse %s" % path)
		return false
	var root: Dictionary = parsed
	_parts[part_id] = root.get("part", {})
	var table: Dictionary = {}
	var raw: Dictionary = root.get("scenes", {})
	for sid: Variant in raw:
		table[str(sid)] = OOTScene.from_dict(raw[sid])
	_scenes[part_id] = table
	return true


func has_part(part_id: String) -> bool:
	return _scenes.has(part_id)


func get_part_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: Variant in _parts:
		ids.append(str(k))
	return ids


func get_part_name(part_id: String) -> String:
	return str((_parts.get(part_id, {}) as Dictionary).get("name", part_id))


## Episode dictionaries: title, start, blurb. Index 0 is episode 1.
func get_episodes(part_id: String) -> Array:
	return (_parts.get(part_id, {}) as Dictionary).get("episodes", [])


func get_episode_start(part_id: String, episode: int) -> String:
	var eps: Array = get_episodes(part_id)
	if episode < 1 or episode > eps.size():
		return ""
	return str((eps[episode - 1] as Dictionary).get("start", ""))


func get_people(part_id: String) -> Dictionary:
	return (_parts.get(part_id, {}) as Dictionary).get("people", {})


func get_clue(part_id: String, clue_id: String) -> Dictionary:
	var clues: Dictionary = (_parts.get(part_id, {}) as Dictionary).get("clues", {})
	return clues.get(clue_id, {})


func is_proof(part_id: String, clue_id: String) -> bool:
	return bool(get_clue(part_id, clue_id).get("proof", false))


# Scenes
func get_scenes(part_id: String) -> Dictionary:
	return _scenes.get(part_id, {})


func get_scene_count(part_id: String) -> int:
	return get_scenes(part_id).size()


func has_scene(part_id: String, scene_id: String) -> bool:
	return get_scenes(part_id).has(scene_id)


func get_scene(part_id: String, scene_id: String) -> OOTScene:
	return get_scenes(part_id).get(scene_id) as OOTScene


func get_lines(part_id: String, scene_id: String) -> Array[OOTDialogueLine]:
	var s: OOTScene = get_scene(part_id, scene_id)
	return s.lines if s != null else ([] as Array[OOTDialogueLine])


## All choices of a scene regardless of availability.
func get_choices(part_id: String, scene_id: String) -> Array[OOTChoice]:
	var s: OOTScene = get_scene(part_id, scene_id)
	return s.choices if s != null else ([] as Array[OOTChoice])


## Choices to display: drops once-choices already taken. Locked ones stay listed
## (check is_choice_available) like the prototype.
func get_visible_choices(scene: OOTScene) -> Array[OOTChoice]:
	var out: Array[OOTChoice] = []
	for c: OOTChoice in scene.choices:
		if not c.once.is_empty() and StoryState.has_flag("once_" + c.once):
			continue
		out.append(c)
	return out


func get_available_choices(scene: OOTScene) -> Array[OOTChoice]:
	var out: Array[OOTChoice] = []
	for c: OOTChoice in get_visible_choices(scene):
		if is_choice_available(c):
			out.append(c)
	return out


func is_choice_available(choice: OOTChoice) -> bool:
	return evaluate_requirements(choice.req)


## Mirrors reqMet() in prototype/browser/engine.js for declarative conditions.
## Function-based ("dynamic") conditions cannot be exported and count as met.
func evaluate_requirements(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	for f: Variant in req.get("flags", []):
		if not StoryState.has_flag(str(f)):
			return false
	for f: Variant in req.get("notFlags", []):
		if StoryState.has_flag(str(f)):
			return false
	for c: Variant in req.get("clues", []):
		if not StoryState.has_clue(str(c)):
			return false
	if req.has("proofs") and StoryState.get_proof_count() < int(req["proofs"]):
		return false
	return true


func get_locked_reason(choice: OOTChoice) -> String:
	return choice.locked_reason if not choice.locked_reason.is_empty() else "not yet"
