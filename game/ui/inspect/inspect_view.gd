class_name OOTInspectView
extends Control
## Shows an interactable's Visual large, in its own 3D world, on the right ~58%
## of the screen over a darkened view; the notes panel is on the left. Drag
## (or right stick) rotates, the wheel zooms, Esc / Interact closes. Turning a
## face with a hidden detail toward the camera reveals it (see OOTRevealSpot).
## Captions come from the story data; nothing is invented here.

signal opened
signal closed
signal revealed(spot: OOTRevealSpot)

const ITEM_SIZE: float = 1.5
const ZOOM_MIN: float = 1.1
const ZOOM_MAX: float = 3.6
const ZOOM_DEFAULT: float = 2.2
const OBJECT_LEFT: float = 0.42  ## object area starts at this fraction of the width
const PANEL_RIGHT: float = 0.37  ## notes panel ends at this fraction of the width
const STICK_SPEED: float = 2.6

var is_open: bool = false

var _vp: SubViewport
var _cont: SubViewportContainer
var _cam: Camera3D
var _pivot: Node3D
var _holder: Node3D
var _flash: OmniLight3D
var _panel: PanelContainer
var _name_label: Label
var _caption: Label
var _found_box: VBoxContainer
var _hint: Label
var _current: OOTInteractable = null
var _close_frame: int = -1
var _zoom: float = ZOOM_DEFAULT
var _hold: Dictionary = {}  # reveal index -> seconds held


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_to_group("oot_modal")
	_build()


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_cont = SubViewportContainer.new()
	_cont.stretch = true
	_cont.anchor_left = OBJECT_LEFT
	_cont.anchor_right = 1.0
	_cont.anchor_top = 0.0
	_cont.anchor_bottom = 1.0
	_cont.offset_left = 0.0
	_cont.offset_right = 0.0
	_cont.offset_top = 0.0
	_cont.offset_bottom = 0.0
	_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cont)

	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(740, 720)
	_cont.add_child(_vp)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 0, _zoom)
	_cam.fov = 40
	_vp.add_child(_cam)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -25, 0)
	light.light_energy = 1.1
	_vp.add_child(light)
	_flash = OmniLight3D.new()
	_flash.position = Vector3(0, 0.2, 1.4)
	_flash.omni_range = 4.0
	_flash.light_energy = 0.0
	_flash.light_color = Color(1.0, 0.92, 0.78)
	_vp.add_child(_flash)
	var env: Environment = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 0.75
	env.background_mode = Environment.BG_CLEAR_COLOR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)

	# Notes panel, left side.
	_panel = PanelContainer.new()
	_panel.name = "NotesPanel"
	_panel.anchor_left = 0.0
	_panel.anchor_right = PANEL_RIGHT
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 40.0
	_panel.offset_right = 0.0
	_panel.offset_top = 56.0
	_panel.offset_bottom = -56.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.1, 0.84)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(28.0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 32)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_name_label)

	var rule: ColorRect = ColorRect.new()
	rule.color = Color(1, 1, 1, 0.18)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "NotesScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(scroll)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 14)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(inner)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 21)
	_caption.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_caption)

	_found_box = VBoxContainer.new()
	_found_box.name = "Found"
	_found_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_found_box.add_theme_constant_override("separation", 10)
	_found_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_found_box)

	_hint = Label.new()
	_hint.text = "Drag to turn  -  Scroll to zoom  -  Esc to close"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.modulate = Color(1, 1, 1, 0.4)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hint)


func open_for(target: OOTInteractable) -> bool:
	var visual: Node3D = target.get_visual()
	if visual == null:
		return false
	for c: Node in _pivot.get_children():
		_pivot.remove_child(c)
		c.queue_free()
	_pivot.basis = Basis.IDENTITY
	_zoom = ZOOM_DEFAULT
	_cam.position = Vector3(0, 0, _zoom)
	var copy: Node3D = visual.duplicate() as Node3D
	copy.transform = Transform3D.IDENTITY
	_holder = Node3D.new()
	_holder.add_child(copy)
	_pivot.add_child(_holder)
	var aabb: AABB = _combined_aabb(visual)
	var longest: float = maxf(maxf(aabb.size.x, aabb.size.y), maxf(aabb.size.z, 0.01))
	var s: float = ITEM_SIZE / longest
	var base: Basis = _front_basis(target, visual, aabb)
	_holder.transform = Transform3D(base.scaled(Vector3.ONE * s), -(base * (aabb.position + aabb.size * 0.5)) * s)
	_current = target
	_hold.clear()
	for c: Node in _found_box.get_children():
		_found_box.remove_child(c)
		c.queue_free()
	# Hide every reveal decal, then show the ones found earlier.
	for i: int in range(target.reveals.size()):
		var spot: OOTRevealSpot = target.reveals[i]
		var decal: Node = copy.get_node_or_null(spot.decal_path)
		if decal != null:
			_set_decal_visible(decal, target.revealed_ids.has(spot.id), false)
		if target.revealed_ids.has(spot.id):
			_add_found(spot, false)
	_name_label.text = target.display_name
	_caption.text = target.get_caption()
	_caption.visible = not _caption.text.is_empty()
	var first: bool = target.mark_inspected()
	if first:
		OOTJournalData.grant(target.get_journal_entry())
	is_open = true
	visible = true
	opened.emit()
	return true


## Rotation (item-local -> inspect frame) that turns the item's front face to +Z.
func _front_basis(target: OOTInteractable, visual: Node3D, aabb: AABB) -> Basis:
	var n: Vector3 = target.inspect_face
	if n == Vector3.ZERO:
		# Automatic: a flat item faces us with its broad side.
		var dims: Array[float] = [aabb.size.x, aabb.size.y, aabb.size.z]
		var thin: int = 0
		for i: int in range(3):
			if dims[i] < dims[thin]:
				thin = i
		var other: float = 0.0
		for i: int in range(3):
			if i != thin:
				other = maxf(other, dims[i])
		if dims[thin] > other * 0.4:
			return Basis.IDENTITY
		n = Vector3.ZERO
		n[thin] = 1.0
		# Face the side the game camera is on.
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null and visual.is_inside_tree():
			var to_cam: Vector3 = cam.global_position - visual.global_position
			if (visual.global_basis * n).dot(to_cam) < 0.0:
				n = -n
	n = n.normalized()
	return Basis(Quaternion(n, Vector3.BACK))


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_current = null
	_close_frame = Engine.get_process_frames()
	closed.emit()


## Orientation of the item (item-local -> view space).
func get_item_basis() -> Basis:
	return _pivot.basis


func set_item_rotation(b: Basis) -> void:
	_pivot.basis = b.orthonormalized()


func get_zoom() -> float:
	return _zoom


func set_zoom(distance: float) -> void:
	_zoom = clampf(distance, ZOOM_MIN, ZOOM_MAX)
	_cam.position = Vector3(0, 0, _zoom)


func rotate_item(delta_px: Vector2, sensitivity: float = 0.01) -> void:
	var b: Basis = Basis(Vector3.UP, delta_px.x * sensitivity) * Basis(Vector3.RIGHT, delta_px.y * sensitivity) * _pivot.basis
	_pivot.basis = b.orthonormalized()


## The screen-space rectangles of the object area and the notes panel (for layout checks).
func get_object_rect() -> Rect2:
	return _cont.get_global_rect()


func get_panel_rect() -> Rect2:
	return _panel.get_global_rect()


func _process(delta: float) -> void:
	if not is_open:
		return
	var stick: Vector2 = Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.2:
		rotate_item(stick * STICK_SPEED * delta * 100.0)
	update_reveals(delta)


## Checks every reveal spot against the current orientation; hold timers
## advance by `delta`. Public so tests can step it.
func update_reveals(delta: float) -> void:
	if _current == null:
		return
	for i: int in range(_current.reveals.size()):
		var spot: OOTRevealSpot = _current.reveals[i]
		if _current.revealed_ids.has(spot.id):
			continue
		if spot.angle_to_camera(_pivot.basis) <= spot.tolerance_deg and spot.zoom_ok(_zoom):
			_hold[i] = float(_hold.get(i, 0.0)) + delta
			if float(_hold[i]) >= spot.hold_time:
				_reveal(spot)
		else:
			_hold[i] = 0.0


func _reveal(spot: OOTRevealSpot) -> void:
	if _current == null or not _current.mark_revealed(spot):
		return
	var decal: Node = _holder.get_child(0).get_node_or_null(spot.decal_path) if _holder.get_child_count() > 0 else null
	if decal != null:
		_set_decal_visible(decal, true, true)
	_add_found(spot, true)
	_pulse_highlight()
	if not spot.journal_entry.is_empty():
		OOTJournalData.grant(spot.journal_entry)
	revealed.emit(spot)


func _add_found(spot: OOTRevealSpot, animate: bool) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head: Label = Label.new()
	head.text = "Turned over"
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(0.95, 0.78, 0.45))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var t: Label = Label.new()
	t.text = spot.text
	t.add_theme_font_size_override("font_size", 23)
	t.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(t)
	if not spot.subtitle.is_empty():
		var sub: Label = Label.new()
		sub.text = spot.subtitle
		sub.add_theme_font_size_override("font_size", 17)
		sub.modulate = Color(1, 1, 1, 0.65)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(sub)
	_found_box.add_child(box)
	if animate:
		box.modulate.a = 0.0
		create_tween().tween_property(box, "modulate:a", 1.0, 0.9)


func _pulse_highlight() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_flash, "light_energy", 2.4, 0.35)
	tw.tween_property(_flash, "light_energy", 0.0, 1.0)


## Shows or hides the decal node; when shown with `fade`, fades it in.
func _set_decal_visible(decal: Node, shown: bool, fade: bool) -> void:
	if decal is Node3D:
		(decal as Node3D).visible = shown
	if not shown:
		return
	var targets: Array[Node] = [decal]
	targets.append_array(decal.find_children("*", "", true, false))
	for n: Node in targets:
		if n is GeometryInstance3D:
			var gi: GeometryInstance3D = n
			if fade:
				gi.transparency = 1.0
				create_tween().tween_property(gi, "transparency", 0.0, 0.9)
			else:
				gi.transparency = 0.0
		elif n is Label3D or n is Sprite3D or n is Decal:
			var from: Color = n.get("modulate")
			if fade:
				n.set("modulate", Color(from.r, from.g, from.b, 0.0))
				create_tween().tween_property(n, "modulate:a", from.a if from.a > 0.0 else 1.0, 0.9)


func _combined_aabb(root: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = n as VisualInstance3D
		if vi is Light3D:
			continue
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
		rotate_item((event as InputEventMouseMotion).relative)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(_zoom - 0.15)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(_zoom + 0.15)
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
