extends SceneTree
## Generates every chapter's levels and proves each one is solvable in one shot.
##
## Levels are built backwards from a solution: lay out walls, fire a random shot,
## then place targets along its ricochet path. The solver then grades difficulty by
## how much of the 360 degree aim range clears the room, and rejects rooms whose
## widest solving window is too narrow to hit fairly on a touch screen.
##
## Run: godot --headless --path . -s res://tools/level_lab.gd [-- ch1 ch3]

const OUT_DIR: String = "res://content/levels/"
const GRID: float = 40.0
const LEVELS_PER_CHAPTER: int = 20

## Per-chapter generation rules. Ranges are [easy, hard] across the chapter.
const CHAPTERS: Array = [
	{"id": "ch1", "name": "Dawn", "targets": [1, 4], "bounces": [1, 4], "walls": [1, 5], "glass": [0, 0], "void": [0, 0], "bumpers": [0, 0], "portals": 0, "prisms": 0, "armored": 0, "min_width": [1.4, 0.7], "seed": 101},
	{"id": "ch2", "name": "Glass", "targets": [2, 4], "bounces": [2, 4], "walls": [1, 4], "glass": [1, 3], "void": [0, 0], "bumpers": [0, 0], "portals": 0, "prisms": 0, "armored": 0, "min_width": [1.2, 0.6], "seed": 202, "require": "glass"},
	{"id": "ch3", "name": "Void", "targets": [2, 5], "bounces": [2, 5], "walls": [1, 4], "glass": [0, 1], "void": [1, 3], "bumpers": [1, 2], "portals": 0, "prisms": 0, "armored": 0, "min_width": [1.0, 0.55], "seed": 303, "require": "bumper"},
	{"id": "ch4", "name": "Shift", "targets": [2, 5], "bounces": [2, 5], "walls": [1, 4], "glass": [0, 1], "void": [0, 2], "bumpers": [0, 1], "portals": 1, "prisms": 0, "armored": 0, "min_width": [1.0, 0.5], "seed": 404, "require": "portal"},
	{"id": "ch5", "name": "Prism", "targets": [3, 6], "bounces": [2, 5], "walls": [1, 4], "glass": [0, 2], "void": [0, 2], "bumpers": [0, 1], "portals": 0, "prisms": 1, "armored": 1, "min_width": [0.9, 0.45], "seed": 505, "require": "split"},
]

## Hand-made opening rooms that teach aiming and the first bank shot.
const HANDMADE: Dictionary = {
	"ch1": [
		{"launcher": [320, 860], "bounces": 0, "targets": [[320, 280, 1]], "walls": []},
		{"launcher": [320, 860], "bounces": 1, "targets": [[160, 300, 1]], "walls": [[240, 560, 320, 16, 0, "wall"]]},
	],
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	var only: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for chapter: Dictionary in CHAPTERS:
		if not only.is_empty() and not only.has(chapter["id"]):
			continue
		var t0: int = Time.get_ticks_msec()
		var levels: Array = _build_chapter(chapter)
		_write(chapter, levels)
		print("%s: %d levels in %.1fs (armored candidates tried: %d)" % [chapter["id"], levels.size(), (Time.get_ticks_msec() - t0) / 1000.0, armored_made])
	quit(0)


func _build_chapter(chapter: Dictionary) -> Array:
	rng.seed = int(chapter["seed"])
	var result: Array = []
	var handmade: Array = HANDMADE.get(chapter["id"], [])
	for raw: Dictionary in handmade:
		var level: Dictionary = raw.duplicate(true)
		var graded: Dictionary = _grade(level, 0.3)
		if graded.is_empty():
			push_error("Handmade level is not solvable: " + str(raw))
			continue
		result.append(graded)
	var slots: int = LEVELS_PER_CHAPTER - result.size()
	for slot: int in slots:
		var k: float = float(slot) / float(maxi(1, slots - 1))
		var picked: Dictionary = {}
		var pool: Array = []
		var attempts: int = 0
		while pool.size() < 6 and attempts < 900:
			attempts += 1
			var cand: Dictionary = _candidate(chapter, k)
			if not cand.is_empty():
				pool.append(cand)
		if pool.is_empty():
			push_error("No candidate for %s slot %d" % [chapter["id"], slot])
			continue
		# Pick the candidate whose difficulty best matches the slot's target.
		var want: float = lerpf(1.2, 3.4, k) + 0.2 * float(CHAPTERS.find(chapter))
		pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _fit(a, want) < _fit(b, want))
		picked = pool[0]
		result.append(picked)
	# Keep handmade openers first, sort the rest gently by difficulty.
	var head: Array = result.slice(0, handmade.size())
	var tail: Array = result.slice(handmade.size())
	tail.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["difficulty"]) < float(b["difficulty"]))
	# The first generated room of a chapter should introduce its mechanic gently.
	return head + tail


## How well a candidate matches the wanted difficulty; armored rooms get a nudge
## so the chapter actually features its newest idea.
func _fit(level: Dictionary, want: float) -> float:
	var d: float = absf(float(level["difficulty"]) - want)
	for t: Array in level["targets"]:
		if int(t[2]) > 1:
			return d - 0.8
	return d


var armored_made: int = 0


func _range_i(r: Array, k: float) -> int:
	var lo: int = int(r[0])
	var hi: int = int(r[1])
	var centre: float = lerpf(float(lo), float(hi), k)
	return clampi(int(round(centre + rng.randf_range(-0.7, 0.7))), lo, hi)


func _snap(v: float) -> float:
	return round(v / GRID) * GRID


func _candidate(chapter: Dictionary, k: float) -> Dictionary:
	var level: Dictionary = {"launcher": [[200, 320, 440][rng.randi_range(0, 2)] if rng.randf() < 0.35 else 320, 860]}
	var mirror: bool = rng.randf() < 0.45 and int(level["launcher"][0]) == 320
	var walls: Array = []
	var n_walls: int = _range_i(chapter["walls"], k)
	for i: int in n_walls:
		var w: Array = _random_wall(level, walls)
		if w.is_empty():
			continue
		walls.append(w)
		if mirror and absf(float(w[0]) - 320.0) > 60.0:
			var m: Array = w.duplicate()
			m[0] = 640.0 - float(w[0])
			m[4] = -float(w[4])
			walls.append(m)
	_convert_kind(walls, _range_i(chapter["glass"], k), "glass")
	_convert_kind(walls, _range_i(chapter["void"], k), "void")
	level["walls"] = walls
	var bumpers: Array = []
	for i: int in _range_i(chapter["bumpers"], k):
		var p: Vector2 = _free_point(level, 90.0)
		if p != Vector2.INF:
			bumpers.append([p.x, p.y, 30])
	level["bumpers"] = bumpers
	if int(chapter["portals"]) > 0:
		var a: Vector2 = _free_point(level, 80.0)
		var b: Vector2 = _free_point(level, 80.0)
		if a == Vector2.INF or b == Vector2.INF or a.distance_to(b) < 260.0:
			return {}
		level["portals"] = [[a.x, a.y, b.x, b.y]]
	if int(chapter["prisms"]) > 0:
		var pr: Vector2 = _free_point(level, 90.0)
		if pr == Vector2.INF:
			return {}
		level["prisms"] = [[pr.x, pr.y]]
	level["targets"] = []
	var bounces: int = _range_i(chapter["bounces"], k)
	level["bounces"] = bounces
	# Fire the generating shot through the empty room.
	var angle: float = -PI + rng.randf_range(0.18, PI - 0.18)
	var empty_state: Dictionary = RicochetSim.initial_state(level)
	var shot: Dictionary = RicochetSim.simulate(level, empty_state, angle)
	var required: String = str(chapter.get("require", ""))
	if not required.is_empty() and not _has_event(shot, required):
		return {}
	var n_targets: int = _range_i(chapter["targets"], k)
	var targets: Array = _place_targets(level, shot, n_targets, int(chapter["armored"]) > 0 and k > 0.25)
	if targets.size() < n_targets:
		return {}
	level["targets"] = targets
	# Trim the bounce limit to what this path actually needs, with slack early on.
	var probe: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), angle)
	if not bool(probe["cleared"]):
		return {}
	var need: int = _bounces_needed(level, angle)
	level["bounces"] = need + (1 if k < 0.3 and rng.randf() < 0.6 else 0)
	if need < 1 and k > 0.1:
		return {}
	var graded: Dictionary = _grade(level, lerpf(float(chapter["min_width"][0]), float(chapter["min_width"][1]), k))
	if graded.is_empty():
		return {}
	if not required.is_empty():
		var best: Dictionary = RicochetSim.simulate(graded, RicochetSim.initial_state(graded), deg_to_rad(float(graded["solution"][0])))
		if not _has_event(best, required):
			return {}
	return graded


func _bounces_needed(level: Dictionary, angle: float) -> int:
	for b: int in range(0, 9):
		var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), angle, b)
		if bool(res["cleared"]):
			return b
	return 8


func _has_event(res: Dictionary, kind: String) -> bool:
	for e: Dictionary in res["events"]:
		if str(e["type"]) == kind:
			return true
	return false


func _random_wall(level: Dictionary, existing: Array) -> Array:
	for attempt: int in 40:
		var shape: float = rng.randf()
		var w: Array
		if shape < 0.42:
			w = [_snap(rng.randf_range(80, 560)), _snap(rng.randf_range(120, 720)), _snap(rng.randf_range(120, 280)), 16.0, 0.0, "wall"]
		elif shape < 0.68:
			w = [_snap(rng.randf_range(80, 560)), _snap(rng.randf_range(120, 720)), 16.0, _snap(rng.randf_range(120, 280)), 0.0, "wall"]
		elif shape < 0.9:
			w = [_snap(rng.randf_range(100, 540)), _snap(rng.randf_range(140, 700)), _snap(rng.randf_range(120, 220)), 16.0, [45.0, -45.0, 30.0, -30.0][rng.randi_range(0, 3)], "wall"]
		else:
			var s: float = [40.0, 80.0][rng.randi_range(0, 1)]
			w = [_snap(rng.randf_range(100, 540)), _snap(rng.randf_range(140, 700)), s, s, 0.0, "wall"]
		var c: Vector2 = Vector2(float(w[0]), float(w[1]))
		if c.distance_to(RicochetSim.launcher(level)) < 200.0:
			continue
		var ok: bool = true
		for o: Array in existing:
			if c.distance_to(Vector2(float(o[0]), float(o[1]))) < 110.0:
				ok = false
				break
		if ok:
			return w
	return []


func _convert_kind(walls: Array, count: int, kind: String) -> void:
	var plain: Array = []
	for i: int in walls.size():
		if RicochetSim.wall_kind(walls[i]) == "wall" and float(walls[i][2]) + float(walls[i][3]) > 100.0:
			plain.append(i)
	for n: int in mini(count, plain.size()):
		var pick: int = plain.pop_at(rng.randi_range(0, plain.size() - 1))
		walls[pick][5] = kind


## A random point at least `clearance` away from walls, the launcher and features.
func _free_point(level: Dictionary, clearance: float) -> Vector2:
	for attempt: int in 60:
		var p: Vector2 = Vector2(_snap(rng.randf_range(100, 540)), _snap(rng.randf_range(140, 680)))
		if _clearance(level, p) >= clearance:
			return p
	return Vector2.INF


func _clearance(level: Dictionary, p: Vector2) -> float:
	var best: float = minf(minf(p.x, RicochetSim.ARENA.x - p.x), minf(p.y, RicochetSim.ARENA.y - p.y))
	best = minf(best, p.distance_to(RicochetSim.launcher(level)) - 120.0)
	for w: Array in level.get("walls", []):
		var pts: PackedVector2Array = RicochetSim.wall_corners(w)
		for i: int in 4:
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % 4])))
	for b: Array in level.get("bumpers", []):
		best = minf(best, p.distance_to(Vector2(float(b[0]), float(b[1]))) - 30.0)
	for pt: Array in level.get("portals", []):
		best = minf(best, p.distance_to(Vector2(float(pt[0]), float(pt[1]))) - 20.0)
		best = minf(best, p.distance_to(Vector2(float(pt[2]), float(pt[3]))) - 20.0)
	for pr: Array in level.get("prisms", []):
		best = minf(best, p.distance_to(Vector2(float(pr[0]), float(pr[1]))) - 20.0)
	for t: Array in level.get("targets", []):
		best = minf(best, p.distance_to(Vector2(float(t[0]), float(t[1]))) - 60.0)
	return best


## Samples points along the generating shot and spreads targets across its legs.
func _place_targets(level: Dictionary, shot: Dictionary, count: int, allow_armored: bool) -> Array:
	var candidates: Array = []
	for track: Dictionary in shot["tracks"]:
		var pts: Array = track["points"]
		for leg: int in pts.size() - 1:
			var a: Vector2 = pts[leg]
			var b: Vector2 = pts[leg + 1]
			var length: float = a.distance_to(b)
			var s: float = 50.0
			while s < length - 40.0:
				candidates.append({"p": a.lerp(b, s / length), "leg": leg, "track": track["id"]})
				s += 26.0
	if candidates.is_empty():
		return []
	var chosen: Array = []
	var used_legs: Dictionary = {}
	var temp: Dictionary = level.duplicate(true)
	temp["targets"] = []
	# Always try to put one target on the very last leg so every bounce matters.
	var order: Array = candidates.duplicate()
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = order[i]
		order[i] = order[j]
		order[j] = swap
	var last_leg: int = 0
	for c: Dictionary in order:
		last_leg = maxi(last_leg, int(c["leg"]))
	for i: int in order.size():
		if int(order[i]["leg"]) == last_leg:
			order.push_front(order.pop_at(i))
			break
	for c: Dictionary in order:
		if chosen.size() >= count:
			break
		var key: String = "%d:%d" % [c["track"], c["leg"]]
		if used_legs.has(key) and used_legs.size() < count:
			continue
		var p: Vector2 = c["p"]
		if _clearance(temp, p) < RicochetSim.TARGET_R + 22.0:
			continue
		var t: Array = [round(p.x), round(p.y), 1]
		chosen.append(t)
		temp["targets"].append(t)
		used_legs[key] = true
	if allow_armored and chosen.size() >= 2 and rng.randf() < 0.6:
		# An armored target needs two passes: put it where the path crosses itself.
		var cross: Vector2 = _self_crossing(shot)
		if cross != Vector2.INF:
			temp["targets"].pop_back()
			if _clearance(temp, cross) >= RicochetSim.TARGET_R + 22.0:
				chosen[chosen.size() - 1] = [round(cross.x), round(cross.y), 2]
				armored_made += 1
	return chosen


## A point where two non-adjacent legs of the shot cross, or Vector2.INF.
func _self_crossing(shot: Dictionary) -> Vector2:
	var legs: Array = []
	for track: Dictionary in shot["tracks"]:
		var pts: Array = track["points"]
		for i: int in pts.size() - 1:
			legs.append([pts[i], pts[i + 1], track["id"], i])
	var found: Array = []
	for a: int in legs.size():
		for b: int in range(a + 1, legs.size()):
			if legs[a][2] == legs[b][2] and absi(int(legs[a][3]) - int(legs[b][3])) < 2:
				continue
			var x: Variant = Geometry2D.segment_intersects_segment(legs[a][0], legs[a][1], legs[b][0], legs[b][1])
			if x != null:
				found.append(x)
	if found.is_empty():
		return Vector2.INF
	return found[rng.randi_range(0, found.size() - 1)]


## Solves the level and annotates it. Returns {} if it is unfair or unsolvable.
func _grade(level: Dictionary, min_width_deg: float) -> Dictionary:
	var state: Dictionary = RicochetSim.initial_state(level)
	var windows: Array = RicochetSim.solve(level, state, 1440, true)
	if windows.is_empty():
		return {}
	var best: Dictionary = windows[0]
	var width_deg: float = rad_to_deg(float(best["width"]))
	if width_deg < min_width_deg:
		return {}
	var total: float = 0.0
	for w: Dictionary in windows:
		total += float(w["width"])
	var fraction: float = total / TAU
	if fraction > 0.06 and level.get("targets", []).size() > 1:
		return {}
	var out: Dictionary = level.duplicate(true)
	out["shots"] = 3
	out["par"] = 1
	out["solution"] = [snappedf(rad_to_deg(float(best["angle"])), 0.001)]
	out["window"] = snappedf(width_deg, 0.01)
	out["windows"] = windows.size()
	out["difficulty"] = snappedf(log(1.0 / maxf(fraction, 0.00001)) / log(10.0) + 0.22 * float(out["bounces"]) + 0.12 * float(level["targets"].size()), 0.01)
	return out


func _write(chapter: Dictionary, levels: Array) -> void:
	var out: Array = []
	for i: int in levels.size():
		var lv: Dictionary = levels[i]
		lv["id"] = "%s_%02d" % [chapter["id"], i + 1]
		lv["number"] = i + 1
		for key: String in ["walls", "bumpers", "portals", "prisms"]:
			if lv.has(key) and (lv[key] as Array).is_empty():
				lv.erase(key)
		out.append(lv)
	var data: Dictionary = {"id": chapter["id"], "name": chapter["name"], "levels": out}
	var file: FileAccess = FileAccess.open(OUT_DIR + chapter["id"] + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", false))
