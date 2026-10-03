extends Node
## Exercises saved solving shots through the real physics bodies.
const Runtime = preload("res://game/core/level_runtime.gd")
const Tuning: PhysicsTuning = preload("res://game/core/physics_tuning.tres")
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	AudioManager.mute_for_tests = true
	var control: Control = Control.new()
	control.size = Vector2(1100, 500)
	get_tree().root.add_child(control)
	var runtime: LevelRuntime = Runtime.new()
	runtime.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.add_child(runtime)
	var chapter: Dictionary = LevelRegistry.load_chapter("ch01")
	var levels: Array = chapter.get("levels", [])
	var colors: Dictionary = preload("res://game/ui/themes/theme_tokens.gd").DARK
	var tuning: PhysicsTuning = Tuning.duplicate(true)
	await get_tree().process_frame
	for level_value: Variant in levels:
		var data: Dictionary = level_value
		runtime.configure(data, colors, tuning)
		await get_tree().physics_frame
		runtime.fire(runtime._solution_vector())
		var elapsed: float = 0.0
		while runtime.state != "win" and elapsed < 5.5:
			await get_tree().physics_frame
			elapsed += 1.0 / 60.0
		_expect(runtime.state == "win", "Solving shot wins Level %d" % int(data.get("number", -1)))
		runtime.restart()
		await get_tree().physics_frame
	_expect(runtime.get_stars() == 3, "One shot earns three stars")
	runtime.shots_used = 2
	_expect(runtime.get_stars() == 2, "Two shots earn two stars")
	runtime.shots_used = 3
	_expect(runtime.get_stars() == 1, "More than two shots earns one star")
	runtime.configure(levels[0], colors, tuning)
	await get_tree().physics_frame
	runtime.restart()
	await get_tree().physics_frame
	for miss: int in 3:
		runtime.fire(Vector2.LEFT)
		var elapsed: float = 0.0
		while runtime.state not in ["aiming", "try_again"] and elapsed < 3.0:
			await get_tree().physics_frame
			elapsed += 1.0 / 60.0
		if miss < 2:
			_expect(runtime.state == "aiming", "Miss %d returns to aiming" % (miss + 1))
		_expect(runtime.state == "try_again" if miss == 2 else runtime.state == "aiming", "Shot budget resolves after miss %d" % (miss + 1))
	_expect(runtime.undo(), "Undo restores the prior shot")
	_expect(runtime.shots_used == 2, "Undo restores the earlier shot count")
	runtime.restart()
	_expect(runtime.shots_used == 0 and runtime.state == "aiming", "Restart resets the board")
	SaveSystem.data = SaveSystem._default_data()
	SaveSystem.data["last_reset_date"] = SaveSystem.local_date_string()
	SaveSystem.data["hints_left"] = 3
	_expect(SaveSystem.spend_hint() and int(SaveSystem.data["hints_left"]) == 2, "Hint spends a free hint first")
	SaveSystem.data["hints_left"] = 0
	SaveSystem.add_bonus_hint(1)
	_expect(SaveSystem.spend_hint() and int(SaveSystem.data["bonus_hints"]) == 0, "Hint spends a bonus after free hints")
	for player: AudioStreamPlayer in AudioManager.sfx_players:
		player.stop()
		player.stream = null
	_control_finish(control)
	if failures == 0:
		print("PASS: all 20 solving shots win; misses, Undo, Restart, stars, and hints pass")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _control_finish(control: Node) -> void:
	get_tree().root.remove_child(control)
	control.free()
	for _frame: int in 4: await get_tree().physics_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("Gameplay test failed: " + message)
