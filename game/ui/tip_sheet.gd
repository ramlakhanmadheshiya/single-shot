extends Overlay
## The tip jar: say thanks, as often as you like. A tip opens nothing new.
## Four quick amounts, or pick your own with minus/plus or the slider. Every
## amount is shown in the player's own currency (Store.price); the rupee amount
## only names the product.

const DEFAULT_TIP: int = 500

var _status: Label
var _price: Label
var _slider: HSlider
var _custom_btn: Button
var _amounts: Array = Store.tip_amounts()


func build() -> void:
	name = "Tips"
	add_title("Tip jar")
	var body: VBoxContainer = card_body()
	body.add_theme_constant_override("separation", 14)
	var sub: Label = UIKit.label("Say thanks, as often as you like. A tip opens nothing new: it all goes into making the next chapter.", 22, pal["muted"], 400)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	for rupees: int in Store.TIP_PRESETS:
		var id: String = "tip_%d" % rupees
		var b: Button = UIKit.pill(Store.price(id), pal, "soft", Vector2(0, 84), 28)
		b.name = "Tip_%d" % rupees
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _tip(rupees))
		grid.add_child(b)
		if _first_focus == null:
			_first_focus = b
	add_gap(4)
	body.add_child(UIKit.caption("Or pick your own", pal, 16, HORIZONTAL_ALIGNMENT_CENTER))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var minus: Button = UIKit.icon_button("minus", pal, 68.0)
	minus.name = "TipMinus"
	minus.pressed.connect(func() -> void: _nudge(-1))
	row.add_child(minus)
	_price = UIKit.label("", 34, pal["ink"], 600)
	_price.name = "TipPrice"
	_price.custom_minimum_size = Vector2(220, 72)
	row.add_child(_price)
	var plus: Button = UIKit.icon_button("plus", pal, 68.0)
	plus.name = "TipPlus"
	plus.pressed.connect(func() -> void: _nudge(1))
	row.add_child(plus)
	_slider = UIKit.slider(pal)
	_slider.name = "TipSlider"
	_slider.min_value = 0.0
	_slider.max_value = float(_amounts.size() - 1)
	_slider.step = 1.0
	_slider.custom_minimum_size = Vector2(0, 48)
	_slider.value = float(maxi(_amounts.find(DEFAULT_TIP), 0))
	_slider.value_changed.connect(func(_v: float) -> void: _refresh_custom())
	body.add_child(_slider)
	_custom_btn = UIKit.pill("", pal, "accent", Vector2(0, 86), 28)
	_custom_btn.name = "TipCustom"
	_custom_btn.pressed.connect(func() -> void: _tip(_custom()))
	body.add_child(_custom_btn)
	_status = UIKit.label(_thanks(), 20, pal["accent"], 600)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	body.add_child(UIKit.refund_note(pal))
	_refresh_custom()
	Store.price_updated.connect(func(_id: String, _p: String) -> void: _refresh_prices())
	Store.purchase_finished.connect(func(ok: bool, msg: String, id: String) -> void:
		if not is_inside_tree() or not (Store.is_tip(id) or id.is_empty()):
			return
		_status.text = msg if not ok else _thanks()
		if ok:
			AudioManager.play("win", 1.0, -9.0)
			Haptics.tap(30)
	)


## The selected amount (in rupees, the product id's unit; never shown as rupees).
func _custom() -> int:
	return int(_amounts[clampi(int(_slider.value), 0, _amounts.size() - 1)])


func _nudge(dir: int) -> void:
	_slider.value = clampf(_slider.value + float(dir), 0.0, _slider.max_value)
	_refresh_custom()


func _refresh_custom() -> void:
	var p: String = Store.price("tip_%d" % _custom())
	_price.text = p
	_custom_btn.text = "Tip %s" % p


## Play's real prices replace the fallbacks as they arrive.
func _refresh_prices() -> void:
	if not is_inside_tree():
		return
	for amount: int in Store.TIP_PRESETS:
		var b: Button = find_child("Tip_%d" % amount, true, false) as Button
		if b != null:
			b.text = Store.price("tip_%d" % amount)
	_refresh_custom()


func _tip(rupees: int) -> void:
	_status.text = "Opening Google Play…"
	Store.buy("tip_%d" % rupees)


func _thanks() -> String:
	var n: int = SaveSystem.tips_given()
	return "" if n == 0 else "You've tipped %d %s. Thank you ♥" % [n, "time" if n == 1 else "times"]
