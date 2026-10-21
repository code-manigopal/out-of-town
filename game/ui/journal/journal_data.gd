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
const SECTIONS: Array[String] = ["goal", "people", "clues", "notes"]
const SECTION_TITLES: Dictionary = {
	"goal": "Current goal", "people": "People", "clues": "Clues", "notes": "Notes",
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


## Adds the entry (and any "adds") to StoryState. True if anything new was added.
static func grant(entry_id: String) -> bool:
	var st: Node = OOTServices.state()
	if st == null or entry_id.is_empty():
		return false
	var added: bool = st.journal_add(entry_id)
	for extra: Variant in get_entry(entry_id).get("adds", []):
		if st.journal_add(str(extra)):
			added = true
	return added
