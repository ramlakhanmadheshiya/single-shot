extends Screen
## Supporter Pack: a single one-time purchase that removes ads and makes hints free.

var _buy: Button
var _status: Label


func _ready() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	col.add_child(make_header("", func() -> void: app.open_home()))

	var heart: _Heart = _Heart.new()
	heart.pal = pal
	heart.custom_minimum_size = Vector2(0, 170)
	col.add_child(heart)
	col.add_child(UIKit.label("Supporter Pack", 52, pal["ink"], 500))
	var sub: Label = UIKit.label("One Clean Shot is made by one person. Support it once,\nand play it the calm way, forever.", 24, pal["muted"], 400)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)

	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(list)
	for perk: Array in [["ban", "No banner ads"], ["infinity", "Every hint free, always"], ["heart", "Keeps new chapters coming"]]:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var ic: TextureRect = TextureRect.new()
		ic.texture = UIKit.icon(perk[0])
		ic.custom_minimum_size = Vector2(40, 40)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = pal["accent"]
		row.add_child(ic)
		row.add_child(UIKit.label(perk[1], 28, pal["ink"], 500, HORIZONTAL_ALIGNMENT_LEFT))
		list.add_child(row)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	_status = UIKit.label("", 22, pal["muted"], 500)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	_buy = UIKit.pill("", pal, "primary", Vector2(420, 96), 32)
	_buy.name = "Buy"
	_buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buy.pressed.connect(func() -> void:
		_status.text = "Opening Google Play…"
		Store.buy()
	)
	col.add_child(_buy)
	var restore: Button = UIKit.pill("Restore purchase", pal, "ghost", Vector2(320, 72), 24)
	restore.name = "Restore"
	restore.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restore.pressed.connect(func() -> void:
		_status.text = "Checking your purchases…"
		Store.restore()
	)
	col.add_child(restore)
	var bottom: Control = Control.new()
	bottom.custom_minimum_size = Vector2(0, 16)
	col.add_child(bottom)

	Store.purchase_finished.connect(_on_result)
	Store.restore_finished.connect(_on_result)
	Store.price_updated.connect(func(_p: String) -> void: _refresh())
	Events.supporter_changed.connect(func(_on: bool) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	if SaveSystem.is_supporter():
		_buy.text = "You're a supporter  ♥"
		_buy.disabled = true
		if _status.text.is_empty():
			_status.text = "Thank you! Ads are off and hints are free."
	else:
		_buy.text = "Support  ·  %s" % Store.price
		_buy.disabled = false


func _on_result(ok: bool, message: String) -> void:
	_status.text = message
	if ok:
		AudioManager.play("unlock", 1.0)
		Haptics.tap(30)
	_refresh()


func focus_default() -> void:
	_buy.grab_focus()


func handle_back() -> bool:
	app.open_home()
	return true


class _Heart:
	extends Control
	var pal: Dictionary
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var beat: float = 1.0 + 0.06 * maxf(0.0, sin(_t * 4.0)) * maxf(0.0, sin(_t * 1.3))
		var s: float = 120.0 * beat
		var c: Vector2 = size * 0.5
		draw_circle(c, 78.0, Color(pal["accent"], 0.14), true, -1.0, true)
		draw_texture_rect(UIKit.icon("heart-filled"), Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, pal["target"])
