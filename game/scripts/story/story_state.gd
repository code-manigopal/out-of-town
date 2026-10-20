extends Node
## Story state for the current part: flags, trust per character, danger (0-5),
## clues and proof, and Nila's health. Port of UOOTStorySubsystem; mirrors the
## browser prototype's state model (prototype/browser/engine.js).
## Autoload name: StoryState.

signal part_started(part_id: String)
signal flag_changed(flag: String, value: bool)
signal trust_changed(character: String, value: int)
signal clue_added(clue_id: String)
signal danger_changed(new_danger: int)
signal nila_health_changed(value: int)

const TRUST_MIN: int = -3
const TRUST_MAX: int = 3
const DANGER_MIN: int = 0
const DANGER_MAX: int = 5
## Prototype clamps health changes to 3..100; direct sets accept 0..100.
const HEALTH_MIN: int = 0
const HEALTH_MAX: int = 100
const HEALTH_DELTA_MIN: int = 3
const SAVE_VERSION: int = 1

var part: String = ""
var scene: String = ""
var flags: Dictionary = {}   # String -> true
var trust: Dictionary = {}   # String -> int
var danger: int = 0
var clues: Array[String] = []
var nila_health: int = 100
var vars: Dictionary = {}    # prototype "vars" (set / add effects)


## Clears all state for a new playthrough of a part ("p1" or "p2").
func start_part(part_id: String) -> void:
	part = part_id
	scene = ""
	flags.clear()
	trust.clear()
	clues.clear()
	vars.clear()
	danger = 0
	nila_health = 100
	# Mirrors part.init in prototype/browser/part1.js and part2.js.
	if part_id == "p1":
		vars["rounds"] = 6
	part_started.emit(part_id)


func get_part() -> String:
	return part


func set_scene(scene_id: String) -> void:
	scene = scene_id


# Flags
func set_flag(flag: String, value: bool = true) -> void:
	var had: bool = flags.has(flag)
	if value:
		flags[flag] = true
	else:
		flags.erase(flag)
	if had != value:
		flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return flags.has(flag)


# Trust (-3 to 3)
func add_trust(character: String, delta: int) -> void:
	var value: int = clampi(get_trust(character) + delta, TRUST_MIN, TRUST_MAX)
	trust[character] = value
	trust_changed.emit(character, value)


func get_trust(character: String) -> int:
	return int(trust.get(character, 0))


# Danger (0 to 5)
func add_danger(delta: int) -> void:
	var old: int = danger
	danger = clampi(danger + delta, DANGER_MIN, DANGER_MAX)
	if danger != old:
		danger_changed.emit(danger)


func get_danger() -> int:
	return danger


# Clues and proof
func add_clue(clue_id: String) -> bool:
	if clues.has(clue_id):
		return false
	clues.append(clue_id)
	clue_added.emit(clue_id)
	return true


func has_clue(clue_id: String) -> bool:
	return clues.has(clue_id)


func get_clues() -> Array[String]:
	return clues


## Number of held clues that StoryDB marks as proof.
func get_proof_count() -> int:
	var count: int = 0
	for clue_id: String in clues:
		if StoryDB.is_proof(part, clue_id):
			count += 1
	return count


# Nila's health (story clock, 0 to 100)
func set_nila_health(value: int) -> void:
	var v: int = clampi(value, HEALTH_MIN, HEALTH_MAX)
	if v != nila_health:
		nila_health = v
		nila_health_changed.emit(v)


func get_nila_health() -> int:
	return nila_health


# Prototype vars (fx.set / fx.add)
func set_var(key: String, value: Variant) -> void:
	vars[key] = value


func add_var(key: String, delta: int) -> void:
	vars[key] = int(vars.get(key, 0)) + delta


func get_var(key: String, default: Variant = null) -> Variant:
	return vars.get(key, default)


## Applies a prototype effect object (flag, unflag, clue, trust, danger,
## health, setHealth, set, add). Inventory keys (hp, ammo, grenades, trunk,
## medkits, restock, heal) belong to the combat layer and are ignored here.
func apply_fx(fx: Variant) -> void:
	if not fx is Dictionary:
		return
	var d: Dictionary = fx
	for f: Variant in _as_array(d.get("flag")):
		set_flag(str(f), true)
	for f: Variant in _as_array(d.get("unflag")):
		set_flag(str(f), false)
	for c: Variant in _as_array(d.get("clue")):
		add_clue(str(c))
	var t: Variant = d.get("trust")
	if t is Dictionary:
		for who: Variant in (t as Dictionary):
			add_trust(str(who), int((t as Dictionary)[who]))
	if d.has("danger"):
		add_danger(int(d["danger"]))
	if d.has("health"):
		set_nila_health(clampi(nila_health + int(d["health"]), HEALTH_DELTA_MIN, HEALTH_MAX))
	if d.has("setHealth"):
		set_nila_health(int(d["setHealth"]))
	var s: Variant = d.get("set")
	if s is Dictionary:
		for k: Variant in (s as Dictionary):
			set_var(str(k), (s as Dictionary)[k])
	var a: Variant = d.get("add")
	if a is Dictionary:
		for k: Variant in (a as Dictionary):
			add_var(str(k), int((a as Dictionary)[k]))


func _as_array(v: Variant) -> Array:
	if v == null:
		return []
	if v is Array:
		return v
	return [v]


# Save / load
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"part": part,
		"scene": scene,
		"flags": flags.keys(),
		"trust": trust,
		"danger": danger,
		"clues": clues,
		"nila_health": nila_health,
		"vars": vars,
	}


func from_dict(data: Dictionary) -> void:
	part = str(data.get("part", ""))
	scene = str(data.get("scene", ""))
	flags.clear()
	for f: Variant in data.get("flags", []):
		flags[str(f)] = true
	trust.clear()
	var t: Dictionary = data.get("trust", {})
	for k: Variant in t:
		trust[str(k)] = int(t[k])
	danger = int(data.get("danger", 0))
	clues.clear()
	for c: Variant in data.get("clues", []):
		clues.append(str(c))
	nila_health = int(data.get("nila_health", 100))
	vars = (data.get("vars", {}) as Dictionary).duplicate(true)


func save_path(slot: Variant) -> String:
	return "user://save_%s.json" % str(slot)


func save_game(slot: Variant = 1) -> Error:
	var file: FileAccess = FileAccess.open(save_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


func has_save(slot: Variant = 1) -> bool:
	return FileAccess.file_exists(save_path(slot))


func load_game(slot: Variant = 1) -> Error:
	if not has_save(slot):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path(slot)))
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	from_dict(parsed)
	return OK


func delete_save(slot: Variant = 1) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(save_path(slot))
