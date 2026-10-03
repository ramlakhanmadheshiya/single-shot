extends Overlay
## What the game is, its version, and where to find it.

const SITE: String = "theramlakhan.com/one-clean-shot"


func build() -> void:
	name = "About"
	add_title("About")
	var body: VBoxContainer = card_body()
	body.add_theme_constant_override("separation", 10)
	body.add_child(UIKit.label("One Clean Shot", 36, pal["ink"], 500))
	body.add_child(UIKit.label("Version %s" % str(ProjectSettings.get_setting("application/config/version", "1.0.0")), 20, pal["muted"], 500))
	add_gap(6)
	var blurb: Label = UIKit.label("A quiet ricochet puzzle. Read the room, find the angle, and clear it with one clean shot. 320 rooms across 8 chapters, every one proven solvable.", 24, pal["ink"], 400)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(blurb)
	add_gap(6)
	body.add_child(UIKit.label("Made by Ramlakhan Madheshiya", 22, pal["muted"], 500))
	var site: Button = UIKit.pill(SITE, pal, "soft", Vector2(0, 68), 20)
	site.name = "Website"
	site.pressed.connect(func() -> void: OS.shell_open("https://" + SITE + "/"))
	body.add_child(site)
	var privacy: Label = UIKit.label("Progress is saved only on this device. Ads (Android) are served by Google AdMob.", 18, pal["muted"], 400)
	privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(privacy)
	_first_focus = site
