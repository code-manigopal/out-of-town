class_name OOTScene
extends RefCounted
## A story scene: lines, choices, and how it ends (next / puzzle / combat / episode end / ending).

var id: String = ""
var episode: int = 1
var place: String = ""
var time: String = ""
var lines: Array[OOTDialogueLine] = []
var choices: Array[OOTChoice] = []
var next_scene: String = ""
var fx: Dictionary = {}
var timer_seconds: float = 0.0
var timer_target: String = ""
var timer_fx: Dictionary = {}
var puzzle: Dictionary = {}   # type, title, to, fx
var combat: Dictionary = {}   # to, cleanTo
var is_episode_end: bool = false
var ending: String = ""


static func from_dict(data: Dictionary) -> OOTScene:
	var s: OOTScene = OOTScene.new()
	s.id = str(data.get("id", ""))
	s.episode = int(data.get("ep", 1))
	s.place = str(data.get("place", ""))
	s.time = str(data.get("time", ""))
	var raw_lines: Array = data.get("lines", [])
	for i: int in raw_lines.size():
		s.lines.append(OOTDialogueLine.from_dict(raw_lines[i], s.id, i))
	s.next_scene = str(data.get("next", ""))
	s.fx = data.get("fx", {}) if data.get("fx") is Dictionary else {}
	if data.get("timer") is Dictionary:
		var t: Dictionary = data["timer"]
		s.timer_seconds = float(t.get("secs", 0))
		s.timer_target = str(t.get("to", ""))
		s.timer_fx = t.get("fx", {}) if t.get("fx") is Dictionary else {}
	if data.get("puzzle") is Dictionary:
		s.puzzle = data["puzzle"]
	if data.get("combat") is Dictionary:
		s.combat = data["combat"]
	s.is_episode_end = bool(data.get("episodeEnd", false))
	s.ending = str(data.get("ending", "")) if data.get("ending") != null else ""
	for c: Dictionary in data.get("choices", []):
		var choice: OOTChoice = OOTChoice.from_dict(c, s.id)
		choice.timer_seconds = s.timer_seconds
		s.choices.append(choice)
	return s


func is_ending() -> bool:
	return not ending.is_empty()
