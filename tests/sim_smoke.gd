extends SceneTree
## Quick checks for RicochetSim geometry. Run:
## godot --headless --path . -s res://tests/sim_smoke.gd

var failures: int = 0


func _init() -> void:
	_direct_hit()
	_one_bounce()
	_bounce_limit()
	_glass_breaks()
	_void_absorbs()
	_portal_and_prism()
	_armored()
	_timing()
	print("SIM SMOKE: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	quit(1 if failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		push_error("FAILED: " + label)
	else:
		print("  ok  ", label)


func _direct_hit() -> void:
	var level: Dictionary = {"launcher": [320, 880], "bounces": 0, "targets": [[320, 300]]}
	var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), -PI / 2)
	_check(res["cleared"], "straight up clears a target directly above")
	var miss: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), -PI / 2 + 0.2)
	_check(not miss["cleared"], "angled shot misses it")


func _one_bounce() -> void:
	# Target on the left; reach it by bouncing off the right arena wall.
	var level: Dictionary = {"launcher": [320, 880], "bounces": 1, "targets": [[120, 400]], "walls": [[200, 640, 400, 20, 0, "wall"]]}
	var state: Dictionary = RicochetSim.initial_state(level)
	var wins: Array = RicochetSim.solve(level, state, 720)
	_check(not wins.is_empty(), "bank shot level has a solution")
	if not wins.is_empty():
		var res: Dictionary = RicochetSim.simulate(level, state, wins[0]["angle"])
		_check(res["cleared"] and int(res["bounces_used"]) >= 1, "solution uses a bounce")


func _bounce_limit() -> void:
	var level: Dictionary = {"launcher": [320, 880], "bounces": 0, "targets": [[100, 100]]}
	var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), -0.3)
	var fizzled: bool = false
	for e: Dictionary in res["events"]:
		if e["type"] == "fizzle":
			fizzled = true
	_check(fizzled, "orb fizzles on first wall with zero bounces")


func _glass_breaks() -> void:
	var level: Dictionary = {"launcher": [320, 880], "bounces": 1, "targets": [[320, 100]], "walls": [[320, 500, 300, 16, 0, "glass"]]}
	var state: Dictionary = RicochetSim.initial_state(level)
	var res: Dictionary = RicochetSim.simulate(level, state, -PI / 2)
	_check(not res["cleared"], "glass reflects the first shot")
	_check(not bool(res["state"]["intact"][0]), "glass shatters after being hit")
	var res2: Dictionary = RicochetSim.simulate(level, res["state"], -PI / 2)
	_check(res2["cleared"], "second shot passes where the glass was")


func _void_absorbs() -> void:
	var level: Dictionary = {"launcher": [320, 880], "bounces": 5, "targets": [[320, 100]], "walls": [[320, 500, 300, 16, 0, "void"]]}
	var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), -PI / 2)
	_check(res["events"][-1]["type"] == "absorb", "void block swallows the orb")


func _portal_and_prism() -> void:
	var level: Dictionary = {"launcher": [320, 880], "bounces": 0, "targets": [[100, 200]], "portals": [[320, 600, 100, 400]]}
	var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), -PI / 2)
	_check(res["cleared"], "portal teleports the orb onto the target line")
	var split: Dictionary = {"launcher": [320, 880], "bounces": 0, "targets": [[320 - 300 * tan(0.5585), 300], [320 + 300 * tan(0.5585), 300]], "prisms": [[320, 600]]}
	var res2: Dictionary = RicochetSim.simulate(split, RicochetSim.initial_state(split), -PI / 2)
	_check(res2["cleared"], "prism splits the orb into two that hit both targets")


func _armored() -> void:
	var level: Dictionary = {"launcher": [320, 880], "bounces": 1, "targets": [[320, 300, 2]]}
	var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), -PI / 2)
	_check(res["cleared"], "armored target falls to two passes (up, then back down)")
	var once: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), -PI / 2, 0)
	_check(not once["cleared"] and int(once["state"]["hp"][0]) == 1, "one pass only cracks the shield")


func _timing() -> void:
	var level: Dictionary = {"launcher": [320, 880], "bounces": 6, "targets": [[100, 100], [540, 140], [300, 420]], "walls": [[200, 300, 160, 20, 30, "wall"], [450, 600, 200, 20, -20, "glass"]]}
	var t0: int = Time.get_ticks_msec()
	var wins: Array = RicochetSim.solve(level, RicochetSim.initial_state(level), 1440, true)
	print("  solve(1440) took %d ms, %d windows" % [Time.get_ticks_msec() - t0, wins.size()])
