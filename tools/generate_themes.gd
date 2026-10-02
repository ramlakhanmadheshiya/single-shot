extends SceneTree
## Emits matched theme resources from the semantic token dictionaries.
const Tokens = preload("res://game/ui/themes/theme_tokens.gd")
func _initialize() -> void:
    _write_theme(Tokens.DARK, "res://game/ui/themes/dark_theme.tres")
    _write_theme(Tokens.LIGHT, "res://game/ui/themes/light_theme.tres")
    quit(0)
func _write_theme(colors: Dictionary, path: String) -> void:
    var theme: Theme = Theme.new()
    theme.default_font_size = 28
    var normal: StyleBoxFlat = _button_style(colors["surface"], colors["outline"])
    var hover: StyleBoxFlat = _button_style(colors["surface_alt"], colors["accent"])
    var pressed: StyleBoxFlat = _button_style(colors["primary"], colors["accent"])
    var panel: StyleBoxFlat = _button_style(colors["surface"], colors["outline"])
    for type_name: String in ["Button"]:
        theme.set_color("font_color", type_name, Color(colors["text"]))
        theme.set_color("font_hover_color", type_name, Color(colors["accent"]))
        theme.set_color("font_pressed_color", type_name, Color(colors["accent"]))
        theme.set_stylebox("normal", type_name, normal)
        theme.set_stylebox("hover", type_name, hover)
        theme.set_stylebox("pressed", type_name, pressed)
        theme.set_stylebox("focus", type_name, hover)
    theme.set_color("font_color", "Label", Color(colors["text"]))
    theme.set_stylebox("panel", "Panel", panel)
    var error: Error = ResourceSaver.save(theme, path)
    if error != OK:
        push_error("Unable to write theme: " + path)
func _button_style(fill: String, outline: String) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(fill)
    style.border_color = Color(outline)
    style.set_border_width_all(3)
    style.set_corner_radius_all(18)
    style.content_margin_left = 30; style.content_margin_right = 30
    style.content_margin_top = 15; style.content_margin_bottom = 15
    return style
