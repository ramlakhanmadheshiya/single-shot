extends Node
## End-to-end flow through the real app, headless:
## home -> play -> win level 1 -> result sheet -> next -> undo/hint -> settings -> back.
## Run: godot --headless --path . res://tests/ui_flow.tscn

var app: Control
var failures: int = 0
var _backup: Dictionary


func _ready() -> void:
	AudioManager.mute_for_tests = true
	_backup = SaveSystem.data.duplicate(true)
	SaveSystem.reset_progress()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		failures += 1
		push_error("FAILED: " + label)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _find(name: String) -> Node:
	return app.find_child(name, true, false)


func _run() -> void:
	await _wait(0.6)
	_check(app.current != null and app.current.get_script().resource_path.ends_with("home_screen.gd"), "starts on the home screen")
	(_find("Play") as Button).pressed.emit()
	await _wait(0.8)
	var board: Board = app.current.get("board")
	_check(board != null and str(board.level.get("id", "")) == "ch1_01", "Play opens the first room")

	# A wrong shot uses a shot and leaves the target.
	board.fire(deg_to_rad(10.0))
	await _wait(2.5)
	_check(board.shots_left() == 2 and board.targets_left() == 1, "a miss costs one shot")
	_check(not (_find("Undo") as Button).disabled, "undo is available after a shot")
	(_find("Undo") as Button).pressed.emit()
	_check(board.shots_left() == 3, "undo refunds the shot")

	var hints_before: int = SaveSystem.hints_left()
	(_find("Hint") as Button).pressed.emit()
	_check(SaveSystem.hints_left() == hints_before - 1, "a hint is spent and the path is shown")

	board.fire(deg_to_rad(float(board.level["solution"][0])))
	await _wait(3.5)
	_check(SaveSystem.stars_for("ch1_01") == 3, "one-shot clear records three stars")
	var next: Button = _find("Next") as Button
	_check(next != null, "result sheet offers Next")
	if next != null:
		next.pressed.emit()
		await _wait(0.8)
	_check(str((app.current.get("board") as Board).level.get("id", "")) == "ch1_02", "Next opens room 2")

	app.open_settings()
	await _wait(0.3)
	_check(_find("Settings") != null, "settings sheet opens")
	app.go_back()
	await _wait(0.3)
	_check(_find("Settings") == null, "back closes settings first")
	app.go_back()
	await _wait(0.6)
	_check(app.current.get_script().resource_path.ends_with("levels_screen.gd"), "back from a room goes to its level grid")
	_check(Levels.level_open("ch1", 3) and not Levels.level_open("ch1", 5), "levels open in a window ahead of progress")
	app.go_back()
	await _wait(0.6)
	_check(app.current.get_script().resource_path.ends_with("chapters_screen.gd"), "back goes to chapters")
	_check(not Levels.chapter_open("ch2"), "chapter 2 stays locked until 12 Dawn clears")

	SaveSystem.data = _backup
	SaveSystem.save()
	print("UI FLOW: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	get_tree().quit(1 if failures > 0 else 0)
