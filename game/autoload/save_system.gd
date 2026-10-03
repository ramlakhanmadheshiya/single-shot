extends Node
## Versioned local progress and settings. Each level uses a stable string key.
const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 2
var data: Dictionary = {}

func _ready() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_data()
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		data = _default_data()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	data = parsed if parsed is Dictionary else _default_data()
	_migrate()

func save() -> void:
	data["save_version"] = SAVE_VERSION
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func get_setting(key: String, fallback: Variant = null) -> Variant:
	var settings: Dictionary = data.get("settings", {})
	return settings.get(key, fallback)

func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[key] = value
	data["settings"] = settings
	save()
	Events.setting_changed.emit(key, value)

func get_level(level_id: String) -> Dictionary:
	var levels: Dictionary = data.get("levels", {})
	var record: Variant = levels.get(level_id, {})
	return record if record is Dictionary else {}

func record_level(level_id: String, stars: int, badge: bool = false) -> void:
	var levels: Dictionary = data.get("levels", {})
	var previous: Dictionary = get_level(level_id)
	levels[level_id] = {"stars": maxi(stars, int(previous.get("stars", 0))), "badge": badge or bool(previous.get("badge", false))}
	data["levels"] = levels
	save()

func total_stars() -> int:
	var total: int = 0
	var levels: Dictionary = data.get("levels", {})
	for record: Variant in levels.values():
		if record is Dictionary:
			total += int(record.get("stars", 0))
	return total

func chapter_is_open(chapter_number: int) -> bool:
	if chapter_number <= 1:
		return true
	var levels: Dictionary = data.get("levels", {})
	var previous_chapter: int = chapter_number - 1
	for number: int in 20:
		var level_id: String = "ch%02d_l%03d" % [previous_chapter, number + 1]
		if not levels.has(level_id):
			return false
	return true

func reset_progress() -> void:
	data["levels"] = {}
	data["unlocks"] = ["ch01"]
	data["tutorial_seen"] = false
	var settings: Dictionary = data.get("settings", {})
	settings["last_played_chapter"] = 0
	data["settings"] = settings
	save()

func _default_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"levels": {},
		"unlocks": ["ch01"],
		"tutorial_seen": false,
		"settings": {
			"music_volume": 0.65,
			"sound_volume": 0.8,
			"ui_volume": 0.85,
			"sound_enabled": true,
			"music_enabled": true,
			"vibration": true,
			"show_aim_guide": true,
			"screen_shake": true,
			"theme": "dark",
			"last_played_chapter": 0
		}
	}

func _migrate() -> void:
	var defaults: Dictionary = _default_data()
	for key: String in defaults:
		if not data.has(key):
			data[key] = defaults[key]
	var old_settings: Dictionary = data.get("settings", {})
	var default_settings: Dictionary = defaults["settings"]
	for key: String in default_settings:
		if not old_settings.has(key):
			old_settings[key] = default_settings[key]
	# Carry forward the old Foundation volume and guide choices.
	if old_settings.has("music") and not old_settings.has("music_volume"):
		old_settings["music_volume"] = old_settings["music"]
	if old_settings.has("sfx") and not old_settings.has("sound_volume"):
		old_settings["sound_volume"] = old_settings["sfx"]
	if old_settings.has("ui") and not old_settings.has("ui_volume"):
		old_settings["ui_volume"] = old_settings["ui"]
	if old_settings.has("aim_assist") and not old_settings.has("show_aim_guide"):
		old_settings["show_aim_guide"] = old_settings["aim_assist"]
	data["settings"] = old_settings
	data["save_version"] = SAVE_VERSION
	save()
