extends Screen
## 4 x 5 grid of round level tiles for one chapter.

var chapter_id: String = "ch1"
var _focus: Control


func music_track() -> String:
	return chapter_id


func _ready() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	col.add_child(make_header(str(pal["name"]), func() -> void: app.open_chapters()))
	var total: int = Levels.level_count(chapter_id)
	col.add_child(UIKit.label("★ %d / %d" % [Levels.stars_in(chapter_id), total * 3], 24, pal["muted"], 500))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	col.add_child(spacer)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 34)
	center.add_child(grid)
	var next: Dictionary = Levels.continue_target()
	for i: int in total:
		var lv: Dictionary = Levels.level(chapter_id, i)
		var tile: _LevelTile = _LevelTile.new()
		tile.name = "Level_%d" % (i + 1)
		tile.pal = pal
		tile.number = i + 1
		tile.stars = SaveSystem.stars_for(str(lv["id"]))
		tile.open = Levels.level_open(chapter_id, i)
		tile.current = str(next["chapter"]) == chapter_id and int(next["index"]) == i
		var idx: int = i
		tile.pressed.connect(func() -> void:
			if tile.open:
				app.open_game(chapter_id, idx)
			else:
				AudioManager.play_ui("ui_back")
		)
		grid.add_child(tile)
		if tile.current or (_focus == null and tile.open):
			_focus = tile
		tile.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_interval(0.018 * float(i))
		tw.tween_property(tile, "modulate:a", 1.0, 0.25)
	var bottom: Control = Control.new()
	bottom.custom_minimum_size = Vector2(0, 60)
	col.add_child(bottom)


func focus_default() -> void:
	if _focus != null:
		_focus.grab_focus()


func handle_back() -> bool:
	app.open_chapters()
	return true


class _LevelTile:
	extends Button
	var pal: Dictionary
	var number: int = 1
	var stars: int = 0
	var open: bool = false
	var current: bool = false
	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(112, 132)
		focus_mode = Control.FOCUS_ALL
		flat = true
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for key: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(key, empty)

	func _ready() -> void:
		UIKit.add_press_feel(self)

	func _process(delta: float) -> void:
		_t += delta
		if current or has_focus():
			queue_redraw()

	func _draw() -> void:
		var ink: Color = pal["ink"]
		var c: Vector2 = Vector2(size.x * 0.5, 52)
		var r: float = 46.0
		var f: Font = UIKit.font(600)
		if has_focus():
			draw_arc(c, r + 9.0, 0.0, TAU, 48, pal["accent"], 3.0, true)
		if not open:
			draw_circle(c, r, Color(ink, 0.05), true, -1.0, true)
			draw_circle(c, 5.0, Color(ink, 0.25), true, -1.0, true)
			return
		if stars > 0:
			draw_circle(c, r, ink, true, -1.0, true)
			_text(f, str(number), c, 32, pal["top"])
		else:
			draw_circle(c, r, Color(ink, 0.06), true, -1.0, true)
			draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(ink, 0.5), 3.0, true)
			_text(f, str(number), c, 32, ink)
		if current:
			var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
			draw_arc(c, r + 5.0 + 4.0 * pulse, 0.0, TAU, 48, Color(pal["accent"], 0.8 - 0.5 * pulse), 3.0, true)
		for k: int in 3:
			var p: Vector2 = Vector2(c.x + (float(k) - 1.0) * 18.0, c.y + r + 18.0)
			if k < stars:
				draw_circle(p, 5.0, pal["accent"], true, -1.0, true)
			else:
				draw_circle(p, 4.0, Color(ink, 0.14), true, -1.0, true)

	func _text(f: Font, s: String, centre: Vector2, fs: int, col: Color) -> void:
		var w: Vector2 = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var asc: float = f.get_ascent(fs)
		var desc: float = f.get_descent(fs)
		draw_string(f, Vector2(centre.x - w.x * 0.5, centre.y + (asc - desc) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
