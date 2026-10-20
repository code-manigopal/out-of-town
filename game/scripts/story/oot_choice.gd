class_name OOTChoice
extends RefCounted
## A choice offered at the end of a scene.

var scene_id: String = ""
var label: String = ""
var sub_label: String = ""
var target_scene: String = ""
## Prototype requirement object: flags, notFlags, clues, proofs, dynamic.
var req: Dictionary = {}
## Prototype effect object (flag, clue, trust, danger, set...).
var fx: Dictionary = {}
var locked_reason: String = ""
## Once-id: the choice disappears after being taken (flag "once_<id>").
var once: String = ""
var show_dynamic: bool = false
var dynamic_target: bool = false
## Seconds of the scene's timer, 0 when untimed (set by OOTScene).
var timer_seconds: float = 0.0


static func from_dict(data: Dictionary, p_scene_id: String) -> OOTChoice:
	var c: OOTChoice = OOTChoice.new()
	c.scene_id = p_scene_id
	c.label = str(data.get("label", ""))
	c.sub_label = str(data.get("sub", ""))
	c.target_scene = str(data.get("to", ""))
	c.req = data.get("req", {}) if data.get("req") is Dictionary else {}
	c.fx = data.get("fx", {}) if data.get("fx") is Dictionary else {}
	c.locked_reason = str(data.get("lock", ""))
	var o: Variant = data.get("once", "")
	c.once = "" if o is bool else str(o)
	if o is bool and o:
		c.once = "%s_%s" % [p_scene_id, c.label.md5_text().left(6)]
	c.show_dynamic = bool(data.get("showDynamic", false))
	c.dynamic_target = bool(data.get("dynamicTarget", false))
	return c
