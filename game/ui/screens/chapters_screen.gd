extends Screen
## A calm vertical list of chapters, each card painted in its own palette.

var _first: Control


func _ready() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	col.add_child(make_header("Chapters", func() -> void: app.open_home()))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)
	var prev: Control = null
	for i: int in Levels.chapters.size():
		var c: Dictionary = Levels.chapters[i]
		var card: Button = _card(c, i)
		list.add_child(card)
		if prev == null:
			_first = card
		else:
			card.focus_neighbor_top = prev.get_path()
			prev.focus_neighbor_bottom = card.get_path()
		prev = card
		card.modulate.a = 0.0
		card.position.y += 30
		var tw: Tween = create_tween()
		tw.tween_interval(0.05 * float(i))
		tw.tween_property(card, "modulate:a", 1.0, 0.3)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	list.add_child(spacer)


func _card(c: Dictionary, index: int) -> Button:
	var id: String = str(c["id"])
	var cp: Dictionary = Palette.get_palette(id)
	var open: bool = Levels.chapter_open(id)
	var b: Button = Button.new()
	b.name = "Chapter_" + id
	b.custom_minimum_size = Vector2(0, 168)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = cp["bottom"]
	sb.set_corner_radius_all(36)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb)
	var focus: StyleBoxFlat = sb.duplicate()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = pal["accent"]
	focus.set_border_width_all(4)
	focus.expand_margin_left = 6
	focus.expand_margin_right = 6
	focus.expand_margin_top = 6
	focus.expand_margin_bottom = 6
	b.add_theme_stylebox_override("focus", focus)
	UIKit.add_press_feel(b)
	var art: Control = _CardArt.new()
	art.pal = cp
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	b.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(UIKit.label("%02d" % (index + 1), 22, cp["muted"], 600, HORIZONTAL_ALIGNMENT_LEFT))
	text.add_child(UIKit.label(str(cp["name"]), 48, cp["ink"], 500, HORIZONTAL_ALIGNMENT_LEFT))
	text.add_child(UIKit.label(str(cp["tagline"]), 22, cp["muted"], 400, HORIZONTAL_ALIGNMENT_LEFT))
	var right: VBoxContainer = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	var total: int = Levels.level_count(id)
	if open:
		right.add_child(UIKit.label("★ %d/%d" % [Levels.stars_in(id), total * 3], 26, cp["ink"], 600, HORIZONTAL_ALIGNMENT_RIGHT))
		right.add_child(UIKit.label("%d/%d cleared" % [Levels.cleared_in(id), total], 20, cp["muted"], 400, HORIZONTAL_ALIGNMENT_RIGHT))
		b.pressed.connect(func() -> void: app.open_levels(id))
	else:
		var lock: TextureRect = TextureRect.new()
		lock.texture = UIKit.icon("lock")
		lock.custom_minimum_size = Vector2(40, 40)
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.modulate = cp["ink"]
		lock.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(lock)
		var prev_name: String = str(Palette.get_palette(str(Levels.chapters[index - 1]["id"]))["name"])
		right.add_child(UIKit.label("Clear %d in %s" % [Levels.CHAPTER_GATE, prev_name], 20, cp["muted"], 500, HORIZONTAL_ALIGNMENT_RIGHT))
		art.modulate.a = 0.5
		b.pressed.connect(func() -> void:
			AudioManager.play_ui("ui_back")
			var tw: Tween = b.create_tween()
			for k: int in 3:
				tw.tween_property(b, "position:x", b.position.x + 10.0, 0.04)
				tw.tween_property(b, "position:x", b.position.x - 10.0, 0.04)
			tw.tween_property(b, "position:x", b.position.x, 0.04)
		)
	return b


func focus_default() -> void:
	if _first != null:
		_first.grab_focus()


func handle_back() -> bool:
	app.open_home()
	return true


## A tiny decorative ricochet path in the chapter's colours.
class _CardArt:
	extends Control
	var pal: Dictionary

	func _draw() -> void:
		var top: Color = pal["top"]
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(36)
		sb.corner_detail = 12
		sb.anti_aliasing = true
		sb.bg_color = top
		draw_style_box(sb, r)
		var pts: PackedVector2Array = PackedVector2Array([Vector2(size.x * 0.40, size.y - 26), Vector2(size.x * 0.48, 26), Vector2(size.x * 0.56, size.y - 34), Vector2(size.x * 0.62, 52)])
		for i: int in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n: int = int(a.distance_to(b) / 16.0)
			for k: int in n:
				draw_circle(a.lerp(b, float(k) / float(n)), 2.4, Color(pal["ink"], 0.18), true, -1.0, true)
		draw_circle(pts[-1], 13.0, Color(pal["target"], 0.85), true, -1.0, true)
		draw_circle(pts[0], 7.0, Color(pal["ink"], 0.4), true, -1.0, true)
