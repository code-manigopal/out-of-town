class_name OOTDialogueLine
extends RefCounted
## One spoken or narrated line. Prototype format "NAME (TAG): text || subtitle".

var scene_id: String = ""
var order: int = 0
## Speaker id, e.g. "NILA". Empty for narration.
var speaker: String = ""
## How the line is heard: V.O., radio, phone... Empty when spoken in person.
var channel: String = ""
var text: String = ""
## English subtitle. Empty in data when text is already English.
var subtitle: String = ""
var is_narration: bool = false
var dynamic: bool = false


static func from_dict(data: Dictionary, p_scene_id: String, p_order: int) -> OOTDialogueLine:
	var line: OOTDialogueLine = OOTDialogueLine.new()
	line.scene_id = p_scene_id
	line.order = p_order
	line.speaker = str(data.get("speaker", ""))
	line.channel = str(data.get("channel", ""))
	line.text = str(data.get("text", ""))
	line.subtitle = str(data.get("subtitle", ""))
	line.is_narration = bool(data.get("narration", false))
	line.dynamic = bool(data.get("dynamic", false))
	return line


## Every spoken line gets an English subtitle; narration gets none.
func get_subtitle() -> String:
	if is_narration:
		return ""
	return subtitle if not subtitle.is_empty() else text
