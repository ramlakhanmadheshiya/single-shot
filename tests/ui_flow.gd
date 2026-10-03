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
	_check(_find("Tutorial") != null, "first play shows the hands-on tutorial")

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

	app.open_settings(true)
	await _wait(0.3)
	_check(_find("Settings") != null, "settings sheet opens from inside a level")
	_check(_find("Reset") == null, "progress reset is hidden while playing a level")
	app.go_back()
	await _wait(0.3)
	_check(_find("Settings") == null, "back closes settings first")
	app.go_back()
	await _wait(0.6)
	_check(app.current.get_script().resource_path.ends_with("levels_screen.gd"), "back from a room goes to its level grid")
	_check(Levels.level_open("ch1", 1) and not Levels.level_open("ch1", 2), "levels unlock strictly one at a time")
	app.go_back()
	await _wait(0.6)
	_check(app.current.get_script().resource_path.ends_with("chapters_screen.gd"), "back goes to chapters")
	_check(not Levels.chapter_open("ch2"), "chapter 2 stays locked until 15 Dawn clears")
	_check(_find("TotalStars") != null and _find("SettingsButton") != null, "chapters page shows total stars and a settings button")
	app.go_back()
	await _wait(0.6)
	_check(app.current.get_script().resource_path.ends_with("home_screen.gd"), "back from chapters goes home")
	app._last_back_msec = -1000
	app.go_back()
	await _wait(0.3)
	_check(_find("Confirm") != null, "back on home asks before quitting")
	(_find("No") as Button).pressed.emit()
	await _wait(0.3)
	_check(_find("Confirm") == null, "choosing to keep playing closes the prompt")
	app.open_settings(false)
	await _wait(0.3)
	_check(_find("Reset") != null, "progress reset is available outside a level")
	(_find("Credits") as Button).pressed.emit()
	await _wait(0.3)
	_check(_find("Credits") != null and _find("Settings") == null, "credits open from settings")
	app.close_settings()
	(_find("Supporter") as Button).pressed.emit()
	await _wait(0.8)
	_check(_find("Buy") != null and _find("Restore") != null, "heart opens the Supporter Pack with buy and restore")
	# Out of hints with no ad available: the hint is given free, never a dead end.
	app.open_game("ch1", 1)
	await _wait(0.8)
	SaveSystem.data["hints"] = 0
	(_find("Hint") as Button).pressed.emit()
	await _wait(0.2)
	_check(float((app.current.get("board") as Board).get("_hint_t")) > 0.0 and SaveSystem.hints_left() == 0, "no ad available -> free hint")
	_check(Store.regional_price() != "" and Store.REGIONAL_PRICES["IN"] == "₹249", "regional price table includes rupees")
	var before: int = SaveSystem.hints_left()
	SaveSystem.data["hint_day"] = "2000-01-01"
	_check(SaveSystem.hints_left() == SaveSystem.DAILY_HINTS, "hints refill to exactly 3 on a new day (was %d)" % before)

	SaveSystem.data = _backup
	SaveSystem.save()
	print("UI FLOW: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	get_tree().quit(1 if failures > 0 else 0)
