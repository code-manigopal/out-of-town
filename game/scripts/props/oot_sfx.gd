class_name OOTSfx
extends RefCounted
## Tiny helpers for the interactive apartment props: load an optional stream and play 3D one-shots / loops on the SFX bus.
## Every sound is optional: a missing file means silence, never an error.

const DIR: String = "res://audio/sfx/apartment/"


static func load_stream(file_or_path: String) -> AudioStream:
	var path: String = file_or_path if file_or_path.begins_with("res://") else DIR + file_or_path
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


## Plays a one-shot at the node's position (the player is parented to `parent` and frees itself when done).
static func play_at(parent: Node3D, file_or_path: String, volume_db: float = 0.0, unit_size: float = 5.0) -> AudioStreamPlayer3D:
	var stream: AudioStream = load_stream(file_or_path)
	if stream == null or parent == null or not parent.is_inside_tree():
		return null
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.unit_size = unit_size
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## A looping 3D player (not started). Ogg streams are duplicated so looping does not alter the shared resource.
static func make_loop(parent: Node3D, file_or_path: String, bus: StringName = &"SFX", volume_db: float = 0.0, unit_size: float = 4.0) -> AudioStreamPlayer3D:
	var stream: AudioStream = load_stream(file_or_path)
	if stream == null:
		return null
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.unit_size = unit_size
	parent.add_child(p)
	return p
