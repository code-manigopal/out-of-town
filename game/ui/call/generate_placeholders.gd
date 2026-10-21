extends SceneTree
## Renders the three *_placeholder.png call stills (needs a window: do not pass --headless):
##   godot --path game --script res://ui/call/generate_placeholders.gd

func _initialize() -> void:
	for key: String in OOTCallImages.KEYS:
		var vp: SubViewport = SubViewport.new()
		vp.size = OOTCallImages.IMAGE_SIZE
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var art: OOTCallPlaceholderArt = OOTCallPlaceholderArt.new()
		art.size = Vector2(OOTCallImages.IMAGE_SIZE)
		art.who = {"amma_close": "amma", "appa_close": "appa"}.get(key, "wide")
		vp.add_child(art)
		await process_frame
		await process_frame
		await process_frame
		var img: Image = vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var path: String = ProjectSettings.globalize_path(OOTCallImages.placeholder_path(key))
		print("saved ", path, " ", img.save_png(path), " ", img.get_size())
		vp.queue_free()
	quit()
