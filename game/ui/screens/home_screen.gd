extends Screen
## Title screen: wordmark, a live attract-mode room, and one obvious Play button.

var _play: Button
var _board: Board


func _ready() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.custom_minimum_size = Vector2(0, 96)
	var shop: Button = UIKit.icon_button("shopping-bag", pal, 72.0)
	shop.name = "Shop"
	shop.pressed.connect(func() -> void: app.open_shop())
	top.add_child(shop)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var settings: Button = UIKit.icon_button("settings", pal, 72.0)
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: app.open_settings(false))
	top.add_child(settings)
	col.add_child(top)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", -6)
	var fv: FontVariation = (UIKit.font(250) as FontVariation).duplicate()
	fv.spacing_glyph = 6
	for word: String in ["one clean", "shot"]:
		var title: Label = UIKit.label(word, 96, pal["ink"], 250)
		title.add_theme_font_override("font", fv)
		title.add_theme_constant_override("line_spacing", -10)
		title_box.add_child(title)
	title_box.add_child(UIKit.label("a quiet ricochet puzzle", 26, pal["muted"], 400))
	col.add_child(title_box)

	_board = Board.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size = Vector2(0, 360)
	_board.demo = true
	_board.quiet = true
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_board)
	var demo_level: Dictionary = Levels.level("ch1", 11)
	if demo_level.is_empty():
		demo_level = Levels.level("ch1", 0)
	_board.setup(demo_level, pal)
	_board.modulate.a = 0.9

	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 18)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.custom_minimum_size = Vector2(0, 260)
	var target: Dictionary = Levels.continue_target()
	var cpal: Dictionary = Palette.get_palette(str(target["chapter"]))
	_play = UIKit.pill("Play", pal, "primary", Vector2(320, 96), 36)
	_play.name = "Play"
	_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play.pressed.connect(func() -> void: app.open_game(str(target["chapter"]), int(target["index"])))
	bottom.add_child(_play)
	var sub: Label = UIKit.label("%s  ·  %d" % [cpal["name"], int(target["index"]) + 1], 24, pal["muted"], 500)
	sub.name = "Continue"
	bottom.add_child(sub)
	var levels: Button = UIKit.pill("Chapters", pal, "ghost", Vector2(240, 72), 26)
	levels.name = "Chapters"
	levels.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	levels.pressed.connect(func() -> void: app.open_chapters())
	bottom.add_child(levels)
	col.add_child(bottom)

	_play.focus_neighbor_bottom = levels.get_path()
	levels.focus_neighbor_top = _play.get_path()
	_play.pivot_offset = _play.custom_minimum_size * 0.5
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(_play, "scale", Vector2(1.035, 1.035), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_play, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play.button_down.connect(func() -> void: tw.kill())


func focus_default() -> void:
	if _play != null:
		_play.grab_focus()
