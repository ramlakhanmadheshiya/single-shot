extends Node
## Fake banner and rewarded placements. No network or ad SDK is used.
signal rewarded_completed
signal rewarded_failed

var next_result: String = "completed"
var test_delay_seconds: float = -1.0
var _ad_layer: CanvasLayer

func is_rewarded_ready() -> bool:
	return true

func create_banner(parent: Control, label_text: String, surface: Color, border: Color, ink: Color) -> PanelContainer:
	var strip: PanelContainer = PanelContainer.new()
	strip.name = "MockBanner"
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top = -70.0
	strip.offset_bottom = 0.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.z_index = 20
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = surface
	style.border_color = border
	style.set_border_width_all(2)
	strip.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = label_text
	label.name = "BannerLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ink)
	label.add_theme_font_size_override("font_size", 20)
	strip.add_child(label)
	parent.add_child(strip)
	return strip

func show_rewarded() -> void:
	if _ad_layer != null:
		return
	_ad_layer = CanvasLayer.new()
	_ad_layer.name = "MockRewardedAd"
	_ad_layer.layer = 100
	get_tree().root.add_child(_ad_layer)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ad_layer.add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.07, 0.88)
	root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 300)
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color("#211A33")
	card_style.border_color = Color("#F2EEFF")
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(24)
	card_style.content_margin_left = 28.0
	card_style.content_margin_right = 28.0
	card_style.content_margin_top = 24.0
	card_style.content_margin_bottom = 24.0
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	card.add_child(box)
	var message: Label = Label.new()
	message.text = "Playing a short ad…"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 34)
	message.add_theme_color_override("font_color", Color("#F2EEFF"))
	box.add_child(message)
	var close: Button = Button.new()
	close.name = "MockAdClose"
	close.text = "Close"
	close.custom_minimum_size = Vector2(180, 72)
	close.add_theme_font_size_override("font_size", 25)
	close.visible = false
	close.pressed.connect(_finish_ad)
	box.add_child(close)
	var delay: float = 3.0 if test_delay_seconds < 0.0 else test_delay_seconds
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(close):
		if next_result == "completed":
			close.visible = true
		else:
			_finish_ad()

func fail_for_test() -> void:
	next_result = "failed"

func _finish_ad() -> void:
	var result: String = next_result
	next_result = "completed"
	if _ad_layer != null:
		_ad_layer.queue_free()
	_ad_layer = null
	if result == "completed":
		rewarded_completed.emit()
	else:
		rewarded_failed.emit()
