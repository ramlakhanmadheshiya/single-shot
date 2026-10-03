extends Node
## Versioned local progress and settings, stored as JSON in user://.

const SAVE_PATH: String = "user://carom_save.json"
const SAVE_VERSION: int = 1
const DAILY_HINTS: int = 3

var data: Dictionary = {}


func _ready() -> void:
	load_save()
	refresh_daily_hints()


func load_save() -> void:
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)


func save() -> void:
	data["version"] = SAVE_VERSION
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return (data["settings"] as Dictionary).get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save()
	Events.setting_changed.emit(key, value)


func level_record(level_id: String) -> Dictionary:
	return (data["levels"] as Dictionary).get(level_id, {})


func stars_for(level_id: String) -> int:
	return int(level_record(level_id).get("stars", 0))


func is_cleared(level_id: String) -> bool:
	return stars_for(level_id) > 0


## Stores a finished level. Returns true if this was a new best.
func record_level(level_id: String, stars: int, shots: int) -> bool:
	var prev: Dictionary = level_record(level_id)
	var better: bool = stars > int(prev.get("stars", 0))
	data["levels"][level_id] = {
		"stars": maxi(stars, int(prev.get("stars", 0))),
		"best": mini(shots, int(prev.get("best", 99))),
	}
	save()
	return better


func total_stars() -> int:
	var total: int = 0
	for rec: Variant in (data["levels"] as Dictionary).values():
		if rec is Dictionary:
			total += int(rec.get("stars", 0))
	return total


func set_last_played(chapter_id: String, index: int) -> void:
	data["last"] = {"chapter": chapter_id, "index": index}
	save()


func last_played() -> Dictionary:
	return data.get("last", {"chapter": "ch1", "index": 0})


func flag(key: String) -> bool:
	return bool((data["flags"] as Dictionary).get(key, false))


func set_flag(key: String, value: bool = true) -> void:
	data["flags"][key] = value
	save()


# --- Hints -------------------------------------------------------------------

func refresh_daily_hints() -> void:
	var today: String = Time.get_date_string_from_system()
	if str(data.get("hint_day", "")) < today:
		data["hint_day"] = today
		data["hints"] = maxi(int(data.get("hints", 0)), DAILY_HINTS)
		save()


func hints_left() -> int:
	return int(data.get("hints", 0))


func spend_hint() -> bool:
	refresh_daily_hints()
	if hints_left() <= 0:
		return false
	data["hints"] = hints_left() - 1
	save()
	return true


func add_hints(count: int) -> void:
	data["hints"] = hints_left() + maxi(0, count)
	save()


func reset_progress() -> void:
	data["levels"] = {}
	data["last"] = {"chapter": "ch1", "index": 0}
	data["flags"] = {}
	save()


func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"levels": {},
		"last": {"chapter": "ch1", "index": 0},
		"flags": {},
		"hints": DAILY_HINTS,
		"hint_day": "",
		"settings": {
			"music_volume": 0.5,
			"sound_volume": 0.75,
			"haptics": true,
			"shake": true,
			"long_guide": false,
		},
	}


## Copies saved values over defaults so new keys appear after updates.
func _merge(into: Dictionary, from: Dictionary) -> void:
	for key: Variant in from:
		if into.has(key) and into[key] is Dictionary and from[key] is Dictionary and key != "levels":
			_merge(into[key], from[key])
		else:
			into[key] = from[key]
