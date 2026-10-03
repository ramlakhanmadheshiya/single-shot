extends Node
## Versioned local progress and settings. Each level uses a stable string key.
const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 4
var data: Dictionary = {}

func _ready() -> void:
	load_save()
	update_daily_hints()

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

func update_daily_hints(today: String = "") -> void:
	if today.is_empty():
		today = local_date_string()
	var changed: bool = false
	if not data.has("hints_left"):
		data["hints_left"] = 3
		changed = true
	if not data.has("bonus_hints"):
		data["bonus_hints"] = 0
		changed = true
	var last_reset: String = str(data.get("last_reset_date", ""))
	var last_seen: String = str(data.get("last_seen_date", ""))
	if last_reset.is_empty():
		last_reset = today
		data["last_reset_date"] = today
		changed = true
	var effective_day: String = today
	if last_seen > effective_day:
		effective_day = last_seen
	if last_reset > effective_day:
		effective_day = last_reset
	if effective_day > last_reset:
		data["hints_left"] = 3
		data["last_reset_date"] = effective_day
		changed = true
	if effective_day > last_seen:
		data["last_seen_date"] = effective_day
		changed = true
	if changed:
		save()

func local_date_string() -> String:
	var date: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.get("year", 2000)), int(date.get("month", 1)), int(date.get("day", 1))]

func spend_hint() -> bool:
	update_daily_hints()
	var free_count: int = int(data.get("hints_left", 0))
	if free_count > 0:
		data["hints_left"] = free_count - 1
		save()
		return true
	var bonus_count: int = int(data.get("bonus_hints", 0))
	if bonus_count > 0:
		data["bonus_hints"] = bonus_count - 1
		save()
		return true
	return false

func add_bonus_hint(count: int = 1) -> void:
	data["bonus_hints"] = int(data.get("bonus_hints", 0)) + maxi(0, count)
	save()

func record_level(level_id: String, stars: int, badge: bool = false, shots: int = 999) -> void:
	var levels: Dictionary = data.get("levels", {})
	var previous: Dictionary = get_level(level_id)
	var best_shots: int = mini(shots, int(previous.get("best_shots", 999)))
	levels[level_id] = {"stars": maxi(stars, int(previous.get("stars", 0))), "badge": badge or bool(previous.get("badge", false)), "best_shots": best_shots}
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
	data["tutorial_levels_seen"] = []
	data["current_level"] = 1
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
		"tutorial_levels_seen": [],
		"current_level": 1,
		"hints_left": 3,
		"bonus_hints": 0,
		"last_reset_date": "",
		"last_seen_date": "",
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
			"last_played_chapter": 0,
			"ads_enabled": true
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
