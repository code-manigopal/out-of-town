extends SceneTree
## Storytelling-UI tests: narration skipping, objectives, hints, phone data, the phone (Tab), the notification banner,
## the objective toast and the cold-open lock screen. Run:
##   godot --headless --path game --script res://tests/run_story_ui_tests.gd
## Exits with code 1 on any failure.

var _failures: int = 0
var _checks: int = 0
var _state: Node


func _initialize() -> void:
	_state = root.get_node_or_null("StoryState")
	if _state == null:
		printerr("FAIL: StoryState autoload missing")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	await process_frame
	_test_hints()
	await _test_narration_skipped()
	_test_objectives()
	_test_phone_data()
	await _test_phone_ui()
	await _test_banner()
	await _test_toast()
	await _test_lock_screen()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _test_hints() -> void:
	_check(OOTHints.text("need_car_keys") == "I need my car keys.", "hint text comes from data/ui/p1_hints.json")
	_check(OOTHints.text("need_bag") == "I'm not leaving without the bag.", "second hint")
	_check(OOTHints.fmt("picked_up", ["Duffel"]) == "Picked up: Duffel", "hint with an argument")
	_check(OOTHints.text("no_such_hint") == "no_such_hint", "unknown hint returns its id")
	var src: String = FileAccess.get_file_as_string("res://scripts/episodes/e1/apartment.gd")
	_check(not src.contains("\"I need my car keys.\"") and not src.contains("\"I'm not leaving without the bag.\""),
			"apartment.gd has no hard-coded hint strings")
	_check(InputMap.has_action("phone"), "input action 'phone' exists")
	var has_tab: bool = false
	for e: InputEvent in InputMap.action_get_events("phone"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_P:
			has_tab = true
	_check(has_tab, "phone is bound to P")
	_check(OOTPhone.key_name() == "P" and OOTHints.key_name("phone") == "P", "the phone key reads P")


func _test_narration_skipped() -> void:
	_state.start_part("p1")
	var runner: OOTStoryRunner = OOTStoryRunner.new()
	runner.part_id = "p1"
	var box: OOTDialogueBox = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate() as OOTDialogueBox
	root.add_child(box)
	await process_frame
	_check(not box.show_narration, "show_narration defaults to false")
	var narration: Array[String] = []
	var db: Node = root.get_node("StoryDB")
	for sid: String in ["e1_open", "e1_apt", "e1_call"]:
		for l: OOTDialogueLine in db.get_scene("p1", sid).lines:
			if l.is_narration:
				narration.append(l.text)
	_check(narration.size() >= 4, "the cold open, apartment and call scenes have narration lines (%d)" % narration.size())
	runner.enter("e1_open")
	box.begin(runner)
	var speaker: Label = box.find_child("Speaker", true, false) as Label
	var text: RichTextLabel = box.find_child("LineText", true, false) as RichTextLabel
	_check(speaker.text.begins_with("NILA"), "e1_open opens on Nila's voicemail line, not narration (%s)" % speaker.text)
	var seen: Array[String] = []
	var guard: int = 0
	while box.is_open and guard < 10:
		seen.append(text.get_parsed_text())
		for n: String in narration:
			_check(text.get_parsed_text() != n, "narration is not shown: %s" % n.left(30))
		box.advance()
		guard += 1
	_check(seen.size() == 3, "the voicemail shows exactly its 3 spoken lines (%d)" % seen.size())
	# e1_apt is all narration: the box hands control straight back.
	var finished: Array[String] = []
	box.finished.connect(func(id: String) -> void: finished.append(id))
	runner.enter("e1_apt")
	box.begin(runner)
	_check(not box.is_open and finished == ["e1_apt"], "an all-narration scene shows nothing and hands over (%s)" % [finished])
	# The call keeps spoken lines and choices.
	runner.enter("e1_call")
	box.begin(runner)
	_check(speaker.text == "AMMA", "the call starts on Amma (%s)" % speaker.text)
	guard = 0
	while box.get_node("Margin") != null and box._choices.get_child_count() == 0 and guard < 10:
		box.advance()
		guard += 1
	_check(box._choices.get_child_count() == 2, "choices still appear (%d)" % box._choices.get_child_count())
	box.queue_free()
	# With show_narration on, narration is presented (the dialogue test scene keeps its own full display).
	var box2: OOTDialogueBox = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate() as OOTDialogueBox
	box2.show_narration = true
	root.add_child(box2)
	await process_frame
	runner.enter("e1_open")
	box2.begin(runner)
	var t2: RichTextLabel = box2.find_child("LineText", true, false) as RichTextLabel
	_check(t2.get_parsed_text().begins_with("Radio static"), "show_narration=true presents the narration line")
	box2.queue_free()
	var dt: String = FileAccess.get_file_as_string("res://ui/dialogue/dialogue_test.gd")
	_check(not dt.contains("OOTDialogueBox"), "dialogue_test.tscn has its own display and still shows every line")
	await process_frame


func _test_objectives() -> void:
	_state.start_part("p1")
	var started: Array[String] = []
	var finished: Array[String] = []
	_state.objective_started.connect(func(id: String) -> void: started.append(id))
	_state.objective_finished.connect(func(id: String) -> void: finished.append(id))
	_check(_state.objective_current() == "", "no objective at the start")
	_check(OOTJournalData.grant("e1_goal_packing"), "granting a goal entry works")
	_check(_state.objective_current() == "e1_goal_packing" and started == ["e1_goal_packing"], "a goal journal entry becomes the current objective")
	_check(not _state.journal_has("e1_goal_packing"), "a goal is not a journal page")
	_check(not OOTJournalData.grant("e1_goal_packing"), "granting the same goal twice does nothing")
	OOTJournalData.grant("e1_goal_leave")
	_check(_state.objective_current() == "e1_goal_leave" and finished == ["e1_goal_packing"], "a new goal completes the previous one")
	_check(_state.objective_is_done("e1_goal_packing") and not _state.objective_is_done("e1_goal_leave"), "done flags")
	_check(_state.objective_list() == ["e1_goal_packing", "e1_goal_leave"], "objectives are kept in order")
	_check(_state.objective_complete("e1_goal_leave") and _state.objective_current() == "", "objective_complete clears the current objective")
	_check(not _state.objective_complete("nope"), "completing an unknown objective is false")
	OOTJournalData.grant("e1_goal_ruth")
	var d: Dictionary = _state.to_dict()
	_state.save_game("storyuitest")
	_state.start_part("p1")
	_check(_state.objective_current() == "" and _state.objective_list().is_empty(), "start_part clears objectives")
	_state.start_part("p1")
	_check(_state.load_game("storyuitest") == OK, "load")
	_check(_state.objective_current() == "e1_goal_ruth" and _state.objective_is_done("e1_goal_leave") and _state.objective_list().size() == 3,
			"objectives persist through save/load")
	_state.delete_save("storyuitest")
	_state.from_dict(d)
	_check(_state.objective_current() == "e1_goal_ruth", "objectives persist through to_dict/from_dict")
	_state.start_part("p1")


func _test_phone_data() -> void:
	_state.start_part("p1")
	var ids: Array[String] = OOTPhoneData.thread_ids()
	_check(ids == ["nila", "tess", "amma"], "threads in order (%s)" % [ids])
	_check(OOTPhoneData.messages("nila").size() == 4, "Nila has her last messages before Sunday")
	_check(OOTPhoneData.messages("tess").is_empty(), "Tess's thread is empty until her texts arrive")
	_check(OOTPhoneData.messages("amma").size() == 2, "Amma has 2 messages")
	_check(OOTPhoneData.unread_count() == 2 and OOTPhoneData.unread_count("amma") == 2, "Amma's messages are unread")
	for m: Dictionary in OOTPhoneData.messages("amma") + OOTPhoneData.messages("nila"):
		_check(not str(m.get("subtitle", "")).is_empty(), "Tanglish message %s has an English subtitle" % m["id"])
	_check(OOTPhoneData.photos().size() == 3, "three photos")
	for p: Dictionary in OOTPhoneData.photos():
		_check(load(str(p["file"])) is Texture2D, "photo loads: %s" % p["id"])
	_check(OOTPhoneData.calls().size() == 1 and str(OOTPhoneData.calls()[0]["kind"]) == "voicemail", "only Nila's voicemail at the very start")
	_state.set_flag("e1_apt_started")
	_state.set_flag("e1_call_taken")
	_check(OOTPhoneData.calls().size() == 3, "call log grows with story flags")
	_check(OOTPhoneData.vo_line("e1_open_001") != null and OOTPhoneData.vo_line("e1_open_001").speaker == "NILA", "VO line id resolves to its dialogue line")
	_check(OOTPhone.notify_message("tess", "tess_2"), "notify_message delivers a message")
	_check(not OOTPhone.notify_message("tess", "tess_2"), "...only once")
	_check(not OOTPhone.notify_message("nila", "tess_1"), "wrong thread for a message is refused")
	_check(OOTPhoneData.messages("tess").size() == 1 and OOTPhoneData.unread_count("tess") == 1, "delivered message is visible and unread")
	var saved: Dictionary = _state.to_dict()
	_state.start_part("p1")
	_check(OOTPhoneData.messages("tess").is_empty(), "start_part clears delivered messages")
	_state.from_dict(saved)
	_check(OOTPhoneData.messages("tess").size() == 1, "delivered messages persist through save/load")
	_state.phone_mark_read("tess_2")
	_check(OOTPhoneData.unread_count("tess") == 0, "mark read")
	_state.start_part("p1")


func _key(action: String, pressed: bool = true) -> InputEventAction:
	var e: InputEventAction = InputEventAction.new()
	e.action = action
	e.pressed = pressed
	return e


func _page_text(phone: OOTPhone) -> String:
	var out: PackedStringArray = PackedStringArray()
	for l: Node in phone._content.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return " | ".join(out)


func _test_phone_ui() -> void:
	_state.start_part("p1")
	var runner: OOTStoryRunner = OOTStoryRunner.new()
	runner.part_id = "p1"
	runner.enter("e1_apt")
	OOTJournalData.grant("e1_goal_packing")
	OOTJournalData.grant("e1_goal_leave")
	var holder: Control = Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.size = Vector2(1280, 720)
	root.add_child(holder)
	var phone: OOTPhone = OOTPhone.new()
	phone.animate = false
	holder.add_child(phone)
	await process_frame
	phone.position = Vector2.ZERO
	phone.size = Vector2(1280, 720)   # the headless window is 64x64; lay the phone out as in the 1280x720 game
	_check(OOTPhone.instance() == phone, "OOTPhone.instance() finds the phone")
	_check(not phone.is_open and not phone._root.visible, "closed at the start")
	phone._input(_key("phone"))
	await process_frame
	_check(phone.is_open and phone._root.visible and phone.page == "home", "the phone action opens the phone on the home screen")
	_check(phone._body.get_global_rect().get_center().distance_to(Vector2(640, 360)) < 3.0, "the phone is centred on screen (%s)" % phone._body.get_global_rect().get_center())
	_check(phone._status_time.text == "09:05", "the clock shows the story time (%s)" % phone._status_time.text)
	_check(phone._content.find_child("App_objectives", true, false) != null and phone._content.find_child("App_calls", true, false) != null, "apps on the home screen")
	_check(phone._content.find_child("App_messages", true, false) != null and phone._content.find_child("App_photos", true, false) != null, "Calls, Messages, Objectives and Photos on the home screen")
	_check(phone._content.find_child("Badge", true, false) != null, "Messages shows an unread badge")
	_check(phone._content.find_child("NowCard", true, false) != null, "the home screen shows the current objective")
	# Objectives
	phone.go("objectives")
	await process_frame
	_check(phone._content.find_child("Objective_e1_goal_leave", true, false) != null, "current objective listed")
	_check(phone._content.find_child("Objective_e1_goal_packing", true, false) != null, "completed objective listed")
	_check(_page_text(phone).contains("Pack, then go") and _page_text(phone).contains("Get on the road"), "objective titles come from the journal data")
	# Messages
	phone.back()
	phone.go("messages")
	await process_frame
	_check(phone._content.find_child("Thread_nila", true, false) != null and phone._content.find_child("Thread_tess", true, false) != null
			and phone._content.find_child("Thread_amma", true, false) != null, "three threads")
	_check(_page_text(phone).contains("No messages yet"), "Tess's thread says it is empty")
	phone.go("thread", "amma")
	await process_frame
	await process_frame
	var txt: String = _page_text(phone)
	_check(txt.contains("Kanna, call pannu. Nila phone edukkala.") and txt.contains("Kanna, call me. Nila isn't picking up."),
			"Amma's Tanglish message shows its English subtitle under the bubble")
	_check(phone._content.find_children("Subtitle", "Label", true, false).size() == 2, "a subtitle under each Tanglish bubble")
	_check(txt.contains("Monday") and txt.contains("Tuesday"), "day separators")
	_check(OOTPhoneData.unread_count("amma") == 0, "opening the thread marks it read")
	phone.back()
	phone.go("thread", "nila")
	await process_frame
	await process_frame
	_check(phone._content.find_children("Msg_*", "HBoxContainer", true, false).size() == 4, "Nila thread: 4 bubbles")
	_check(_page_text(phone).contains("Read"), "outgoing bubbles show a read state")
	phone.go("thread", "tess")
	await process_frame
	_check(_page_text(phone).contains("No messages yet."), "empty Tess thread page")
	# Photos
	phone.go("photos")
	await process_frame
	_check(phone._content.find_children("Photo_*", "Button", true, false).size() == 3, "photo grid has 3 photos")
	phone.go("photo", "1")
	await process_frame
	_check((phone._content.find_child("Picture", true, false) as TextureRect).texture != null and _page_text(phone).contains("Convocation"), "photo viewer shows the convocation photo")
	phone._input(_key("ui_right"))
	await process_frame
	_check(phone.page == "photo" and phone.page_arg == "2" and _page_text(phone).contains("Baby Nila"), "right arrow steps to the next photo")
	phone.back()
	_check(phone.page == "photos", "Back from a photo returns to the gallery")
	# Calls: the Sunday voicemail plays its VO
	phone.go("calls")
	await process_frame
	var rows: Array[Node] = phone._content.find_children("Call_*", "Button", true, false)
	_check(rows.size() == 1, "calls: one entry at this point (%d)" % rows.size())
	(phone._content.find_child("Call_call_voicemail", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	_check(phone.page == "call" and phone.page_arg == "call_voicemail", "tapping the voicemail opens it")
	_check(phone.vm_playing and phone._vm_player.playing, "the voicemail plays its VO")
	_check(phone._vm_player.bus == &"VO", "voicemail audio is on the VO bus")
	_check(phone._vm_lines == ["e1_open_001", "e1_open_002", "e1_open_003"], "voicemail plays e1_open VO lines")
	var vt: String = _page_text(phone)
	_check(vt.contains("Anna, naan dhaan") and vt.contains("I found something. I can't say it on the phone."), "transcript carries Tanglish and English subtitle")
	phone.back()
	_check(not phone.vm_playing and not phone._vm_player.playing, "leaving the voicemail stops playback")
	# Close with Esc
	phone._input(_key("pause"))
	_check(not phone.is_open, "Esc closes the phone")
	phone._input(_key("phone"))
	_check(phone.is_open and phone.page == "home", "reopens on the home screen")
	phone._input(_key("phone"))
	_check(not phone.is_open, "P closes the phone")
	holder.queue_free()
	await process_frame


func _test_banner() -> void:
	_state.start_part("p1")
	var holder: Control = Control.new()
	holder.size = Vector2(1280, 720)
	root.add_child(holder)
	var phone: OOTPhone = OOTPhone.new()
	phone.animate = false
	holder.add_child(phone)
	await process_frame
	var shown: Array[String] = []
	phone.banner_shown.connect(func(t: String, m: String) -> void: shown.append("%s/%s" % [t, m]))
	_check(not phone.banner_visible(), "no banner at first")
	OOTPhone.notify_message("tess", "tess_2")
	await process_frame
	_check(phone.banner_visible() and shown == ["tess/tess_2"], "a new message shows the banner (%s)" % [shown])
	_check(phone._banner_name.text == "Tess" and phone._banner_text.text.begins_with("haven't seen her"), "banner shows sender and text")
	_check(phone._vib_player.stream is AudioStreamWAV and phone._vib_player.playing, "the vibrate sound plays")
	phone.open()
	_check(not phone.banner_visible(), "opening the phone dismisses the banner")
	phone.go("messages")
	await process_frame
	_check(_page_text(phone).contains("haven't seen her since sunday night"), "the message is in the thread preview")
	# Message arriving while the phone is open: no banner, thread refreshes.
	phone.go("thread", "tess")
	await process_frame
	OOTPhone.notify_message("tess", "tess_1")
	await process_frame
	await process_frame
	_check(not phone.banner_visible(), "no banner while the phone is open")
	_check(phone._content.find_children("Msg_*", "HBoxContainer", true, false).size() == 2, "an open thread updates with the new message")
	phone.close()
	holder.queue_free()
	await process_frame


func _test_toast() -> void:
	_state.start_part("p1")
	var holder: Control = Control.new()
	holder.size = Vector2(1280, 720)
	root.add_child(holder)
	var toast: OOTObjectiveToast = OOTObjectiveToast.new()
	holder.add_child(toast)
	await process_frame
	_check(not toast.visible and toast.modulate.a == 0.0, "toast hidden at first")
	OOTJournalData.grant("e1_goal_packing")
	_check(toast.is_showing and toast.title_text == "Pack, then go", "an objective change shows the toast with the journal title")
	_check(toast.position.x < 60.0 and toast.position.y < 60.0, "the toast is in the top-left corner (%s)" % toast.position)
	await _wait(0.2)
	_check(toast.modulate.a > 0.0 and toast.modulate.a < 1.0, "fading in (%.2f)" % toast.modulate.a)
	await _wait(0.9)
	_check(toast.modulate.a > 0.99, "fully visible while held (%.2f)" % toast.modulate.a)
	await _wait(3.4)
	_check(toast.modulate.a > 0.99 and toast.is_showing, "held about four seconds")
	await _wait(0.9)
	_check(toast.modulate.a < 0.99 and toast.modulate.a > 0.0 and toast.is_showing, "smoothly fading out (%.2f)" % toast.modulate.a)
	await _wait(1.1)
	_check(not toast.is_showing and not toast.visible, "gone afterwards")
	# The HUD brings the phone and the toast.
	var hud: OOTHud = (load("res://ui/hud/hud.tscn") as PackedScene).instantiate() as OOTHud
	root.add_child(hud)
	await process_frame
	_check(hud.phone != null and hud.objective_toast != null and hud.get_tree().get_nodes_in_group("oot_phone").size() == 1, "the HUD brings the phone and the objective toast")
	# the opening objective: "Check the Phone [P]" (text from the journal data, the key from the input map)
	hud.objective_toast.show_objective("e1_goal_phone")
	_check(hud.objective_toast.title_text == "Check the Phone [P]" and hud.objective_toast.body_text.is_empty(), "the toast reads 'Check the Phone [P]' (%s)" % hud.objective_toast.title_text)
	# Mani's inner voice: THOUGHT channel line, italic subtitle, no speaker frame
	_check(hud.show_thought("e1_thought_pack1") and hud.thought.is_showing, "the inner-voice line plays from the HUD")
	_check(hud.thought.text_shown.begins_with("Nila enna solla vandhaa") and hud.thought.subtitle_shown == "What was Nila trying to tell me? Is something wrong?", "thought text and English subtitle (%s)" % hud.thought.subtitle_shown)
	_check(OOTVoiceLines.has_stream("e1_thought_pack1_000") and not OOTVoiceLines.get_lip_cues("e1_thought_pack1_000").is_empty(), "the thought has VO and lip cues")
	var tl: OOTDialogueLine = OOTServices.db().get_scene("p1", "e1_thought_pack1").lines[0]
	_check(OOTThoughtSubtitle.is_thought(tl) and tl.speaker == "MANI", "e1_thought_pack1 is a MANI (THOUGHT) line")
	var tbox: OOTDialogueBox = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate() as OOTDialogueBox
	holder.add_child(tbox)
	var trunner: OOTStoryRunner = OOTStoryRunner.new()
	trunner.part_id = "p1"
	trunner.enter("e1_thought_pack1")
	tbox.begin(trunner, "e1_apt")
	_check(tbox._speaker_label(tl).is_empty() and not tbox._speaker.visible, "a thought shows no speaker name in the dialogue box")
	_check((tbox._panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a == 0.0, "a thought has no frame behind it")
	tbox.queue_free()
	hud.queue_free()
	holder.queue_free()
	await process_frame


func _test_lock_screen() -> void:
	_state.start_part("p1")
	var runner: OOTStoryRunner = OOTStoryRunner.new()
	runner.part_id = "p1"
	runner.enter("e1_open")
	var lock: OOTPhoneLockScreen = OOTPhoneLockScreen.new()
	root.add_child(lock)
	await process_frame
	lock.setup(runner.scene)
	await process_frame
	_check(lock.who_text == "Nila" and lock.when_text == "Sunday 23:52", "lock screen reads sender and time from the scene (%s, %s)" % [lock.who_text, lock.when_text])
	var texts: PackedStringArray = PackedStringArray()
	for l: Node in lock.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var all: String = " ".join(texts)
	_check(all.contains("Nila") and all.contains("Sunday 23:52") and all.contains("23:52") and all.to_upper().contains("VOICEMAIL"), "lock screen shows Voicemail, Nila, Sunday 23:52 (%s)" % all)
	_check(lock.wave != null, "lock screen has a waveform")
	lock.queue_free()
	await process_frame
