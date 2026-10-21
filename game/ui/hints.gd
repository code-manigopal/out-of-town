class_name OOTHints
extends RefCounted
## Player hints and short toasts, loaded from data/ui/p1_hints.json (never hard-code them in scenes).
##   OOTHints.text("need_car_keys")            -> "I need my car keys."
##   OOTHints.fmt("picked_up", ["Duffel bag"]) -> "Picked up: Duffel bag"
## An unknown id returns the id itself, so a missing string is visible instead of blank.

const PATHS: Array[String] = ["res://data/ui/p1_hints.json"]

static var _hints: Dictionary = {}
static var _loaded: bool = false


static func reload() -> void:
	_hints.clear()
	for path: String in PATHS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for k: Variant in (parsed as Dictionary):
				if not str(k).begins_with("_"):
					_hints[str(k)] = str((parsed as Dictionary)[k])
	_loaded = true


static func has(id: String) -> bool:
	if not _loaded:
		reload()
	return _hints.has(id)


static func text(id: String) -> String:
	if not _loaded:
		reload()
	return str(_hints.get(id, id))


## text(id) with printf-style args (%s).
static func fmt(id: String, args: Array) -> String:
	return text(id) % args


## The keyboard key bound to an input action (e.g. "phone" -> "P"); the action name if it has none.
static func key_name(action: String) -> String:
	if InputMap.has_action(action):
		for e: InputEvent in InputMap.action_get_events(action):
			if e is InputEventKey:
				return OS.get_keycode_string((e as InputEventKey).physical_keycode)
	return action
