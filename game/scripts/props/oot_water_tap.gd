class_name OOTWaterTap
extends Node3D
## A sink tap. Place this node at the spout tip (the stream falls straight down from here by `drop_height`).
## Add the lever model (origin = pivot, arm toward local +Z) as a child named "Lever" at the lever's position.
## Using the lever toggles the water: the lever lifts, a stream appears with splash droplets, a loop plays.

signal toggled(is_on: bool)

@export var display_name: String = "tap"
@export var drop_height: float = 0.3
@export var stream_radius: float = 0.0055
@export var lever_lift_deg: float = 35.0
## Where the interaction body sits, local to this node (default: at the lever).
@export var use_offset: Vector3 = Vector3.ZERO
@export var use_size: Vector3 = Vector3(0.14, 0.16, 0.14)
@export var water_sound: String = "water_loop.ogg"
@export var squeak_sound: String = "tap_squeak.ogg"

var interactable: OOTInteractable = null
var is_on: bool = false
var stream: MeshInstance3D = null
var splash: GPUParticles3D = null
var _loop: AudioStreamPlayer3D = null
var _lever: Node3D = null
var _lever_base: Basis = Basis.IDENTITY
var _lift: float = 0.0           # 0..1
var _tween: Tween = null


func _ready() -> void:
	_lever = get_node_or_null("Lever") as Node3D
	if _lever != null:
		_lever_base = _lever.transform.basis
		if use_offset == Vector3.ZERO:
			use_offset = _lever.position
	_build_stream()
	_build_interactable()
	_loop = OOTSfx.make_loop(self, water_sound, &"SFX", -6.0, 3.0)
	_apply(false)
	_refresh_prompt()


func _build_interactable() -> void:
	interactable = OOTInteractable.new()
	interactable.name = "Use"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = use_size
	shape.shape = box
	interactable.add_child(shape)
	interactable.position = use_offset
	interactable.item_id = String(name).to_snake_case()
	interactable.display_name = display_name
	interactable.kind = OOTInteractable.Kind.USE
	interactable.interacted.connect(func(_by: Node) -> void: toggle())
	add_child(interactable)


func _build_stream() -> void:
	stream = MeshInstance3D.new()
	stream.name = "Stream"
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = stream_radius
	cyl.bottom_radius = stream_radius * 0.8
	cyl.height = drop_height
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	stream.mesh = cyl
	stream.position = Vector3(0, -drop_height / 2.0, 0)
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://materials/apartment/water_stream.gdshader") as Shader
	stream.material_override = mat
	stream.visible = false
	add_child(stream)
	# splash droplets where the stream lands
	splash = GPUParticles3D.new()
	splash.name = "Splash"
	splash.position = Vector3(0, -drop_height, 0)
	splash.amount = 14
	splash.lifetime = 0.45
	splash.local_coords = false
	splash.emitting = false
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0, -2.8, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.01
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	splash.process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.007, 0.007)
	var qm: StandardMaterial3D = StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.albedo_color = Color(0.85, 0.94, 1.0, 0.7)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = qm
	splash.draw_pass_1 = quad
	add_child(splash)


func toggle() -> void:
	set_on(not is_on)


func set_on(on: bool) -> void:
	if on == is_on:
		return
	is_on = on
	OOTSfx.play_at(self, squeak_sound, -6.0, 2.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_lift, _lift, 1.0 if on else 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	_apply(true)
	_refresh_prompt()
	toggled.emit(on)


func _apply(_animated: bool) -> void:
	stream.visible = is_on
	splash.emitting = is_on
	if _loop != null:
		if is_on and not _loop.playing:
			_loop.play()
		elif not is_on:
			_loop.stop()
	if not _animated:
		_set_lift(1.0 if is_on else 0.0)


func _set_lift(v: float) -> void:
	_lift = v
	if _lever != null:
		# the lever arm points to local +Z; a negative rotation about X raises it
		_lever.transform.basis = _lever_base * Basis(Vector3.RIGHT, -deg_to_rad(lever_lift_deg) * v)
	if stream != null:
		stream.scale = Vector3(v, 1.0, v)


func _refresh_prompt() -> void:
	if interactable != null:
		interactable.prompt_text = "Turn off the %s" % display_name if is_on else "Turn on the %s" % display_name
