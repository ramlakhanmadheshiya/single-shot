extends Overlay
## Settings. "Reset progress" is hidden while a level is being played so stars
## can't be wiped by accident mid-game.

var in_game: bool = false
var _confirm_reset: bool = false
var _reset_btn: Button


func build() -> void:
	name = "Settings"
	add_title("Settings")
	var body: VBoxContainer = card_body()
	for item: Array in [["Music", "music_volume", 0.5], ["Sound", "sound_volume", 0.75]]:
		var key: String = item[1]
		var row: Control = UIKit.slider_row(item[0], float(SaveSystem.get_setting(key, item[2])), pal, func(v: float) -> void: SaveSystem.set_setting(key, v))
		row.name = "Row_" + key
		body.add_child(row)
		if _first_focus == null:
			_first_focus = row.get_child(1)
	for item: Array in [["Vibration", "haptics"], ["Screen shake", "shake"], ["Longer aim guide", "long_guide"]]:
		var tkey: String = item[1]
		var trow: HBoxContainer = UIKit.toggle_row(item[0], bool(SaveSystem.get_setting(tkey, tkey != "long_guide")), pal, func(on: bool) -> void: SaveSystem.set_setting(tkey, on))
		trow.name = "Row_" + tkey
		body.add_child(trow)
	add_gap(16)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	body.add_child(buttons)
	var credits: Button = UIKit.pill("Credits", pal, "soft", Vector2(0, 72), 24)
	credits.name = "Credits"
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.pressed.connect(func() -> void: app.open_credits())
	buttons.add_child(credits)
	var provider: Node = AdManager.provider
	if provider != null and provider.has_method("privacy_options_required") and provider.privacy_options_required():
		var privacy: Button = UIKit.pill("Privacy", pal, "soft", Vector2(0, 72), 24)
		privacy.name = "Privacy"
		privacy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		privacy.pressed.connect(func() -> void: provider.show_privacy_options())
		buttons.add_child(privacy)
	if not in_game:
		add_gap(4)
		_reset_btn = UIKit.pill("Reset progress", pal, "ghost", Vector2(0, 72), 24)
		_reset_btn.name = "Reset"
		_reset_btn.pressed.connect(_on_reset)
		body.add_child(_reset_btn)


func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_btn.text = "Tap again to erase all stars"
		return
	SaveSystem.reset_progress()
	app.close_settings()
	app.open_home()
