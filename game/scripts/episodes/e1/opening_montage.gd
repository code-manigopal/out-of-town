class_name OOTOpeningMontage
extends Node3D
## Episode 1 opening: Nila's voicemail plays over four slow exterior shots of an early-November morning in Windsor.
##   (a) the riverside, Detroit across the water   <- voicemail line 1 (e1_open_001)
##   (b) a busy Windsor road                       <- voicemail line 2 (e1_open_002)
##   (c) the forest edge of the city               <- voicemail line 3 (e1_open_003), which cuts off
##   (d) Mani's house, cranes up to the window of the upper flat, then a flash of light through the blinds.
## Esc / Enter / Space skips. The montage is time driven: seek(t) renders any moment (tests and stills use it).
## Story text and audio come from StoryDB scene `e1_open` and the VO files; the picture is built in code from the
## environments in game/environments/windsor/montage/.

signal finished(skipped: bool)
## A voicemail line was shown (line_id like e1_open_001).
signal line_started(line_id: String)

const PART_ID: String = "p1"
const SCENE_ID: String = "e1_open"
const AMBIENCE: String = "res://audio/ambience/city_morning.ogg"
const FADE: float = 0.45
## Shots: segment key, start, duration, voicemail line (index in scene e1_open, -1 none) and when it starts within the shot,
## ambience volume (dB), how the shot is left ("dip" black dip, "cut" hard cut, "flash" bright flash to the apartment).
const SHOTS: Array[Dictionary] = [
	{"key": "riverside", "start": 0.0, "dur": 10.0, "line": 1, "line_at": 1.3, "amb": -15.0, "out": "dip"},
	{"key": "street", "start": 10.0, "dur": 12.2, "line": 2, "line_at": 0.9, "amb": -4.0, "out": "dip"},
	{"key": "forest", "start": 22.2, "dur": 4.2, "line": 3, "line_at": 0.6, "amb": -17.0, "out": "cut"},
	{"key": "house", "start": 26.4, "dur": 8.2, "line": -1, "line_at": 0.0, "amb": -8.0, "out": "flash"},
]

@export var play_audio: bool = true
@export var allow_skip: bool = true
@export var autoplay: bool = true

var time: float = 0.0
var playing: bool = false
var is_done: bool = false
var shot_index: int = -1
var camera: Camera3D
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var segments: Dictionary = {}
var current_line_id: String = ""

var _layer: CanvasLayer
var _fade: ColorRect
var _flash: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _sub_panel: PanelContainer
var _sub_speaker: Label
var _sub_text: Label
var _sub_sub: Label
var _sub_hint: Label
var _vo: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _scene: OOTScene = null
var _line_end: float = -1.0
var _lines_shown: Array[int] = []
var _built: bool = false
var _env: Environment


func _ready() -> void:
	build()
	if autoplay:
		play()


## Builds the world once (all four shots, only the current one visible). Safe to call again.
func build() -> void:
	if _built:
		return
	_built = true
	_env = OOTMontageKit.make_environment(0.0016)
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = _env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 3.4
	sun.light_angular_distance = 0.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)
	sun.light_volumetric_fog_energy = 1.0
	camera = Camera3D.new()
	camera.name = "MontageCamera"
	camera.far = 6000.0
	camera.near = 0.15
	camera.fov = 45.0
	add_child(camera)
	camera.current = true
	var attr: CameraAttributesPractical = CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = false
	attr.dof_blur_far_distance = 40.0
	attr.dof_blur_far_transition = 60.0
	attr.dof_blur_amount = 0.08
	camera.attributes = attr
	_make_segment("riverside", OOTMontageRiverside.new(), Vector3(0, 0, 0))
	_make_segment("street", OOTMontageStreet.new(), Vector3(4000, 0, 0))
	_make_segment("forest", OOTMontageForest.new(), Vector3(8000, 0, 0))
	_make_segment("house", OOTMontageHouse.new(), Vector3(12000, 0, 0))
	_build_ui()
	_build_audio()
	var db: Node = OOTServices.db()
	if db != null:
		_scene = db.get_scene(PART_ID, SCENE_ID)
	set_shot(0)
	update_view()


func _make_segment(key: String, seg: Node3D, pos: Vector3) -> void:
	var t0: int = Time.get_ticks_msec()
	seg.name = key.capitalize()
	add_child(seg)
	seg.position = pos
	seg.call("build", camera)
	seg.visible = false
	segments[key] = seg
	if OS.get_cmdline_user_args().has("--montage-timing"):
		print("montage segment ", key, " built in ", Time.get_ticks_msec() - t0, " ms")
	# the water reflection viewport of a hidden segment still renders: keep it off until the shot is on
	_set_segment_active(seg, false)


func _set_segment_active(seg: Node3D, on: bool) -> void:
	seg.visible = on
	var refl: Variant = seg.get("reflection")
	if refl is OOTPlanarReflection:
		(refl as OOTPlanarReflection).viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		(refl as OOTPlanarReflection).set_process(on)
	seg.set_process(on)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_bar_top = _bar()
	_bar_bottom = _bar()
	_sub_panel = PanelContainer.new()
	_sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.05, 0.68)
	sb.set_content_margin_all(16)
	sb.set_corner_radius_all(6)
	_sub_panel.add_theme_stylebox_override("panel", sb)
	_sub_panel.anchor_left = 0.5
	_sub_panel.anchor_right = 0.5
	_sub_panel.anchor_top = 1.0
	_sub_panel.anchor_bottom = 1.0
	_sub_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub_panel.custom_minimum_size = Vector2(880, 0)
	_sub_panel.offset_top = -60.0
	_sub_panel.offset_bottom = -60.0
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_panel.add_child(col)
	_sub_speaker = Label.new()
	_sub_speaker.add_theme_font_size_override("font_size", 17)
	_sub_speaker.modulate = Color(0.9, 0.75, 0.45)
	col.add_child(_sub_speaker)
	_sub_text = Label.new()
	_sub_text.add_theme_font_size_override("font_size", 24)
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub_text)
	_sub_sub = Label.new()
	_sub_sub.add_theme_font_size_override("font_size", 18)
	_sub_sub.modulate = Color(1, 1, 1, 0.78)
	_sub_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub_sub)
	_layer.add_child(_sub_panel)
	_sub_panel.visible = false
	_sub_hint = Label.new()
	_sub_hint.text = "Esc / Enter to skip"
	_sub_hint.add_theme_font_size_override("font_size", 13)
	_sub_hint.modulate = Color(1, 1, 1, 0.35)
	_sub_hint.anchor_left = 1.0
	_sub_hint.anchor_right = 1.0
	_sub_hint.anchor_top = 1.0
	_sub_hint.anchor_bottom = 1.0
	_sub_hint.offset_left = -170.0
	_sub_hint.offset_top = -30.0
	_sub_hint.offset_right = -18.0
	_sub_hint.offset_bottom = -8.0
	_sub_hint.visible = allow_skip
	_layer.add_child(_sub_hint)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.96, 0.86, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


func _bar() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	_layer.add_child(r)
	return r


func _build_audio() -> void:
	_vo = AudioStreamPlayer.new()
	_vo.name = "VoicemailVoice"
	_vo.bus = OOTVoiceLines.VO_BUS
	add_child(_vo)
	_amb = AudioStreamPlayer.new()
	_amb.name = "Ambience"
	_amb.bus = &"Ambience"
	_amb.volume_db = -15.0
	if ResourceLoader.exists(AMBIENCE):
		var s: AudioStream = (load(AMBIENCE) as AudioStream).duplicate() as AudioStream
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_amb.stream = s
	add_child(_amb)


func total_duration() -> float:
	var last: Dictionary = SHOTS[SHOTS.size() - 1]
	return float(last["start"]) + float(last["dur"])


func play() -> void:
	if playing:
		return
	playing = true
	if play_audio and _amb != null and _amb.stream != null:
		_amb.play()


func _process(delta: float) -> void:
	_layout_bars()
	if not playing or is_done:
		return
	time += delta
	if time >= total_duration():
		_finish(false)
		return
	update_view()


## Renders the montage at time t without playing (voice and ambience stay quiet).
func seek(t: float) -> void:
	time = clampf(t, 0.0, total_duration() - 0.001)
	update_view(true)


func shot_at(t: float) -> int:
	for i: int in SHOTS.size():
		var s: Dictionary = SHOTS[i]
		if t < float(s["start"]) + float(s["dur"]):
			return i
	return SHOTS.size() - 1


func set_shot(i: int) -> void:
	if i == shot_index:
		return
	shot_index = i
	var key: String = String(SHOTS[i]["key"])
	for k: String in segments:
		_set_segment_active(segments[k], k == key)
	var seg: Node3D = segments[key]
	var pose: Dictionary = seg.call("camera_pose", 0.0)
	var attr: CameraAttributesPractical = camera.attributes as CameraAttributesPractical
	attr.dof_blur_far_enabled = bool(pose.get("dof", false))
	_env.volumetric_fog_enabled = bool(pose.get("volumetric", false))
	if _env.volumetric_fog_enabled:
		_env.volumetric_fog_density = 0.016
		_env.volumetric_fog_anisotropy = 0.72
		_env.volumetric_fog_length = 120.0
		_env.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)
		_env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
		_env.volumetric_fog_ambient_inject = 0.2
	_env.fog_density = {"riverside": 0.0007, "forest": 0.004}.get(key, 0.0016)
	_aim_sun(key)
	if _amb != null:
		_amb.volume_db = float(SHOTS[i]["amb"])


## The morning sun sits low in the south-east (the HDRI's own sun is turned to match).
func _aim_sun(_key: String) -> void:
	var az: float = deg_to_rad(SUN_AZIMUTH_DEG)
	var el: float = deg_to_rad(OOTMontageKit.SUN_ELEVATION_DEG)
	# direction the light travels (from the sun toward the ground)
	var to_sun: Vector3 = Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	sun.global_transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)
	(_env.sky.sky_material as PanoramaSkyMaterial).energy_multiplier = 1.0
	_env.sky_rotation = Vector3(0.0, SKY_YAW, 0.0)


const SUN_AZIMUTH_DEG: float = 128.0     # compass-style: 0 = north (-z), 90 = east (+x)
const SKY_YAW: float = 0.0


func update_view(force: bool = false) -> void:
	var i: int = shot_at(time)
	if i != shot_index:
		set_shot(i)
		if playing and shot_index > 0:
			var prev_out: String = String(SHOTS[shot_index - 1]["out"])
			if prev_out == "dip":
				_dip_in()
	var s: Dictionary = SHOTS[shot_index]
	var u: float = clampf((time - float(s["start"])) / float(s["dur"]), 0.0, 1.0)
	var seg: Node3D = segments[String(s["key"])]
	var e: float = u * u * u * (u * (u * 6.0 - 15.0) + 10.0)        # smootherstep
	var e_lin: float = lerpf(u, e, 0.55)                            # keeps a little drift at the ends
	var pose: Dictionary = seg.call("camera_pose", e_lin)
	camera.fov = float(pose["fov"])
	camera.global_position = pose["pos"]
	camera.look_at(pose["look"], Vector3.UP)
	if bool(pose.get("dof", false)):
		(camera.attributes as CameraAttributesPractical).dof_blur_far_distance = float(pose.get("dof_distance", 40.0))
	_update_fades(s, time - float(s["start"]), float(s["dur"]))
	_update_line(s, time)


func _update_fades(s: Dictionary, local_t: float, dur: float) -> void:
	var a: float = 0.0
	if shot_index == 0:
		a = clampf(1.0 - local_t / 1.2, 0.0, 1.0)                     # first fade in from black
	elif String(SHOTS[shot_index - 1]["out"]) == "dip":
		a = clampf(1.0 - local_t / FADE, 0.0, 1.0)
	if String(s["out"]) == "dip":
		a = maxf(a, clampf(1.0 - (dur - local_t) / FADE, 0.0, 1.0))
	_fade.color.a = a * a * (3.0 - 2.0 * a)
	var f: float = 0.0
	if String(s["out"]) == "flash":
		f = clampf((local_t - (dur - 1.1)) / 1.1, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
	_flash.color.a = f
	if shot_index == 1 and String(SHOTS[0]["out"]) == "dip":
		pass


func _dip_in() -> void:
	pass


func _update_line(s: Dictionary, t: float) -> void:
	var line: int = int(s["line"])
	if line < 0 or _scene == null or line >= _scene.lines.size():
		if t >= _line_end:
			_sub_panel.visible = false
		return
	var at: float = float(s["start"]) + float(s["line_at"])
	var l: OOTDialogueLine = _scene.lines[line]
	var lid: String = OOTVoiceLines.make_id(SCENE_ID, line)
	var stream: AudioStream = OOTVoiceLines.get_stream(lid, PART_ID)
	var length: float = stream.get_length() if stream != null else 3.0
	if t >= at and t < at + length + 0.5:
		if current_line_id != lid:
			current_line_id = lid
			_sub_speaker.text = "%s (%s)" % [l.speaker, l.channel] if not l.channel.is_empty() else l.speaker
			_sub_text.text = l.text
			_sub_sub.text = l.get_subtitle()
			_sub_sub.visible = not _sub_sub.text.is_empty()
			_sub_panel.visible = true
			if playing and play_audio and stream != null:
				_vo.stream = stream
				_vo.play()
			_line_end = at + length + 0.5
			line_started.emit(lid)
	elif t >= at + length + 0.5 or t < at:
		if current_line_id == lid and t >= at + length + 0.5:
			_sub_panel.visible = false
		elif t < at and current_line_id == lid:
			current_line_id = ""
			_sub_panel.visible = false


func _layout_bars() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var h: float = maxf((vs.y - vs.x / 2.39) * 0.5, 0.0)
	_bar_top.offset_top = 0.0
	_bar_top.offset_bottom = h
	_bar_bottom.anchor_top = 1.0
	_bar_bottom.anchor_bottom = 1.0
	_bar_bottom.offset_top = -h
	_bar_bottom.offset_bottom = 0.0
	_sub_panel.offset_top = -18.0 - h
	_sub_panel.offset_bottom = -18.0 - h


func skip() -> void:
	if is_done:
		return
	_finish(true)


func _finish(was_skipped: bool) -> void:
	if is_done:
		return
	is_done = true
	playing = false
	if _vo != null:
		_vo.stop()
	if _amb != null:
		_amb.stop()
	_sub_panel.visible = false
	finished.emit(was_skipped)


func _unhandled_input(event: InputEvent) -> void:
	if not allow_skip or is_done or not playing:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
