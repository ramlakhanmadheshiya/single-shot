extends Control
## Main menu, one-chapter level pages, sheets and the ready-for-play screen.
const DARK: Dictionary = preload("res://game/ui/themes/theme_tokens.gd").DARK
const LIGHT: Dictionary = preload("res://game/ui/themes/theme_tokens.gd").LIGHT
const PAGE_DOT_WINDOW: int = 5
const HINTS_PER_LEVEL: int = 3
const START_TUTORIAL: Array[Dictionary] = [{"target": "PlayArea", "message": "tutorial_action_aim", "action": "drag"}]
const RuntimeScript = preload("res://game/core/level_runtime.gd")
const TuningScript = preload("res://game/core/physics_tuning.tres")
var palette: Dictionary = {}
var screen: String = "menu"
var content_layer: Control
var screen_body: Control
var title_label: Label
var settings_layer: Control
var settings_panel: PanelContainer
var settings_scroll: ScrollContainer
var settings_content: VBoxContainer
var info_layer: Control
var info_panel: PanelContainer
var info_id: String = ""
var info_step: int = 0
var modal_kind: String = ""
var more_sound_rows: VBoxContainer
var more_sound_button: Button
var settings_status: Label
var switch_controls: Dictionary = {}
var volume_controls: Dictionary = {}
var theme_buttons: Dictionary = {}
var chapter_index: int = 0
var chapter_data: Dictionary = {}
var page_dots: Array[Button] = []
var page_indicator: Button
var jump_overlay: Control
var jump_input: SpinBox
var current_level_number: int = 1
var shots_used: int = 0
var hints_left: int = HINTS_PER_LEVEL
var hint_line: Control
var tutorial_overlay: Control
var tutorial_step: int = 0
var tutorial_replay: bool = false
var force_mobile_controls: bool = false
var _pointer_start: Vector2 = Vector2.ZERO
var _pointer_down: bool = false
var _touching_sheet: bool = false
var _next_playable_level: int = 1
var _return_to_menu_after_level: bool = false
var tutorial_drag_start: Vector2 = Vector2.ZERO
var tutorial_drag_active: bool = false
var tutorial_target: Control
var _tutorial_hand_base_y: float = 0.0
var active_tutorial_steps: Array[Dictionary] = []
var banner_strip: PanelContainer
var banner_label: Label
var hint_sheet: Control
var ad_sheet: Control
var hint_bonus_mark: Label
var web_start_layer: Control
var gameplay: LevelRuntime
var game_overlay: Control
var game_state: String = "intro"
var game_tuning: PhysicsTuning = TuningScript.duplicate(true)
var physics_panel: PanelContainer
var star_label: Label
var best_result_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ThemeManager.apply_theme(false)
	Events.theme_changed.connect(_on_theme_changed)
	AdManager.rewarded_completed.connect(_on_rewarded_completed)
	AdManager.rewarded_failed.connect(_on_rewarded_failed)
	_build_world()
	_build_banner_strip()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_show_menu()
	if OS.has_feature("web"):
		_show_web_start()

func _process(_delta: float) -> void:
	if tutorial_overlay == null or not is_instance_valid(tutorial_overlay):
		return
	var hand: Label = tutorial_overlay.get_node_or_null("TutorialHand") as Label
	if hand != null:
		hand.position = Vector2(8.0, 28.0 + sin(float(Time.get_ticks_msec()) / 300.0) * 4.0)

func _build_world() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var art: Control = Control.new()
	art.name = "GraveyardArt"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_graveyard.bind(art))
	add_child(art)
	content_layer = Control.new()
	content_layer.name = "ScreenContent"
	content_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content_layer)
	_refresh_palette()

func _build_banner_strip() -> void:
	banner_strip = AdManager.create_banner(self, _t("ad_space"), Color(palette["surface_alt"]), Color(palette["outline"]), Color(palette["text_muted"]))
	banner_strip.name = "BannerStrip"
	_update_banner()

func _update_banner() -> void:
	if banner_strip == null:
		return
	var allowed: bool = screen == "menu" or screen == "levels"
	banner_strip.visible = allowed and settings_layer == null and info_layer == null and hint_sheet == null and AdManager.banner_visible

func _tile_dimensions(width: float, height: float) -> Vector2:
	return Vector2(clampf((width - 150.0) / 4.0, 112.0, 260.0), clampf((height - 370.0) / 5.0, 72.0, 122.0))

func _on_viewport_resized() -> void:
	if screen == "levels" and settings_layer == null and jump_overlay == null:
		_build_level_page()
	elif screen == "menu" and settings_layer == null:
		_show_menu()
	if settings_panel != null:
		var height: float = minf(900.0, get_viewport_rect().size.y * 0.9)
		settings_panel.custom_minimum_size.y = height
		settings_panel.offset_top = -height
		settings_panel.offset_bottom = 0.0
		var actions: GridContainer = settings_panel.find_child("SettingsActions", true, false) as GridContainer
		if actions != null:
			actions.columns = 1 if get_viewport_rect().size.x < 900.0 else 2
		for slider_value: Variant in volume_controls.values():
			var slider: VolumeSlider = slider_value as VolumeSlider
			if is_instance_valid(slider):
				slider.custom_minimum_size.x = minf(320.0, get_viewport_rect().size.x * 0.46)
	_update_banner()

func _draw_graveyard(canvas: Control) -> void:
	var size: Vector2 = canvas.size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	canvas.draw_circle(Vector2(size.x * 0.82, size.y * 0.16), size.y * 0.075, Color(palette["moon"]), true, -1.0, true)
	canvas.draw_rect(Rect2(0.0, size.y * 0.78, size.x, size.y * 0.22), Color(palette["surface_alt"]), true)
	for index: int in 12:
		var x: float = fmod(float(index) * 197.0 + 35.0, size.x)
		var height: float = 60.0 + fmod(float(index * 61), 110.0)
		var width: float = 34.0 + fmod(float(index * 17), 28.0)
		var rect: Rect2 = Rect2(x, size.y * 0.78 - height, width, height)
		canvas.draw_rect(rect, Color(palette["surface"]), true)
		canvas.draw_rect(Rect2(rect.position, Vector2(width, 8.0)), Color(palette["primary"]), true)
	for index: int in 9:
		var x: float = fmod(float(index) * 271.0 + 50.0, size.x)
		var base_y: float = size.y * 0.79
		canvas.draw_line(Vector2(x, base_y), Vector2(x + 7.0, base_y - 115.0), Color(palette["outline"]), 16.0, true)
		canvas.draw_line(Vector2(x - 28.0, base_y - 45.0), Vector2(x + 38.0, base_y - 45.0), Color(palette["outline"]), 12.0, true)

func _refresh_palette() -> void:
	palette = LIGHT if ThemeManager._effective_light() else DARK
	var backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
	if backdrop != null:
		backdrop.color = Color(palette["bg"])
	if banner_strip != null:
		banner_strip.add_theme_stylebox_override("panel", _button_style(str(palette["surface_alt"]), str(palette["outline"]), false))
		var banner_text: Label = banner_strip.find_child("BannerLabel", true, false) as Label
		if banner_text != null:
			banner_text.add_theme_color_override("font_color", Color(palette["text_muted"]))
	var art: Control = get_node_or_null("GraveyardArt") as Control
	if art != null:
		art.queue_redraw()
	if content_layer != null:
		_restyle_tree(content_layer)
	if settings_layer != null:
		_restyle_tree(settings_layer)
	if info_layer != null:
		_restyle_tree(info_layer)
	for mode_value: Variant in theme_buttons.keys():
		var theme_button: Button = theme_buttons[mode_value] as Button
		if is_instance_valid(theme_button):
			var button_style: String = "theme_active" if int(mode_value) == int(ThemeManager.mode) else "secondary"
			theme_button.set_meta("bb_style", button_style)
			_style_button(theme_button, button_style)
	for slider_value: Variant in volume_controls.values():
		var slider: VolumeSlider = slider_value as VolumeSlider
		if is_instance_valid(slider):
			slider.set_palette(Color(palette["surface_alt"]), Color(palette["primary"]), Color(palette["surface"]), Color(palette["outline"]))

func _restyle_tree(node: Node) -> void:
	if node is PanelContainer:
		(node as PanelContainer).add_theme_stylebox_override("panel", _panel_style())
	elif node is Button:
		var button: Button = node as Button
		_style_button(button, str(button.get_meta("bb_style", "secondary")))
	elif node is Label and node.has_meta("bb_token"):
		(node as Label).add_theme_color_override("font_color", Color(palette[str(node.get_meta("bb_token"))]))
	for child: Node in node.get_children():
		_restyle_tree(child)

func _clear_screen() -> void:
	title_label = null
	screen_body = null
	page_dots.clear()
	page_indicator = null
	if settings_layer == null:
		switch_controls.clear()
		volume_controls.clear()
		theme_buttons.clear()
	tutorial_overlay = null
	hint_line = null
	for child: Node in content_layer.get_children():
		child.queue_free()

func _show_menu() -> void:
	_close_jump_overlay()
	_close_settings(false)
	_clear_screen()
	screen = "menu"
	AdManager.show_banner("main_menu")
	_update_banner()
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.offset_bottom = -94.0
	content_layer.add_child(center)
	var panel: PanelContainer = _make_panel()
	panel.custom_minimum_size = Vector2(minf(940.0, get_viewport_rect().size.x * 0.88), minf(820.0, get_viewport_rect().size.y * 0.9))
	center.add_child(panel)
	var menu: VBoxContainer = VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 28)
	panel.add_child(menu)
	var title: Label = _make_label(menu, "game_title", minf(92.0, get_viewport_rect().size.x * 0.105), "accent")
	title.name = "GameTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tagline: Label = _make_label(menu, "tagline", 30, "text_muted")
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var play: Button = _make_button(menu, "", _play_current_level, Vector2(minf(610.0, get_viewport_rect().size.x * 0.78), 128.0), "primary")
	play.name = "PlayButton"
	play.set_meta("bb_action", "play")
	var play_text: VBoxContainer = VBoxContainer.new()
	play_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_text.alignment = BoxContainer.ALIGNMENT_CENTER
	play_text.add_theme_constant_override("separation", -3)
	play_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(play_text)
	var play_label: Label = _make_label(play_text, "play", 38, "text")
	play_label.add_theme_color_override("font_color", Color.WHITE)
	play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var current_label: Label = _make_label(play_text, "current_level", 21, "text")
	current_label.text = _t("current_level", {"number": _current_level_global()})
	current_label.add_theme_color_override("font_color", Color.WHITE)
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var levels_button: Button = _make_button(menu, _t("levels"), _show_level_select, Vector2(minf(420.0, get_viewport_rect().size.x * 0.58), 84.0), "secondary")
	levels_button.name = "LevelsButton"
	levels_button.set_meta("bb_action", "levels_menu")
	# Keep this control above the full-screen menu container in draw and input order.
	var gear: Button = _make_button(content_layer, _t("settings_icon"), _show_settings, Vector2(76.0, 76.0), "secondary")
	gear.name = "SettingsIcon"
	gear.set_meta("bb_action", "settings")
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.offset_left = -106.0
	gear.offset_right = -30.0
	gear.offset_top = 26.0
	gear.offset_bottom = 102.0

func _show_web_start() -> void:
	if web_start_layer != null:
		return
	web_start_layer = Control.new()
	web_start_layer.name = "WebStartScreen"
	web_start_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	web_start_layer.z_index = 120
	add_child(web_start_layer)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(palette["bg"])
	web_start_layer.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	web_start_layer.add_child(center)
	var panel: PanelContainer = _make_panel()
	center.add_child(panel)
	var start: Button = _make_button(panel, _t("tap_to_start"), _start_web_game, Vector2(420.0, 96.0), "primary")
	start.set_meta("bb_action", "web_start")

func _start_web_game() -> void:
	AudioManager.start_after_user_gesture()
	if web_start_layer != null:
		web_start_layer.queue_free()
	web_start_layer = null

func _show_level_select() -> void:
	_close_jump_overlay()
	_clear_screen()
	screen = "levels"
	AdManager.show_banner("level_select")
	_update_banner()
	_return_to_menu_after_level = false
	chapter_index = _current_level_chapter()
	_build_level_page()

func _play_current_level() -> void:
	var current: int = _current_level_global()
	if current > LevelRegistry.total_level_count():
		_show_level_select()
		return
	var chapter: int = _current_level_chapter()
	chapter_index = chapter
	chapter_data = LevelRegistry.load_chapter(str(LevelRegistry.chapters[chapter].get("id", "")))
	_return_to_menu_after_level = true
	_open_level(current - chapter * 20)

func _current_level_global() -> int:
	var global_number: int = 1
	for entry: Dictionary in LevelRegistry.chapters:
		var chapter_id: String = str(entry.get("id", ""))
		var level_count: int = int(entry.get("level_count", 20))
		for index: int in level_count:
			var record: Dictionary = SaveSystem.get_level("%s_l%03d" % [chapter_id, index + 1])
			if record.is_empty():
				_store_current_level(global_number)
				return global_number
			global_number += 1
	var total: int = LevelRegistry.total_level_count()
	_store_current_level(total + 1)
	return total + 1

func _store_current_level(number: int) -> void:
	if int(SaveSystem.data.get("current_level", 1)) == number:
		return
	SaveSystem.data["current_level"] = number
	SaveSystem.save()

func _current_level_chapter() -> int:
	var current: int = _current_level_global()
	if LevelRegistry.chapters.is_empty():
		return 0
	return clampi((current - 1) / 20, 0, LevelRegistry.chapters.size() - 1)

func _global_level_number(chapter: int, local_number: int) -> int:
	return chapter * 20 + local_number

func _build_level_page() -> void:
	_clear_screen()
	if LevelRegistry.chapters.is_empty():
		return
	chapter_index = clampi(chapter_index, 0, LevelRegistry.chapters.size() - 1)
	var entry: Dictionary = LevelRegistry.chapters[chapter_index]
	var chapter_id: String = str(entry.get("id", ""))
	chapter_data = LevelRegistry.load_chapter(chapter_id)
	_next_playable_level = _find_next_playable(chapter_data)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_bottom = -94.0
	root.add_theme_constant_override("separation", 18)
	content_layer.add_child(root)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	page.add_child(top)
	var back: Button = _make_button(top, _t("back"), _show_menu, Vector2(120.0, 72.0), "secondary")
	back.set_meta("bb_action", "back")
	var levels_title: Label = _make_label(top, "levels", 52, "text")
	levels_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var star_label: Label = _make_label(top, "stars_total", 25, "text", {"earned": SaveSystem.total_stars(), "total": LevelRegistry.total_level_count() * 3})
	star_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var gear: Button = _make_button(top, _t("settings_icon"), _show_settings, Vector2(72.0, 72.0), "secondary")
	gear.name = "SettingsIcon"
	if get_viewport_rect().size.x < 900.0:
		star_label.visible = false
	gear.set_meta("bb_action", "settings")
	var chapter_row: VBoxContainer = VBoxContainer.new()
	chapter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chapter_row.add_theme_constant_override("separation", 2)
	page.add_child(chapter_row)
	var chapter_number: Label = _make_label(chapter_row, "chapter_number", 32, "text", {"number": chapter_index + 1})
	chapter_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if get_viewport_rect().size.x < 900.0:
		var compact_stars: Label = _make_label(chapter_row, "stars_total", 21, "text", {"earned": SaveSystem.total_stars(), "total": LevelRegistry.total_level_count() * 3})
		compact_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var chapter_name: String = _chapter_name_key(entry)
	var chapter_title: Label = _make_label(chapter_row, chapter_name, minf(39.0, get_viewport_rect().size.x * 0.06), "accent")
	chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid_area: CenterContainer = CenterContainer.new()
	grid_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(grid_area)
	if _chapter_is_open(chapter_index):
		_build_level_grid(grid_area, chapter_data)
	else:
		_build_locked_chapter(grid_area)
	LevelRegistry.last_loaded_chapter_id = chapter_id
	_build_pager(page, LevelRegistry.chapters.size())
	if not chapter_index == int(SaveSystem.get_setting("last_played_chapter", 0)):
		# Browsing does not change the remembered place until a level starts.
		pass

func _build_level_grid(parent: Control, chapter: Dictionary) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.name = "LevelGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)
	var levels: Array = chapter.get("levels", [])
	var width: float = get_viewport_rect().size.x
	var height: float = get_viewport_rect().size.y
	var tile_size: Vector2 = _tile_dimensions(width, height)
	var tile_width: float = tile_size.x
	var tile_height: float = tile_size.y
	for index: int in 20:
		var info: Dictionary = levels[index] if index < levels.size() else {"id": "", "number": index + 1}
		var number: int = int(info.get("number", index + 1))
		var id: String = str(info.get("id", ""))
		var record: Dictionary = SaveSystem.get_level(id)
		var open: bool = _is_level_open(chapter, index)
		var stars: int = int(record.get("stars", 0))
		var tile_text: String = (str(number) + "\n" + _t("stars_%d" % clampi(stars, 0, 3))) if open else ""
		var action: Callable = _open_level.bind(number) if open else _ignore_locked_level
		var style: String = "highlight" if number == _next_playable_level and open else ("completed" if record.size() > 0 else "tile")
		var tile: Button = _make_button(grid, tile_text, action, Vector2(tile_width, tile_height), style)
		tile.name = "LevelTile_%02d" % number
		tile.set_meta("level_number", number)
		tile.set_meta("level_id", id)
		tile.set_meta("bb_action", "level_%02d" % number)
		tile.disabled = not open
		if not open:
			_add_lock_icon(tile, minf(66.0, tile_height * 0.62), true)

func _add_lock_icon(parent: Control, icon_size: float, centered: bool = false) -> void:
	var icon: LockIcon = LockIcon.new()
	icon.name = "LockIcon"
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size = icon.custom_minimum_size
	if centered:
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.anchor_top = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -icon_size * 0.5
		icon.offset_right = icon_size * 0.5
		icon.offset_top = -icon_size * 0.5
		icon.offset_bottom = icon_size * 0.5
	else:
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.anchor_top = 0.0
		icon.anchor_bottom = 0.0
		icon.offset_left = -icon_size * 0.5
		icon.offset_right = icon_size * 0.5
		icon.offset_top = 82.0
		icon.offset_bottom = 82.0 + icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_colors(Color(palette["text"]), Color(palette["surface_alt"]))
	parent.add_child(icon)

func _build_locked_chapter(parent: Control) -> void:
	var panel: Button = _make_button(parent, "", _ignore_locked_chapter, Vector2(minf(760.0, get_viewport_rect().size.x * 0.75), 390.0), "tile")
	panel.name = "LockedChapterButton"
	panel.set_meta("bb_action", "locked_chapter")
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	var lock: LockIcon = LockIcon.new()
	lock.custom_minimum_size = Vector2(120.0, 120.0)
	lock.size = lock.custom_minimum_size
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock.set_colors(Color(palette["text"]), Color(palette["surface_alt"]))
	box.add_child(lock)
	var locked_line: Label = _make_label(box, "chapter_locked", 30, "text", {"number": chapter_index})
	locked_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	locked_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_pager(parent: Control, total_pages: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var compact: bool = get_viewport_rect().size.x < 900.0
	var arrow_size: float = 64.0 if compact else 78.0
	var dot_size: float = 32.0 if compact else 42.0
	var row_gap: int = 7 if compact else 18
	row.add_theme_constant_override("separation", row_gap)
	var left: Button = _make_button(row, _t("arrow_left"), func(): _change_chapter(-1), Vector2(arrow_size, 72.0), "secondary")
	left.name = "PreviousChapter"
	left.set_meta("bb_action", "previous")
	var dot_box: HBoxContainer = HBoxContainer.new()
	dot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	dot_box.add_theme_constant_override("separation", 6 if compact else 10)
	row.add_child(dot_box)
	page_dots.clear()
	var first_dot: int = maxi(0, chapter_index - PAGE_DOT_WINDOW / 2)
	first_dot = mini(first_dot, maxi(0, total_pages - PAGE_DOT_WINDOW))
	var end_dot: int = mini(total_pages, first_dot + PAGE_DOT_WINDOW)
	for index: int in range(first_dot, end_dot):
		var dot_text: String = _t("page_dot_on") if index == chapter_index else _t("page_dot_off")
		var dot: Button = _make_button(dot_box, dot_text, _set_chapter.bind(index), Vector2(dot_size, 62.0), "dot_active" if index == chapter_index else "dot")
		dot.set_meta("page_index", index)
		page_dots.append(dot)
	page_indicator = _make_button(row, "", _open_jump_sheet, Vector2(100.0 if compact else 112.0, 72.0), "secondary")
	page_indicator.name = "PageIndicator"
	page_indicator.text = _t("page_number", {"current": chapter_index + 1, "total": total_pages})
	page_indicator.set_meta("bb_action", "page_indicator")
	var right: Button = _make_button(row, _t("arrow_right"), func(): _change_chapter(1), Vector2(arrow_size, 72.0), "secondary")
	right.name = "NextChapter"
	right.set_meta("bb_action", "next")

func _change_chapter(amount: int) -> void:
	_set_chapter(chapter_index + amount)

func _set_chapter(index: int) -> void:
	if LevelRegistry.chapters.is_empty():
		return
	chapter_index = clampi(index, 0, LevelRegistry.chapters.size() - 1)
	_build_level_page()

func _open_jump_sheet() -> void:
	if jump_overlay != null:
		return
	jump_overlay = Control.new()
	jump_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	jump_overlay.z_index = 20
	content_layer.add_child(jump_overlay)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(palette["overlay"], 0.6)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_jump_overlay()
	)
	jump_overlay.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	jump_overlay.add_child(center)
	var panel: PanelContainer = _make_panel()
	panel.custom_minimum_size = Vector2(420.0, 240.0)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	_make_label(box, "jump_to_chapter", 30, "text")
	jump_input = SpinBox.new()
	jump_input.min_value = 1
	jump_input.max_value = LevelRegistry.chapters.size()
	jump_input.value = chapter_index + 1
	jump_input.custom_minimum_size = Vector2(240.0, 60.0)
	box.add_child(jump_input)
	var go: Button = _make_button(box, _t("go"), func():
		var target: int = int(jump_input.value) - 1
		_close_jump_overlay()
		_set_chapter(target)
	, Vector2(180.0, 72.0), "primary")
	go.name = "JumpGo"
	go.set_meta("bb_action", "jump_go")

func _close_jump_overlay() -> void:
	if jump_overlay != null:
		jump_overlay.queue_free()
	jump_overlay = null
	jump_input = null

func _show_settings() -> void:
	if settings_layer != null:
		return
	AdManager.hide_banner()
	_update_banner()
	settings_layer = Control.new()
	settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_layer.z_index = 40
	add_child(settings_layer)
	var dim: ColorRect = ColorRect.new()
	dim.name = "SettingsOutside"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(palette["overlay"], 0.63)
	dim.gui_input.connect(_on_settings_outside)
	settings_layer.add_child(dim)
	var height: float = minf(900.0, get_viewport_rect().size.y * 0.9)
	settings_panel = _make_panel()
	settings_panel.name = "SettingsSheet"
	settings_panel.anchor_left = 0.035
	settings_panel.anchor_right = 0.965
	settings_panel.anchor_top = 1.0
	settings_panel.anchor_bottom = 1.0
	settings_panel.offset_left = 0.0
	settings_panel.offset_right = 0.0
	settings_panel.offset_top = -height
	settings_panel.offset_bottom = 0.0
	settings_panel.custom_minimum_size.y = height
	settings_layer.add_child(settings_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(scroll)
	settings_scroll = scroll
	settings_content = VBoxContainer.new()
	settings_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_content.add_theme_constant_override("separation", 12)
	scroll.add_child(settings_content)
	_build_settings_contents()
	var tween: Tween = create_tween()
	settings_panel.offset_top = 0.0
	settings_panel.offset_bottom = height
	tween.tween_property(settings_panel, "offset_top", -height, 0.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(settings_panel, "offset_bottom", 0.0, 0.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _build_settings_contents() -> void:
	switch_controls.clear()
	volume_controls.clear()
	var header: HBoxContainer = HBoxContainer.new()
	settings_content.add_child(header)
	var settings_title: Label = _make_label(header, "settings", 38, "text")
	settings_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button: Button = _make_button(header, _t("close"), _close_settings, Vector2(132.0, 72.0), "secondary")
	close_button.set_meta("bb_action", "close_settings")
	_add_switch_row("sound", "sound_enabled", true)
	_add_switch_row("music", "music_enabled", true)
	if _is_mobile():
		_add_switch_row("vibration", "vibration", true)
	_add_switch_row("aim_guide", "show_aim_guide", true, true)
	_add_switch_row("screen_shake", "screen_shake", true)
	var theme_row: HBoxContainer = HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 10)
	settings_content.add_child(theme_row)
	var theme_label: Label = _make_label(theme_row, "theme", 26, "text")
	theme_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var choices: HBoxContainer = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 5)
	theme_row.add_child(choices)
	theme_buttons.clear()
	var values: Array[int] = [ThemeManager.Mode.SYSTEM, ThemeManager.Mode.LIGHT, ThemeManager.Mode.DARK]
	var keys: Array[String] = ["auto", "light", "dark"]
	for index: int in values.size():
		var theme_button: Button = _make_button(choices, _t(keys[index]), _set_theme_mode.bind(values[index]), Vector2(116.0, 72.0), "theme_active" if int(ThemeManager.mode) == values[index] else "secondary")
		theme_button.set_meta("theme_mode", values[index])
		theme_button.set_meta("bb_action", "theme_%d" % values[index])
		theme_buttons[values[index]] = theme_button
	more_sound_button = _make_button(settings_content, _t("more_sound"), _toggle_sound_rows, Vector2(330.0, 72.0), "secondary")
	more_sound_button.set_meta("bb_action", "more_sound")
	more_sound_rows = VBoxContainer.new()
	more_sound_rows.add_theme_constant_override("separation", 8)
	more_sound_rows.visible = false
	settings_content.add_child(more_sound_rows)
	_add_volume_row(more_sound_rows, "music_volume", "music_volume", 0.65)
	_add_volume_row(more_sound_rows, "sound_volume", "sound_volume", 0.8)
	_add_volume_row(more_sound_rows, "ui_volume", "ui_volume", 0.85)
	var actions: GridContainer = GridContainer.new()
	actions.name = "SettingsActions"
	actions.columns = 1 if get_viewport_rect().size.x < 900.0 else 2
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 8)
	settings_content.add_child(actions)
	var how_button: Button = _make_button(actions, _t("how_to_play"), _open_how_to, Vector2(minf(300.0, get_viewport_rect().size.x * 0.62), 72.0), "secondary")
	how_button.set_meta("bb_action", "how_to_play")
	var credits_button: Button = _make_button(actions, _t("credits"), _open_credits, Vector2(minf(300.0, get_viewport_rect().size.x * 0.62), 72.0), "secondary")
	credits_button.set_meta("bb_action", "credits")
	var about_button: Button = _make_button(actions, _t("about"), _open_about, Vector2(minf(300.0, get_viewport_rect().size.x * 0.62), 72.0), "secondary")
	about_button.set_meta("bb_action", "about")
	if screen != "game":
		var reset_button: Button = _make_button(actions, _t("reset_progress"), _open_reset_confirm, Vector2(minf(300.0, get_viewport_rect().size.x * 0.62), 72.0), "danger")
		reset_button.set_meta("bb_action", "reset_progress")
	if OS.is_debug_build():
		var ads_row: HBoxContainer = HBoxContainer.new()
		settings_content.add_child(ads_row)
		var ads_text: Label = _make_label(ads_row, "ads_enabled", 24, "text")
		ads_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ads_enabled: bool = bool(SaveSystem.get_setting("ads_enabled", true))
		var ads_switch: Button = _make_button(ads_row, _t("on") if ads_enabled else _t("off"), _toggle_ads_enabled, Vector2(112.0, 72.0), "switch_on" if ads_enabled else "switch_off")
		ads_switch.name = "AdsEnabledSwitch"
		ads_switch.set_meta("bb_action", "ads_enabled")
	if AppLinks.WEBSITE_URL != "" or AppLinks.PRIVACY_URL != "":
		var links: HBoxContainer = HBoxContainer.new()
		links.alignment = BoxContainer.ALIGNMENT_CENTER
		settings_content.add_child(links)
		if AppLinks.WEBSITE_URL != "":
			var website: Button = _make_button(links, _t("website"), func(): OS.shell_open(AppLinks.WEBSITE_URL), Vector2(180.0, 64.0), "secondary")
			website.set_meta("bb_action", "website")
		if AppLinks.PRIVACY_URL != "":
			var privacy: Button = _make_button(links, _t("privacy"), func(): OS.shell_open(AppLinks.PRIVACY_URL), Vector2(180.0, 64.0), "secondary")
			privacy.set_meta("bb_action", "privacy")
	settings_status = _make_label(settings_content, "reset_done", 20, "success")
	settings_status.name = "SettingsStatus"
	settings_status.visible = false
	settings_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var version: Label = _make_label(settings_content, "version", 18, "text_muted")
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _add_switch_row(label_key: String, setting_key: String, fallback: bool, help_text: bool = false) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	settings_content.add_child(row)
	var caption: Label = _make_label(row, label_key, 26, "text")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if help_text:
		caption.tooltip_text = _t("aim_guide_help")
	var value: bool = bool(SaveSystem.get_setting(setting_key, fallback))
	var toggle: Button = _make_button(row, _t("on") if value else _t("off"), func(): _toggle_setting(setting_key), Vector2(112.0, 72.0), "switch_on" if value else "switch_off")
	toggle.name = "Switch_" + setting_key
	toggle.set_meta("setting_key", setting_key)
	toggle.set_meta("switch_value", value)
	toggle.set_meta("bb_action", "switch_" + setting_key)
	switch_controls[setting_key] = toggle

func _add_volume_row(parent: Control, label_key: String, setting_key: String, fallback: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label: Label = _make_label(row, label_key, 22, "text")
	label.custom_minimum_size.x = minf(220.0, get_viewport_rect().size.x * 0.3)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider: VolumeSlider = _make_volume_slider(setting_key, float(SaveSystem.get_setting(setting_key, fallback)))
	slider.custom_minimum_size = Vector2(minf(320.0, get_viewport_rect().size.x * 0.46), 56.0)
	row.add_child(slider)
	volume_controls[setting_key] = slider

func _make_volume_slider(setting_key: String, initial_value: float) -> VolumeSlider:
	var slider: VolumeSlider = VolumeSlider.new()
	slider.value = initial_value
	slider.value_changed.connect(func(value: float): _set_volume(setting_key, value))
	slider.set_palette(Color(palette["surface_alt"]), Color(palette["primary"]), Color(palette["surface"]), Color(palette["outline"]))
	return slider

func _set_volume(key: String, value: float) -> void:
	SaveSystem.set_setting(key, value)
	var bus: String = "Music" if key == "music_volume" else ("SFX" if key == "sound_volume" else "UI")
	AudioManager.set_bus_linear(bus, value)

func _toggle_setting(key: String) -> void:
	var control: Button = switch_controls.get(key) as Button
	if control == null:
		return
	var value: bool = not bool(control.get_meta("switch_value", false))
	SaveSystem.set_setting(key, value)
	control.set_meta("switch_value", value)
	control.set_meta("bb_style", "switch_on" if value else "switch_off")
	control.text = _t("on") if value else _t("off")
	_style_button(control, "switch_on" if value else "switch_off")
	if key == "sound_enabled":
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not value)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("UI"), not value)
	elif key == "music_enabled":
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not value)

func _toggle_ads_enabled() -> void:
	var enabled: bool = not bool(SaveSystem.get_setting("ads_enabled", true))
	SaveSystem.set_setting("ads_enabled", enabled)
	AdManager.set_ads_enabled(enabled)
	var control: Button = settings_content.find_child("AdsEnabledSwitch", true, false) as Button
	if control != null:
		control.text = _t("on") if enabled else _t("off")
		_style_button(control, "switch_on" if enabled else "switch_off")
	_update_banner()

func _set_theme_mode(mode: int) -> void:
	ThemeManager.set_mode(mode as ThemeManager.Mode)

func _toggle_sound_rows() -> void:
	if more_sound_rows == null:
		return
	more_sound_rows.visible = not more_sound_rows.visible

func _is_mobile() -> bool:
	return force_mobile_controls or OS.has_feature("mobile")

func _open_how_to() -> void:
	_open_info_sheet("how_to_play")

func _open_credits() -> void:
	_open_info_sheet("credits")

func _open_about() -> void:
	_open_info_sheet("about")

func _open_reset_confirm() -> void:
	_open_info_sheet("reset_confirm")

func _open_info_sheet(kind: String) -> void:
	if info_layer != null:
		return
	info_id = kind
	info_step = 0
	info_layer = Control.new()
	info_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_layer.z_index = 60
	add_child(info_layer)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(palette["overlay"], 0.68)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_info_sheet()
	)
	info_layer.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_layer.add_child(center)
	var panel: PanelContainer = _make_panel()
	panel.name = "InfoPanel"
	panel.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x * 0.82), 260.0) if kind != "reset_confirm" else Vector2(minf(780.0, get_viewport_rect().size.x * 0.88), 360.0)
	center.add_child(panel)
	info_panel = panel
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	if kind == "reset_confirm":
		_make_label(box, "reset_question", 31, "text")
		var buttons: HBoxContainer = HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons.add_theme_constant_override("separation", 18)
		box.add_child(buttons)
		var cancel: Button = _make_button(buttons, _t("cancel"), _close_info_sheet, Vector2(190.0, 74.0), "secondary")
		cancel.set_meta("bb_action", "reset_cancel")
		var delete: Button = _make_button(buttons, _t("delete"), _delete_progress, Vector2(190.0, 74.0), "danger")
		delete.set_meta("bb_action", "reset_delete")
	else:
		var title_key: String = kind
		_make_label(box, title_key, 42, "accent")
		_make_label(box, "pending", 28, "text")

func _delete_progress() -> void:
	SaveSystem.reset_progress()
	chapter_index = 0
	_return_to_menu_after_level = false
	_close_info_sheet()
	if settings_status != null and is_instance_valid(settings_status):
		settings_status.text = _t("reset_done")
		settings_status.visible = true
	if screen == "levels":
		_build_level_page()

func _close_info_sheet() -> void:
	if info_layer != null:
		info_layer.queue_free()
	info_layer = null
	info_panel = null
	info_id = ""
	_update_banner()

func _on_settings_outside(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_settings()
	elif event is InputEventScreenTouch and event.pressed:
		_close_settings()

func _close_settings(animate: bool = true) -> void:
	if settings_layer == null:
		return
	if animate and settings_panel != null:
		var panel_to_close: PanelContainer = settings_panel
		var height: float = panel_to_close.size.y
		var tween: Tween = create_tween()
		tween.tween_property(panel_to_close, "offset_top", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(panel_to_close, "offset_bottom", height, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			if settings_layer != null:
				settings_layer.queue_free()
			settings_layer = null
			settings_panel = null
			settings_content = null
			_sync_banner_for_screen()
		)
	else:
		settings_layer.queue_free()
		settings_layer = null
		settings_panel = null
		settings_content = null
		_sync_banner_for_screen()
	_close_info_sheet()

func _sync_banner_for_screen() -> void:
	if screen == "menu":
		AdManager.show_banner("main_menu")
	elif screen == "levels":
		AdManager.show_banner("level_select")
	else:
		AdManager.hide_banner()
	_update_banner()

func _show_game(level_number: int) -> void:
	AdManager.hide_banner()
	_update_banner()
	_close_settings(false)
	_clear_screen()
	screen = "game"
	current_level_number = level_number
	shots_used = 0
	SaveSystem.update_daily_hints()
	hints_left = int(SaveSystem.data.get("hints_left", 3))
	SaveSystem.set_setting("last_played_chapter", chapter_index)
	var data: Dictionary = _level_metadata(level_number)
	game_tuning = TuningScript.duplicate(true) as PhysicsTuning
	var level_physics: Dictionary = data.get("physics", {})
	for property: Dictionary in game_tuning.get_property_list():
		var property_name: String = str(property.get("name", ""))
		if level_physics.has(property_name) and (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) != 0:
			game_tuning.set(property_name, level_physics[property_name])
	var par_three: int = int(data.get("par_3", 2))
	GameState.begin_level(str(data.get("id", "ch01_l%03d" % level_number)), str(chapter_data.get("id", "ch01")))
	game_state = "intro"
	var page: VBoxContainer = VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_body = page
	page.add_theme_constant_override("separation", 20)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	page.add_child(margin)
	content_layer.add_child(page)
	var game_box: VBoxContainer = VBoxContainer.new()
	game_box.add_theme_constant_override("separation", 18)
	game_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(game_box)
	var compact: bool = get_viewport_rect().size.x < 900.0
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8 if compact else 20)
	game_box.add_child(header)
	var back: Button = _make_button(header, _t("back"), _game_back, Vector2(90.0 if compact else 120.0, 72.0), "secondary")
	back.set_meta("bb_action", "game_back")
	var level_title: Label = _make_label(header, "level_number", 28 if compact else 38, "text", {"number": current_level_number})
	level_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shots: Label = _make_label(header, "shots_used", 17 if compact else 23, "text", {"number": shots_used})
	shots.name = "ShotsUsed"
	var goal: Label = _make_label(header, "three_star_goal", 17 if compact else 23, "text", {"number": par_three})
	goal.size_flags_horizontal = Control.SIZE_SHRINK_END
	var play_area: PanelContainer = _make_panel()
	play_area.name = "PlayArea"
	play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_box.add_child(play_area)
	gameplay = RuntimeScript.new() as LevelRuntime
	gameplay.name = "Gameplay"
	gameplay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_area.add_child(gameplay)
	gameplay.configure(data, palette, game_tuning)
	gameplay.shots_changed.connect(_on_game_shots_changed)
	gameplay.state_changed.connect(_on_game_state_changed)
	gameplay.action_made.connect(_on_game_action)
	var hint_row: HBoxContainer = HBoxContainer.new()
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	game_box.add_child(hint_row)
	var hint_button: Button = _make_button(hint_row, _t("hint_count", {"number": hints_left + int(SaveSystem.data.get("bonus_hints", 0))}), _use_hint, Vector2(200.0, 72.0), "secondary")
	hint_button.name = "HintButton"
	hint_button.set_meta("bb_action", "hint")
	var bulb: LightBulbIcon = LightBulbIcon.new()
	bulb.custom_minimum_size = Vector2(38.0, 42.0)
	bulb.anchor_left = 0.0
	bulb.anchor_right = 0.0
	bulb.anchor_top = 0.5
	bulb.anchor_bottom = 0.5
	bulb.offset_left = 12.0
	bulb.offset_right = 50.0
	bulb.offset_top = -21.0
	bulb.offset_bottom = 21.0
	bulb.set_tint(Color(palette["moon"]), Color(palette["outline"]))
	bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_button.add_child(bulb)
	hint_bonus_mark = Label.new()
	hint_bonus_mark.name = "HintBonusMark"
	hint_bonus_mark.text = "+"
	hint_bonus_mark.add_theme_font_size_override("font_size", 20)
	hint_bonus_mark.add_theme_color_override("font_color", Color(palette["accent"]))
	hint_bonus_mark.anchor_left = 1.0
	hint_bonus_mark.anchor_right = 1.0
	hint_bonus_mark.offset_left = -40.0
	hint_bonus_mark.offset_right = -12.0
	hint_bonus_mark.offset_top = 4.0
	hint_bonus_mark.offset_bottom = 30.0
	hint_bonus_mark.visible = hints_left <= 0
	hint_bonus_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_button.add_child(hint_bonus_mark)
	hint_button.set_meta("bb_action", "hint")
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	game_box.add_child(footer)
	var undo: Button = _make_button(footer, _t("undo"), _undo_shot, Vector2(200.0, 72.0), "secondary")
	undo.name = "UndoButton"
	undo.set_meta("bb_action", "undo")
	var restart: Button = _make_button(footer, _t("restart"), _restart_game, Vector2(200.0, 72.0), "secondary")
	restart.name = "RestartButton"
	restart.set_meta("bb_action", "restart")
	var settings: Button = _make_button(footer, _t("settings_icon"), _show_settings, Vector2(82.0, 72.0), "secondary")
	settings.set_meta("bb_action", "settings")
	if current_level_number <= 3 and not _tutorial_was_seen(current_level_number):
		var steps: Array[Dictionary] = _tutorial_steps(current_level_number)
		_show_tutorial(false, steps)
	if OS.is_debug_build():
		_set_physics_gravity()

func _on_game_shots_changed(value: int) -> void:
	shots_used = value
	_update_shots_label()

func _on_game_action(action: String) -> void:
	AudioManager.play_ui("ui_click")
	if action == "shot":
		game_state = "shot_flying"
		if _tutorial_waiting_for("drag"):
			_advance_tutorial()
	elif action == "undo":
		game_state = "aiming"
		if _tutorial_waiting_for("tutorial_undo"):
			_advance_tutorial()

func _on_game_state_changed(value: String) -> void:
	game_state = value
	match value:
		"aiming":
			GameState.play_state = GameState.PlayState.AIMING
			_set_hazel_pose("idle")
		"shot_flying":
			GameState.play_state = GameState.PlayState.FIRED
			_set_hazel_pose("fire")
		"settling": GameState.play_state = GameState.PlayState.RESOLVING
		"win":
			GameState.play_state = GameState.PlayState.WIN
			_set_hazel_pose("win")
			_finish_level_win()
		"try_again":
			GameState.play_state = GameState.PlayState.FAIL
			_set_hazel_pose("lose")
			_show_try_again_panel()

func _set_hazel_pose(pose: String) -> void:
	if gameplay != null and gameplay.hazel_sprite != null:
		gameplay.hazel_sprite.pose = pose
		gameplay.hazel_sprite.queue_redraw()

func _finish_level_win() -> void:
	if game_overlay != null:
		return
	var data: Dictionary = _level_metadata(current_level_number)
	var level_id: String = str(data.get("id", "ch01_l%03d" % current_level_number))
	var stars: int = gameplay.get_stars() if gameplay != null else 1
	SaveSystem.record_level(level_id, stars, false, shots_used)
	SaveSystem.data["current_level"] = _current_level_global()
	SaveSystem.save()
	AudioManager.play_game("star_ding")
	_show_result_panel(true)

func _show_try_again_panel() -> void:
	_show_result_panel(false)

func _show_result_panel(won: bool) -> void:
	if game_overlay != null:
		return
	AdManager.hide_banner()
	game_overlay = Control.new()
	game_overlay.name = "WinPanel" if won else "TryAgainPanel"
	game_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_overlay.z_index = 25
	game_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	content_layer.add_child(game_overlay)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(palette["overlay"], 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_overlay.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -94.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_overlay.add_child(center)
	var panel: PanelContainer = _make_panel()
	panel.name = "ResultCard"
	panel.custom_minimum_size = Vector2(minf(620.0, size.x * 0.85), 350.0)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	_make_label(box, "win_title" if won else "try_again_text", 36, "text")
	if won:
		star_label = _make_label(box, "stars_" + str(gameplay.get_stars()), 42, "accent")
		star_label.name = "EarnedStars"
		star_label.scale = Vector2(0.5, 0.5)
		var tw: Tween = create_tween()
		tw.tween_property(star_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var next: Button = _make_button(box, "", _go_next_level, Vector2(370, 68), "primary")
		next.name = "NextLevelButton"
		next.text = _t("next_level")
		next.set_meta("bb_action", "next_level")
	var retry: Button = _make_button(box, _t("try_again"), _restart_game, Vector2(370, 68), "secondary")
	retry.set_meta("bb_action", "retry")
	var levels_button: Button = _make_button(box, _t("levels"), _show_level_select, Vector2(370, 68), "secondary")
	levels_button.set_meta("bb_action", "result_levels")
	var result_data: Dictionary = _level_metadata(current_level_number)
	var result_id: String = str(result_data.get("id", "ch01_l%03d" % current_level_number))
	var record: Dictionary = SaveSystem.get_level(result_id)
	best_result_label = _make_label(box, "best_shots", 18, "text_muted", {"number": int(record.get("best_shots", shots_used))})
	best_result_label.name = "BestResult"

func _restart_game() -> void:
	if game_overlay != null:
		game_overlay.queue_free()
	game_overlay = null
	_show_game(current_level_number)

func _go_next_level() -> void:
	if current_level_number < int(chapter_data.get("level_count", 20)):
		if game_overlay != null: game_overlay.queue_free()
		game_overlay = null
		_show_game(current_level_number + 1)
	else:
		_show_level_select()

func _show_tutorial(replay: bool, steps: Array[Dictionary] = []) -> void:
	if screen != "game" or settings_layer != null or info_layer != null or hint_sheet != null:
		return
	if tutorial_overlay != null:
		tutorial_overlay.queue_free()
	tutorial_replay = replay
	tutorial_step = 0
	active_tutorial_steps = steps.duplicate(true) if not steps.is_empty() else START_TUTORIAL.duplicate(true)
	tutorial_overlay = Control.new()
	tutorial_overlay.name = "TutorialOverlay"
	tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.z_index = 50
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_layer.add_child(tutorial_overlay)
	tutorial_overlay.draw.connect(_draw_tutorial_overlay)
	var skip: Button = _make_button(tutorial_overlay, _t("skip"), _finish_tutorial, Vector2(144.0, 64.0), "secondary")
	skip.name = "TutorialSkip"
	skip.set_meta("bb_action", "tutorial_skip")
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -170.0
	skip.offset_right = -24.0
	skip.offset_top = 22.0
	skip.offset_bottom = 86.0
	tutorial_target = screen_body.find_child(str(active_tutorial_steps[0].get("target", "PlayArea")), true, false) as Control if screen_body != null else null
	if tutorial_target == null and settings_panel != null:
		tutorial_target = settings_panel
	if tutorial_target == null:
		tutorial_target = Control.new()
		tutorial_target.name = "TutorialPracticeTarget"
		tutorial_target.anchor_left = 0.18
		tutorial_target.anchor_right = 0.82
		tutorial_target.anchor_top = 0.2
		tutorial_target.anchor_bottom = 0.76
		content_layer.add_child(tutorial_target)
	var card: PanelContainer = _make_panel()
	card.name = "TutorialTextCard"
	var card_width: float = minf(620.0, get_viewport_rect().size.x - 280.0)
	card.custom_minimum_size = Vector2(card_width, 120.0)
	card.anchor_left = 0.0
	card.anchor_right = 0.0
	card.anchor_top = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = 70.0
	card.offset_right = 70.0 + card_width
	card.offset_top = 8.0
	card.offset_bottom = 128.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_overlay.add_child(card)
	var pad: MarginContainer = MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	card.add_child(pad)
	var step: Label = _make_label(pad, str(active_tutorial_steps[0].get("message", "tutorial_action_aim")), 30, "text")
	step.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step.name = "TutorialStep"
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hand: Label = _make_label(tutorial_overlay, "tutorial_hand", 54, "accent")
	hand.name = "TutorialHand"
	hand.text = "👆"
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_hand_base_y = hand.position.y
	tutorial_overlay.queue_redraw()

func _tutorial_target_rect() -> Rect2:
	if current_level_number <= 2 and gameplay != null and not active_tutorial_steps.is_empty() and str(active_tutorial_steps[tutorial_step].get("action", "")) == "drag":
		var hazel_pos: Vector2 = _tutorial_canvas_local(gameplay.gameplay_screen_origin())
		return Rect2(hazel_pos - Vector2(62.0, 62.0), Vector2(124.0, 124.0))
	if tutorial_target == null or not is_instance_valid(tutorial_target):
		return Rect2()
	var global: Rect2 = tutorial_target.get_global_rect()
	return Rect2(global.position - tutorial_overlay.global_position, global.size)

func _draw_tutorial_overlay() -> void:
	if tutorial_overlay == null or not is_instance_valid(tutorial_overlay):
		return
	var w: float = tutorial_overlay.size.x
	var h: float = tutorial_overlay.size.y
	var target: Rect2 = _tutorial_play_area_rect()
	var dim: Color = Color(palette["overlay"], 0.78)
	tutorial_overlay.draw_rect(Rect2(0, 0, w, target.position.y), dim, true)
	tutorial_overlay.draw_rect(Rect2(0, target.end.y, w, h - target.end.y), dim, true)
	tutorial_overlay.draw_rect(Rect2(0, target.position.y, target.position.x, target.size.y), dim, true)
	tutorial_overlay.draw_rect(Rect2(target.end.x, target.position.y, w - target.end.x, target.size.y), dim, true)

func _tutorial_play_area_rect() -> Rect2:
	var area: Control = screen_body.find_child("PlayArea", true, false) as Control if screen_body != null else null
	if area == null or tutorial_overlay == null:
		return Rect2()
	var global: Rect2 = area.get_global_rect()
	return Rect2(global.position - tutorial_overlay.global_position, global.size)

func _tutorial_canvas_local(point: Vector2) -> Vector2:
	return tutorial_overlay.get_global_transform_with_canvas().affine_inverse() * point

func _on_tutorial_input(event: InputEvent) -> void:
	var tutorial_action: String = str(active_tutorial_steps[tutorial_step].get("action", "drag")) if not active_tutorial_steps.is_empty() else "drag"
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		var target: Rect2 = _tutorial_target_rect().grow(14.0)
		if mouse.pressed and target.has_point(mouse.position):
			tutorial_drag_active = true
			tutorial_drag_start = mouse.position
			if tutorial_action.begins_with("tutorial_"):
				_perform_tutorial_action(tutorial_action)
				if tutorial_overlay != null: _advance_tutorial()
		elif not mouse.pressed and tutorial_drag_active:
			var dragged: float = mouse.position.distance_to(tutorial_drag_start)
			tutorial_drag_active = false
			if Rect2(Vector2.ZERO, tutorial_overlay.size).has_point(mouse.position) and dragged > 24.0 and tutorial_action == "drag" and gameplay != null and gameplay.tutorial_drag_is_real(tutorial_drag_start, mouse.position):
				if gameplay != null:
					gameplay.fire(tutorial_drag_start - mouse.position)
				if tutorial_overlay != null: _advance_tutorial()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var target: Rect2 = _tutorial_target_rect().grow(14.0)
		if touch.pressed and target.has_point(touch.position):
			tutorial_drag_active = true
			tutorial_drag_start = touch.position
			if tutorial_action.begins_with("tutorial_"):
				_perform_tutorial_action(tutorial_action)
				if tutorial_overlay != null: _advance_tutorial()
		elif not touch.pressed and tutorial_drag_active:
			tutorial_drag_active = false
			if Rect2(Vector2.ZERO, tutorial_overlay.size).has_point(touch.position) and touch.position.distance_to(tutorial_drag_start) > 24.0 and tutorial_action == "drag" and gameplay != null and gameplay.tutorial_drag_is_real(tutorial_drag_start, touch.position):
				if gameplay != null:
					gameplay.fire(tutorial_drag_start - touch.position)
				if tutorial_overlay != null: _advance_tutorial()
	if tutorial_overlay != null:
		tutorial_overlay.accept_event()

func _advance_tutorial() -> void:
	tutorial_step += 1
	if tutorial_step >= active_tutorial_steps.size():
		_finish_tutorial()
		return
	var step: Dictionary = active_tutorial_steps[tutorial_step]
	var label: Label = tutorial_overlay.find_child("TutorialStep", true, false) as Label
	if label != null:
		label.text = _t(str(step.get("message", "tutorial_action_aim")))
	tutorial_target = find_child(str(step.get("target", "PlayArea")), true, false) as Control
	if tutorial_target == null:
		tutorial_target = settings_panel
	tutorial_overlay.queue_redraw()

func _finish_tutorial() -> void:
	if not tutorial_replay:
		var seen: Array = SaveSystem.data.get("tutorial_levels_seen", [])
		if not seen.has(current_level_number): seen.append(current_level_number)
		SaveSystem.data["tutorial_levels_seen"] = seen
		SaveSystem.data["tutorial_seen"] = not seen.is_empty()
		SaveSystem.save()
	if tutorial_overlay != null:
		tutorial_overlay.queue_free()
	tutorial_overlay = null
	tutorial_target = null
	tutorial_drag_active = false
	active_tutorial_steps.clear()

func _use_hint() -> void:
	if tutorial_overlay != null:
		if _tutorial_waiting_for("tutorial_hint") and gameplay != null:
			gameplay.show_hint()
			_advance_tutorial()
		return
	if gameplay == null or gameplay.state != "aiming":
		return
	if not SaveSystem.spend_hint():
		_open_hint_sheet()
		return
	hints_left = int(SaveSystem.data.get("hints_left", 0))
	_update_hint_button()
	gameplay.show_hint()

func _update_hint_button() -> void:
	var button: Button = find_child("HintButton", true, false) as Button
	if button == null:
		return
	button.text = _t("hint_count", {"number": int(SaveSystem.data.get("hints_left", 0)) + int(SaveSystem.data.get("bonus_hints", 0))})
	var plus: Label = button.get_node_or_null("HintBonusMark") as Label
	if plus != null:
		plus.visible = int(SaveSystem.data.get("hints_left", 0)) + int(SaveSystem.data.get("bonus_hints", 0)) == 0

func _open_hint_sheet() -> void:
	if hint_sheet != null:
		return
	hint_sheet = Control.new()
	hint_sheet.name = "NoHintsSheet"
	hint_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_sheet.z_index = 80
	add_child(hint_sheet)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(palette["overlay"], 0.7)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_hint_sheet()
	)
	hint_sheet.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_sheet.add_child(center)
	var panel: PanelContainer = _make_panel()
	panel.custom_minimum_size = Vector2(minf(600.0, get_viewport_rect().size.x * 0.9), 340.0)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	_make_label(box, "no_hints_left", 34, "text")
	var status: Label = _make_label(box, "", 20, "danger")
	status.name = "HintAdStatus"
	status.visible = false
	var watch: Button = _make_button(box, _t("watch_hint_ad"), func(): AdManager.show_rewarded(), Vector2(minf(470.0, get_viewport_rect().size.x * 0.78), 76.0), "primary")
	watch.name = "WatchHintAd"
	watch.set_meta("bb_action", "watch_hint_ad")
	watch.disabled = not AdManager.is_rewarded_ready()
	var later: Button = _make_button(box, _t("not_now"), _close_hint_sheet, Vector2(200.0, 68.0), "secondary")
	later.set_meta("bb_action", "hint_not_now")
	_update_banner()

func _close_hint_sheet() -> void:
	if hint_sheet != null:
		hint_sheet.queue_free()
	hint_sheet = null
	_update_banner()

func _on_rewarded_completed() -> void:
	SaveSystem.add_bonus_hint(1)
	_close_hint_sheet()
	_update_hint_button()

func _on_rewarded_failed() -> void:
	if hint_sheet == null:
		return
	var status: Label = hint_sheet.find_child("HintAdStatus", true, false) as Label
	if status != null:
		status.text = _t("no_ad_available")
		status.visible = true

func _undo_shot() -> void:
	if gameplay != null:
		gameplay.undo()
		shots_used = gameplay.shots_used
	_update_shots_label()
	if game_overlay != null:
		game_overlay.queue_free()
		game_overlay = null
	if _tutorial_waiting_for("tutorial_undo"):
		_advance_tutorial()

func _tutorial_waiting_for(action: String) -> bool:
	return tutorial_overlay != null and not active_tutorial_steps.is_empty() and tutorial_step < active_tutorial_steps.size() and str(active_tutorial_steps[tutorial_step].get("action", "")) == action

func _tutorial_was_seen(level: int) -> bool:
	return SaveSystem.data.get("tutorial_levels_seen", []).has(level)

func _tutorial_steps(level: int) -> Array[Dictionary]:
	match level:
		1: return [{"target": "PlayArea", "message": "tutorial_action_aim", "action": "drag"}]
		2: return [{"target": "PlayArea", "message": "tutorial_bounce", "action": "drag"}]
		3: return [
			{"target": "UndoButton", "message": "tutorial_undo", "action": "tutorial_undo"},
			{"target": "HintButton", "message": "tutorial_hint", "action": "tutorial_hint"}
		]
	return []

func _perform_tutorial_action(action: String) -> void:
	if action == "tutorial_undo" and gameplay != null:
		gameplay.undo()
	elif action == "tutorial_hint" and gameplay != null:
		gameplay.show_hint()
		AudioManager.play_ui("ui_click")

func _update_shots_label() -> void:
	var label: Label = find_child("ShotsUsed", true, false) as Label
	if label != null:
		label.text = _t("shots_used", {"number": shots_used})

func _show_level_select_and_clear_tutorial() -> void:
	if tutorial_overlay != null:
		tutorial_overlay.queue_free()
		tutorial_overlay = null
	_show_level_select()

func _open_level(number: int) -> void:
	var index: int = maxi(0, number - 1)
	if not _is_level_open(chapter_data, index):
		return
	_show_game(number)

func _game_back() -> void:
	if _return_to_menu_after_level:
		_return_to_menu_after_level = false
		_show_menu()
	else:
		_show_level_select()

func _ignore_locked_level() -> void:
	return

func _ignore_locked_chapter() -> void:
	return

func _chapter_is_open(index: int) -> bool:
	if index <= 0:
		return true
	var previous_entry: Dictionary = LevelRegistry.chapters[index - 1]
	var previous: Dictionary = LevelRegistry.load_chapter(str(previous_entry.get("id", "")))
	var previous_levels: Array = previous.get("levels", [])
	if previous_levels.size() != 20:
		return false
	for level_value: Variant in previous_levels:
		if not level_value is Dictionary or SaveSystem.get_level(str(level_value.get("id", ""))).is_empty():
			return false
	return true

func _is_level_open(chapter: Dictionary, index: int) -> bool:
	if index <= 0:
		return _chapter_is_open(chapter_index)
	var levels: Array = chapter.get("levels", [])
	if index - 1 >= levels.size():
		return false
	var previous: Dictionary = levels[index - 1]
	return SaveSystem.get_level(str(previous.get("id", ""))).size() > 0

func _find_next_playable(chapter: Dictionary) -> int:
	var levels: Array = chapter.get("levels", [])
	for index: int in mini(20, levels.size()):
		if _is_level_open(chapter, index) and SaveSystem.get_level(str((levels[index] as Dictionary).get("id", ""))).is_empty():
			return index + 1
	return 0

func _level_metadata(number: int) -> Dictionary:
	var levels: Array = chapter_data.get("levels", [])
	var index: int = number - 1
	return levels[index] if index >= 0 and index < levels.size() and levels[index] is Dictionary else {}

func _chapter_name_key(entry: Dictionary) -> String:
	return str(entry.get("name_key", "chapter_name_generic"))

func _handle_swipe(delta_x: float) -> void:
	if absf(delta_x) < 70.0:
		return
	_change_chapter(-1 if delta_x > 0.0 else 1)

func _input(event: InputEvent) -> void:
	if info_layer != null and info_panel != null:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and not info_panel.get_global_rect().has_point((event as InputEventScreenTouch).position):
			_close_info_sheet()
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not info_panel.get_global_rect().has_point((event as InputEventMouseButton).position):
			_close_info_sheet()
			return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_pointer_start = touch.position
			_pointer_down = true
			_touching_sheet = settings_layer != null and touch.position.y >= settings_panel.get_global_rect().position.y
		elif _pointer_down:
			var delta: Vector2 = touch.position - _pointer_start
			if settings_layer != null and _touching_sheet and delta.y > 90.0:
				_close_settings()
			elif screen == "levels" and settings_layer == null:
				_handle_swipe(delta.x)
			_pointer_down = false
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed:
			_pointer_start = mouse.position
			_pointer_down = true
			_touching_sheet = settings_layer != null and settings_panel.get_global_rect().has_point(mouse.position)
		elif _pointer_down:
			var delta: Vector2 = mouse.position - _pointer_start
			if settings_layer != null and _touching_sheet and delta.y > 90.0:
				_close_settings()
			elif screen == "levels" and settings_layer == null:
				_handle_swipe(delta.x)
			_pointer_down = false
	elif event is InputEventMouseMotion and _pointer_down and screen == "levels" and settings_layer == null:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT != 0 and absf(motion.position.x - _pointer_start.x) > 70.0:
			_handle_swipe(motion.position.x - _pointer_start.x)
			_pointer_down = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F1 and OS.is_debug_build():
		_toggle_physics_panel()
		return
	if screen != "levels" or settings_layer != null:
		return
	if key.keycode == KEY_LEFT:
		_change_chapter(-1)
	elif key.keycode == KEY_RIGHT:
		_change_chapter(1)

func _set_physics_gravity() -> void:
	ProjectSettings.set_setting("physics/2d/default_gravity", game_tuning.gravity)
	if gameplay != null:
		gameplay.tuning.gravity = game_tuning.gravity
		for body in gameplay.crates:
			if is_instance_valid(body): body.gravity_scale = game_tuning.gravity / game_tuning.default_gravity

func _toggle_physics_panel() -> void:
	if physics_panel != null:
		physics_panel.queue_free()
		physics_panel = null
		return
	physics_panel = _make_panel()
	physics_panel.name = "PhysicsTuningPanel"
	physics_panel.z_index = 110
	physics_panel.anchor_left = 0.0
	physics_panel.anchor_right = 0.0
	physics_panel.anchor_top = 0.0
	physics_panel.anchor_bottom = 0.0
	physics_panel.position = Vector2(18, 18)
	physics_panel.custom_minimum_size = Vector2(minf(520, size.x * 0.88), 500)
	content_layer.add_child(physics_panel)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	physics_panel.add_child(list)
	_make_label(list, "physics_tuning", 24, "text")
	_add_tuning_slider(list, "tune_gravity", "gravity", 0, 1600, 25)
	var print_button: Button = _make_button(list, _t("print_values"), _print_physics_values, Vector2(240, 48), "secondary")
	print_button.name = "PrintPhysicsValues"

func _add_tuning_slider(parent: Control, title: String, property: String, low: float, high: float, step: float) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	var value: float = float(game_tuning.get(property))
	var label: Label = _make_label(row, title, 16, "text")
	label.name = "Tune_" + property
	label.text = _t(title) + ": " + str(snappedf(value, step))
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(430, 28)
	slider.value_changed.connect(func(next_value: float):
		game_tuning.set(property, next_value)
		label.text = _t(title) + ": " + str(snappedf(next_value, step))
		if gameplay != null: gameplay.tuning.set(property, next_value)
		if property == "gravity": _set_physics_gravity()
	)
	row.add_child(slider)

func _print_physics_values() -> void:
	print("Physics tuning: gravity=%.2f" % game_tuning.gravity)

func _on_theme_changed(_mode: int) -> void:
	_refresh_palette()

func _make_label(parent: Node, key: String, size: int, token: String, args: Dictionary = {}) -> Label:
	var label: Label = Label.new()
	label.text = _t(key, args)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(palette[token]))
	label.set_meta("bb_token", token)
	parent.add_child(label)
	return label

func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	return panel

func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(palette["surface"])
	style.border_color = Color(palette["outline"])
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	return style

func _make_button(parent: Node, text: String, action: Callable, minimum: Vector2 = Vector2(180.0, 72.0), style_name: String = "secondary") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = minimum
	button.add_theme_font_size_override("font_size", 27)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if minimum.x > 0.0 else Control.SIZE_EXPAND_FILL
	button.set_meta("bb_style", style_name)
	_style_button(button, style_name)
	button.mouse_entered.connect(func(): AudioManager.play_ui("ui_hover"))
	button.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		if action.is_valid():
			action.call()
	)
	parent.add_child(button)
	return button

func _style_button(button: Button, style_name: String) -> void:
	var fill: String = str(palette["surface_alt"])
	var border: String = str(palette["outline"])
	var text_color: String = str(palette["text"])
	match style_name:
		"primary":
			fill = str(palette["primary"])
			border = str(palette["outline"])
			text_color = "#FFFFFF" if ThemeManager._effective_light() else str(palette["text"])
		"highlight", "theme_active", "switch_on", "dot_active":
			fill = str(palette["primary"])
			border = str(palette["accent"])
			text_color = "#FFFFFF"
		"completed":
			fill = str(palette["surface_alt"])
			border = str(palette["success"])
		"danger":
			fill = str(palette["danger"])
			border = str(palette["outline"])
			text_color = "#FFFFFF"
		"switch_off":
			fill = str(palette["surface_alt"])
			border = str(palette["text_muted"])
		"dot":
			fill = str(palette["surface"])
			border = str(palette["surface_alt"])
	var normal: StyleBoxFlat = _button_style(fill, border, false)
	var hover: StyleBoxFlat = _button_style(str(palette["surface_alt"]), str(palette["accent"]), false)
	var pressed: StyleBoxFlat = _button_style(str(palette["primary"]), str(palette["accent"]), true)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(text_color))
	button.add_theme_color_override("font_hover_color", Color(palette["accent"]))
	button.add_theme_color_override("font_pressed_color", Color(palette["text"]))
	button.add_theme_color_override("font_disabled_color", Color(palette["text_muted"]))

func _button_style(fill: String, border: String, pressed: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(border)
	style.set_border_width_all(3)
	style.border_width_bottom = 2 if pressed else 5
	style.set_corner_radius_all(18)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style

func _t(key: String, args: Dictionary = {}) -> String:
	return Strings.text(key, args)
