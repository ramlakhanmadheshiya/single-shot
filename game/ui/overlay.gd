class_name Overlay
extends Control
## A centred card over a soft shade. Tapping the shade closes it.
## Subclasses fill `card_body()` in `build()`.

var app: Node
var pal: Dictionary
var _body: VBoxContainer
var _card: PanelContainer
var _first_focus: Control


func _ready() -> void:
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
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(580, 0)
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
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_card.add_child(_body)
	build()
	_card.pivot_offset = Vector2(290, 300)
	_card.scale = Vector2(0.92, 0.92)
	modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.35)


## Override to add content to card_body().
func build() -> void:
	pass


func card_body() -> VBoxContainer:
	return _body


## Title row with a close button.
func add_title(text: String) -> void:
	var head: HBoxContainer = HBoxContainer.new()
	var title: Label = UIKit.label(text, 40, pal["ink"], 600, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close: Button = UIKit.icon_button("x", pal, 64.0)
	close.name = "Close"
	close.pressed.connect(func() -> void: app.close_settings())
	head.add_child(close)
	_body.add_child(head)
	add_gap(12)


func add_gap(h: float) -> void:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, h)
	_body.add_child(gap)


func focus_default() -> void:
	if _first_focus != null:
		_first_focus.grab_focus()
