class_name OOTMirror
extends Node3D
## A real planar mirror. Place this node at the mirror's centre with local +Z pointing out of the glass (into the room).
## A SubViewport camera sits at the viewer's camera reflected across the mirror plane, looking into the room
## through the mirror rectangle (an off-axis frustum), and its image is shown on the quad. The SubViewport only
## renders while the active camera is inside `active_box` (global AABB, e.g. the bathroom) or while the mirror view
## is open, so the extra render pass costs nothing elsewhere.
##
## Using the mirror calls enter_view(): a temporary Camera3D frames the mirror from view_offset (mirror-local) and
## the owner locks the player on `view_entered` (and unlocks on `view_exited`). Interact / Esc / a movement key leaves,
## restoring the camera that was current before.

signal view_entered
signal view_exited

@export var mirror_size: Vector2 = Vector2(0.5, 0.7)
@export var viewport_width: int = 480
## Global-space box in which the reflection is rendered. Size zero = always.
@export var active_box: AABB = AABB(Vector3(-1.5, 0.0, 0.5), Vector3(1.55, 2.6, 2.4))
## Mirror-local camera position and look target for the close-up.
@export var view_offset: Vector3 = Vector3(0.22, 0.5, 1.25)
@export var view_look_at: Vector3 = Vector3(0.0, -0.12, 0.0)
@export var view_fov: float = 40.0
## Interaction body, mirror-local; its collision covers the glass.
@export var use_offset: Vector3 = Vector3(-0.22, -0.45, 0.0)

var interactable: OOTInteractable = null
var viewport: SubViewport = null
var mirror_camera: Camera3D = null
var quad: MeshInstance3D = null
var in_view: bool = false
var rendering: bool = false
var _view_cam: Camera3D = null
var _prev_cam: Camera3D = null

const MIRROR_LAYER: int = 20      # visual layer only the mirror quad is on; the mirror camera skips it


func _ready() -> void:
	var h: int = int(round(viewport_width * mirror_size.y / mirror_size.x))
	viewport = SubViewport.new()
	viewport.name = "ReflectionViewport"
	viewport.size = Vector2i(viewport_width, h)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.own_world_3d = false
	add_child(viewport)
	mirror_camera = Camera3D.new()
	mirror_camera.name = "MirrorCamera"
	mirror_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	mirror_camera.cull_mask = 0xFFFFF & ~(1 << (MIRROR_LAYER - 1))
	mirror_camera.top_level = true
	viewport.add_child(mirror_camera)
	mirror_camera.current = true
	quad = MeshInstance3D.new()
	quad.name = "Glass"
	var qm: QuadMesh = QuadMesh.new()
	qm.size = mirror_size
	quad.mesh = qm
	quad.layers = 1 << (MIRROR_LAYER - 1)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://materials/apartment/mirror.gdshader") as Shader
	mat.set_shader_parameter("reflection", viewport.get_texture())
	mat.set_shader_parameter("live", 0.0)
	quad.material_override = mat
	add_child(quad)
	interactable = OOTInteractable.new()
	interactable.name = "Use"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(mirror_size.x, mirror_size.y, 0.03)
	shape.shape = box
	shape.position = -use_offset
	interactable.add_child(shape)
	interactable.position = use_offset
	interactable.item_id = "bathroom_mirror"
	interactable.display_name = "mirror"
	interactable.kind = OOTInteractable.Kind.USE
	interactable.prompt_text = "Look in the mirror"
	interactable.interacted.connect(func(_by: Node) -> void: enter_view())
	add_child(interactable)


func _process(_delta: float) -> void:
	var cam: Camera3D = _active_camera()
	var should: bool = in_view or _camera_in_zone(cam)
	if should != rendering:
		rendering = should
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if should else SubViewport.UPDATE_DISABLED
		(quad.material_override as ShaderMaterial).set_shader_parameter("live", 1.0 if should else 0.0)
	if rendering and cam != null:
		_update_mirror_camera(cam)


func _active_camera() -> Camera3D:
	var cam: Camera3D = get_viewport().get_camera_3d()
	return cam


func _camera_in_zone(cam: Camera3D) -> bool:
	if cam == null:
		return false
	if active_box.size == Vector3.ZERO:
		return true
	return active_box.has_point(cam.global_position)


## Puts the mirror camera at the viewer's reflected position, aimed along the mirror normal, with a frustum
## that exactly fits the mirror rectangle.
func _update_mirror_camera(cam: Camera3D) -> void:
	var gt: Transform3D = global_transform
	var n: Vector3 = gt.basis.z.normalized()
	var up: Vector3 = gt.basis.y.normalized()
	var eye: Vector3 = cam.global_position
	var d: float = (eye - gt.origin).dot(n)
	if d < 0.02:
		return                                    # viewer is behind the glass
	var eye_r: Vector3 = eye - 2.0 * d * n
	var cz: Vector3 = -n
	var cx: Vector3 = up.cross(cz).normalized()
	mirror_camera.global_transform = Transform3D(Basis(cx, up, cz), eye_r)
	var to_c: Vector3 = gt.origin - eye_r
	mirror_camera.set_frustum(mirror_size.y, Vector2(to_c.dot(cx), to_c.dot(up)), d, 30.0)


func enter_view() -> void:
	if in_view:
		return
	in_view = true
	_prev_cam = get_viewport().get_camera_3d()
	_view_cam = Camera3D.new()
	_view_cam.name = "MirrorViewCamera"
	_view_cam.fov = view_fov
	_view_cam.top_level = true
	add_child(_view_cam)
	_view_cam.global_position = to_global(view_offset)
	_view_cam.look_at(to_global(view_look_at), Vector3.UP)
	_view_cam.make_current()
	view_entered.emit()


func exit_view() -> void:
	if not in_view:
		return
	in_view = false
	if _view_cam != null:
		_view_cam.queue_free()
		_view_cam = null
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_prev_cam = null
	view_exited.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not in_view:
		return
	for a: StringName in [&"interact", &"ui_cancel", &"move_forward", &"move_back", &"move_left", &"move_right"]:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			get_viewport().set_input_as_handled()
			exit_view()
			return
