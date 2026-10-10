extends Node
## Versioned local progress and settings, stored as JSON in user://.

const SAVE_PATH: String = "user://one_clean_shot_save.json"
## Saves from before the rename to One Clean Shot; moved over on first launch.
const LEGACY_SAVE_PATH: String = "user://carom_save.json"
const SAVE_VERSION: int = 3
## A video unlocks a cosmetic pack for this long.
const TRIAL_SECONDS: int = 6 * 60 * 60
const DAILY_HINTS: int = 3

var data: Dictionary = {}


func _ready() -> void:
	load_save()
	refresh_daily_hints()


func load_save() -> void:
	data = _defaults()
	var path: String = SAVE_PATH
	if not FileAccess.file_exists(SAVE_PATH):
		if not FileAccess.file_exists(LEGACY_SAVE_PATH):
			_apply_cosmetics()
			return
		path = LEGACY_SAVE_PATH
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)
		if int((parsed as Dictionary).get("version", 1)) < 2:
			# v2: the longer aim guide became the default for everyone.
			data["settings"]["long_guide"] = true
		if int((parsed as Dictionary).get("version", 1)) < 3 and flag("supporter"):
			# v3: purchases are tracked per product.
			data["owned"]["supporter_pack"] = true
		save()
	if path == LEGACY_SAVE_PATH:
		save()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))
	_apply_cosmetics()


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
	if key == "theme":
		_apply_cosmetics()
	Events.setting_changed.emit(key, value)


## Applies the chosen theme, falling back to chapter colours once a trial ends.
func _apply_cosmetics() -> void:
	var theme: String = str(get_setting("theme", "chapters"))
	Palette.theme_id = theme if theme == "chapters" or owns("theme_pack") else "chapters"


func orb_style() -> String:
	var id: String = str(get_setting("orb_style", "classic"))
	return id if OrbStyles.is_free(id) or owns("orb_pack") else "classic"


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


## Missed shots on a room not yet cleared (so "first try" survives leaving and coming back).
func misses(level_id: String) -> int:
	return int((data["tries"] as Dictionary).get(level_id, 0))


func add_miss(level_id: String) -> void:
	data["tries"][level_id] = misses(level_id) + 1
	save()


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

## Free hints refill to exactly DAILY_HINTS at local midnight.
func refresh_daily_hints() -> void:
	var today: String = Time.get_date_string_from_system()
	if str(data.get("hint_day", "")) != today:
		data["hint_day"] = today
		data["hints"] = DAILY_HINTS
		save()
		Events.hints_changed.emit(DAILY_HINTS)


func hints_left() -> int:
	refresh_daily_hints()
	return int(data.get("hints", 0))


## Supporters have unlimited hints; everyone else spends from the daily pool.
func spend_hint() -> bool:
	if is_supporter():
		return true
	if hints_left() <= 0:
		return false
	data["hints"] = hints_left() - 1
	save()
	Events.hints_changed.emit(int(data["hints"]))
	return true


func is_supporter() -> bool:
	return owns("supporter_pack")


func set_supporter(on: bool) -> void:
	set_owned("supporter_pack", on)


# --- Purchases and trials ----------------------------------------------------

## True if the pack is bought (directly or through the Complete pack) or, for
## cosmetic packs, on a video trial that hasn't run out.
func owns(product: String) -> bool:
	var owned: Dictionary = data["owned"]
	if bool(owned.get(product, false)) or bool(owned.get("complete_pack", false)):
		return true
	if product == "supporter_pack" and flag("supporter"):
		return true
	return trial_left(product) > 0


func bought(product: String) -> bool:
	return bool((data["owned"] as Dictionary).get(product, false)) or bool((data["owned"] as Dictionary).get("complete_pack", false))


func set_owned(product: String, on: bool) -> void:
	data["owned"][product] = on
	if product in ["supporter_pack", "complete_pack"]:
		data["flags"]["supporter"] = bool(data["owned"].get("supporter_pack", false)) or bool(data["owned"].get("complete_pack", false))
	save()
	_apply_cosmetics()
	Events.purchases_changed.emit()
	if product in ["supporter_pack", "complete_pack"]:
		Events.supporter_changed.emit(is_supporter())


## Seconds left on a video trial (0 if none).
func trial_left(product: String) -> int:
	var until: int = int((data["trials"] as Dictionary).get(product, 0))
	return maxi(0, until - int(Time.get_unix_time_from_system()))


func start_trial(product: String) -> void:
	data["trials"][product] = int(Time.get_unix_time_from_system()) + TRIAL_SECONDS
	save()
	_apply_cosmetics()
	Events.purchases_changed.emit()


func has_all_levels() -> bool:
	return owns("all_levels")


func tips_given() -> int:
	return int(data.get("tips", 0))


func add_tip() -> void:
	data["tips"] = tips_given() + 1
	save()


func add_hints(count: int) -> void:
	data["hints"] = hints_left() + maxi(0, count)
	save()
	Events.hints_changed.emit(int(data["hints"]))


func reset_progress() -> void:
	data["levels"] = {}
	data["tries"] = {}
	data["last"] = {"chapter": "ch1", "index": 0}
	# Keep purchases; only clear tutorials and tips.
	data["flags"] = {"supporter": is_supporter()}
	save()


func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"levels": {},
		"last": {"chapter": "ch1", "index": 0},
		"flags": {},
		"tries": {},
		"owned": {},
		"trials": {},
		"tips": 0,
		"hints": DAILY_HINTS,
		"hint_day": "",
		"settings": {
			"music_volume": 0.5,
			"sound_volume": 0.75,
			"haptics": true,
			"shake": true,
			"long_guide": true,
			"theme": "chapters",
			"orb_style": "classic",
		},
	}


## Copies saved values over defaults so new keys appear after updates.
func _merge(into: Dictionary, from: Dictionary) -> void:
	for key: Variant in from:
		if into.has(key) and into[key] is Dictionary and from[key] is Dictionary and not key in ["levels", "tries"]:
			_merge(into[key], from[key])
		else:
			into[key] = from[key]
