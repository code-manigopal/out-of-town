extends SceneTree
## UI tests: reticle styles, inspect layout and reveals, journal. Run:
##   godot --headless --path game --script res://tests/run_ui_tests.gd
## Exits with code 1 on any failure.

var _failures: int = 0
var _checks: int = 0
var _state: Node


func _initialize() -> void:
	_state = root.get_node_or_null("StoryState")
	_check(_state != null, "StoryState autoload exists")
	if _state == null:
		quit(1)
		return
	if not _lfs_assets_present():
		print("NOTE: Git LFS assets not checked out; UI tests use only synthetic nodes anyway.")
	await process_frame
	_state.start_part("p1")
	_test_state_journal()
	await _test_reticle()
	await _test_inspect()
	await _test_journal()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


static func _lfs_assets_present() -> bool:
	var f: FileAccess = FileAccess.open("res://characters/mani/mani.glb", FileAccess.READ)
	if f == null:
		return false
	return not f.get_buffer(24).get_string_from_ascii().begins_with("version https://git-lfs")


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + msg)


func _make_item(item_id: String, name_text: String, kind: OOTInteractable.Kind = OOTInteractable.Kind.INSPECT) -> OOTInteractable:
	var it: OOTInteractable = OOTInteractable.new()
	it.item_id = item_id
	it.display_name = name_text
	it.kind = kind
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.0, 0.7, 0.05)
	mi.mesh = box
	visual.add_child(mi)
	var decal: MeshInstance3D = MeshInstance3D.new()
	decal.name = "RevealDecal"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.5, 0.2)
	decal.mesh = quad
	visual.add_child(decal)
	it.add_child(visual)
	return it


func _test_state_journal() -> void:
	_check(_state.journal_entries().is_empty(), "journal starts empty")
	_check(_state.journal_add("e1_voicemail"), "journal_add returns true for new entry")
	_check(not _state.journal_add("e1_voicemail"), "journal_add is idempotent")
	_check(_state.journal_has("e1_voicemail"), "journal_has")
	var saved: Dictionary = _state.to_dict()
	_state.start_part("p1")
	_check(not _state.journal_has("e1_voicemail"), "start_part clears the journal")
	_state.from_dict(saved)
	_check(_state.journal_has("e1_voicemail"), "journal persists through save/load dict")
	_state.save_game("uitest")
	_state.start_part("p1")
	_check(_state.load_game("uitest") == OK and _state.journal_has("e1_voicemail"), "journal persists through save file")
	_state.delete_save("uitest")
	var data: Dictionary = OOTJournalData.all_entries()
	_check(data.size() >= 8, "journal data loads")
	for id: Variant in data:
		var e: Dictionary = data[id]
		_check((OOTJournalData.SECTIONS.has(str(e.get("section", ""))) or OOTJournalData.is_objective(str(id))) and e.has("title") and e.has("text"),
				"entry %s has section/title/text" % id)
	_check(OOTJournalData.entry_for_item("grad_photo") == "e1_grad_photo", "item_id maps to journal entry")
	_state.start_part("p1")


func _test_reticle() -> void:
	var hud: OOTHud = (load("res://ui/hud/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
	var expect: Dictionary = {
		OOTInteractable.Kind.INSPECT: &"inspect", OOTInteractable.Kind.PICKUP: &"pickup", OOTInteractable.Kind.USE: &"use"}
	for k: Variant in expect:
		var it: OOTInteractable = _make_item("t", "Thing", k)
		_check(it.get_reticle_hint() == expect[k], "default reticle hint for kind %s" % k)
		hud.set_target(it)
		_check(hud.reticle.style == expect[k], "reticle style follows kind %s" % k)
		it.free()
	for h: StringName in [&"door", &"talk"]:
		var it2: OOTInteractable = _make_item("t", "Thing", OOTInteractable.Kind.USE)
		it2.reticle_hint = h
		hud.set_target(it2)
		_check(hud.reticle.style == h, "reticle_hint override %s" % h)
		it2.free()
	hud.set_target(null)
	_check(hud.reticle.style == &"dot", "no target -> dot")
	_check(OOTUiSettings.show_interact_names, "show_interact_names defaults on")
	_check(hud.get_tree().get_nodes_in_group("oot_journal").size() == 1, "HUD brings the journal")
	hud.queue_free()
	await process_frame


func _test_inspect() -> void:
	var view: OOTInspectView = (load("res://ui/inspect/inspect_view.tscn") as PackedScene).instantiate()
	var holder: Control = Control.new()
	holder.size = Vector2(1280, 720)
	root.add_child(holder)
	holder.add_child(view)
	await process_frame
	await process_frame
	var W: float = view.size.x
	var H: float = view.size.y
	var photo: OOTInteractable = _make_item("grad_photo", "Graduation photo")
	root.add_child(photo)
	var back: OOTRevealSpot = OOTRevealSpot.new()
	back.id = &"back"
	back.direction = Vector3(0, 0, -1)
	back.hold_time = 0.2
	back.text = "Written on the back."
	back.journal_entry = "e1_grad_photo_back"
	var stamp: OOTRevealSpot = OOTRevealSpot.new()
	stamp.id = &"stamp"
	stamp.direction = Vector3(0, 0, 1)
	stamp.max_camera_distance = 1.5
	stamp.hold_time = 0.0
	stamp.text = "A date stamp."
	photo.reveals = [back, stamp]
	_check(view.open_for(photo), "inspect opens")
	await process_frame
	var obj: Rect2 = view.get_object_rect()
	var pan: Rect2 = view.get_panel_rect()
	_check(obj.position.x >= W * 0.38 and obj.end.x >= W - 1.0 and obj.size.y >= H - 1.0, "object area fills the right side (%s)" % obj)
	_check(pan.end.x <= obj.position.x and pan.position.x < 100.0 and pan.size.x > W * 0.28, "notes panel is on the left, readable (%s) W=%s obj=%s" % [pan, W, obj])
	_check(_state.journal_has("e1_grad_photo"), "inspecting adds the journal entry")
	# Front is toward the camera: back not revealed.
	view.update_reveals(1.0)
	_check(not photo.revealed_ids.has(&"back"), "back not revealed while front faces camera")
	_check(not photo.revealed_ids.has(&"stamp"), "zoom reveal needs zoom")
	view.set_zoom(1.2)
	view.update_reveals(0.1)
	_check(photo.revealed_ids.has(&"stamp"), "front zoom reveal triggers when zoomed in")
	view.set_zoom(2.2)
	view.rotate_item(Vector2(PI / 0.01, 0))
	view.update_reveals(0.1)
	_check(not photo.revealed_ids.has(&"back"), "reveal waits for hold time")
	view.update_reveals(0.2)
	_check(photo.revealed_ids.has(&"back"), "rotating the back to the camera reveals it")
	_check(_state.journal_has("e1_grad_photo_back"), "reveal adds its journal entry")
	var decal: Node3D = view._holder.get_child(0).get_node("RevealDecal")
	_check(decal.visible, "RevealDecal shown after reveal")
	view.close()
	_check(not view.is_open, "inspect closes")
	view.open_for(photo)
	_check(view._holder.get_child(0).get_node("RevealDecal").visible, "revealed decal stays visible on reopen")
	view.close()
	# A multi-line caption (whiteboard job history) fits in the scrolling panel.
	var wb: OOTInteractable = _make_item("whiteboard", "Whiteboard")
	root.add_child(wb)
	view.open_for(wb)
	view._caption.text = "Line one\nLine two\nLine three\nLine four\nLine five\nLine six\nLine seven\nLine eight"
	view._caption.visible = true
	await process_frame
	await process_frame
	_check(view.get_panel_rect().size.y <= H, "multi-line text stays inside the panel")
	view.close()
	photo.queue_free()
	wb.queue_free()
	holder.queue_free()
	await process_frame


func _test_journal() -> void:
	_state.start_part("p1")
	var j: OOTJournal = (load("res://ui/journal/journal.tscn") as PackedScene).instantiate()
	root.add_child(j)
	await process_frame
	for id: String in ["e1_goal_packing", "e1_goal_ruth", "e1_voicemail", "e1_person_nila", "e1_whiteboard", "e1_gift_radio",
			"e1_grad_photo", "e1_nila_photo"]:
		_state.journal_add(id)
	j.open()
	_check(j.is_open and paused, "journal opens and pauses the game")
	_check(j.spread_count() >= 3, "one spread per section at least")
	_check(not OOTJournalData.SECTIONS.has("goal") and not j._tabs.has("goal"), "the journal has no Current goal tab any more")
	_check(j.current_section() == "people" and j.current_entry_ids().has("e1_person_nila"), "journal opens on People")
	_check(not j.current_entry_ids().has("e1_goal_ruth"), "goal entries are not journal pages")
	_check(j.next_page() and j.current_section() == "clues", "turn page forward -> Clues")
	_check(j.prev_page() and j.spread_index == 0, "turn page back")
	_check(not j.prev_page(), "cannot turn before the first page")
	j.open("clues")
	j.close()
	j.open("clues")
	_check(j.current_section() == "clues" and j.current_entry_ids().has("e1_voicemail"), "open(section) goes to Clues")
	j.close()
	_check(not j.is_open and not paused, "journal closes and unpauses")
	# Enough notes to overflow into a second notes spread.
	var notes_before: int = j.spread_count()
	for i: int in range(12):
		_state.journal_add("e1_whiteboard")
	j.rebuild_spreads()
	_check(j.spread_count() == notes_before, "duplicates are not added twice")
	j.queue_free()
	await process_frame


func _unused() -> void:
	pass
