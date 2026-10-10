extends Node
## End-to-end flow through the real app, headless:
## home -> play -> miss (room resets) -> hint -> clear -> result -> next ->
## chapter intro -> settings, pickers, shop and product cards -> back.
## Run: godot --headless --path . res://tests/ui_flow.tscn

var app: Control
var failures: int = 0
var _backup: Dictionary


func _ready() -> void:
	AudioManager.mute_for_tests = true
	_backup = SaveSystem.data.duplicate(true)
	SaveSystem.reset_progress()
	SaveSystem.data["owned"] = {}
	SaveSystem.data["trials"] = {}
	SaveSystem.data["settings"]["theme"] = "chapters"
	SaveSystem.data["settings"]["orb_style"] = "classic"
	SaveSystem._apply_cosmetics()
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


func _screen_is(file: String) -> bool:
	return app.current != null and app.current.get_script().resource_path.ends_with(file)


## Waits until the board's shot is over (bounded).
func _settle(board: Board) -> void:
	for i: int in 200:
		if not board.playing:
			break
		await _wait(0.05)
	await _wait(0.4)


func _run() -> void:
	await _wait(0.6)
	_check(_screen_is("home_screen.gd"), "starts on the home screen")
	_check(_find("Shop") != null, "home has a shop button")
	(_find("Play") as Button).pressed.emit()
	await _wait(0.8)
	var board: Board = app.current.get("board")
	_check(board != null and str(board.level.get("id", "")) == "ch1_01", "Play opens the first room")
	_check(int(board.level["shots"]) == 1 and board.shots_left() == 1, "a room gives exactly one shot")
	_check(_find("Tutorial") != null, "first play shows the hands-on tutorial")

	# A miss resets the room for the next try and says why.
	board.fire(deg_to_rad(10.0))
	await _settle(board)
	_check(board.shots_left() == 1 and board.targets_left() == 1, "a miss resets the room")
	_check(SaveSystem.misses("ch1_01") == 1, "the miss is counted as a try")
	_check((_find("TryInfo") as Label).text.begins_with("Try 2"), "the header shows the next try")
	_check(not (board.get("_ghost_tracks") as Array).is_empty(), "the missed path stays visible as a guide")

	var hints_before: int = SaveSystem.hints_left()
	(_find("Hint") as Button).pressed.emit()
	_check(SaveSystem.hints_left() == hints_before - 1, "a hint is spent and the path is shown")

	board.fire(deg_to_rad(float(board.level["solution"][0])))
	await _settle(board)
	await _wait(0.8)
	_check(SaveSystem.stars_for("ch1_01") == 2, "a second-try clear with a hint earns two stars")
	_check(SaveSystem.flag("tutorial_done"), "clearing the tutorial room finishes the tutorial")
	for n: String in ["Next", "Watch", "Share", "Replay", "Levels"]:
		_check(_find(n) != null, "result card offers %s" % n)
	(_find("Watch") as Button).pressed.emit()
	await _wait(0.2)
	_check(board.playing and board.replaying, "Watch replays the winning shot")
	await _settle(board)
	await _wait(1.0)
	_check(SaveSystem.stars_for("ch1_01") == 2, "watching a replay records nothing new")
	(_find("Share") as Button).pressed.emit()
	await _wait(0.5)
	_check(_find("ShareNow") != null and _find("Save") != null and _find("CopyLink") != null, "share card offers share, save and copy link")
	_check(ShareService.message_for({"chapter": "Dawn", "number": 1, "verdict": "First try. Perfect."}).contains("theramlakhan.com/one-clean-shot"), "the share message links to the game")
	app.close_settings()
	(_find("Next") as Button).pressed.emit()
	await _wait(0.8)
	board = app.current.get("board")
	_check(str(board.level.get("id", "")) == "ch1_02", "Next opens room 2")

	# First clean shot on a fresh room is three stars.
	board.fire(deg_to_rad(float(board.level["solution"][0])))
	await _settle(board)
	await _wait(0.8)
	_check(SaveSystem.stars_for("ch1_02") == 3, "a first-try clear earns three stars")

	app.open_settings(true)
	await _wait(0.3)
	_check(_find("Settings") != null, "settings opens from inside a level")
	_check(_find("Reset") == null, "progress reset is hidden while playing a level")
	_check(_find("PickColours") != null and _find("PickOrbs") != null, "settings offers colour and orb pickers")
	app.go_back()
	await _wait(0.3)
	_check(_find("Settings") == null, "back closes settings first")
	app.go_back()
	await _wait(0.6)
	_check(_screen_is("levels_screen.gd"), "back from a room goes to its level grid")
	_check(Levels.level_open("ch1", 2) and not Levels.level_open("ch1", 3), "levels unlock strictly one at a time")
	app.go_back()
	await _wait(0.6)
	_check(_screen_is("chapters_screen.gd"), "back goes to chapters")
	_check(Levels.chapters.size() == 9 and _find("Chapter_ch9") != null, "nine chapters, Drift included")
	_check(_find("Art") is ChapterArt, "chapter cards show their chapter's scene")
	_check(not Levels.chapter_open("ch2"), "chapter 2 stays locked until 15 Dawn clears")
	app.go_back()
	await _wait(0.6)
	_check(_screen_is("home_screen.gd"), "back from chapters goes home")
	app._last_back_msec = -1000
	app.go_back()
	await _wait(0.3)
	_check(_find("Confirm") != null, "back on home asks before quitting")
	(_find("No") as Button).pressed.emit()
	await _wait(0.3)

	# Chapter intro: the opening room of a new chapter teaches its idea.
	app.open_game("ch2", 0)
	await _wait(0.8)
	_check(_find("ChapterIntro") != null, "a chapter's first room opens with its tutorial card")
	(_find("GotIt") as Button).pressed.emit()
	await _wait(0.3)
	_check(float((app.current.get("board") as Board).get("_hint_t")) > 0.0, "after the card, the solving path is shown once")
	_check(SaveSystem.flag("intro_ch2"), "the chapter tutorial is remembered")

	# Shop, product cards, pickers.
	app.open_shop()
	await _wait(0.8)
	_check(_screen_is("shop_screen.gd"), "shop opens")
	for id: String in Store.PRODUCTS:
		_check(_find("Product_" + id) != null, "shop lists %s" % id)
	_check(_find("TipJar") != null and _find("Restore") != null, "shop has a tip jar and restore")
	(_find("Product_orb_pack") as Button).pressed.emit()
	await _wait(0.4)
	_check(_find("Product") != null and _find("Buy") != null and _find("Trial") != null, "a cosmetic pack card offers buy and a video trial")
	(_find("Buy") as Button).pressed.emit()
	await _wait(0.3)
	_check(SaveSystem.bought("orb_pack"), "buying the orb pack (simulated in debug) unlocks it")
	app.open_picker("orbs")
	await _wait(0.3)
	(_find("Pick_comet") as Button).pressed.emit()
	await _wait(0.3)
	_check(SaveSystem.orb_style() == "comet", "an owned orb style can be chosen")
	app.open_picker("themes")
	await _wait(0.3)
	(_find("Pick_nord") as Button).pressed.emit()
	await _wait(0.5)
	_check(_find("Product") != null and Palette.theme_id == "chapters", "a locked theme opens its pack instead")
	SaveSystem.start_trial("theme_pack")
	app.open_picker("themes")
	await _wait(0.3)
	(_find("Pick_nord") as Button).pressed.emit()
	await _wait(0.8)
	_check(Palette.theme_id == "nord" and Color(Palette.get_palette("ch1")["top"]) == Color("#2E3440"), "a theme on trial repaints the game")
	SaveSystem.data["trials"]["theme_pack"] = 0
	SaveSystem._apply_cosmetics()
	_check(Palette.theme_id == "chapters", "themes fall back to chapter colours when a trial ends")
	app.close_settings()
	_check(Store.complete_saving() > 20, "the complete pack is a real saving (%d%%)" % Store.complete_saving())
	_check(Store.REGIONAL_TIERS["IN"][Store.tier_of("supporter_pack")] == "₹249", "regional price table includes rupees")
	SaveSystem.set_owned("all_levels", true)
	_check(Levels.chapter_open("ch9") and Levels.level_open("ch9", 39), "Every level opens every room")
	SaveSystem.set_owned("all_levels", false)

	# Out of hints with no ad available: the hint is given free, never a dead end.
	app.open_game("ch1", 1)
	await _wait(0.8)
	SaveSystem.data["hints"] = 0
	(_find("Hint") as Button).pressed.emit()
	await _wait(0.2)
	_check(float((app.current.get("board") as Board).get("_hint_t")) > 0.0 and SaveSystem.hints_left() == 0, "no ad available -> free hint")
	SaveSystem.data["hint_day"] = "2000-01-01"
	_check(SaveSystem.hints_left() == SaveSystem.DAILY_HINTS, "hints refill to exactly 3 on a new day")
	app.open_about()
	await _wait(0.3)
	_check(_find("About") != null and _find("Privacy") != null and _find("Help") != null, "about links to privacy and help")
	app.open_credits()
	await _wait(0.3)
	_check(_find("CardScroll") != null, "credits scroll inside a floating card")
	app.close_settings()

	SaveSystem.data = _backup
	SaveSystem.save()
	SaveSystem._apply_cosmetics()
	print("UI FLOW: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	get_tree().quit(1 if failures > 0 else 0)
