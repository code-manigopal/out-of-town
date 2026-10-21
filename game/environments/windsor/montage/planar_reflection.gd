class_name OOTPlanarReflection
extends Node
## Planar reflection for a flat water surface: a SubViewport shares the main 3D world and renders it through a camera mirrored
## in the water plane; the water shader samples the viewport (flipped) with the screen UV. The water itself is on render
## layer 20 and excluded from the reflection camera.

const WATER_LAYER_BIT: int = 1 << 19

var main_camera: Camera3D
var plane_y: float = 0.0
var viewport: SubViewport
var camera: Camera3D
## Reflection resolution relative to the main viewport.
var scale_factor: float = 0.6


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "ReflectionViewport"
	viewport.size = Vector2i(768, 432)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_debanding = false
	viewport.audio_listener_enable_3d = false
	add_child(viewport)
	camera = Camera3D.new()
	camera.name = "MirrorCamera"
	camera.cull_mask = 0xFFFFF & ~WATER_LAYER_BIT
	viewport.add_child(camera)
	camera.current = true


func texture() -> ViewportTexture:
	return viewport.get_texture()


func _process(_delta: float) -> void:
	if main_camera == null or not is_instance_valid(main_camera) or camera == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280, 720)
	var want: Vector2i = Vector2i(maxi(int(vs.x * scale_factor), 64), maxi(int(vs.y * scale_factor), 64))
	if viewport.size != want:
		viewport.size = want
	var xf: Transform3D = main_camera.global_transform
	var p: Vector3 = xf.origin
	var fwd: Vector3 = -xf.basis.z
	var mp: Vector3 = Vector3(p.x, 2.0 * plane_y - p.y, p.z)
	var mf: Vector3 = Vector3(fwd.x, -fwd.y, fwd.z)
	# the mirrored image is flipped vertically by the shader; keep the camera upright (no roll) for that to hold
	camera.global_transform = Transform3D(Basis.looking_at(mf, Vector3.UP), mp)
	camera.fov = main_camera.fov
	camera.near = main_camera.near
	camera.far = main_camera.far
	camera.keep_aspect = main_camera.keep_aspect
