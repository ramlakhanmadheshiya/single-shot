extends Node
## Creates 30 temporary chapter files and checks lazy page construction.
const MAIN_SCENE: PackedScene = preload("res://game/scenes/main_menu.tscn")
const DUMMY_DIR: String = "user://boneyard_dummy_registry"
var app: Control
var saved_chapters: Array[Dictionary]
var saved_data: Dictionary

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	saved_chapters = LevelRegistry.chapters.duplicate(true)
	saved_data = SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem._default_data()
	SaveSystem.save()
	var dummy: Array[Dictionary] = []
	for chapter_number: int in 30:
		var chapter_id: String = "dummy_%02d" % (chapter_number + 1)
		var chapter_path: String = DUMMY_DIR.path_join(chapter_id)
		var levels: Array[Dictionary] = []
		for number: int in 20:
			levels.append({"id": "%s_l%03d" % [chapter_id, number + 1], "number": number + 1, "par_3": 2, "par_2": 3, "ammo": ["silver"]})
		var chapter: Dictionary = {"id": chapter_id, "name_key": "chapter_name_generic", "level_count": 20, "levels": levels}
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(chapter_path))
		var file: FileAccess = FileAccess.open(chapter_path.path_join("chapter.json"), FileAccess.WRITE)
		_expect(file != null, "dummy chapter file opens")
		if file != null:
			file.store_string(JSON.stringify(chapter))
		dummy.append({"id": chapter_id, "path": chapter_path, "name_key": "chapter_name_generic", "level_count": 20})
	LevelRegistry.chapters = dummy
	LevelRegistry.chapter_cache.clear()
	var progress: Dictionary = {}
	for chapter_number: int in 29:
		var chapter_id: String = "dummy_%02d" % (chapter_number + 1)
		for number: int in 20:
			progress["%s_l%03d" % [chapter_id, number + 1]] = {"stars": 1}
	SaveSystem.data["levels"] = progress
	SaveSystem.save()
	LevelRegistry.metadata_load_count = 0
	_expect(LevelRegistry.total_level_count() == 600, "dummy registry contains six hundred levels")
	app = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(app)
	var build_start: int = Time.get_ticks_msec()
	app._show_level_select()
	await get_tree().process_frame
	var first_page_ms: int = Time.get_ticks_msec() - build_start
	_expect(_tiles().size() == 20, "only twenty tiles exist on the shown page")
	_expect(app.page_dots.size() == 5, "thirty chapters show only five dots")
	_expect(app.page_indicator.text == "1 / 30", "first page number is shown")
	app._handle_swipe(-180.0)
	await get_tree().process_frame
	_expect(app.page_indicator.text == "2 / 30", "swiping updates the page number")
	_expect(LevelRegistry.last_loaded_chapter_id == "dummy_02", "only the visible chapter metadata loads")
	_expect(LevelRegistry.metadata_load_count <= 3, "picker loads only the pages visited")
	app.page_indicator.pressed.emit()
	await get_tree().process_frame
	_expect(app.jump_input != null, "tapping page count opens chapter jump")
	if app.jump_input != null:
		app.jump_input.value = 30
	var go: Button = app.find_child("JumpGo", true, false) as Button
	_expect(go != null, "chapter jump has a Go button")
	if go != null:
		go.pressed.emit()
	await get_tree().process_frame
	_expect(app.chapter_index == 29, "chapter jump opens page thirty")
	_expect(app.page_indicator.text == "30 / 30", "last page count is correct")
	_expect(app.page_dots.size() == 5, "last page also shows only five dots")
	_expect(_tiles().size() == 20, "last page still builds twenty buttons")
	_expect(first_page_ms < 1000, "first page builds quickly")
	_expect(_grid_fits_width(720.0, 1280.0), "four columns fit a phone-shaped view")
	_expect(_grid_fits_width(1280.0, 720.0), "four columns fit a small wide view")
	_expect(_grid_fits_width(1920.0, 1080.0), "four columns fit a full HD view")
	if DisplayServer.get_name() != "headless":
		for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(720, 1280), Vector2i(2560, 1440)]:
			DisplayServer.window_set_size(window_size)
			await get_tree().create_timer(0.15).timeout
			await get_tree().process_frame
			var grid: Control = app.find_child("LevelGrid", true, false) as Control
			_expect(grid != null, "Level grid remains after window resize")
			if grid != null:
				var rect: Rect2 = grid.get_global_rect()
				var view: Vector2 = app.get_viewport_rect().size
				_expect(rect.position.x >= -3.0 and rect.end.x <= view.x + 3.0, "Level grid stays inside resized window")
			var image: Image = get_viewport().get_texture().get_image()
			image.save_png("/tmp/bb_levels_%d.png" % window_size.x)

	LevelRegistry.chapters = saved_chapters
	LevelRegistry.chapter_cache.clear()
	SaveSystem.data = saved_data
	SaveSystem.save()
	for chapter_number: int in 30:
		var chapter_id: String = "dummy_%02d" % (chapter_number + 1)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DUMMY_DIR.path_join(chapter_id).path_join("chapter.json")))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DUMMY_DIR.path_join(chapter_id)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DUMMY_DIR))
	AudioManager.music_player.stop()
	AudioManager.music_player.stream = null
	AudioManager.ui_player.stop()
	AudioManager.ui_player.stream = null
	await get_tree().create_timer(0.2).timeout
	print("PASS: 30 chapters, 600 levels, five-dot paging and lazy page loading (%d ms)" % first_page_ms)
	get_tree().quit(0)

func _grid_fits_width(width: float, height: float) -> bool:
	var tile_size: Vector2 = app._tile_dimensions(width, height)
	var grid_width: float = tile_size.x * 4.0 + 14.0 * 3.0
	return grid_width <= width - 68.0

func _tiles() -> Array[Node]:
	return app.find_children("LevelTile_*", "Button", true, false)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error("Level select scale test failed: " + message)
		get_tree().quit(1)
