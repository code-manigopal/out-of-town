class_name OOTApartmentContent
extends RefCounted
## Applies data/journal/p1_e1_props.json to the apartment: writes the whiteboard
## and pin-board cards, turns the pins into inspectables, and sets each prop's
## journal entry and hidden details (OOTRevealSpot). Story text stays in data.

const PROPS_PATH: String = "res://data/journal/p1_e1_props.json"
const MARKER_COLOR: Color = Color(0.08, 0.12, 0.35)
const NOTE_COLOR: Color = Color(0.15, 0.15, 0.18)
const STAMP_COLOR: Color = Color(1.0, 0.55, 0.15)


static func apply(apartment: Node) -> void:
	var f: FileAccess = FileAccess.open(PROPS_PATH, FileAccess.READ)
	if f == null:
		push_warning("apartment content: %s missing" % PROPS_PATH)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	for key: String in ["whiteboard", "grad_photo", "nila_photo"]:
		if data.has(key):
			_apply_prop(apartment, data[key])
	var used: Array[String] = []
	for pin: Dictionary in data.get("pins", []):
		_apply_pin(apartment, pin)
		used.append(str(pin["pin"]).get_file())
	# Blank cards that no data uses are removed rather than left empty on the board.
	var board: Node = apartment.get_node_or_null("Interactive/PinBoard")
	if board != null:
		for child: Node in board.get_children():
			if child.name.begins_with("Pin_") and not used.has(str(child.name)) and not child is OOTInteractable:
				child.queue_free()


static func _apply_prop(apartment: Node, cfg: Dictionary) -> void:
	var item: OOTInteractable = apartment.get_node_or_null(str(cfg["node"])) as OOTInteractable
	if item == null:
		push_warning("apartment content: no interactable at %s" % cfg["node"])
		return
	item.journal_entry = str(cfg.get("journal_entry", ""))
	item.reveals = _make_reveals(cfg.get("reveals", []))
	if cfg.has("board_lines"):
		var visual: Node3D = item.get_visual()
		var model: Node3D = visual.get_node_or_null("Model") as Node3D
		_write_board(model if model != null else visual, cfg["board_lines"])


## Writes marker lines on the whiteboard's front face. "~~text~~" is struck through.
static func _write_board(visual: Node3D, lines: Array) -> void:
	var box: AABB = _local_aabb(visual)
	if box.size == Vector3.ZERO:
		return
	var font_size: int = 48
	# Size the writing to the board (local units), so a scaled model still fits.
	var pixel: float = box.size.x * 0.00068
	var line_h: float = box.size.y * 0.8 / maxf(lines.size(), 1)
	var top: float = box.position.y + box.size.y * 0.9
	var left: float = box.position.x + box.size.x * 0.07
	var z: float = box.end.z + 0.004
	for i: int in lines.size():
		var raw: String = str(lines[i])
		if raw.is_empty():
			continue
		var struck: bool = raw.contains("~~")
		var text: String = raw.replace("~~", "")
		var label: Label3D = _label(text, font_size, pixel, MARKER_COLOR)
		label.name = "BoardLine_%d" % i
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.position = Vector3(left, top - line_h * i, z)
		visual.add_child(label)
		if struck:
			_strike_segments(visual, raw, label, font_size, pixel, z)


## A thin marker line through each ~~segment~~ of a whiteboard line.
static func _strike_segments(visual: Node3D, raw: String, label: Label3D, font_size: int, pixel: float, z: float) -> void:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var parts: PackedStringArray = raw.split("~~")
	var x: float = label.position.x
	for p: int in parts.size():
		var w: float = font.get_string_size(parts[p], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * pixel
		if p % 2 == 1 and w > 0.0:
			var bar: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(w, 0.004, 0.001)
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = MARKER_COLOR
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material = mat
			bar.mesh = mesh
			bar.position = Vector3(x + w * 0.5, label.position.y, z + 0.001)
			visual.add_child(bar)
		x += w


static func _apply_pin(apartment: Node, cfg: Dictionary) -> void:
	var card: Node3D = apartment.get_node_or_null(str(cfg["pin"])) as Node3D
	if card == null:
		push_warning("apartment content: no pin at %s" % cfg["pin"])
		return
	var xform: Transform3D = card.global_transform
	var item: OOTInteractable = OOTInteractable.new()
	item.name = "Pin_" + str(cfg["item_id"])
	item.item_id = str(cfg["item_id"])
	item.display_name = str(cfg.get("display_name", ""))
	item.kind = OOTInteractable.Kind.INSPECT
	item.spot_title = ""
	item.journal_entry = str(cfg.get("journal_entry", ""))
	item.reveals = _make_reveals(cfg.get("reveals", []))
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	item.add_child(visual)
	card.get_parent().add_child(item)
	item.global_transform = xform
	card.reparent(visual, true)
	var box: AABB = _local_aabb(visual)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var bshape: BoxShape3D = BoxShape3D.new()
	bshape.size = Vector3(maxf(box.size.x, 0.12), maxf(box.size.y, 0.1), maxf(box.size.z, 0.03))
	shape.shape = bshape
	shape.position = box.get_center()
	item.add_child(shape)
	var front: float = box.end.z + 0.002
	if cfg.has("photo") and ResourceLoader.exists(str(cfg["photo"])):
		var sprite: Sprite3D = Sprite3D.new()
		sprite.texture = load(str(cfg["photo"]))
		sprite.pixel_size = box.size.x * 0.86 / float(sprite.texture.get_width())
		sprite.position = Vector3(box.get_center().x, box.get_center().y, front)
		visual.add_child(sprite)
	if cfg.has("stamp"):
		var stamp: Label3D = _label(str(cfg["stamp"]), 22, 0.0006, STAMP_COLOR)
		stamp.name = "DateStamp"
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stamp.position = Vector3(box.end.x - box.size.x * 0.08, box.position.y + box.size.y * 0.12, front + 0.001)
		visual.add_child(stamp)
	if cfg.has("note"):
		var note: Label3D = _label(str(cfg["note"]), 20, box.size.x * 0.0042, NOTE_COLOR)
		note.width = box.size.x * 0.9 / note.pixel_size
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.name = "NoteText"
		note.position = Vector3(box.get_center().x, box.get_center().y, front)
		visual.add_child(note)


static func _make_reveals(list: Array) -> Array[OOTRevealSpot]:
	var out: Array[OOTRevealSpot] = []
	for r: Dictionary in list:
		var spot: OOTRevealSpot = OOTRevealSpot.new()
		spot.id = StringName(str(r.get("id", "")))
		var d: Array = r.get("direction", [0, 0, -1])
		spot.direction = Vector3(float(d[0]), float(d[1]), float(d[2]))
		spot.max_camera_distance = float(r.get("max_camera_distance", 0.0))
		spot.text = str(r.get("text", ""))
		spot.journal_entry = str(r.get("journal_entry", ""))
		out.append(spot)
	return out


static func _label(text: String, font_size: int, pixel: float, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	return label


## Combined mesh bounds of a node's children, in the node's local space.
static func _local_aabb(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var inv: Transform3D = root.global_transform.affine_inverse()
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var box: AABB = (inv * mi.global_transform) * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
