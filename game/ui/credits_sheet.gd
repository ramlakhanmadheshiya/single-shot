extends Overlay
## Who made what.

const LINES: Array = [
	["Game design & development", "Ramlakhan Madheshiya"],
	["Built with", "Claude (Anthropic) — code, levels, art, music & sound"],
	["Engine", "Godot Engine 4.7 (MIT)"],
	["Typeface", "Outfit — SIL Open Font License"],
	["Icons", "Lucide — ISC License"],
	["Ads & purchases", "Poing AdMob plugin · Godot Google Play Billing (MIT)"],
]


func build() -> void:
	name = "Credits"
	add_title("Credits")
	var body: VBoxContainer = card_body()
	body.add_theme_constant_override("separation", 4)
	for line: Array in LINES:
		body.add_child(UIKit.label(str(line[0]), 20, pal["muted"], 500))
		var v: Label = UIKit.label(str(line[1]), 26, pal["ink"], 500)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(v)
		add_gap(10)
	body.add_child(UIKit.label("Thank you for playing ♥", 22, pal["accent"], 600))
