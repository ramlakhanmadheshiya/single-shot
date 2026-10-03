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
	AudioManager.mute_for_tests = true
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
	await _wait(2.4)
	await _shot("01_home")
	app.open_chapters()
	await _wait(0.9)
	await _shot("02_chapters")
	app.open_levels("ch1")
	await _wait(0.9)
	await _shot("03_levels")
	app.open_game("ch1", 0)
	await _wait(1.2)
	await _shot("04_game_tip")
	var b: Board = _board()
	b.has_aim = true
	b.aim_angle = deg_to_rad(-70.0)
	await _wait(0.2)
	await _shot("05_aiming")
	for spec: Array in [["ch1", 12, "06_dawn_13"], ["ch2", 6, "07_glass_07"], ["ch3", 9, "08_void_10"], ["ch4", 8, "09_shift_09"], ["ch6", 6, "10b_gate_07"], ["ch7", 8, "10c_spark_09"], ["ch8", 12, "10d_turn_13"], ["ch5", 10, "10_prism_11"]]:
		app.open_game(spec[0], spec[1])
		await _wait(1.1)
		b = _board()
		b.fire(deg_to_rad(float(b.level["solution"][0])))
		await _wait(0.45)
		await _shot(spec[2] + "_flight")
	await _wait(4.5)
	await _shot("11_result")
	app.open_game("ch2", 3)
	await _wait(1.0)
	_board().show_hint()
	await _wait(0.4)
	await _shot("12_hint")
	app.open_settings(true)
	await _wait(0.6)
	await _shot("13_settings")
	app.close_settings()
	app.open_supporter()
	await _wait(1.0)
	await _shot("14_supporter")
	app.open_home()
	await _wait(0.8)
	app.go_back()
	await _wait(0.6)
	await _shot("15_quit")
	SaveSystem.data = _backup
	SaveSystem.save()
	get_tree().quit()
