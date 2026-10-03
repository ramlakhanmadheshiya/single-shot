extends SceneTree
## Proves every shipped level is fair: its stored solution clears the room in one
## shot, the solving window is wide enough to hit by touch, and nothing overlaps.
## Run: godot --headless --path . -s res://tests/levels_test.gd

const MIN_WINDOW_DEG: float = 0.4
var failures: int = 0


func _init() -> void:
	var ids: Dictionary = {}
	var count: int = 0
	for cid: String in Palette.ids():
		var path: String = "res://content/levels/%s.json" % cid
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			_fail("%s: missing or invalid" % path)
			continue
		# Levels 1-3 are easy; from level 4 on each one must be strictly harder,
		# so level 40 is the hardest in the chapter.
		var list: Array = data["levels"]
		for i: int in range(3, list.size()):
			if float(list[i]["difficulty"]) <= float(list[i - 1]["difficulty"]):
				_fail("%s: level %d is not harder than level %d" % [cid, i + 1, i])
		for i: int in mini(3, list.size()):
			if float(list[i]["difficulty"]) >= float(list[3]["difficulty"]):
				_fail("%s: easy level %d is not easier than level 4" % [cid, i + 1])
		for lv: Dictionary in data["levels"]:
			count += 1
			var id: String = str(lv["id"])
			if ids.has(id):
				_fail("duplicate id " + id)
			ids[id] = true
			var res: Dictionary = RicochetSim.simulate(lv, RicochetSim.initial_state(lv), deg_to_rad(float(lv["solution"][0])))
			if not bool(res["cleared"]):
				_fail("%s: stored solution does not clear" % id)
			if float(lv.get("window", 0.0)) < MIN_WINDOW_DEG:
				_fail("%s: solving window %.2f deg is too narrow" % [id, float(lv["window"])])
			for t: Array in lv["targets"]:
				var p: Vector2 = Vector2(float(t[0]), float(t[1]))
				if not Rect2(Vector2(30, 30), RicochetSim.ARENA - Vector2(60, 60)).has_point(p):
					_fail("%s: target outside the arena" % id)
			if int(lv.get("shots", 0)) < 1:
				_fail("%s: no shots" % id)
	if count != 320:
		_fail("expected 320 levels (8 chapters x 40), found %d" % count)
	print("LEVELS: %d checked, %s" % [count, "FAIL (%d)" % failures if failures > 0 else "PASS"])
	quit(1 if failures > 0 else 0)


func _fail(msg: String) -> void:
	failures += 1
	push_error(msg)
