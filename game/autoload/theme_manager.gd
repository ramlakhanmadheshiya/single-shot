extends Node
## Applies generated themes and persists DARK, LIGHT or SYSTEM preference.
enum Mode { DARK, LIGHT, SYSTEM }
var mode: Mode = Mode.DARK
var _tween: Tween

func _ready() -> void:
    var saved: String = str(SaveSystem.get_setting("theme", "dark"))
    mode = Mode.LIGHT if saved == "light" else (Mode.SYSTEM if saved == "system" else Mode.DARK)
    apply_theme(false)

func set_mode(next_mode: Mode) -> void:
    mode = next_mode
    SaveSystem.set_setting("theme", _mode_key())
    apply_theme(true)

func apply_theme(animate: bool = false) -> void:
    var path: String = "res://game/ui/themes/light_theme.tres" if _effective_light() else "res://game/ui/themes/dark_theme.tres"
    var theme_resource: Theme = load(path) as Theme
    if theme_resource != null:
        get_tree().root.theme = theme_resource
    Events.theme_changed.emit(mode)

func _effective_light() -> bool:
    if mode == Mode.SYSTEM:
        return DisplayServer.get_name() == "macos" and DisplayServer.is_dark_mode_supported() and not DisplayServer.is_dark_mode()
    return mode == Mode.LIGHT

func _mode_key() -> String:
    return ["dark", "light", "system"][int(mode)]
