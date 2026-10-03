extends Control
## Settings as a centered card over a soft shade. Tap outside to close.

var app: Node
var pal: Dictionary
var _confirm_reset: bool = false
var _reset_btn: Button
var _first: Control


func _ready() -> void:
	name = "Settings"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(pal["bottom"], 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			app.close_settings()
	)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = (pal["top"] as Color).lightened(0.06 if pal.get("dark", false) else 0.4)
	sb.set_corner_radius_all(44)
	sb.corner_detail = 12
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 36
	sb.content_margin_bottom = 36
	sb.shadow_color = Color(0, 0, 0, 0.14)
	sb.shadow_size = 30
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	var title: Label = UIKit.label("Settings", 40, pal["ink"], 600, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close: Button = UIKit.icon_button("x", pal, 64.0)
	close.name = "Close"
	close.pressed.connect(func() -> void: app.close_settings())
	head.add_child(close)
	col.add_child(head)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	col.add_child(gap)
	var first: Control = null
	for item: Array in [["Music", "music_volume", 0.5], ["Sound", "sound_volume", 0.75]]:
		var vkey: String = item[1]
		var vrow: Control = UIKit.slider_row(item[0], float(SaveSystem.get_setting(vkey, item[2])), pal, func(v: float) -> void: SaveSystem.set_setting(vkey, v))
		vrow.name = "Row_" + vkey
		col.add_child(vrow)
		if first == null:
			first = vrow.get_child(1)
	for item: Array in [["Vibration", "haptics"], ["Screen shake", "shake"], ["Longer aim guide", "long_guide"]]:
		var key: String = item[1]
		var row: HBoxContainer = UIKit.toggle_row(item[0], bool(SaveSystem.get_setting(key, true)), pal, func(on: bool) -> void: SaveSystem.set_setting(key, on))
		row.name = "Row_" + key
		col.add_child(row)
		if first == null:
			first = row.get_child(1)
	var gap2: Control = Control.new()
	gap2.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap2)
	_reset_btn = UIKit.pill("Reset progress", pal, "ghost", Vector2(0, 72), 24)
	_reset_btn.name = "Reset"
	_reset_btn.pressed.connect(_on_reset)
	col.add_child(_reset_btn)
	var credits: Label = UIKit.label("Outfit font (SIL OFL)  ·  Lucide icons (ISC)\nMusic & sound synthesised for Carom", 18, pal["muted"], 400)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(credits)
	card.pivot_offset = Vector2(280, 300)
	card.scale = Vector2(0.92, 0.92)
	modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(card, "scale", Vector2.ONE, 0.35)
	_first = first


func focus_default() -> void:
	if _first != null:
		_first.grab_focus()


func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_btn.text = "Tap again to erase all stars"
		return
	SaveSystem.reset_progress()
	app.close_settings()
	app.open_home()
