class_name OOTJournalData
extends RefCounted
## Loads the journal text (data/journal/pN_journal.json). Schema, one object
## per entry id:
##   { "section": "goal|people|clues|notes", "title": str, "text": str,
##     "subtitle": str (English for Tanglish text, optional), "episode": int,
##     "draft": bool (placeholder, not final copy),
##     "item": str (optional: interactable item_id that grants this entry),
##     "adds": [entry ids granted along with this one] }

const PATHS: Array[String] = ["res://data/journal/p1_journal.json"]
## Journal (J) sections. "goal" entries are not a journal tab: they become phone objectives (OBJECTIVE_SECTION).
const SECTIONS: Array[String] = ["people", "clues", "notes"]
const OBJECTIVE_SECTION: String = "goal"
const SECTION_TITLES: Dictionary = {
	"goal": "Objectives", "people": "People", "clues": "Clues", "notes": "Notes",
}

static var _entries: Dictionary = {}
static var _loaded: bool = false


static func reload() -> void:
	_entries.clear()
	for path: String in PATHS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for k: Variant in (parsed as Dictionary):
				if not str(k).begins_with("_") and (parsed as Dictionary)[k] is Dictionary:
					_entries[str(k)] = (parsed as Dictionary)[k]
	_loaded = true


static func all_entries() -> Dictionary:
	if not _loaded:
		reload()
	return _entries


## The entry's data, or {} if the id is unknown.
static func get_entry(entry_id: String) -> Dictionary:
	return all_entries().get(entry_id, {})


static func entry_for_item(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	var all: Dictionary = all_entries()
	for id: Variant in all:
		if str((all[id] as Dictionary).get("item", "")) == item_id:
			return str(id)
	return ""


## True if the entry is a goal (an objective, not a journal page).
static func is_objective(entry_id: String) -> bool:
	return str(get_entry(entry_id).get("section", "")) == OBJECTIVE_SECTION


## Adds the entry (and any "adds") to StoryState. A "goal" entry becomes the current objective instead (the previous
## one is completed). True if anything new was added.
static func grant(entry_id: String) -> bool:
	var st: Node = OOTServices.state()
	if st == null or entry_id.is_empty():
		return false
	var added: bool = false
	if is_objective(entry_id):
		added = st.objective_set(entry_id)
	else:
		added = st.journal_add(entry_id)
	for extra: Variant in get_entry(entry_id).get("adds", []):
		if is_objective(str(extra)):
			if st.objective_set(str(extra)):
				added = true
		elif st.journal_add(str(extra)):
			added = true
	return added
