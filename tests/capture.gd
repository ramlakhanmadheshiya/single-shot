extends Node
## Drives the real app through every screen and saves screenshots.
## Run (needs a window): godot --path . res://tests/capture.tscn -- <out_dir>

var out_dir: String = "user://captures"
var app: Control
var _backup: Dictionary


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	AudioManager.mute_for_tests = not OS.get_cmdline_user_args().has("--new")
	_backup = SaveSystem.data.duplicate(true)
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("captured ", name)


func _board() -> Board:
	return app.current.get("board") as Board


func _run() -> void:
	if OS.get_cmdline_user_args().has("--new"):
		await _new_screens()
		return
	if OS.get_cmdline_user_args().has("--about"):
		await _wait(1.5)
		app.open_about()
		await _wait(0.8)
		await _shot("about")
		get_tree().quit()
		return
	SaveSystem.data["owned"] = {}
	SaveSystem.data["flags"] = {}
	await _wait(2.4)
	await _shot("01_home")
	app.open_chapters()
	await _wait(1.6)
	await _shot("02_chapters")
	(app.find_child("Scroll", true, false) as TouchScroll).scroll_to(1200.0)
	await _wait(0.8)
	await _shot("02b_chapters_more")
	app.open_levels("ch1")
	await _wait(0.9)
	await _shot("03_levels")
	app.open_game("ch1", 0)
	await _wait(1.6)
	await _shot("04_tutorial")
	app.open_game("ch2", 0)
	await _wait(1.2)
	await _shot("05_chapter_intro")
	app.current.find_child("GotIt", true, false).emit_signal("pressed")
	await _wait(0.8)
	await _shot("05b_intro_spotlight")
	var b: Board
	for spec: Array in [["ch1", 12, "06_dawn_13"], ["ch3", 9, "08_void_10"], ["ch4", 8, "09_shift_09"], ["ch9", 5, "10e_drift_06"], ["ch9", 30, "10f_drift_31"], ["ch8", 12, "10d_turn_13"], ["ch5", 10, "10_prism_11"]]:
		app.open_game(spec[0], spec[1])
		await _wait(1.1)
		b = _board()
		await _shot(spec[2] + "_room")
		b.fire(deg_to_rad(float(b.level["solution"][0])))
		await _wait(0.5)
		await _shot(spec[2] + "_flight")
	await _wait(5.0)
	await _shot("11_result")
	app.current.find_child("Share", true, false).emit_signal("pressed")
	await _wait(1.5)
	await _shot("11b_share")
	app.close_settings()
	app.open_game("ch1", 20)
	await _wait(1.0)
	b = _board()
	b.fire(deg_to_rad(float(b.level["solution"][0]) + 4.0))
	while b.playing:
		await _wait(0.1)
	await _wait(0.4)
	await _shot("12_missed")
	app.open_settings(true)
	await _wait(0.6)
	await _shot("13_settings")
	app.open_how_to_play()
	await _wait(0.6)
	await _shot("13b_how_to_play")
	app.open_about()
	await _wait(0.6)
	await _shot("13c_about")
	app.open_credits()
	await _wait(0.6)
	await _shot("13e_credits")
	app.close_settings()
	app.open_shop()
	await _wait(1.2)
	await _shot("14_shop")
	app.open_product("complete_pack")
	await _wait(0.8)
	await _shot("14b_complete")
	app.open_product("orb_pack")
	await _wait(0.8)
	await _shot("14c_orbs")
	app.open_picker("themes")
	await _wait(0.8)
	await _shot("14d_themes_picker")
	app.open_tips()
	await _wait(0.6)
	await _shot("14e_tips")
	app.close_settings()
	SaveSystem.data["owned"] = {"theme_pack": true}
	SaveSystem.set_setting("theme", "midnight")
	app.open_chapters()
	await _wait(1.4)
	await _shot("16_theme_midnight")
	SaveSystem.set_setting("theme", "chapters")
	SaveSystem.data = _backup
	SaveSystem.save()
	SaveSystem._apply_cosmetics()
	get_tree().quit()


## The screens added in the second round of changes.
func _new_screens() -> void:
	await _wait(1.25)
	await _shot("n01_splash_shot")
	await _wait(0.75)
	await _shot("n02_splash_title")
	AudioManager.mute_for_tests = true
	await _wait(1.2)
	for i: int in 13:
		SaveSystem.data["levels"]["ch1_%02d" % (i + 1)] = {"stars": [3, 2, 3, 1][i % 4], "best": 1}
	SaveSystem.data["keys"] = 3
	SaveSystem.data["unlocked"]["ch1_20"] = true
	app.open_levels("ch1")
	await _wait(1.4)
	await _shot("n03_levels")
	(app.find_child("Scroll", true, false) as TouchScroll).scroll_to(900.0)
	await _wait(0.6)
	await _shot("n04_levels_bottom")
	app.open_locked("ch1", 25)
	await _wait(0.6)
	await _shot("n05_locked")
	app.open_keys()
	await _wait(0.6)
	app.find_child("Quick_5", true, false).emit_signal("pressed")
	await _wait(0.4)
	await _shot("n06_keys")
	app.open_tips()
	await _wait(0.6)
	await _shot("n07_tips")
	app.open_setting_info("long_guide")
	await _wait(0.8)
	await _shot("n08_info_guide")
	app.open_setting_info("shake")
	await _wait(1.0)
	await _shot("n09_info_shake")
	app.close_settings()
	app.open_game("ch1", 14)
	await _wait(1.0)
	var b: Board = _board()
	b.fire(deg_to_rad(float(b.level["solution"][0]) + 5.0))
	while b.playing:
		await _wait(0.1)
	await _wait(0.5)
	b.fire(deg_to_rad(float(b.level["solution"][0]) + 5.0))
	while b.playing:
		await _wait(0.1)
	await _wait(0.6)
	await _shot("n10_hud_try3")
	app.current.call("_hint")
	await _wait(0.4)
	await _shot("n11_hint")
	app.open_game("ch9", 7)
	await _wait(1.0)
	app.current.call("_hint")
	await _wait(0.7)
	await _shot("n12_drift_hint")
	app.open_shop()
	await _wait(1.0)
	await _shot("n13_shop")
	SaveSystem.data = _backup
	SaveSystem.save()
	get_tree().quit()
