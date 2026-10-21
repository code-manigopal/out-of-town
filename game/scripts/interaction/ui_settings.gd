class_name OOTUiSettings
extends RefCounted
## Small player-facing UI options, persisted in user://settings.cfg.

const PATH: String = "user://settings.cfg"

## Fade in a small name next to the reticle when something can be interacted with.
static var show_interact_names: bool = true
static var _loaded: bool = false


static func load_settings() -> void:
	_loaded = true
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) == OK:
		show_interact_names = bool(cfg.get_value("ui", "show_interact_names", true))


static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()


static func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("ui", "show_interact_names", show_interact_names)
	cfg.save(PATH)
