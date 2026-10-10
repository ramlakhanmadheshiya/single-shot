extends Overlay
## The tip jar: say thanks, as often as you like. A tip opens nothing new.

var _status: Label


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
	for id: String in Store.TIPS:
		var b: Button = UIKit.pill(Store.price(id), pal, "soft", Vector2(0, 84), 28)
		b.name = "Tip_" + id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_status.text = "Opening Google Play…"
			Store.buy(id)
		)
		grid.add_child(b)
		if _first_focus == null:
			_first_focus = b
	_status = UIKit.label(_thanks(), 20, pal["accent"], 600)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	Store.purchase_finished.connect(func(ok: bool, msg: String, id: String) -> void:
		if not is_inside_tree() or not Store.TIPS.has(id) and not msg.contains("cancel"):
			return
		_status.text = msg if not ok else _thanks()
		if ok:
			AudioManager.play("win", 1.0)
			Haptics.tap(30)
	)


func _thanks() -> String:
	var n: int = SaveSystem.tips_given()
	return "" if n == 0 else "You've tipped %d %s. Thank you ♥" % [n, "time" if n == 1 else "times"]
