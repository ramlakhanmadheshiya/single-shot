extends Node
## Versioned local save storage. Progress keys are string level ids.
const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 1
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
        file.store_string(JSON.stringify(data, "  "))

func get_setting(key: String, fallback: Variant = null) -> Variant:
    var settings: Dictionary = data.get("settings", {})
    return settings.get(key, fallback)

func set_setting(key: String, value: Variant) -> void:
    var settings: Dictionary = data.get("settings", {})
    settings[key] = value
    data["settings"] = settings
    save()
    Events.setting_changed.emit(key, value)

func record_level(level_id: String, stars: int, badge: bool = false) -> void:
    var levels: Dictionary = data.get("levels", {})
    var previous: Dictionary = levels.get(level_id, {})
    levels[level_id] = {"stars": maxi(stars, int(previous.get("stars", 0))), "badge": badge or bool(previous.get("badge", false))}
    data["levels"] = levels
    save()

func _default_data() -> Dictionary:
    return {"save_version": SAVE_VERSION, "levels": {}, "unlocks": ["ch01"], "settings": {"music": 0.65, "sfx": 0.8, "ui": 0.85, "screen_shake": true, "aim_assist": true, "fullscreen": false, "theme": "dark"}}

func _migrate() -> void:
    var old_version: int = int(data.get("save_version", 0))
    if old_version < 1:
        data = _default_data()
    else:
        var defaults: Dictionary = _default_data()
        for key: String in defaults:
            if not data.has(key):
                data[key] = defaults[key]
    data["save_version"] = SAVE_VERSION
    save()
