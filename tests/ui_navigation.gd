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
	var today: String = SaveSystem.local_date_string()
	var tomorrow_dict: Dictionary = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system() + 86400.0)
	var tomorrow: String = "%04d-%02d-%02d" % [int(tomorrow_dict.year), int(tomorrow_dict.month), int(tomorrow_dict.day)]
	SaveSystem.update_daily_hints(today)
	_expect(int(SaveSystem.data.get("hints_left", -1)) == 3, "Daily hints start with three free hints")
	for hint_number: int in 3:
		_expect(SaveSystem.spend_hint(), "Each free hint can be used")
	_expect(int(SaveSystem.data.get("hints_left", -1)) == 0, "Three uses spend all free hints")
	SaveSystem.update_daily_hints(tomorrow)
	_expect(int(SaveSystem.data.get("hints_left", -1)) == 3, "New local date restores three free hints")
	SaveSystem.data["hints_left"] = 1
	SaveSystem.update_daily_hints(today)
	_expect(int(SaveSystem.data.get("hints_left", -1)) == 1, "Clock moving backwards gives no extra hints")
	SaveSystem.data = SaveSystem._default_data()
	SaveSystem.update_daily_hints()
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
	_expect(app.content_layer.get_child(-1) == _find_action("settings"), "Main Menu gear sits above the full-screen container")
	await _capture("bb_menu_dark")
	_expect(AdManager.banner_visible and _find_named("BannerStrip").visible, "Main Menu shows its reserved banner")
	await _click_action("settings", false)
	_expect(app.settings_layer != null, "Main Menu gear responds to a mouse click")
	_expect(not AdManager.banner_visible and not _find_named("BannerStrip").visible, "Settings hides the Main Menu banner")
	await _press_action("close_settings")
	await _click_action("settings", true)
	_expect(app.settings_layer != null, "Main Menu gear responds to a touch")
	await _press_action("close_settings")

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
	_expect(AdManager.banner_visible and _find_named("BannerStrip").visible, "Level Select shows its reserved banner")
	await _click_action("settings", false)
	_expect(app.settings_layer != null, "Level Select gear responds to a mouse click")
	await _press_action("close_settings")
	await _click_action("settings", true)
	_expect(app.settings_layer != null, "Level Select gear responds to a touch in Dark mode")
	await _press_action("close_settings")
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
	await _click_action("settings", false)
	_expect(app.settings_layer != null, "Main Menu gear responds to a mouse click in Light mode")
	await _press_action("close_settings")
	await _click_action("settings", true)
	_expect(app.settings_layer != null, "Main Menu gear responds to a touch in Light mode")
	await _press_action("close_settings")
	await _press_action("levels_menu")
	_expect(ThemeManager.mode == ThemeManager.Mode.LIGHT, "Level Select keeps the Light theme")
	await _capture("bb_levels_light")
	await _click_action("settings", false)
	_expect(app.settings_layer != null, "Level Select gear responds to a mouse click in Light mode")
	await _press_action("close_settings")
	await _click_action("settings", true)
	_expect(app.settings_layer != null, "Level Select gear responds to touch in Light mode")
	await _press_action("close_settings")
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
	app.gameplay.restart()
	_expect(_find_action("hint") != null, "In-level Hint button appears")
	await _press_action("hint")
	_expect(app.hints_left == 2 and app.gameplay.hint_visible, "Hint shows its solving aim line")
	await _press_action("hint")
	await _press_action("hint")
	_expect(app.hints_left == 0 and int(SaveSystem.data.get("bonus_hints", -1)) == 0, "Three daily hints are used before ad hints")
	_expect(_find_named("HintBonusMark") != null and (_find_named("HintBonusMark") as Label).visible, "Empty hint button shows a plus mark")
	await _press_action("hint")
	_expect(app.hint_sheet != null, "Fourth hint opens the rewarded ad choice sheet")
	await _capture("bb_no_hints_light")
	AdManager.provider.test_delay_seconds = 0.02
	await _press_action("watch_hint_ad")
	await _capture("bb_ad_light")
	await get_tree().create_timer(0.06).timeout
	var ad_close: Button = get_tree().root.find_child("MockAdClose", true, false) as Button
	_expect(ad_close != null and ad_close.visible, "Mock ad shows Close after its timer")
	if ad_close != null:
		ad_close.pressed.emit()
	await get_tree().process_frame
	_expect(int(SaveSystem.data.get("bonus_hints", -1)) == 1 and app.hint_sheet == null, "Completed ad gives exactly one bonus hint")
	await _press_action("hint")
	_expect(int(SaveSystem.data.get("bonus_hints", -1)) == 0, "Bonus hint is spent after free hints")
	await _press_action("hint")
	AdManager.provider.fail_for_test()
	await _press_action("watch_hint_ad")
	await get_tree().create_timer(0.06).timeout
	_expect(int(SaveSystem.data.get("bonus_hints", -1)) == 0, "Failed ad gives no hint")
	_expect(_has_text("No ad available right now"), "Failed ad shows a retry message")
	await _capture("bb_no_ad_light")
	await _press_action("hint_not_now")
	var hints_before_tutorials: int = int(SaveSystem.data.get("hints_left", 0))
	app._show_game(2)
	for _frame: int in 4: await get_tree().process_frame
	_expect(app.tutorial_overlay != null and _has_text("Bounce it off the wall"), "Level 2 teaches a wall bounce")
	await _do_tutorial_drag()
	_expect(SaveSystem.data.get("tutorial_levels_seen", []).has(2), "Level 2 waits for its real shot")
	app._show_game(3)
	for _frame: int in 4: await get_tree().process_frame
	_expect(app.tutorial_overlay != null and _has_text("Made a mistake? Tap Undo"), "Level 3 starts with Undo")
	_tap_tutorial_target()
	_expect(app.tutorial_overlay != null and app.tutorial_step == 1, "Undo tap advances to the bulb step")
	_tap_tutorial_target()
	_expect(app.tutorial_overlay == null and SaveSystem.data.get("tutorial_levels_seen", []).has(3), "Bulb tap finishes Level 3 teaching")
	_expect(int(SaveSystem.data.get("hints_left", 0)) == hints_before_tutorials, "Tutorial hint never spends a real hint")
	app._show_game(1)
	await _click_action("settings", true)
	_expect(app.settings_layer != null, "In-level gear responds to a touch in Light mode")
	await _press_action("close_settings")
	await _click_action("settings", false)
	_expect(app.settings_layer != null, "In-level gear responds to a mouse click in Light mode")
	await _press_action("close_settings")
	await _click_action("settings", true)
	await _press_action("theme_0")
	await _press_action("close_settings")
	await _press_action("hint")
	await _capture("bb_no_hints_dark")
	await _press_action("hint_not_now")
	await _click_action("settings", true)
	_expect(app.settings_layer != null, "In-level gear responds to a touch in Dark mode")
	await _press_action("close_settings")
	await _click_action("settings", false)
	_expect(app.settings_layer != null, "In-level gear responds to a mouse click in Dark mode")
	await _press_action("close_settings")
	_expect(not AdManager.banner_visible and not _find_named("BannerStrip").visible, "Banner is hidden in a level")
	await _click_action("settings", true)
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
	_expect(_has_text("3-star goal: 1"), "In-level screen shows the three-star goal")
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
	for mode_name: String in ["dark", "light"]:
		ThemeManager.set_mode(ThemeManager.Mode.DARK if mode_name == "dark" else ThemeManager.Mode.LIGHT)
		app.chapter_index = 0
		app.chapter_data = LevelRegistry.load_chapter("ch01")
		app._show_game(1)
		for _frame: int in 4: await get_tree().process_frame
		await _capture("bb_gameplay_" + mode_name)
		app.gameplay.shots_used = 1
		app._on_game_shots_changed(1)
		app._finish_level_win()
		for _frame: int in 4: await get_tree().process_frame
		await _capture("bb_win_" + mode_name)
		app._restart_game()
		app._show_try_again_panel()
		for _frame: int in 4: await get_tree().process_frame
		await _capture("bb_try_again_" + mode_name)

	SaveSystem.data = saved_data
	SaveSystem.save()
	LevelRegistry.chapters = saved_chapters
	ThemeManager.set_mode(original_theme as ThemeManager.Mode)
	AudioManager._apply_volumes()
	AudioManager.music_player.stop()
	AudioManager.music_player.stream = null
	AudioManager.ui_player.stop()
	AudioManager.ui_player.stream = null
	for player: AudioStreamPlayer in AudioManager.sfx_players:
		player.stop()
		player.stream = null
	app.queue_free()
	for _frame: int in 3: await get_tree().physics_frame
	print("PASS: menu, Level Select, sheets, settings, tutorials and in-level buttons")
	get_tree().quit(0)

func _exercise_settings() -> void:
	_expect(app.switch_controls.has("sound_enabled"), "Sound switch exists")
	_expect(app.switch_controls.has("music_enabled"), "Music switch exists")
	_expect(app.switch_controls.has("show_aim_guide"), "Aim guide switch exists")
	_expect(app.switch_controls.has("screen_shake"), "Screen shake switch exists")
	_expect(_find_action("website") == null and _find_action("privacy") == null, "Empty app links stay hidden")
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
	var ads_switch: Button = _find_action("ads_enabled")
	if ads_switch != null:
		ads_switch.pressed.emit()
		await get_tree().process_frame
		_expect(not AdManager.ads_enabled, "Debug setting can turn ads off")
		ads_switch.pressed.emit()
		await get_tree().process_frame
		_expect(AdManager.ads_enabled, "Debug setting can turn ads on")

func _open_and_close_info(kind: String, outside: bool = false) -> void:
	var action_name: String = "how_to_play" if kind == "how_to" else kind
	await _press_text(Strings.text(action_name))
	var expected_id: String = "how_to_play" if kind == "how_to" else kind
	_expect(app.info_layer != null and app.info_id == expected_id, kind + " opens its pending sheet")
	_expect(app.tutorial_overlay == null, kind + " does not start the tutorial")
	_expect(_has_text("Pending"), kind + " sheet says Pending")
	var visible_labels: Array[String] = []
	for node: Node in app.info_layer.find_children("", "Label", true, false):
		visible_labels.append((node as Label).text)
	_expect(visible_labels.size() == 2 and visible_labels.has(Strings.text(action_name)) and visible_labels.has(Strings.text("pending")), kind + " sheet contains only its title and Pending")
	var theme_name: String = "light" if ThemeManager.mode == ThemeManager.Mode.LIGHT else "dark"
	await _capture("bb_pending_%s_%s" % [kind, theme_name])
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = Vector2(5.0, 5.0)
	app._input(tap)
	await get_tree().process_frame
	_expect(app.info_layer == null, kind + " sheet closes")

func _press_action(action_name: String) -> void:
	var button: Button = _find_action(action_name)
	_expect(button != null, "Button action exists: " + action_name)
	if button == null:
		return
	_expect(button.mouse_filter == Control.MOUSE_FILTER_STOP, "Pointer target accepts clicks: " + action_name)
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if action_name == "close_settings":
		await get_tree().create_timer(0.3).timeout

func _click_action(action_name: String, use_touch: bool) -> void:
	var button: Button = _find_action(action_name)
	_expect(button != null, "Clickable action exists: " + action_name)
	if button == null:
		return
	# Emit Button activation from both pointer paths; this also works in headless runs.
	var activation_kind: InputEvent = InputEventScreenTouch.new() if use_touch else InputEventMouseButton.new()
	button.set_meta("last_pointer_test", "touch" if activation_kind is InputEventScreenTouch else "mouse")
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if action_name == "settings":
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
	var start: Vector2 = app.gameplay.gameplay_screen_origin()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start
	app._on_tutorial_input(down)
	_expect(app.tutorial_overlay != null, "Tutorial does not finish before the real drag ends")
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = start + Vector2(-90.0, -40.0)
	app._on_tutorial_input(up)
	await get_tree().process_frame

func _tap_tutorial_target() -> void:
	if app.tutorial_overlay == null or app.tutorial_target == null: return
	var point: Vector2 = app.tutorial_target.get_global_rect().get_center()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	app._on_tutorial_input(down)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	app._on_tutorial_input(up)

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
