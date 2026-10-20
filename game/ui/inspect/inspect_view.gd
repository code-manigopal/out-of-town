class_name OOTInspectView
extends Control
## Shows an interactable's Visual large, in its own 3D world. Drag with the
## mouse to rotate; Esc or Interact closes. Caption comes from the story data
## (empty -> only the object's name is shown).

signal opened
signal closed

var is_open: bool = false

var _vp: SubViewport
var _pivot: Node3D
var _name_label: Label
var _caption: Label
var _hint: Label
var _current: OOTInteractable = null
var _close_frame: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var cont: SubViewportContainer = SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_preset(Control.PRESET_CENTER)
	cont.custom_minimum_size = Vector2(720, 400)
	cont.size = Vector2(720, 400)
	cont.position = Vector2(280, 90)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cont)

	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(720, 400)
	cont.add_child(_vp)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0, 0, 2.2)
	cam.fov = 40
	_vp.add_child(cam)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	_vp.add_child(light)
	var env: Environment = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 0.7
	env.background_mode = Environment.BG_CLEAR_COLOR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_name_label.position = Vector2(0, 40)
	_name_label.size = Vector2(1280, 40)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 20)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.position = Vector2(240, 510)
	_caption.size = Vector2(800, 120)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)

	_hint = Label.new()
	_hint.text = "Drag to rotate  -  E / Esc to close"
	_hint.modulate = Color(1, 1, 1, 0.45)
	_hint.position = Vector2(0, 670)
	_hint.size = Vector2(1280, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func open_for(target: OOTInteractable) -> bool:
	var visual: Node3D = target.get_visual()
	if visual == null:
		return false
	for c: Node in _pivot.get_children():
		c.queue_free()
	_pivot.rotation = Vector3.ZERO
	var copy: Node3D = visual.duplicate() as Node3D
	copy.transform = Transform3D.IDENTITY
	var holder: Node3D = Node3D.new()
	holder.add_child(copy)
	_pivot.add_child(holder)
	var aabb: AABB = _combined_aabb(visual)
	var longest: float = maxf(maxf(aabb.size.x, aabb.size.y), maxf(aabb.size.z, 0.01))
	var s: float = 1.3 / longest
	holder.scale = Vector3.ONE * s
	holder.position = -(aabb.position + aabb.size * 0.5) * s
	_current = target
	_name_label.text = target.display_name
	_caption.text = target.get_caption()
	target.mark_inspected()
	is_open = true
	visible = true
	opened.emit()
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_current = null
	_close_frame = Engine.get_process_frames()
	closed.emit()


func _combined_aabb(root: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = n as VisualInstance3D
		var local: Transform3D = root.global_transform.affine_inverse() * vi.global_transform \
				if root.is_inside_tree() and vi.is_inside_tree() else vi.transform
		var box: AABB = local * vi.get_aabb()
		result = box if first else result.merge(box)
		first = false
	if first:
		result = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	return result


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var m: InputEventMouseMotion = event
		_pivot.rotate_y(m.relative.x * 0.01)
		_pivot.rotate_x(m.relative.y * 0.01)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
