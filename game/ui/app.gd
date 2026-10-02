extends Control
## Responsive single-scene shell for foundation screens; content screens arrive next milestone.
const DARK: Dictionary = preload("res://game/ui/themes/theme_tokens.gd").DARK
const LIGHT: Dictionary = preload("res://game/ui/themes/theme_tokens.gd").LIGHT
var palette: Dictionary = {}
var screen: String = "menu"
var screen_body: VBoxContainer
var menu_panel: PanelContainer
var title_label: Label
var sound_slider: HSlider
var music_slider: HSlider
var shake_check: CheckButton
var aim_check: CheckButton
var fullscreen_check: CheckButton
var theme_option: OptionButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ThemeManager.apply_theme(false)
	Events.theme_changed.connect(_on_theme_changed)
	_build_shell()
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	_show_menu()

func _build_shell() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var sky: Control = Control.new()
	sky.name = "GraveyardArt"
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.draw.connect(_draw_graveyard.bind(sky))
	add_child(sky)
	var vignette: ColorRect = ColorRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(920, 900)
	center.add_child(menu_panel)
	var panel_content: VBoxContainer = VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 22)
	menu_panel.add_child(panel_content)
	title_label = Label.new()
	title_label.name = "ScreenTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size.y = 105
	title_label.add_theme_font_size_override("font_size", 80)
	panel_content.add_child(title_label)
	screen_body = VBoxContainer.new()
	screen_body.add_theme_constant_override("separation", 20)
	screen_body.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_content.add_child(screen_body)
	_refresh_palette()

func _fit_panel() -> void:
	if menu_panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	menu_panel.custom_minimum_size = Vector2(minf(1040.0, viewport_size.x * 0.82), minf(960.0, viewport_size.y * 0.94))

func _draw_graveyard(canvas: Control) -> void:
	var s: Vector2 = canvas.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	canvas.draw_circle(Vector2(s.x * 0.79, s.y * 0.17), s.y * 0.09, Color(palette.get("accent", "#FFB347")), true, -1.0, true)
	canvas.draw_rect(Rect2(0, s.y * 0.77, s.x, s.y * 0.23), Color(palette.get("surface_alt", "#302641")), true)
	for index: int in 12:
		var x: float = fmod(float(index) * 197.0 + 35.0, s.x)
		var height: float = 60.0 + fmod(float(index * 61), 110.0)
		var width: float = 34.0 + fmod(float(index * 17), 28.0)
		var rect: Rect2 = Rect2(x, s.y * 0.78 - height, width, height)
		canvas.draw_rect(rect, Color(palette.get("surface", "#211A33")), true)
		canvas.draw_rect(Rect2(rect.position, Vector2(width, 8)), Color(palette.get("primary", "#7C5CFF")), true)
	for index: int in 9:
		var x: float = fmod(float(index) * 271.0 + 50.0, s.x)
		var base_y: float = s.y * 0.79
		canvas.draw_line(Vector2(x, base_y), Vector2(x + 7, base_y - 115), Color(palette.get("outline", "#0B0812")), 16.0, true)
		canvas.draw_line(Vector2(x - 28, base_y - 45), Vector2(x + 38, base_y - 45), Color(palette.get("outline", "#0B0812")), 12.0, true)

func _refresh_palette() -> void:
	palette = LIGHT if ThemeManager._effective_light() else DARK
	var backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
	if backdrop != null:
		backdrop.color = Color(palette["bg"])
	var vignette: ColorRect = get_node_or_null("Vignette") as ColorRect
	if vignette != null:
		vignette.color = Color(palette["overlay"])
		vignette.modulate.a = 0.23
	if title_label != null:
		title_label.add_theme_color_override("font_color", Color(palette["accent"]))
	var art: Control = get_node_or_null("GraveyardArt") as Control
	if art != null:
		art.queue_redraw()

func _clear_body() -> void:
	# Screen controls are transient; invalidate every convenience reference before freeing.
	music_slider = null
	sound_slider = null
	shake_check = null
	aim_check = null
	fullscreen_check = null
	theme_option = null
	for child: Node in screen_body.get_children():
		child.queue_free()

func _show_menu() -> void:
	screen = "menu"
	_clear_body()
	title_label.text = "BONEYARD
BOUNCE"
	title_label.add_theme_font_size_override("font_size", 80)
	_add_label("A moonlit ricochet puzzle", 26, "text_muted")
	_add_button("Play", _on_play)
	_add_button("Settings", _show_settings)
	_add_button("Credits", _show_credits)
	_add_button("Quit", _quit)
	_add_label("HAZEL GRIMM AND BETSY AWAIT", 17, "text_muted")

func _show_chapters() -> void:
	screen = "chapters"
	_clear_body()
	title_label.text = "CHAPTERS"
	title_label.add_theme_font_size_override("font_size", 52)
	_add_label("The graveyard is stirring...", 24, "text_muted")
	_add_button("Chapter I  ·  Graveyard Gate", _start_demo)
	_add_button("Chapter II  ·  Old Chapel   (soon)", func(): _toast("More chapters are being prepared."))
	_add_button("Chapter III  ·  Crypts   (soon)", func(): _toast("More chapters are being prepared."))
	_add_button("Back", _show_menu)

func _show_settings() -> void:
	screen = "settings"
	_clear_body()
	title_label.text = "SETTINGS"
	title_label.add_theme_font_size_override("font_size", 52)
	music_slider = _add_slider("Music", "music", 0.65)
	sound_slider = _add_slider("Sound effects", "sfx", 0.8)
	_add_slider("Interface", "ui", 0.85)
	shake_check = _add_check("Screen shake", "screen_shake", true)
	aim_check = _add_check("Aim assist", "aim_assist", true)
	fullscreen_check = _add_check("Fullscreen", "fullscreen", false)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_body.add_child(row)
	var theme_label: Label = Label.new()
	theme_label.text = "Appearance"
	row.add_child(theme_label)
	theme_option = OptionButton.new()
	theme_option.add_item("Moonlit · Dark", 0)
	theme_option.add_item("Daylight · Light", 1)
	theme_option.add_item("System", 2)
	theme_option.item_selected.connect(_on_theme_option)
	row.add_child(theme_option)
	theme_option.select(int(ThemeManager.mode))
	_add_button("Back", _show_menu)

func _show_credits() -> void:
	screen = "credits"
	_clear_body()
	title_label.text = "CREDITS"
	title_label.add_theme_font_size_override("font_size", 52)
	_add_label("Boneyard Bounce", 32, "accent")
	_add_label("An original graveyard adventure
Created with Godot and GDScript
Procedural art and synthesized sounds
No third-party assets", 23, "text")
	_add_button("Back", _show_menu)

func _add_label(text_value: String, font_size: int = 22, token: String = "text") -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(palette[token]))
	screen_body.add_child(label)
	return label

func _add_button(text_value: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(520, 78)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_entered.connect(func(): AudioManager.play_ui("ui_hover"))
	button.pressed.connect(func(): AudioManager.play_ui("ui_click"); action.call())
	screen_body.add_child(button)
	return button

func _add_slider(caption: String, key: String, fallback: float) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_body.add_child(row)
	var label: Label = Label.new()
	label.text = caption
	label.custom_minimum_size.x = 220
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(330, 36)
	slider.value = float(SaveSystem.get_setting(key, fallback))
	slider.value_changed.connect(func(value: float): SaveSystem.set_setting(key, value); AudioManager.set_bus_linear("Music" if key == "music" else ("UI" if key == "ui" else "SFX"), value))
	row.add_child(slider)
	return slider

func _add_check(caption: String, key: String, fallback: bool) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.text = caption
	check.button_pressed = bool(SaveSystem.get_setting(key, fallback))
	check.toggled.connect(func(value: bool):
		SaveSystem.set_setting(key, value)
		if key == "fullscreen" and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	screen_body.add_child(check)
	return check

func _on_play() -> void:
	_show_chapters()

func _start_demo() -> void:
	_toast("The playable level slice arrives in Milestone 2.")

func _on_theme_option(index: int) -> void:
	ThemeManager.set_mode(index as ThemeManager.Mode)
	_refresh_palette()

func _on_theme_changed(_mode: int) -> void:
	_refresh_palette()

func _toast(message: String) -> void:
	if screen_body != null:
		_add_label(message, 18, "accent")

func _quit() -> void:
	get_tree().quit()
