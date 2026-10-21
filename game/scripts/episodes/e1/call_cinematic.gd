class_name OOTCallCinematic
extends Node3D
## Ep 1 scene 2: the video call with Amma and Appa, made cinematic. Everything is built at runtime.
## Mani sits at the desk (the seated pose, else stands there), the laptop screen shows the call window
## (OOTCallScreen via a SubViewport), the screen's glow lights his face, the room dims a little, and the
## camera runs slow shots that CUT on every new dialogue line, picked by who speaks. While a choice is
## on screen the camera holds one calm, readable shot. finish() ends the call and gives control back.
## Story logic, flags, VO and subtitles stay in OOTApartment / OOTDialogueBox; this only watches them.

signal shot_changed(shot_name: StringName)
signal finished

const SEAT_POS: Vector3 = Vector3(0.0, 0.0, -2.95)
## The seated clip is authored for a car seat: this lowers and nudges the body onto the office chair.
const SEAT_BODY_OFFSET: Vector3 = Vector3(0.0, -0.3, 0.17)
const STAND_AT_DESK: Vector3 = Vector3(0.0, 0.0, -2.9)
const STAND_UP_POS: Vector3 = Vector3(0.0, 0.0, -2.15)
## Webcam: top centre of the lid. The screen glow sits just in front of the lid.
const WEBCAM_POS: Vector3 = Vector3(0.0, 0.96, -3.79)
const WEBCAM_LOOK: Vector3 = Vector3(0.0, 0.95, -2.74)
const LIGHT_POS: Vector3 = Vector3(0.0, 1.0, -3.5)
const LIGHT_ENERGY: float = 2.4
const ROOM_DIM: float = 0.4
const FIRST_BLEND: float = 0.9
const END_HOLD: float = 0.9
## Screen surface fallback in laptop-local space (centre, width, height, lid lean back from vertical in radians).
const SCREEN_CENTER: Vector3 = Vector3(0.0, 0.1087, -0.1472)
const SCREEN_SIZE_M: Vector2 = Vector2(0.28, 0.164)
const SCREEN_TILT: float = 0.349

## name -> shot: pos/look/fov go from the first value to the second over `dur` seconds (a slow push or drift).
const SHOTS: Dictionary = {
	## The dialogue box covers the lower third (half while choices show), so subjects sit in the upper part of each frame.
	&"ots_laptop": {"pos": [Vector3(0.38, 1.3, -1.75), Vector3(0.32, 1.26, -1.9)], "look": [Vector3(-0.02, 0.7, -3.7), Vector3(0.0, 0.7, -3.74)], "fov": [37.0, 33.0], "dur": 9.0},
	&"screen_closeup": {"pos": [Vector3(0.05, 1.04, -3.26), Vector3(0.0, 0.99, -3.36)], "look": [Vector3(0.0, 0.8, -3.77), Vector3(0.0, 0.8, -3.77)], "fov": [32.0, 28.0], "dur": 8.0},
	&"two_shot": {"pos": [Vector3(1.15, 1.2, -2.55), Vector3(1.05, 1.18, -2.6)], "look": [Vector3(-0.05, 0.85, -3.2), Vector3(-0.02, 0.85, -3.2)], "fov": [38.0, 35.0], "dur": 9.0},
	&"push_face": {"pos": [Vector3(0.04, 1.0, -3.55), Vector3(0.02, 1.04, -3.3)], "look": [Vector3(0.0, 0.97, -2.74), Vector3(0.0, 0.97, -2.74)], "fov": [34.0, 32.0], "dur": 8.0},
	&"face_profile": {"pos": [Vector3(0.75, 1.07, -3.2), Vector3(0.62, 1.07, -3.12)], "look": [Vector3(0.0, 0.99, -2.74), Vector3(0.0, 0.99, -2.74)], "fov": [30.0, 26.0], "dur": 8.0},
	## The calm hold for choices: static, Mani and the call window both in the top half, clear of the choice list.
	&"choice_hold": {"pos": [Vector3(1.0, 1.2, -2.4), Vector3(1.0, 1.2, -2.4)], "look": [Vector3(-0.05, 0.6, -3.2), Vector3(-0.05, 0.6, -3.2)], "fov": [48.0, 48.0], "dur": 1.0},
}
## Shots by who is on screen: remote speakers favour the screen, Mani's lines favour his face.
const SCREEN_SHOTS: Array[StringName] = [&"ots_laptop", &"screen_closeup", &"two_shot"]
const FACE_SHOTS: Array[StringName] = [&"push_face", &"face_profile"]
const HOLD_SHOT: StringName = &"choice_hold"

var active: bool = false
var seated: bool = false
var current_shot: StringName = &""
var cut_count: int = 0
var holding_choice: bool = false
var current_speaker: String = ""
var screen: OOTCallScreen = null
var screen_light: OmniLight3D = null
var screen_quad: MeshInstance3D = null

var _apt: Node3D
var _player: OOTPlayer
var _dialogue: OOTDialogueBox
var _laptop: Node3D
var _screen_vp: SubViewport
var _self_vp: SubViewport
var _fallback_cam: Camera3D
var _chair_shape: CollisionShape3D
var _saved_pos: Vector3
var _saved_yaw: float
var _saved_body_pos: Vector3
var _locked: bool = false
var _sig: String = ""
var _lines_seen: int = 0
var _shot_def: Dictionary = {}
var _shot_t: float = 0.0
var _time: float = 0.0
var _dim: float = 0.0
var _dim_target: float = 0.0
var _light_target: float = 0.0
var _light_base: Dictionary = {}  # Light3D -> original energy
var _env: Environment
var _env_ambient: float = 1.0
var _pick_index: Dictionary = {}
var _ending: bool = false


## Call right BEFORE dialogue.begin() so the first line is already covered.
func start(apartment: Node3D, dialogue: OOTDialogueBox) -> void:
	if active:
		return
	active = true
	_apt = apartment
	_player = apartment.get("player") as OOTPlayer
	_laptop = apartment.get("laptop") as Node3D
	_dialogue = dialogue
	_saved_pos = _player.global_position
	_saved_yaw = _player.yaw
	_saved_body_pos = _player.body.position
	_player.lock_input()
	_locked = true
	_seat_mani()
	_build_screen()
	_build_light()
	_dim_target = 1.0
	_light_target = LIGHT_ENERGY
	_cut_to(&"ots_laptop", FIRST_BLEND)


func _seat_mani() -> void:
	_chair_shape = _apt.get_node_or_null("Geometry/Furniture/OfficeChairBody/Shape") as CollisionShape3D
	if _chair_shape != null:
		_chair_shape.disabled = true
	_player.velocity = Vector3.ZERO
	_player.yaw = 0.0
	_player.pitch = -0.1
	_player.body.rotation.y = 0.0
	if _player.has_action(&"sit_drive"):
		_player.global_position = SEAT_POS
		_player.body.position = SEAT_BODY_OFFSET
		_player.set_pose_override(&"sit_drive", 0.3)
		seated = _player.has_pose_override()
	if not seated:
		_player.body.position = Vector3.ZERO
		_player.global_position = STAND_AT_DESK


# --- Laptop screen, webcam, light --------------------------------------------------------------

func _build_screen() -> void:
	_screen_vp = SubViewport.new()
	_screen_vp.size = OOTCallScreen.SCREEN_SIZE
	_screen_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_screen_vp.disable_3d = true
	add_child(_screen_vp)
	screen = OOTCallScreen.new()
	_screen_vp.add_child(screen)
	# the small webcam camera renders Mani for the self-view tile
	_self_vp = SubViewport.new()
	_self_vp.size = Vector2i(480, 300)
	_self_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_self_vp)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 46.0
	cam.near = 0.05
	cam.cull_mask = 0xFFFFF & ~2  # layer 2 is the screen quad
	_self_vp.add_child(cam)
	cam.global_transform = Transform3D(Basis(), WEBCAM_POS).looking_at(WEBCAM_LOOK, Vector3.UP)
	screen.set_self_texture(_self_vp.get_texture())
	# the quad over the laptop's screen surface
	var c: Vector3 = SCREEN_CENTER
	var sz: Vector2 = SCREEN_SIZE_M
	var tilt: float = SCREEN_TILT
	for n: Node in _laptop.find_children("*", "MeshInstance3D", true, false):
		var found: Dictionary = _find_screen_surface(n as MeshInstance3D)
		if not found.is_empty():
			c = found["center"]
			sz = found["size"]
			tilt = found["tilt"]
			break
	var quad: QuadMesh = QuadMesh.new()
	quad.size = sz * 0.985
	screen_quad = MeshInstance3D.new()
	screen_quad.name = "CallScreenQuad"
	screen_quad.mesh = quad
	screen_quad.layers = 2
	screen_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _screen_vp.get_texture()
	mat.albedo_color = Color(1, 1, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	screen_quad.material_override = mat
	var holder: Node3D = _laptop.get_node_or_null("Visual") as Node3D
	if holder == null:
		holder = _laptop
	holder.add_child(screen_quad)
	# the quad's +Z is the screen normal (faces the user, tilted back by `tilt`); parent offsets are removed
	var qb: Basis = Basis(Vector3.RIGHT, -tilt)
	screen_quad.global_transform = _laptop.global_transform * Transform3D(qb, c + qb.z * 0.002)


## Finds the laptop's mat_screen surface (the lid face) and returns its centre, size and tilt in laptop-local space.
func _find_screen_surface(mi: MeshInstance3D) -> Dictionary:
	if mi.mesh == null:
		return {}
	for s: int in mi.mesh.get_surface_count():
		var m: Material = mi.mesh.surface_get_material(s)
		if m == null or not m.resource_name.contains("screen"):
			continue
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var to_laptop: Transform3D = _laptop.global_transform.affine_inverse() * mi.global_transform
		var pts: Array[Vector3] = []
		for i: int in v.size():
			var n_l: Vector3 = to_laptop.basis * nrm[i]
			if n_l.z > 0.8 and n_l.y > 0.2:
				pts.append(to_laptop * v[i])
		if pts.size() < 3:
			continue
		var lo: Vector3 = pts[0]
		var hi: Vector3 = pts[0]
		var ctr: Vector3 = Vector3.ZERO
		for p: Vector3 in pts:
			ctr += p
			lo = lo.min(p)
			hi = hi.max(p)
		ctr /= pts.size()
		var h: float = Vector2(hi.y - lo.y, hi.z - lo.z).length()
		var tilt: float = atan2(absf(hi.z - lo.z), hi.y - lo.y)  # lid leaning back from vertical
		return {"center": ctr, "size": Vector2(hi.x - lo.x, h), "tilt": tilt}
	return {}


func _build_light() -> void:
	screen_light = OmniLight3D.new()
	screen_light.name = "CallScreenGlow"
	screen_light.light_color = Color(1.0, 0.94, 0.84)  # warm white
	screen_light.light_energy = 0.0
	screen_light.omni_range = 2.6
	screen_light.omni_attenuation = 1.3
	screen_light.shadow_enabled = true
	add_child(screen_light)
	screen_light.global_position = LIGHT_POS
	for n: Node in _apt.get_children():
		if n is Light3D:
			_light_base[n] = (n as Light3D).light_energy
	var we: WorldEnvironment = _apt.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		_env = we.environment
		_env_ambient = _env.ambient_light_energy


func _apply_dim() -> void:
	var f: float = lerpf(1.0, ROOM_DIM, _dim)
	for l: Variant in _light_base:
		if is_instance_valid(l):
			(l as Light3D).light_energy = float(_light_base[l]) * f
	if _env != null:
		_env.ambient_light_energy = _env_ambient * f


# --- Shots -------------------------------------------------------------------------------------------

func _cut_to(shot_name: StringName, blend: float = 0.0) -> void:
	_shot_def = SHOTS[shot_name]
	_shot_t = 0.0
	current_shot = shot_name
	cut_count += 1
	var first: bool = _cam() == null
	if first:
		var marker: Camera3D = Camera3D.new()
		add_child(marker)
		marker.global_transform = _shot_transform(0.0)
		if not _player.use_shot(marker):
			_fallback_cam = Camera3D.new()
			add_child(_fallback_cam)
			_fallback_cam.global_transform = marker.global_transform
			_fallback_cam.current = true
		marker.queue_free()
	var cam: Node3D = _cam()
	if cam != null and cam == _player.shot_cam:
		if cam.get("camera_3d_resource") == null:
			var res: Camera3DResource = Camera3DResource.new()
			res.fov = float(_shot_def["fov"][0])
			cam.set("camera_3d_resource", res)
		var tw: Variant = cam.get("tween_resource")
		if tw != null:
			(tw as Object).set("duration", blend)
	_apply_shot()
	shot_changed.emit(shot_name)


func _cam() -> Node3D:
	if _fallback_cam != null:
		return _fallback_cam
	if _player != null and _player.shot_cam != null and is_instance_valid(_player.shot_cam):
		return _player.shot_cam
	return null


func _shot_transform(t: float) -> Transform3D:
	var pos: Vector3 = (_shot_def["pos"][0] as Vector3).lerp(_shot_def["pos"][1] as Vector3, t)
	var look: Vector3 = (_shot_def["look"][0] as Vector3).lerp(_shot_def["look"][1] as Vector3, t)
	# a little handheld breathing so the frame never feels locked off (none on the calm hold)
	if current_shot != HOLD_SHOT:
		pos += Vector3(sin(_time * 0.9), cos(_time * 0.7) * 0.6, sin(_time * 0.5 + 1.0)) * 0.004
	return Transform3D(Basis(), pos).looking_at(look, Vector3.UP)


func _apply_shot() -> void:
	var cam: Node3D = _cam()
	if cam == null:
		return
	var t: float = clampf(_shot_t / float(_shot_def["dur"]), 0.0, 1.0)
	cam.global_transform = _shot_transform(t)
	var fov: float = lerpf(float(_shot_def["fov"][0]), float(_shot_def["fov"][1]), t)
	if cam is Camera3D:
		(cam as Camera3D).fov = fov
	else:
		cam.set("fov", fov)


## Next shot of a group, never the one on screen now.
func _pick(group: Array[StringName], key: String) -> StringName:
	var i: int = int(_pick_index.get(key, 0))
	var chosen: StringName = group[i % group.size()]
	if chosen == current_shot:
		i += 1
		chosen = group[i % group.size()]
	_pick_index[key] = i + 1
	return chosen


# --- Following the dialogue ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	_shot_t += delta
	_apply_shot()
	_dim = move_toward(_dim, _dim_target, delta / 1.4)
	_apply_dim()
	if screen_light != null:
		var flick: float = 1.0 + 0.04 * sin(_time * 11.0) + 0.03 * sin(_time * 29.0)
		screen_light.light_energy = move_toward(screen_light.light_energy, _light_target * flick, delta * 2.5)
	if not _ending:
		_poll_dialogue()


func _poll_dialogue() -> void:
	if _dialogue == null or not _dialogue.is_open or _dialogue.runner == null or _dialogue.runner.scene == null:
		return
	var scene: OOTScene = _dialogue.runner.scene
	var idx: int = int(_dialogue.get("_line_index"))
	var sig: String = "%s:%d" % [scene.id, idx]
	if sig == _sig:
		return
	_sig = sig
	var line: OOTDialogueLine = scene.lines[idx] if idx < scene.lines.size() else null
	var last_line: bool = scene.lines.is_empty() or idx >= scene.lines.size() - 1
	var choosing: bool = last_line and not _dialogue.runner.get_choices().is_empty()
	var who: String = "" if line == null or line.is_narration else line.speaker
	on_line(who, choosing)


## A new line (or choice list) is on screen. Public so tests can drive it without a dialogue box.
func on_line(who: String, choosing: bool) -> void:
	current_speaker = who.to_upper()
	holding_choice = choosing
	screen.set_speaker(who)
	_lines_seen += 1
	var next: StringName = current_shot
	if choosing:
		next = HOLD_SHOT
	elif current_speaker == "AMMA" or current_speaker == "APPA":
		next = _pick(SCREEN_SHOTS, "screen")
	elif current_speaker == "MANI":
		next = _pick(FACE_SHOTS, "face")
	elif _lines_seen > 1:
		next = _pick(SCREEN_SHOTS, "screen")  # closing narration: back to the screen
	if next != current_shot or _lines_seen > 1:
		_cut_to(next)


# --- Ending ----------------------------------------------------------------------------------------------

## The story reached the end of the call: show "Call ended" for a beat, then release and give control back.
func finish(hold: float = END_HOLD) -> void:
	if not active or _ending:
		return
	_ending = true
	screen.end_call()
	_dim_target = 0.0
	_light_target = 0.0
	if hold > 0.0 and is_inside_tree():
		await get_tree().create_timer(hold).timeout
	_release()


func _release() -> void:
	if not active:
		return
	active = false
	_player.release_shot()
	if _fallback_cam != null:
		_fallback_cam.queue_free()
		_fallback_cam = null
	_dim = 0.0
	_apply_dim()
	if seated:
		_player.clear_pose_override(0.2)
	_player.body.position = _saved_body_pos
	_player.global_position = STAND_UP_POS if seated else _saved_pos
	_player.velocity = Vector3.ZERO
	_player.yaw = 0.0
	if _chair_shape != null:
		_chair_shape.disabled = false
	if screen_quad != null:
		screen_quad.queue_free()
	if screen_light != null:
		screen_light.queue_free()
	if _locked:
		_locked = false
		_player.unlock_input()
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	if active:
		_dim = 0.0
		if _apt != null and is_instance_valid(_apt):
			_apply_dim()
