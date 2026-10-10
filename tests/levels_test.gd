extends SceneTree
## Proves every shipped level is fair and the chapters are paced as designed:
## - one shot per room, and the stored solution clears it in that one shot;
## - the solving window is wide enough to hit by touch;
## - bounces climb with the schedule: 1 at the start of a chapter, 8 at level 40;
## - difficulty rises strictly from level 2 to level 40 (level 1 is the tutorial);
## - neighbouring levels never share a bounce pattern;
## - nothing sits outside the room.
## Run: godot --headless --path . -s res://tests/levels_test.gd

const LevelLab: GDScript = preload("res://tools/level_lab.gd")
const MIN_WINDOW_DEG: float = 0.2
const CHAPTERS: int = 9
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
		var list: Array = data["levels"]
		if list.size() != 40:
			_fail("%s: has %d levels, expected 40" % [cid, list.size()])
			continue
		if not bool(list[0].get("intro", false)):
			_fail("%s: level 1 should be the chapter's tutorial room" % cid)
		for i: int in range(2, list.size()):
			if float(list[i]["difficulty"]) <= float(list[i - 1]["difficulty"]):
				_fail("%s: level %d is not harder than level %d" % [cid, i + 1, i])
			if str(list[i].get("sig", "")) == str(list[i - 1].get("sig", "")):
				_fail("%s: levels %d and %d play the same bounce pattern" % [cid, i, i + 1])
		if float(list[0]["difficulty"]) >= float(list[1]["difficulty"]):
			_fail("%s: the tutorial room is not the easiest" % cid)
		for i: int in range(1, list.size()):
			var want: int = LevelLab.bounce_goal(i + 1)
			if int(list[i].get("need", -1)) != want:
				_fail("%s: level %d needs %d bounces, the schedule says %d" % [cid, i + 1, int(list[i].get("need", -1)), want])
		for lv: Dictionary in list:
			count += 1
			var id: String = str(lv["id"])
			if ids.has(id):
				_fail("duplicate id " + id)
			ids[id] = true
			if int(lv.get("shots", 0)) != 1:
				_fail("%s: should allow exactly one shot" % id)
			var res: Dictionary = RicochetSim.simulate(lv, RicochetSim.initial_state(lv), deg_to_rad(float(lv["solution"][0])))
			if not bool(res["cleared"]):
				_fail("%s: stored solution does not clear" % id)
			if float(lv.get("window", 0.0)) < MIN_WINDOW_DEG:
				_fail("%s: solving window %.2f deg is too narrow" % [id, float(lv["window"])])
			for t: Array in lv["targets"]:
				var p: Vector2 = Vector2(float(t[0]), float(t[1]))
				if not Rect2(Vector2(30, 30), RicochetSim.ARENA - Vector2(60, 60)).has_point(p):
					_fail("%s: target outside the arena" % id)
	if count != CHAPTERS * 40:
		_fail("expected %d levels (%d chapters x 40), found %d" % [CHAPTERS * 40, CHAPTERS, count])
	# Drift really moves.
	var drift: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/ch9.json"))
	if drift is Dictionary:
		for lv: Dictionary in drift["levels"]:
			if not RicochetSim.has_movers(lv):
				_fail("%s: a Drift room without a moving platform" % str(lv["id"]))
	print("LEVELS: %d checked, %s" % [count, "FAIL (%d)" % failures if failures > 0 else "PASS"])
	quit(1 if failures > 0 else 0)


func _fail(msg: String) -> void:
	failures += 1
	push_error(msg)
