extends Node
## Runs menu, picker, sheet and in-level UI in both color themes.
const MAIN_SCENE: PackedScene = preload("res://game/scenes/main_menu.tscn")
var app: Control
var saved_data: Dictionary
var saved_chapters: Array[Dictionary]
var original_theme: int

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	saved_data = SaveSystem.data.duplicate(true)
	saved_chapters = LevelRegistry.chapters.duplicate(true)
	original_theme = int(ThemeManager.mode)
	SaveSystem.data = SaveSystem._default_data()
	SaveSystem.save()
	ThemeManager.set_mode(ThemeManager.Mode.DARK)
	app = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(app)
	app.force_mobile_controls = true
	await get_tree().process_frame
	_expect(app.screen == "menu", "Main Menu opens first")
	_expect(_find_action("play") != null, "Play appears on Main Menu")
	_expect(_find_action("levels_menu") != null, "Levels appears below Play")
	_expect(_has_text("Level 1"), "Play button shows the current level")
	await _capture("bb_menu_dark")

	await _press_action("play")
	_expect(app.screen == "game" and app.current_level_number == 1, "Play continues to new player's Level 1")
	_expect(int(SaveSystem.data.get("current_level", 0)) == 1, "Save file stores the current level")
	_expect(app.tutorial_overlay != null, "First level shows its action tutorial")
	var outside_down: InputEventMouseButton = InputEventMouseButton.new()
	outside_down.button_index = MOUSE_BUTTON_LEFT
	outside_down.pressed = true
	outside_down.position = Vector2(5.0, 5.0)
	app._on_tutorial_input(outside_down)
	var outside_up: InputEventMouseButton = InputEventMouseButton.new()
	outside_up.button_index = MOUSE_BUTTON_LEFT
	outside_up.position = Vector2(5.0, 5.0)
	app._on_tutorial_input(outside_up)
	_expect(app.tutorial_overlay != null and app.hints_left == 3, "Outside taps do not finish or spend tutorial hints")
	await _do_tutorial_drag()
	_expect(app.tutorial_overlay == null and bool(SaveSystem.data.get("tutorial_seen", false)), "Tutorial waits for a real drag and saves once")
	await _press_action("game_back")
	_expect(app.screen == "menu", "Play entry returns to Main Menu from a level")
	await _press_action("levels_menu")
	_expect(app.screen == "levels", "Levels opens Level Select")
	_expect(app.page_dots.size() <= 5, "Chapter dots use a short row")
	_expect(_find_named("LevelGrid") != null, "Level Select builds its visible level grid")
	await _capture("bb_levels_dark")
	_expect(app.find_children("LevelTile_*", "Button", true, false).size() == 20, "One page shows exactly twenty levels")
	var locked_tile: Button = _level_tile(2)
	_expect(locked_tile != null and locked_tile.text.is_empty(), "Locked tile shows no word or empty stars")
	_expect(locked_tile != null and locked_tile.find_child("LockIcon", true, false) != null, "Locked tile shows its lock icon")
	_swipe(-150.0)
	await get_tree().process_frame
	_expect(app.chapter_index == 1, "Swipe opens the next chapter")
	app._unhandled_key_input(_right_key())
	await get_tree().process_frame
	_expect(app.chapter_index == 2, "Right arrow opens the next chapter")
	app._unhandled_key_input(_left_key())
	await get_tree().process_frame
	_expect(app.chapter_index == 1, "Left arrow returns to the last chapter")
	await _press_action("locked_chapter")
	_expect(app.screen == "levels" and app.chapter_index == 1, "A locked chapter stays locked")
	_expect(_has_text("Finish Chapter 1"), "Locked pages explain what opens them")
	await _capture("bb_locked_dark")

	# Visit every sheet in Light mode, then in Dark mode.
	await _press_action("settings")
	_expect(app.settings_layer != null, "Settings slides up as a sheet")
	await get_tree().create_timer(0.28).timeout
	var drag_start: Vector2 = app.settings_panel.get_global_rect().position + Vector2(90.0, 80.0)
	var touch_down: InputEventScreenTouch = InputEventScreenTouch.new()
	touch_down.position = drag_start
	touch_down.pressed = true
	app._input(touch_down)
	var touch_up: InputEventScreenTouch = InputEventScreenTouch.new()
	touch_up.position = drag_start + Vector2(0.0, 130.0)
	touch_up.pressed = false
	app._input(touch_up)
	await get_tree().create_timer(0.28).timeout
	_expect(app.settings_layer == null, "Dragging Settings down closes the sheet")
	await _press_action("settings")
	await get_tree().create_timer(0.28).timeout
	await _capture("bb_settings_dark")
	_expect(app.switch_controls.has("vibration"), "Mobile settings show Vibration")
	await _exercise_settings()
	await _press_action("theme_1") # Light
	_expect(ThemeManager.mode == ThemeManager.Mode.LIGHT, "Light theme button works")
	_expect(Color(app.palette["surface"]).get_luminance() > 0.8, "Light sheets use light surfaces")
	await get_tree().create_timer(0.28).timeout
	await _capture("bb_settings_light")
	await _open_and_close_info("how_to")
	await _open_and_close_info("credits", true)
	await _open_and_close_info("about")
	await _press_action("theme_2") # Auto
	_expect(ThemeManager.mode == ThemeManager.Mode.SYSTEM, "Auto theme button works")
	await _press_action("theme_0") # Dark
	_expect(ThemeManager.mode == ThemeManager.Mode.DARK, "Dark theme button works")
	_expect(Color(app.palette["surface"]).get_luminance() < 0.2, "Dark sheets use dark surfaces")
	await _open_and_close_info("how_to")
	await _open_and_close_info("credits")
	await _open_and_close_info("about")

	SaveSystem.record_level("ch01_l001", 3)
	await _press_action("reset_progress")
	_expect(app.info_id == "reset_confirm", "Reset asks before deleting stars")
	await _press_action("reset_cancel")
	_expect(SaveSystem.total_stars() == 3, "Cancel keeps saved stars")
	await _press_action("reset_progress")
	await _press_action("reset_delete")
	_expect(SaveSystem.total_stars() == 0, "Delete clears saved stars")
	_expect(app.settings_status.visible, "Settings confirms when stars are cleared")
	await _press_action("close_settings")
	_expect(app.settings_layer == null, "Close button hides the Settings sheet")
	await _press_action("back")
	_expect(app.screen == "menu", "Back returns to Main Menu")

	# Show all screens in Light too, then open the first level.
	await _press_action("settings")
	await _press_action("theme_1")
	await _press_action("close_settings")
	await _capture("bb_menu_light")
	await _press_action("levels_menu")
	_expect(ThemeManager.mode == ThemeManager.Mode.LIGHT, "Level Select keeps the Light theme")
	await _capture("bb_levels_light")
	_swipe(-150.0)
	await get_tree().process_frame
	await _capture("bb_locked_light")
	_swipe(150.0)
	await get_tree().process_frame
	await _press_action("back")
	await _press_action("settings")
	await _open_and_close_info("about")
	await _press_action("close_settings")
	await _press_action("levels_menu")
	await _press_level(1)
	_expect(app.screen == "game", "Unlocked level opens the in-level screen")
	_expect(app.tutorial_overlay != null, "First room opens the short tutorial")
	await _capture("bb_tutorial_light")
	await _do_tutorial_drag()
	_expect(bool(SaveSystem.data.get("tutorial_seen", false)), "Tutorial shows only once")
	_expect(_find_action("hint") != null, "In-level Hint button appears")
	await _press_action("hint")
	_expect(app.hints_left == 2 and _find_named("HintLine") != null, "Hint shows a faint aim line")
	await _press_action("settings")
	_expect(app.settings_layer != null, "Settings also opens during a level")
	await _press_action("close_settings")
	await _press_action("game_back")
	_expect(app.screen == "levels", "Level Back returns to Level Select")
	for number: int in 6:
		SaveSystem.record_level("ch01_l%03d" % (number + 1), 3)
	app._build_level_page()
	await get_tree().process_frame
	await _press_action("back")
	await _press_action("play")
	_expect(app.screen == "game" and app.current_level_number == 7, "Play continues at the first unfinished level")
	_expect(int(SaveSystem.data.get("current_level", 0)) == 7, "Save file advances to Level 7")
	await _press_action("game_back")
	_expect(app.screen == "menu", "Play-launched level returns to Main Menu")
	await _press_action("levels_menu")
	_expect(app.chapter_index == 0, "Levels opens the current level's chapter")
	_expect(str(_level_tile(7).get_meta("bb_style", "")) == "highlight", "Level Select highlights the current level")
	await _press_level(7)
	_expect(_has_text("Level 7"), "In-level screen shows its level number")
	_expect(_has_text("Shots used: 0"), "In-level screen shows shots used")
	_expect(_has_text("3-star goal: 2"), "In-level screen shows the three-star goal")
	_expect(_find_action("undo") != null and _find_action("restart") != null, "Undo and Restart buttons appear")
	await _press_action("undo")
	await _press_action("restart")
	_expect(app.screen == "game", "Restart stays in the same level")
	await _press_action("settings")
	_expect(app.settings_layer != null, "Settings also opens during a level")
	await _press_action("close_settings")
	await _press_action("game_back")
	_expect(app.screen == "levels", "Level Back returns to Level Select")
	await _press_action("back")
	_expect(app.screen == "menu", "Final Back returns to Main Menu")
	for chapter: int in 5:
		for number: int in 20:
			SaveSystem.record_level("ch%02d_l%03d" % [chapter + 1, number + 1], 1)
	await _press_action("play")
	_expect(app.screen == "levels" and app.chapter_index == 4, "Play opens Level Select after every level is done")

	SaveSystem.data = saved_data
	SaveSystem.save()
	LevelRegistry.chapters = saved_chapters
	ThemeManager.set_mode(original_theme as ThemeManager.Mode)
	AudioManager._apply_volumes()
	AudioManager.music_player.stop()
	AudioManager.music_player.stream = null
	AudioManager.ui_player.stop()
	AudioManager.ui_player.stream = null
	await get_tree().create_timer(0.2).timeout
	print("PASS: menu, Level Select, sheets, settings, tutorials and in-level buttons")
	get_tree().quit(0)

func _exercise_settings() -> void:
	_expect(app.switch_controls.has("sound_enabled"), "Sound switch exists")
	_expect(app.switch_controls.has("music_enabled"), "Music switch exists")
	_expect(app.switch_controls.has("show_aim_guide"), "Aim guide switch exists")
	_expect(app.switch_controls.has("screen_shake"), "Screen shake switch exists")
	for setting_key: String in ["sound_enabled", "music_enabled", "vibration", "show_aim_guide", "screen_shake"]:
		var control: Button = app.switch_controls.get(setting_key) as Button
		_expect(control != null, "Switch exists: " + setting_key)
		if control != null:
			control.pressed.emit()
			await get_tree().process_frame
	var more: Button = _find_action("more_sound")
	_expect(more != null, "More sound options appears")
	if more != null:
		more.pressed.emit()
		await get_tree().process_frame
	_expect(app.more_sound_rows.visible, "Sound sliders expand")
	for slider_key: String in ["music_volume", "sound_volume", "ui_volume"]:
		var slider: VolumeSlider = app.volume_controls.get(slider_key) as VolumeSlider
		_expect(slider != null, "Sound slider exists: " + slider_key)
		if slider != null:
			slider.value = 0.42
			slider.value_changed.emit(slider.value)

func _open_and_close_info(kind: String, outside: bool = false) -> void:
	var action_name: String = "how_to_play" if kind == "how_to" else kind
	await _press_text(Strings.text(action_name))
	if kind == "how_to":
		_expect(app.tutorial_overlay != null and app.info_layer == null, "How to play starts the action tutorial")
		await _do_tutorial_drag()
		_expect(app.tutorial_overlay == null, "How to play tutorial waits for its action")
		return
	_expect(app.info_layer != null and app.info_id == kind, kind + " opens above Settings")
	if outside:
		var tap: InputEventMouseButton = InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		tap.position = Vector2(5.0, 5.0)
		app._input(tap)
		await get_tree().process_frame
	else:
		await _press_action("info_close")
	_expect(app.info_layer == null, kind + " sheet closes")

func _press_action(action_name: String) -> void:
	var button: Button = _find_action(action_name)
	_expect(button != null, "Button action exists: " + action_name)
	if button == null:
		return
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if action_name == "close_settings":
		await get_tree().create_timer(0.3).timeout

func _press_text(text: String) -> void:
	var button: Button = _find_text_button(text)
	_expect(button != null, "Button text exists: " + text)
	if button != null:
		button.pressed.emit()
		await get_tree().process_frame

func _press_level(number: int) -> void:
	var tile: Button = _level_tile(number)
	_expect(tile != null, "Level tile exists: " + str(number))
	if tile != null:
		tile.pressed.emit()
		await get_tree().process_frame

func _level_tile(number: int) -> Button:
	for node: Node in app.find_children("LevelTile_*", "Button", true, false):
		if int(node.get_meta("level_number", 0)) == number:
			return node as Button
	return null

func _find_action(action_name: String) -> Button:
	for node: Node in app.find_children("", "Button", true, false):
		if str(node.get_meta("bb_action", "")) == action_name:
			return node as Button
	return null

func _find_named(node_name: String) -> Node:
	return app.find_child(node_name, true, false)

func _find_text_button(text: String) -> Button:
	for node: Node in app.find_children("", "Button", true, false):
		if (node as Button).text.contains(text):
			return node as Button
	return null

func _has_text(text: String) -> bool:
	for node: Node in app.find_children("", "Label", true, false):
		if (node as Label).text.contains(text):
			return true
	return false

func _swipe(distance: float) -> void:
	var start: Vector2 = Vector2(400.0, 500.0)
	var down: InputEventScreenTouch = InputEventScreenTouch.new()
	down.pressed = true
	down.position = start
	app._input(down)
	var up: InputEventScreenTouch = InputEventScreenTouch.new()
	up.pressed = false
	up.position = start + Vector2(distance, 0.0)
	app._input(up)
	await get_tree().process_frame

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.08).timeout
	await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	var screenshot_dir: String = ProjectSettings.globalize_path("res://docs/screenshots")
	DirAccess.make_dir_recursive_absolute(screenshot_dir)
	image.save_png(screenshot_dir.path_join(file_name + ".png"))
	image.save_png("/tmp/" + file_name + ".png")

func _do_tutorial_drag() -> void:
	if app.tutorial_overlay == null or app.tutorial_target == null:
		return
	var start: Vector2 = app.tutorial_target.get_global_rect().get_center()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	app._on_tutorial_input(down)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = start + Vector2(-90.0, -40.0)
	app._on_tutorial_input(up)
	await get_tree().process_frame

func _right_key() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_RIGHT
	event.pressed = true
	return event

func _left_key() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_LEFT
	event.pressed = true
	return event

func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("UI navigation test failed: " + message)
		get_tree().quit(1)
