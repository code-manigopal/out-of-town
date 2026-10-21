class_name OOTPhoneData
extends RefCounted
## Mani's phone content, loaded from data/phone/p1_phone.json. Schema:
##   threads:  { id: { name, color (#hex), order } }
##   messages: [ { id, thread, from: "me"|"them", time "Fri 18:40", text, subtitle (Tanglish only),
##                 episode, unlock (flag | "clue:<id>" | "journal:<id>" | ""), unread (bool), status ("read"|"delivered"),
##                 design (bool: invented filler) } ]
##   photos:   [ { id, file (res://), title, caption, episode, unlock } ]
##   calls:    [ { id, name, kind: voicemail|missed|incoming|outgoing|video, time, note, episode, unlock,
##                 lines: [VO line ids "<scene>_<NNN>"] (voicemail playback) } ]
## A message also becomes visible when OOTPhone.notify_message delivers it (StoryState.phone_deliver).

const PATHS: Array[String] = ["res://data/phone/p1_phone.json"]
const PART_ID: String = "p1"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func reload() -> void:
	_data = {"threads": {}, "messages": [], "photos": [], "calls": []}
	for path: String in PATHS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			continue
		var d: Dictionary = parsed
		(_data["threads"] as Dictionary).merge(d.get("threads", {}))
		for key: String in ["messages", "photos", "calls"]:
			(_data[key] as Array).append_array(d.get(key, []))
		if d.has("owner"):
			_data["owner"] = d["owner"]
	_loaded = true


static func _ensure() -> void:
	if not _loaded:
		reload()


static func threads() -> Dictionary:
	_ensure()
	return _data["threads"]


static func thread_ids() -> Array[String]:
	_ensure()
	var ids: Array[String] = []
	for k: Variant in (_data["threads"] as Dictionary):
		ids.append(str(k))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(threads()[a].get("order", 0)) < int(threads()[b].get("order", 0)))
	return ids


static func thread(thread_id: String) -> Dictionary:
	return threads().get(thread_id, {})


static func message(message_id: String) -> Dictionary:
	_ensure()
	for m: Variant in (_data["messages"] as Array):
		if str((m as Dictionary).get("id", "")) == message_id:
			return m
	return {}


## True when an unlock condition holds ("" = always).
static func unlocked(unlock: String) -> bool:
	if unlock.is_empty():
		return true
	var st: Node = OOTServices.state()
	if st == null:
		return false
	if unlock.begins_with("clue:"):
		return st.has_clue(unlock.substr(5))
	if unlock.begins_with("journal:"):
		return st.journal_has(unlock.substr(8))
	return st.has_flag(unlock)


static func message_visible(m: Dictionary) -> bool:
	var st: Node = OOTServices.state()
	if st != null and st.phone_is_delivered(str(m.get("id", ""))):
		return true
	return unlocked(str(m.get("unlock", "")))


## Visible messages of a thread, in file order (which is time order).
static func messages(thread_id: String) -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for m: Variant in (_data["messages"] as Array):
		var d: Dictionary = m
		if str(d.get("thread", "")) == thread_id and message_visible(d):
			out.append(d)
	return out


static func is_unread(m: Dictionary) -> bool:
	if str(m.get("from", "them")) != "them":
		return false
	var st: Node = OOTServices.state()
	if st != null and st.phone_is_read(str(m.get("id", ""))):
		return false
	if bool(m.get("unread", false)):
		return true
	return st != null and st.phone_is_delivered(str(m.get("id", "")))


static func unread_count(thread_id: String = "") -> int:
	_ensure()
	var n: int = 0
	for m: Variant in (_data["messages"] as Array):
		var d: Dictionary = m
		if (thread_id.is_empty() or str(d.get("thread", "")) == thread_id) and message_visible(d) and is_unread(d):
			n += 1
	return n


static func photos() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for p: Variant in (_data["photos"] as Array):
		if unlocked(str((p as Dictionary).get("unlock", ""))):
			out.append(p)
	return out


static func calls() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for c: Variant in (_data["calls"] as Array):
		if unlocked(str((c as Dictionary).get("unlock", ""))):
			out.append(c)
	return out


## The dialogue line (OOTDialogueLine) for a VO line id like "e1_open_001", or null.
static func vo_line(line_id: String, part_id: String = PART_ID) -> OOTDialogueLine:
	var cut: int = line_id.rfind("_")
	if cut < 0:
		return null
	var db: Node = OOTServices.db()
	if db == null:
		return null
	var scene: OOTScene = db.get_scene(part_id, line_id.substr(0, cut))
	var idx: int = int(line_id.substr(cut + 1))
	if scene == null or idx < 0 or idx >= scene.lines.size():
		return null
	return scene.lines[idx]


## "Tue 09:05" -> "09:05"; "Sunday 23:52" -> "23:52".
static func clock_of(time_text: String) -> String:
	var parts: PackedStringArray = time_text.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else time_text


static func day_of(time_text: String) -> String:
	var parts: PackedStringArray = time_text.split(" ")
	return parts[0] if parts.size() > 1 else ""
