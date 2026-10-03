extends Node
## English player text is kept here for future language packs.
const ENGLISH: Dictionary = {
	"game_title": "BONEYARD\nBOUNCE",
	"tagline": "A spooky game of clever shots",
	"play": "Play",
	"settings_icon": "⚙",
	"arrow_left": "‹",
	"arrow_right": "›",
	"page_dot_on": "●",
	"page_dot_off": "○",
	"theme": "Theme",
	"back": "Back",
	"close": "Close",
	"levels": "Levels",
	"chapter_number": "Chapter {number}",
	"stars_total": "{earned} / {total} stars",
	"chapter_locked": "Finish Chapter {number} to open this.",
	"locked": "Locked",
	"stars_0": "☆☆☆",
	"stars_1": "★☆☆",
	"stars_2": "★★☆",
	"stars_3": "★★★",
	"page_number": "{current} / {total}",
	"jump_to_chapter": "Go to chapter",
	"go": "Go",
	"settings": "Settings",
	"sound": "Sound",
	"music": "Music",
	"vibration": "Vibration",
	"on": "On",
	"off": "Off",
	"auto": "Auto",
	"light": "Light",
	"dark": "Dark",
	"aim_guide": "Aim guide",
	"aim_guide_help": "Shows your first bounce.",
	"screen_shake": "Screen shake",
	"more_sound": "More sound options",
	"music_volume": "Music volume",
	"sound_volume": "Sound volume",
	"ui_volume": "Button sounds",
	"how_to_play": "How to play",
	"credits": "Credits",
	"about": "About",
	"reset_progress": "Reset progress",
	"reset_question": "Are you sure? This deletes all your stars.",
	"cancel": "Cancel",
	"delete": "Delete",
	"reset_done": "Your stars are gone.",
	"version": "Version 0.1.0",
	"credits_text": "Made with Godot.\nArt and sounds were made for this game.",
	"about_text": "Help Hazel clear a spooky old graveyard.\nPlan each shot and save your best moves.",
	"tutorial_title": "Let's learn the basics",
	"tutorial_aim": "Aim at a ghoul. Tap to fire.",
	"tutorial_bounce": "Shots can bounce off the walls.",
	"tutorial_ghouls": "Hit every ghoul to clear the room.",
	"tutorial_tools": "The bulb gives hints. Undo and Restart help.",
	"tap_continue": "Tap to continue",
	"skip": "Skip",
	"level_number": "Level {number}",
	"shots_used": "Shots used: {number}",
	"three_star_goal": "3-star goal: {number}",
	"undo": "Undo",
	"restart": "Restart",
	"hint": "Hint ({number})",
	"hint_line": "Try aiming here.",
	"try_again": "Try again",
	"game_ready": "Aim and fire when you are ready.",
	"chapter_graveyard_gate": "Graveyard Gate",
	"chapter_old_chapel": "Old Chapel",
	"chapter_crypts": "Crypts",
	"chapter_pumpkin_patch": "Pumpkin Patch",
	"chapter_haunted_manor": "Haunted Manor",
	"chapter_name_generic": "Haunted Grounds"
}

var _english: Translation

func _ready() -> void:
	_english = Translation.new()
	_english.locale = "en"
	for key: String in ENGLISH:
		_english.add_message(key, str(ENGLISH[key]))
	TranslationServer.add_translation(_english)
	TranslationServer.set_locale("en")

func text(key: String, args: Dictionary = {}) -> String:
	var translated: String = TranslationServer.translate(key)
	if translated == key:
		translated = str(ENGLISH.get(key, key))
	return translated.format(args)
