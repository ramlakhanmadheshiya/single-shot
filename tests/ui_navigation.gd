extends Node
## Headless-friendly click-through for the Foundation screens.
const MAIN_SCENE: PackedScene = preload("res://game/scenes/main_menu.tscn")
var app: Control
var saved_data: Dictionary
var original_theme: int

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	saved_data = SaveSystem.data.duplicate(true)
	original_theme = int(ThemeManager.mode)
	app = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(app)
	await get_tree().process_frame
	_check(app.screen == "menu", "main menu should be visible")
	_check(app.title_label.is_inside_tree(), "screen title should remain in the persistent shell")
	_check(app.title_label.visible and app.title_label.text == "BONEYARD\nBOUNCE", "main menu title should be visible")
	_check(app.title_label.get_theme_font_size("font_size") >= 72, "main menu title should be readable")

	await _press_button("Play")
	_check(app.screen == "chapters", "Play should open Chapters")
	await _press_button("Back")
	await _press_button("Settings")
	_check(app.screen == "settings", "Settings should open")
	_check(app.music_slider != null and is_instance_valid(app.music_slider) and app.music_slider.is_inside_tree(), "music slider should be alive")
	_check(app.sound_slider != null and is_instance_valid(app.sound_slider) and app.sound_slider.is_inside_tree(), "SFX slider should be alive")
	_check(app.shake_check != null and is_instance_valid(app.shake_check) and app.shake_check.is_inside_tree(), "shake toggle should be alive")
	_check(app.aim_check != null and is_instance_valid(app.aim_check) and app.aim_check.is_inside_tree(), "aim toggle should be alive")
	_check(app.fullscreen_check != null and is_instance_valid(app.fullscreen_check) and app.fullscreen_check.is_inside_tree(), "fullscreen toggle should be alive")
	_check(app.theme_option != null and is_instance_valid(app.theme_option) and app.theme_option.is_inside_tree(), "theme selector should be alive")
	app.music_slider.value = 0.31
	app.sound_slider.value = 0.44
	var interface_slider: HSlider = _find_slider_by_caption("Interface")
	_check(interface_slider != null, "interface volume slider should be present")
	interface_slider.value = 0.57
	_toggle_check(app.shake_check)
	_toggle_check(app.aim_check)
	_toggle_check(app.fullscreen_check)
	for mode: int in [ThemeManager.Mode.DARK, ThemeManager.Mode.LIGHT, ThemeManager.Mode.SYSTEM]:
		app.theme_option.select(mode)
		app.theme_option.item_selected.emit(mode)
		await get_tree().process_frame
		_check(int(ThemeManager.mode) == mode, "theme selector should apply each mode")
	_check(app.title_label.is_inside_tree(), "title should survive settings theme changes")

	for mode: int in [ThemeManager.Mode.DARK, ThemeManager.Mode.LIGHT]:
		ThemeManager.set_mode(mode as ThemeManager.Mode)
		await get_tree().process_frame
		_check(app.screen == "settings", "theme cycle should remain in Settings")
		await _press_button("Back")
		_check(app.screen == "menu" and app.title_label.visible, "main menu should render in both themes")
		await _press_button("Credits")
		_check(app.screen == "credits", "Credits should render in both themes")
		await _press_button("Back")
		await _press_button("Play")
		_check(app.screen == "chapters", "Chapters should render in both themes")
		await _press_button("Back")
		await _press_button("Settings")
		_check(app.screen == "settings", "Settings should render in both themes")

	await _press_button("Back")
	ThemeManager.set_mode(ThemeManager.Mode.LIGHT)
	await _press_button("Play")
	await _press_button("Chapter I  ·  Graveyard Gate")
	_check(app.screen == "chapters", "Chapter I selection should leave the chapter landing page active")
	_check(_contains_label("playable level slice arrives"), "Chapter I selection should report the next playable step")

	# Restore the user's preference data after exercising controls.
	SaveSystem.data = saved_data
	SaveSystem.save()
	AudioManager._apply_volumes()
	ThemeManager.set_mode(original_theme as ThemeManager.Mode)
	AudioManager.music_player.stop()
	AudioManager.music_player.stream = null
	AudioManager.ui_player.stop()
	AudioManager.ui_player.stream = null
	for player: AudioStreamPlayer in AudioManager.sfx_players:
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.2).timeout
	print("PASS: UI navigation in Dark/Light, all settings, all theme modes, and Chapter I")
	get_tree().quit(0)

func _press_button(label_text: String) -> void:
	var found: Button = _find_button(app, label_text)
	if found == null:
		_check(false, "missing button: " + label_text)
		return
	if not found.is_inside_tree():
		_check(false, "button is detached: " + label_text)
		return
	found.pressed.emit()
	await get_tree().process_frame

func _find_button(parent: Node, label_text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and (child as Button).text == label_text:
			return child as Button
		var nested: Button = _find_button(child, label_text)
		if nested != null:
			return nested
	return null

func _find_slider_by_caption(caption: String) -> HSlider:
	for slider: HSlider in app.find_children("", "HSlider", true, false):
		var row: Node = slider.get_parent()
		for child: Node in row.get_children():
			if child is Label and (child as Label).text == caption:
				return slider
	return null

func _toggle_check(check: CheckButton) -> void:
	var next_value: bool = not check.button_pressed
	check.set_pressed_no_signal(next_value)
	check.toggled.emit(next_value)

func _contains_label(fragment: String) -> bool:
	for label: Label in app.find_children("", "Label", true, false):
		if label.text.to_lower().contains(fragment.to_lower()):
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("UI navigation test failed: " + message)
		get_tree().quit(1)
