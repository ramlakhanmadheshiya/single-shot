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
	_new_mechanics()
	_moving_platforms()
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


func _moving_platforms() -> void:
	# A platform parked over the launcher's line slides away before the orb arrives:
	# rail 300 to the right, one round trip per 1600 units of travel.
	var level: Dictionary = {"launcher": [320, 880], "bounces": 0, "targets": [[320, 120]],
		"walls": [[320, 300, 160, 16, 0, "wall", [300, 0, 1600]]]}
	var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), -PI / 2)
	_check(bool(res["cleared"]), "a platform slides out of the way while the orb flies")
	var still: Dictionary = level.duplicate(true)
	(still["walls"][0] as Array).resize(6)
	_check(not bool(RicochetSim.simulate(still, RicochetSim.initial_state(still), -PI / 2)["cleared"]), "the same wall standing still blocks the shot")
	_check(RicochetSim.wall_offset(level["walls"][0], 800.0).distance_to(Vector2(300, 0)) < 0.01, "a platform reaches the end of its rail at half its period")
	_check(RicochetSim.wall_offset(level["walls"][0], 0.0) == Vector2.ZERO, "platforms start at rest when the room opens")
	# Platforms never stop: the same angle fired at another moment meets the
	# platform somewhere else.
	var late: Dictionary = RicochetSim.initial_state(level)
	late["t0"] = 800.0
	_check(not bool(RicochetSim.simulate(level, late, -PI / 2)["cleared"]), "the shot depends on when it is fired")
	var lap: Dictionary = RicochetSim.initial_state(level)
	lap["t0"] = 1600.0
	_check(bool(RicochetSim.simulate(level, lap, -PI / 2)["cleared"]), "one full platform cycle later, the same shot works again")
	# A platform sliding into the orb's path is struck and the orb bounces back down.
	var block: Dictionary = {"launcher": [320, 880], "bounces": 1, "targets": [[320, 120]],
		"walls": [[120, 400, 160, 16, 0, "wall", [200, 0, 1200]]]}
	var res2: Dictionary = RicochetSim.simulate(block, RicochetSim.initial_state(block), -PI / 2)
	var bounced: bool = res2["events"].any(func(e: Dictionary) -> bool: return e["type"] == "bounce" and int(e["index"]) == 0)
	_check(bounced and not bool(res2["cleared"]), "a platform sliding into the path is hit")
	# The preview predicts the same first contact as the real shot.
	var pv: Dictionary = RicochetSim.preview(block, RicochetSim.initial_state(block), -PI / 2, 100.0, 1)
	var first: Vector2 = Vector2.INF
	for e: Dictionary in res2["events"]:
		if e["type"] == "bounce":
			first = e["pos"]
			break
	_check(pv["points"].size() == 2 and (pv["points"][1] as Vector2).distance_to(first) < 0.5, "aim preview tracks moving platforms")
	# Deterministic: the same angle always gives the same result.
	var a: Dictionary = RicochetSim.simulate(block, RicochetSim.initial_state(block), -1.3)
	var b: Dictionary = RicochetSim.simulate(block, RicochetSim.initial_state(block), -1.3)
	_check(a["duration"] == b["duration"] and a["events"].size() == b["events"].size(), "moving platforms stay deterministic")


func _new_mechanics() -> void:
	# A gate blocks the target until the orb crosses the switch.
	var gate: Dictionary = {"launcher": [320, 880], "bounces": 1, "targets": [[320, 200]], "switches": [[320, 700]], "walls": [[320, 450, 300, 16, 0, "gate"]]}
	_check(RicochetSim.simulate(gate, RicochetSim.initial_state(gate), -PI / 2)["cleared"], "switch opens the gate in the same shot")
	var closed: Dictionary = gate.duplicate(true)
	closed.erase("switches")
	_check(not RicochetSim.simulate(closed, RicochetSim.initial_state(closed), -PI / 2)["cleared"], "a closed gate blocks the shot")
	# A spark grants the extra bounce needed to come back down to the target.
	var spark: Dictionary = {"launcher": [320, 880], "bounces": 0, "targets": [[200, 880]], "sparks": [[320, 600]]}
	var no_spark: Dictionary = spark.duplicate(true)
	no_spark.erase("sparks")
	_check(RicochetSim.simulate(spark, RicochetSim.initial_state(spark), -PI / 2 - 0.0)["events"].any(func(e: Dictionary) -> bool: return e["type"] == "spark"), "orb collects a spark")
	# A pivot wall turns 90 degrees after it is struck.
	var piv: Dictionary = {"launcher": [320, 880], "bounces": 1, "targets": [[320, 100]], "walls": [[320, 500, 200, 16, 0, "pivot"]]}
	var res: Dictionary = RicochetSim.simulate(piv, RicochetSim.initial_state(piv), -PI / 2)
	_check(float(res["state"]["rot"][0]) == 90.0, "pivot wall turns 90 degrees when struck")
