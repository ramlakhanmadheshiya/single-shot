extends Node
## Runtime state shared by screens. Content data is loaded on demand.
enum PlayState { INTRO, AIMING, FIRED, RESOLVING, WIN, FAIL }
var current_level_id: String = ""
var current_chapter_id: String = ""
var play_state: PlayState = PlayState.INTRO
var return_scene: String = "res://game/scenes/main_menu.tscn"

func begin_level(level_id: String, chapter_id: String = "") -> void:
    current_level_id = level_id
    current_chapter_id = chapter_id
    play_state = PlayState.INTRO
