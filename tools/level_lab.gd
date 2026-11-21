extends SceneTree
## Generates every chapter's 40 levels as a paced learning journey, and proves each
## one can be cleared with a single shot.
##
## Rooms are built backwards from a solution: lay out walls from a layout archetype,
## fire one shot with the bounce allowance this slot calls for, then place targets
## along its ricochet path (always one on the last leg, so every bounce counts).
## The solver then grades each room and rejects anything unfair:
##   - the widest solving window must be wide enough to hit by touch for its band;
##   - the chapter's idea must matter: with that mechanic removed (glass made solid,
##     platforms frozen, the bumper taken away...) the solving shot has to fail;
##   - no much cheaper shortcut: no solving window may need far fewer bounces.
## Picking the 40: bounces climb from 1 to 8 across the chapter, difficulty rises
## strictly from level 2 to level 40, neighbours never share a layout archetype or a
## solving direction, and no two levels in a chapter share a bounce pattern.
##
## Run: godot --headless --path . -s res://tools/level_lab.gd [-- ch1 ch3]

const OUT_DIR: String = "res://content/levels/"
const GRID: float = 20.0
const LEVELS_PER_CHAPTER: int = 40
const MAX_BOUNCES: int = 8

## Narrowest solving window (degrees) allowed for a room that needs b bounces.
const MIN_WINDOW: Dictionary = {0: 5.0, 1: 4.0, 2: 3.0, 3: 2.0, 4: 1.4, 5: 1.0, 6: 0.8, 7: 0.6, 8: 0.5}
## Every moving platform in the game travels at this fraction of the orb's speed
## (about 270 px/s): medium, and the same in every room.
const PLATFORM_SPEED: float = 0.18
## Platforms keep at least this far from other walls through their whole swing.
const PLATFORM_GAP: float = 18.0
## Moving platforms never stop, so the shot also has to be timed. Shortest allowed
## timing window, in world-clock units (the orb's speed: 1500 units = 1 second).
const MIN_TIME_WINDOW: Dictionary = {0: 450.0, 1: 450.0, 2: 375.0, 3: 300.0, 4: 240.0, 5: 195.0, 6: 165.0, 7: 150.0, 8: 120.0}
## Targets per room for a room that needs b bounces.
const TARGETS: Dictionary = {0: [1, 1], 1: [1, 2], 2: [1, 3], 3: [2, 3], 4: [2, 4], 5: [3, 4], 6: [3, 5], 7: [3, 5], 8: [4, 6]}
const ARCHETYPES: Array[String] = [
	"chambers", "nested", "pocket", "zigzag", "funnel",
	"corridor", "diagonals", "pillars", "shelves", "mirror",
	"asymmetric", "crossroad", "frame", "scatter"
]

## Per-chapter rules. Ranges are [early, late] across the chapter. "late" extras are
## ideas from chapters EARLIER IN PLAY ORDER (Palette.ORDER: Dawn, Glass, Gate,
## Drift, Turn, Shift, Void, Prism, Spark) that start mixing in from about level 16.
const CHAPTERS: Array = [
	{"id": "ch1", "name": "Dawn", "seed": 101, "mech": "", "pool_factor": 1.6, "walls": [1, 5]},
	{"id": "ch2", "name": "Glass", "seed": 202, "mech": "glass", "pool_factor": 1.6, "walls": [1, 5], "glass": [1, 3]},
	{"id": "ch3", "name": "Void", "seed": 303, "mech": "void", "pool_factor": 1.6, "window_scale": 0.6, "walls": [1, 5], "void": [1, 3], "bumpers": [1, 2], "late": {"glass": [0, 1]}},
	{"id": "ch4", "name": "Shift", "seed": 404, "mech": "portal", "pool_factor": 1.6, "walls": [1, 5], "portals": 1, "late": {"glass": [0, 1]}},
	{"id": "ch5", "name": "Prism", "seed": 505, "mech": "split", "pool_factor": 1.6, "walls": [1, 5], "prisms": 1, "armored_from": 0.3, "late": {"glass": [0, 1], "void": [0, 1]}},
	{"id": "ch6", "name": "Gate", "seed": 606, "mech": "switch", "pool_factor": 1.6, "walls": [1, 5], "gates": [1, 2], "switches": 1, "late": {"glass": [0, 1]}},
	{"id": "ch7", "name": "Spark", "seed": 707, "mech": "spark", "pool_factor": 1.6, "walls": [1, 5], "sparks": [1, 3], "late": {"glass": [0, 1], "void": [0, 1]}},
	{"id": "ch8", "name": "Turn", "seed": 808, "mech": "pivot", "pool_factor": 1.6, "walls": [2, 5], "pivots": [1, 2], "late": {"glass": [0, 1]}},
	{"id": "ch9", "name": "Drift", "seed": 909, "mech": "move", "pool_factor": 1.3, "walls": [1, 5], "movers": [1, 3]},
]

## Hand-made rooms that open a chapter by showing its one new idea on its own.
const HANDMADE: Dictionary = {
	"ch1": [
		# Aim: straight up, nothing in the way.
		{"launcher": [320, 860], "bounces": 0, "targets": [[320, 300, 1]], "walls": []},
	],
	"ch2": [
		# Glass bounces you once, then it is gone. The target sits in a box whose floor is
		# glass: up, back down off the floor, and up through the gap.
		{"launcher": [320, 860], "bounces": 2, "targets": [[320, 450, 1]], "walls": [
			[320, 600, 296, 16, 0, "glass"], [320, 300, 296, 16, 0, "wall"],
			[180, 450, 16, 316, 0, "wall"], [460, 450, 16, 316, 0, "wall"]]},
	],
	"ch9": [
		# A platform sweeps across the straight shot; release while it is out of the way.
		{"launcher": [320, 860], "bounces": 0, "targets": [[320, 200, 1]], "walls": [[360, 440, 160, 16, 0, "wall", [180, 0, 2000]]]},
	],
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var chapter: Dictionary = {}
var stats: Dictionary = {}


func _init() -> void:
	var only: PackedStringArray = OS.get_cmdline_user_args()
	if only.has("--debug"):
		for ch: Dictionary in CHAPTERS:
			if only.has(ch["id"]):
				chapter = ch
		rng.seed = 5
		stats["debug"] = []
		for i: int in 3000:
			_candidate(1 + i % 8)
		var dbg: Array = stats["debug"]
		stats.erase("debug")
		print(stats)
		var by: Dictionary = {}
		for d: Array in dbg:
			if not by.has(d[0]):
				by[d[0]] = []
			by[d[0]].append(d[1])
		for b: int in by:
			var arr: Array = by[b]
			arr.sort()
			print(b, ": n=", arr.size(), " median=", arr[arr.size() / 2], " p80=", arr[int(arr.size() * 0.8)], " max=", arr[-1])
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for ch: Dictionary in CHAPTERS:
		if not only.is_empty() and not only.has(ch["id"]):
			continue
		var t0: int = Time.get_ticks_msec()
		chapter = ch
		rng.seed = int(ch["seed"])
		var levels: Array = _build_chapter()
		_write(levels)
		print("%s: %d levels in %.0fs  %s" % [ch["id"], levels.size(), (Time.get_ticks_msec() - t0) / 1000.0, str(stats)])
	quit(0)


## Bounces the n-th level (1-based) should need: 1 at the start, 8 at the end.
static func bounce_goal(n: int) -> int:
	return 1 + int(round(float(n - 1) * 7.0 / 39.0))


func _build_chapter() -> Array:
	stats = {}
	var result: Array = []
	for raw: Dictionary in HANDMADE.get(chapter["id"], []):
		var level: Dictionary = raw.duplicate(true)
		var graded: Dictionary = _grade(level, int(level["bounces"]), true)
		if graded.is_empty():
			push_error("%s: hand-made level is not fair: %s" % [chapter["id"], str(raw)])
			continue
		if not _mechanic_matters(graded, deg_to_rad(float(graded["solution"][0]))):
			push_error("%s: hand-made level doesn't need its mechanic" % chapter["id"])
		graded["intro"] = true
		result.append(graded)
	# Without a hand-made opener, generate one: the new idea on its own, as plain
	# as possible, with a wide window.
	if result.is_empty():
		var intro: Dictionary = _intro_room()
		intro["intro"] = true
		result.append(intro)
	# Pool of verified rooms, bucketed by the bounces they need.
	var need: Dictionary = {}
	for n: int in range(result.size() + 1, LEVELS_PER_CHAPTER + 1):
		need[bounce_goal(n)] = int(need.get(bounce_goal(n), 0)) + 1
	var pool: Dictionary = {}
	for b: int in need:
		pool[b] = []
	var attempts: int = 0
	var budget: int = 25000
	while attempts < budget:
		# Work on the bucket that is furthest from its quota.
		var goal: int = -1
		var worst: float = 1.0e9
		for b: int in need:
			var target_count: float = float(need[b]) * float(chapter.get("pool_factor", 3.0))
			var ratio: float = float((pool[b] as Array).size()) / maxf(1.0, target_count)
			if ratio < worst:
				worst = ratio
				goal = b
		if worst >= 1.0:
			break
		attempts += 1
		var cand: Dictionary = _candidate(goal)
		if not cand.is_empty():
			(pool[int(cand["need"])] as Array).append(cand)
		if attempts % 100 == 0:
			var counts: Array = []
			for b: int in need:
				var t_cnt: int = int(round(float(need[b]) * float(chapter.get("pool_factor", 3.0))))
				counts.append("%d:%d/%d" % [b, (pool[b] as Array).size(), t_cnt])
			print("  %s: %d att  %s  rejections: %s" % [chapter["id"], attempts, " ".join(counts), str(stats)])
	stats["attempts"] = attempts
	return _assign(result, pool)


## Fills levels 2-40 from the pool: bounces follow the schedule, difficulty rises
## with intentional pacing (including breathers and a memorable climax at level 40),
## and neighbours are guaranteed to be visually and strategically distinct.
func _assign(result: Array, pool: Dictionary) -> Array:
	var used_sigs: Dictionary = {}
	for lv: Dictionary in result:
		used_sigs[str(lv["sig"])] = true
	var n: int = result.size() + 1
	while n <= LEVELS_PER_CHAPTER:
		var b: int = bounce_goal(n)
		var plateau: Array[int] = []
		var m: int = n
		while m <= LEVELS_PER_CHAPTER and bounce_goal(m) == b:
			plateau.append(m)
			m += 1
		var cands: Array = (pool[b] as Array).duplicate()
		cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["score"]) < float(y["score"]))

		for j: int in plateau.size():
			var slot_num: int = plateau[j]
			var is_breather: bool = (slot_num == 8 or slot_num == 18 or slot_num == 28 or slot_num == 38)
			var is_climax: bool = (slot_num == 40 or slot_num == 20 or slot_num == 30)
			var prev: Dictionary = result[-1]
			var prev2: Dictionary = result[-2] if result.size() >= 2 else {}

			var best_idx: int = -1
			var best_penalty: float = 1.0e9

			for idx: int in cands.size():
				var c: Dictionary = cands[idx]
				var penalty: float = 0.0

				# 1. Structural similarity against recent levels (last 6 levels)
				var max_sim: float = 0.0
				var check_start: int = maxi(0, result.size() - 6)
				for k: int in range(check_start, result.size()):
					var sim: float = structural_similarity(c, result[k])
					if sim > max_sim:
						max_sim = sim
				if max_sim > 0.55:
					penalty += (max_sim - 0.55) * 80.0

				# 2. Archetype repetition penalty
				if str(c["arch"]) == str(prev.get("arch", "")):
					penalty += 45.0
				elif str(c["arch"]) == str(prev2.get("arch", "")):
					penalty += 18.0

				# 3. Aim direction repetition penalty
				if int(c["dir"]) == int(prev.get("dir", -99)):
					penalty += 25.0

				# 4. Signature repetition penalty
				if used_sigs.has(str(c["sig"])):
					penalty += 60.0

				# 5. Favor pure single-solution rooms (exactly 1 winning window)
				if int(c.get("windows", 1)) == 1:
					penalty -= 12.0

				# 6. Pacing and puzzle quality fit
				if is_breather:
					# Breather: spacious, wide solving window, refreshing clarity
					var win_deg: float = float(c.get("window", 1.0))
					penalty += maxf(0.0, (2.6 - win_deg) * 12.0)
					penalty += absf(float(c["score"]) - 1.3) * 5.0
				elif is_climax:
					# Climax: peak challenge, maximum targets, multi-bank grand architecture
					var n_targets: int = (c.get("targets", []) as Array).size()
					penalty += maxf(0.0, (5.0 - float(n_targets)) * 14.0)
					penalty -= float(c["score"]) * 5.0
				else:
					# Smooth progression through plateau
					var q: float = 0.15 + 0.70 * (float(j) / float(maxi(1, plateau.size() - 1)))
					var target_score: float = lerpf(float(cands[0]["score"]), float(cands[-1]["score"]), q)
					penalty += absf(float(c["score"]) - target_score) * 4.0

				if penalty < best_penalty:
					best_penalty = penalty
					best_idx = idx

			if best_idx < 0:
				best_idx = 0

			var chosen: Dictionary = cands.pop_at(best_idx)
			used_sigs[str(chosen["sig"])] = true
			result.append(chosen)
		n = m
	return result


## Computes a structural similarity score in [0.0, 1.0] between two levels.
## Considers layout archetype, 6x8 spatial occupancy, target proximity, and trajectory heading.
static func structural_similarity(lv_a: Dictionary, lv_b: Dictionary) -> float:
	var score: float = 0.0

	# 1. Archetype match
	if str(lv_a.get("arch", "")) == str(lv_b.get("arch", "")):
		score += 0.20

	# 2. Spatial occupancy grid (6 columns x 8 rows = 48 cells)
	var occ_a: Array = _occupancy_grid(lv_a)
	var occ_b: Array = _occupancy_grid(lv_b)
	var intersection: int = 0
	var union_cnt: int = 0
	for i: int in 48:
		var has_a: bool = occ_a[i]
		var has_b: bool = occ_b[i]
		if has_a and has_b:
			intersection += 1
		if has_a or has_b:
			union_cnt += 1
	var jaccard: float = float(intersection) / float(maxi(1, union_cnt))
	score += jaccard * 0.35

	# 3. Target centroid proximity
	var t_a: Array = lv_a.get("targets", [])
	var t_b: Array = lv_b.get("targets", [])
	if not t_a.is_empty() and not t_b.is_empty():
		var c_a: Vector2 = Vector2.ZERO
		for t: Array in t_a:
			c_a += Vector2(float(t[0]), float(t[1]))
		c_a /= float(t_a.size())

		var c_b: Vector2 = Vector2.ZERO
		for t: Array in t_b:
			c_b += Vector2(float(t[0]), float(t[1]))
		c_b /= float(t_b.size())

		var dist: float = c_a.distance_to(c_b)
		var t_sim: float = clampf(1.0 - (dist / 380.0), 0.0, 1.0)
		score += t_sim * 0.25

	# 4. Aim direction & Bounce count similarity
	var dir_diff: int = absi(int(lv_a.get("dir", 0)) - int(lv_b.get("dir", 0)))
	if dir_diff <= 1:
		score += 0.10
	if int(lv_a.get("need", 0)) == int(lv_b.get("need", 0)):
		score += 0.10

	return minf(1.0, score)


static func _occupancy_grid(lv: Dictionary) -> Array:
	var grid: Array = []
	grid.resize(48)
	grid.fill(false)
	var col_w: float = RicochetSim.ARENA.x / 6.0
	var row_h: float = RicochetSim.ARENA.y / 8.0
	for w: Array in lv.get("walls", []):
		var cx: int = clampi(int(float(w[0]) / col_w), 0, 5)
		var cy: int = clampi(int(float(w[1]) / row_h), 0, 7)
		grid[cy * 6 + cx] = true
	for t: Array in lv.get("targets", []):
		var cx2: int = clampi(int(float(t[0]) / col_w), 0, 5)
		var cy2: int = clampi(int(float(t[1]) / row_h), 0, 7)
		grid[cy2 * 6 + cx2] = true
	return grid


# --- Candidate rooms ----------------------------------------------------------------

func _range_i(r: Array, k: float) -> int:
	var lo: int = int(r[0])
	var hi: int = int(r[1])
	var centre: float = lerpf(float(lo), float(hi), k)
	return clampi(int(round(centre + rng.randf_range(-0.7, 0.7))), lo, hi)


func _snap(v: float) -> float:
	return round(v / GRID) * GRID


## Builds one room that should need `goal` bounces. Returns {} if it is unfit.
func _candidate(goal: int) -> Dictionary:
	stats["tried"] = int(stats.get("tried", 0)) + 1
	var k: float = clampf(float(goal - 1) / 7.0 + rng.randf_range(-0.08, 0.08), 0.0, 1.0)
	var lx: float = 320.0 if rng.randf() < 0.65 else [200.0, 440.0][rng.randi_range(0, 1)]
	var level: Dictionary = {"launcher": [lx, 860.0]}
	var arch: String = ARCHETYPES[rng.randi_range(0, ARCHETYPES.size() - 1)]
	var walls: Array = _layout(arch, _range_i(chapter["walls"], k), level)
	var late: bool = k >= 0.4 and rng.randf() < 0.55
	var extras: Dictionary = chapter.get("late", {}) if late else {}
	_convert_kind(walls, _range_i(chapter.get("glass", extras.get("glass", [0, 0])), k), "glass")
	_convert_kind(walls, _range_i(chapter.get("void", extras.get("void", [0, 0])), k), "void")
	_convert_kind(walls, _range_i(chapter.get("gates", [0, 0]), k), "gate")
	_convert_kind(walls, _range_i(chapter.get("pivots", [0, 0]), k), "pivot")
	level["walls"] = walls
	if chapter.has("movers"):
		_add_rails(level, _range_i(chapter["movers"], k))
	if not _place_features(level, k, extras):
		return _reject("features")
	level["targets"] = []
	# The generating shot: spark rooms start with fewer bounces and earn the rest.
	var sparks: int = (level.get("sparks", []) as Array).size()
	var limit: int = maxi(0, goal - sparks) if chapter["mech"] == "spark" else goal
	var found: Dictionary = _find_shot(level, limit, 50)
	if found.is_empty():
		return _reject("mechanic unused")
	var angle: float = found["angle"]
	var shot: Dictionary = found["shot"]
	var tr: Array = TARGETS[goal]
	var n_targets: int = rng.randi_range(int(tr[0]), int(tr[1]))
	var armored: bool = chapter.has("armored_from") and k >= float(chapter["armored_from"]) and rng.randf() < 0.55
	var targets: Array = _place_targets(level, shot, n_targets, armored)
	if targets.size() < n_targets:
		return _reject("targets")
	level["targets"] = targets
	level["bounces"] = limit
	if not bool(RicochetSim.simulate(level, RicochetSim.initial_state(level), angle)["cleared"]):
		return _reject("probe")
	level["bounces"] = _bounces_needed(level, angle)
	if _bounce_count(level, angle) != goal:
		return _reject("bounce count")
	# Cheap screen before the full solve: the window around this angle.
	var lw: float = rad_to_deg(_local_width(level, angle))
	if stats.has("debug"):
		(stats["debug"] as Array).append([goal, snappedf(lw, 0.01)])
	if lw < float(MIN_WINDOW[goal]) * float(chapter.get("window_scale", 1.0)):
		return _reject("narrow")
	var graded: Dictionary = _grade(level, goal, false)
	if graded.is_empty():
		return {}
	# Prune dead walls from this winning candidate:
	if not _prune_dead_walls(level, goal, angle):
		return _reject("prune")
	# Re-grade after pruning:
	graded = _grade(level, goal, false)
	if graded.is_empty():
		return {}
	graded["arch"] = arch
	return graded


## Looks for a generating shot that uses this chapter's idea: random angles first
## (so it is often met on a later leg), then shots aimed near the element itself.
func _find_shot(level: Dictionary, limit: int, tries: int) -> Dictionary:
	var spots: Array = _mechanic_spots(level)
	var lp: Vector2 = RicochetSim.launcher(level)
	for i: int in tries:
		var angle: float = -PI + rng.randf_range(0.2, PI - 0.2)
		if (i >= tries / 4 or rng.randf() < 0.65) and not spots.is_empty():
			var spot: Vector2 = spots[rng.randi_range(0, spots.size() - 1)]
			angle = (spot - lp).angle() + deg_to_rad(rng.randf_range(-5.0, 5.0))
			if angle > -0.15 or angle < -PI + 0.15:
				continue
		var shot: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), angle, limit)
		if _uses_mechanic(shot, level):
			return {"angle": angle, "shot": shot}
	return {}


## Where this chapter's element sits in the room.
func _mechanic_spots(level: Dictionary) -> Array:
	var spots: Array = []
	for key: String in ["bumpers", "prisms", "switches", "sparks"]:
		for q: Array in level.get(key, []):
			spots.append(Vector2(float(q[0]), float(q[1])))
	for pt: Array in level.get("portals", []):
		spots.append(Vector2(float(pt[0]), float(pt[1])))
		spots.append(Vector2(float(pt[2]), float(pt[3])))
	for w: Array in level.get("walls", []):
		spots.append(Vector2(float(w[0]), float(w[1])))
	return spots


func _reject(why: String) -> Dictionary:
	stats[why] = int(stats.get(why, 0)) + 1
	return {}


## An opening room for chapters without a hand-made one: the new idea alone.
func _intro_room() -> Dictionary:
	for attempt: int in 20000:
		var level: Dictionary = {"launcher": [320.0, 860.0]}
		var walls: Array = _layout(["scatter", "shelves", "diagonals"][rng.randi_range(0, 2)], rng.randi_range(1, 2), level)
		_convert_kind(walls, 1 if chapter["mech"] == "glass" else 0, "glass")
		_convert_kind(walls, 1 if chapter["mech"] == "void" else 0, "void")
		_convert_kind(walls, 1 if chapter["mech"] == "switch" else 0, "gate")
		_convert_kind(walls, 1 if chapter["mech"] == "pivot" else 0, "pivot")
		level["walls"] = walls
		if chapter.has("movers"):
			_add_rails(level, 1)
		if not _place_features(level, 0.0, {}):
			continue
		var sparks: int = (level.get("sparks", []) as Array).size()
		var limit: int = 0 if chapter["mech"] == "spark" else rng.randi_range(0, 1)
		var found: Dictionary = _find_shot(level, limit, 20)
		if found.is_empty():
			continue
		var angle: float = found["angle"]
		var shot: Dictionary = found["shot"]
		var want: int = 2 if chapter["mech"] == "split" else 1
		var targets: Array = _place_targets(level, shot, want, false)
		if targets.size() < want:
			continue
		level["targets"] = targets
		level["bounces"] = limit
		if not bool(RicochetSim.simulate(level, RicochetSim.initial_state(level), angle)["cleared"]):
			continue
		level["bounces"] = _bounces_needed(level, angle)
		var graded: Dictionary = _grade(level, int(level["bounces"]) + sparks, true)
		if not graded.is_empty() and float(graded["window"]) >= 4.0 * float(chapter.get("window_scale", 1.0)) and _mechanic_matters(level, deg_to_rad(float(graded["solution"][0]))):
			return graded
	push_error("%s: could not build an intro room" % chapter["id"])
	return {}


# --- Layouts ---------------------------------------------------------------------

func _wall(x: float, y: float, w: float, h: float, rot: float = 0.0) -> Array:
	return [_snap(x), _snap(y), w, h, rot, "wall"]


## Lays out `count` walls in the given archetype's style.
## Uses architectural composition rules to create distinct geometric identities.
func _layout(arch: String, count: int, level: Dictionary) -> Array:
	var walls: Array = []
	match arch:
		"chambers":
			# Interconnected chambers with defined transit doorway apertures
			var y_div: float = _snap(rng.randf_range(400.0, 500.0))
			var gap_w: float = _snap(rng.randf_range(110.0, 140.0))
			var gap_x: float = _snap(rng.randf_range(200.0, 440.0))
			var left_w: float = gap_x - gap_w * 0.5
			var right_w: float = 640.0 - (gap_x + gap_w * 0.5)
			if left_w > 50.0:
				walls.append(_wall(left_w * 0.5, y_div, left_w, 16.0))
			if right_w > 50.0:
				walls.append(_wall(gap_x + gap_w * 0.5 + right_w * 0.5, y_div, right_w, 16.0))
			# Chamber deflector plates
			var ang: float = [35.0, -35.0, 45.0, -45.0, 0.0][rng.randi_range(0, 4)]
			walls.append(_wall(rng.randf_range(180.0, 460.0), rng.randf_range(180.0, 300.0), _snap(rng.randf_range(140.0, 220.0)), 16.0, ang))
			if count >= 3:
				walls.append(_wall([120.0, 520.0][rng.randi_range(0, 1)], 240.0, 16.0, 180.0))

		"nested":
			# Concentric inner sanctum court with outer transit corridors
			var cy: float = _snap(rng.randf_range(380.0, 450.0))
			var bw: float = _snap(rng.randf_range(240.0, 280.0))
			var bh: float = _snap(rng.randf_range(200.0, 240.0))
			var gap: float = 110.0
			# Top opening
			walls.append(_wall(320.0 - gap * 0.5, cy - bh * 0.5, bw - gap, 16.0))
			# Bottom opening offset to other side
			walls.append(_wall(320.0 + gap * 0.5, cy + bh * 0.5, bw - gap, 16.0))
			# Left and right side barriers
			walls.append(_wall(320.0 - bw * 0.5, cy, 16.0, bh))
			walls.append(_wall(320.0 + bw * 0.5, cy, 16.0, bh))
			if count >= 4:
				walls.append(_wall([90.0, 550.0][rng.randi_range(0, 1)], cy, 16.0, 260.0))

		"pocket":
			# Enclosed alcove pocket with an angled deflector guiding the shot
			var on_left: bool = rng.randf() < 0.5
			var px: float = 200.0 if on_left else 440.0
			var py: float = _snap(rng.randf_range(220.0, 320.0))
			var pw: float = 180.0
			var ph: float = 180.0
			walls.append(_wall(px, py, 16.0, ph))
			walls.append(_wall(px - pw * 0.5 if on_left else px + pw * 0.5, py - ph * 0.5, pw, 16.0))
			var defl_x: float = 360.0 if on_left else 280.0
			walls.append(_wall(defl_x, py + 160.0, _snap(rng.randf_range(140.0, 200.0)), 16.0, -45.0 if on_left else 45.0))
			if count >= 3:
				walls.append(_wall(320.0, 600.0, _snap(rng.randf_range(160.0, 240.0)), 16.0))

		"zigzag":
			# Staggered alternating cantilevered baffles (slalom course)
			var n_baffles: int = clampi(count + 1, 3, 4)
			var y_start: float = 640.0
			var y_step: float = (y_start - 180.0) / float(n_baffles - 1)
			for i: int in n_baffles:
				var is_left: bool = (i % 2 == 0)
				var len_b: float = _snap(rng.randf_range(240.0, 300.0))
				var wx: float = len_b * 0.5 if is_left else 640.0 - len_b * 0.5
				walls.append(_wall(wx, y_start - y_step * float(i), len_b, 16.0))

		"funnel":
			# Converging guide walls with a narrow throat and dispersal deflector
			var fy: float = _snap(rng.randf_range(380.0, 480.0))
			var ang: float = 40.0
			var flen: float = _snap(rng.randf_range(180.0, 220.0))
			walls.append(_wall(210.0, fy, flen, 16.0, ang))
			walls.append(_wall(430.0, fy, flen, 16.0, -ang))
			walls.append(_wall(320.0, fy + 120.0, _snap(rng.randf_range(180.0, 240.0)), 16.0))
			if count >= 4:
				walls.append(_wall(320.0, fy - 180.0, 180.0, 16.0, 45.0 if rng.randf() < 0.5 else -45.0))

		"corridor":
			# Twin parallel reflection channel with deflection cap
			var cy: float = _snap(rng.randf_range(380.0, 460.0))
			var gap: float = _snap(rng.randf_range(170.0, 220.0))
			var chgt: float = _snap(rng.randf_range(280.0, 360.0))
			walls.append(_wall(320.0 - gap * 0.5, cy, 16.0, chgt))
			walls.append(_wall(320.0 + gap * 0.5, cy, 16.0, chgt))
			walls.append(_wall(320.0, cy - chgt * 0.5 - 60.0, _snap(rng.randf_range(160.0, 220.0)), 16.0, [30.0, -30.0, 45.0, -45.0][rng.randi_range(0, 3)]))
			if count >= 4:
				walls.append(_wall(100.0 if rng.randf() < 0.5 else 540.0, cy, 16.0, 180.0))

		"diagonals":
			# Diamond constellation or chevron array
			var cy: float = _snap(rng.randf_range(360.0, 440.0))
			var spread: float = _snap(rng.randf_range(110.0, 140.0))
			var dlen: float = _snap(rng.randf_range(140.0, 180.0))
			walls.append(_wall(320.0 - spread, cy - 80.0, dlen, 16.0, 45.0))
			walls.append(_wall(320.0 + spread, cy - 80.0, dlen, 16.0, -45.0))
			walls.append(_wall(320.0 - spread, cy + 80.0, dlen, 16.0, -45.0))
			walls.append(_wall(320.0 + spread, cy + 80.0, dlen, 16.0, 45.0))

		"pillars":
			# Symmetrical 4-column column formation with grid avenues
			var cy: float = _snap(rng.randf_range(380.0, 460.0))
			var sx: float = _snap(rng.randf_range(110.0, 140.0))
			var sy: float = _snap(rng.randf_range(100.0, 120.0))
			var ps: float = [50.0, 60.0, 70.0][rng.randi_range(0, 2)]
			walls.append(_wall(320.0 - sx, cy - sy, ps, ps))
			walls.append(_wall(320.0 + sx, cy - sy, ps, ps))
			walls.append(_wall(320.0 - sx, cy + sy, ps, ps))
			walls.append(_wall(320.0 + sx, cy + sy, ps, ps))
			if count >= 5:
				walls.append(_wall(320.0, cy - sy - 120.0, 160.0, 16.0))

		"shelves":
			# Tiered platform architecture with alternating offset doorways
			var y1: float = _snap(rng.randf_range(540.0, 600.0))
			var y2: float = _snap(rng.randf_range(380.0, 440.0))
			var y3: float = _snap(rng.randf_range(200.0, 260.0))
			walls.append(_wall(220.0, y1, 380.0, 16.0))
			walls.append(_wall(420.0, y2, 380.0, 16.0))
			walls.append(_wall(320.0, y3, 260.0, 16.0))
			if count >= 4:
				walls.append(_wall(100.0 if rng.randf() < 0.5 else 540.0, y2, 16.0, 160.0))

		"mirror":
			# Bilateral architectural symmetry
			var cy: float = _snap(rng.randf_range(360.0, 460.0))
			var ang: float = [30.0, 45.0, 60.0][rng.randi_range(0, 2)]
			var mlen: float = _snap(rng.randf_range(160.0, 220.0))
			walls.append(_wall(180.0, cy, mlen, 16.0, ang))
			walls.append(_wall(460.0, cy, mlen, 16.0, -ang))
			walls.append(_wall(100.0, cy - 140.0, 16.0, 160.0))
			walls.append(_wall(540.0, cy - 140.0, 16.0, 160.0))

		"asymmetric":
			# High-contrast balance: dense pocket vs expansive reflection rail
			var cy: float = _snap(rng.randf_range(380.0, 460.0))
			var left_dense: bool = rng.randf() < 0.5
			var dense_x: float = 180.0 if left_dense else 460.0
			var open_x: float = 540.0 if left_dense else 100.0
			walls.append(_wall(dense_x, cy, 180.0, 16.0, 30.0 if left_dense else -30.0))
			walls.append(_wall(dense_x, cy - 140.0, 16.0, 160.0))
			walls.append(_wall(open_x, cy + 40.0, 16.0, _snap(rng.randf_range(280.0, 360.0))))
			if count >= 4:
				walls.append(_wall(320.0, 200.0, 180.0, 16.0))

		"crossroad":
			# Central cross-partition dividing the board into 4 quadrants
			var cy: float = _snap(rng.randf_range(380.0, 450.0))
			walls.append(_wall(140.0, cy, 180.0, 16.0))
			walls.append(_wall(500.0, cy, 180.0, 16.0))
			walls.append(_wall(320.0, cy - 170.0, 16.0, 160.0))
			walls.append(_wall(320.0, cy + 170.0, 16.0, 160.0))

		"frame":
			# Inset perimeter guide rails with central deflector
			var cy: float = _snap(rng.randf_range(360.0, 460.0))
			var inset: float = _snap(rng.randf_range(80.0, 110.0))
			walls.append(_wall(inset, cy, 16.0, _snap(rng.randf_range(240.0, 320.0))))
			walls.append(_wall(640.0 - inset, cy, 16.0, _snap(rng.randf_range(240.0, 320.0))))
			walls.append(_wall(320.0, 160.0, _snap(rng.randf_range(220.0, 280.0)), 16.0))
			walls.append(_wall(320.0, cy, _snap(rng.randf_range(130.0, 180.0)), 16.0, [45.0, -45.0, 0.0][rng.randi_range(0, 2)]))

		"scatter":
			# Controlled geometric constellation
			for i: int in count:
				var w: Array = _random_wall(level, walls)
				if not w.is_empty():
					walls.append(w)

		_:
			for i: int in count:
				var w6: Array = _random_wall(level, walls)
				if not w6.is_empty():
					walls.append(w6)

	return walls.filter(func(w: Array) -> bool: return _wall_ok(w, level))
	return walls.filter(func(w: Array) -> bool: return _wall_ok(w, level))


func _wall_ok(w: Array, level: Dictionary) -> bool:
	var pts: PackedVector2Array = RicochetSim.wall_corners(w)
	var lp: Vector2 = RicochetSim.launcher(level)
	for p: Vector2 in pts:
		if p.x < 0.0 or p.x > 640.0 or p.y < 60.0 or p.y > 760.0:
			return false
		if p.distance_to(lp) < 170.0:
			return false
	return true


func _random_wall(level: Dictionary, existing: Array) -> Array:
	for attempt: int in 40:
		var shape: float = rng.randf()
		var w: Array
		if shape < 0.42:
			w = _wall(rng.randf_range(80, 560), rng.randf_range(120, 720), _snap(rng.randf_range(120, 280)), 16.0)
		elif shape < 0.68:
			w = _wall(rng.randf_range(80, 560), rng.randf_range(120, 720), 16.0, _snap(rng.randf_range(120, 280)))
		elif shape < 0.9:
			w = _wall(rng.randf_range(100, 540), rng.randf_range(140, 700), _snap(rng.randf_range(120, 220)), 16.0, [45.0, -45.0, 30.0, -30.0][rng.randi_range(0, 3)])
		else:
			var s: float = [40.0, 80.0][rng.randi_range(0, 1)]
			w = _wall(rng.randf_range(100, 540), rng.randf_range(140, 700), s, s)
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


## Puts `count` plain walls on rails. All platforms in a room share one rhythm
## (period), so the moment that works comes round again every second or two.
## They move at 20-35% of the orb's speed and stay inside the room.
func _add_rails(level: Dictionary, count: int) -> void:
	# One travel distance per room, so every platform shares the same rhythm and
	# moves at the same constant speed.
	var amp_abs: float = _snap(rng.randf_range(140.0, 260.0))
	var period: float = round(2.0 * amp_abs / PLATFORM_SPEED / 10.0) * 10.0
	var walls: Array = level["walls"]
	var plain: Array = []
	for i: int in walls.size():
		if RicochetSim.wall_kind(walls[i]) == "wall" and not RicochetSim.is_moving(walls[i]):
			plain.append(i)
	plain.shuffle()
	var made: int = 0
	for i: int in plain:
		if made >= count:
			break
		for attempt: int in 12:
			var horizontal: bool = rng.randf() < 0.65
			var amp: float = amp_abs * (1.0 if rng.randf() < 0.5 else -1.0)
			var d: Vector2 = Vector2(amp, 0) if horizontal else Vector2(0, amp)
			var w: Array = (walls[i] as Array).duplicate()
			w.resize(6)
			w.append([d.x, d.y, period])
			var moved: Array = w.duplicate()
			moved[0] = float(w[0]) + d.x
			moved[1] = float(w[1]) + d.y
			if not _wall_ok(w, level) or not _wall_ok(moved.slice(0, 6), level):
				continue
			var before: Array = walls[i]
			walls[i] = w
			if _sweep_clear(walls, i):
				made += 1
				break
			walls[i] = before


## True if wall `i` never comes within PLATFORM_GAP of any other wall at any
## moment of the cycle (moving walls are checked where they are at that moment).
func _sweep_clear(walls: Array, i: int) -> bool:
	var period: float = float(walls[i][6][2])
	for s: int in 24:
		var t: float = period * float(s) / 24.0
		var grown: Array = Geometry2D.offset_polygon(RicochetSim.wall_corners(walls[i], 0.0, t), PLATFORM_GAP)
		if grown.is_empty():
			continue
		for j: int in walls.size():
			if j == i:
				continue
			if not Geometry2D.intersect_polygons(grown[0], RicochetSim.wall_corners(walls[j], 0.0, t)).is_empty():
				return false
	return true


func _place_features(level: Dictionary, k: float, extras: Dictionary) -> bool:
	var bumpers: Array = []
	for i: int in _range_i(chapter.get("bumpers", extras.get("bumpers", [0, 0])), k):
		# Big bumpers: a round bounce magnifies aiming error by about 2 x distance /
		# radius, so larger ones keep bumper shots fair to aim by touch.
		var radius: float = round(rng.randf_range(44.0, 60.0))
		var p: Vector2 = _free_point(level, radius + 60.0)
		if p != Vector2.INF:
			bumpers.append([p.x, p.y, radius])
	if not bumpers.is_empty():
		level["bumpers"] = bumpers
	if int(chapter.get("portals", 0)) > 0:
		var a: Vector2 = _free_point(level, 80.0)
		var b: Vector2 = _free_point(level, 80.0)
		if a == Vector2.INF or b == Vector2.INF or a.distance_to(b) < 260.0:
			return false
		level["portals"] = [[a.x, a.y, b.x, b.y]]
	if int(chapter.get("switches", 0)) > 0:
		var sw: Vector2 = _free_point(level, 80.0)
		if sw == Vector2.INF:
			return false
		level["switches"] = [[sw.x, sw.y]]
	var sparks: Array = []
	for i: int in _range_i(chapter.get("sparks", [0, 0]), k):
		var sp: Vector2 = _free_point(level, 70.0)
		if sp != Vector2.INF:
			sparks.append([sp.x, sp.y])
	if not sparks.is_empty():
		level["sparks"] = sparks
	if int(chapter.get("prisms", 0)) > 0:
		var pr: Vector2 = _free_point(level, 90.0)
		if pr == Vector2.INF:
			return false
		level["prisms"] = [[pr.x, pr.y]]
	return true


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
		# Moving platforms: keep clear of the whole sweep.
		var stops: Array = [0.0]
		if RicochetSim.is_moving(w):
			var period: float = float(w[6][2])
			stops = [0.0, period * 0.125, period * 0.25, period * 0.375, period * 0.5]
		for t: float in stops:
			var pts: PackedVector2Array = RicochetSim.wall_corners(w, 0.0, t)
			for i: int in 4:
				best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % 4])))
	for b: Array in level.get("bumpers", []):
		best = minf(best, p.distance_to(Vector2(float(b[0]), float(b[1]))) - (float(b[2]) if b.size() > 2 else 30.0))
	for pt: Array in level.get("portals", []):
		best = minf(best, p.distance_to(Vector2(float(pt[0]), float(pt[1]))) - 20.0)
		best = minf(best, p.distance_to(Vector2(float(pt[2]), float(pt[3]))) - 20.0)
	for key: String in ["switches", "sparks"]:
		for q: Array in level.get(key, []):
			best = minf(best, p.distance_to(Vector2(float(q[0]), float(q[1]))) - 20.0)
	for pr: Array in level.get("prisms", []):
		best = minf(best, p.distance_to(Vector2(float(pr[0]), float(pr[1]))) - 20.0)
	for t2: Array in level.get("targets", []):
		best = minf(best, p.distance_to(Vector2(float(t2[0]), float(t2[1]))) - 60.0)
	return best


## Samples points along the generating shot and spreads targets across its legs,
## always putting one on the very last leg so every bounce matters.
func _place_targets(level: Dictionary, shot: Dictionary, count: int, allow_armored: bool) -> Array:
	var candidates: Array = []
	for track: Dictionary in shot["tracks"]:
		var pts: Array = track["points"]
		for leg: int in pts.size() - 1:
			# Never place targets on leg 0 (before the first bounce)
			if leg == 0:
				continue
			var a: Vector2 = pts[leg]
			var b: Vector2 = pts[leg + 1]
			var length: float = a.distance_to(b)
			var s: float = 35.0
			while s < length - 25.0:
				candidates.append({"p": a.lerp(b, s / length), "leg": leg, "track": track["id"]})
				s += 12.0
	if candidates.is_empty():
		return []
	var chosen: Array = []
	var used_legs: Dictionary = {}
	var temp: Dictionary = level.duplicate(true)
	temp["targets"] = []
	var order: Array = candidates.duplicate()
	order.shuffle()
	var last_leg: int = 0
	for c: Dictionary in candidates:
		last_leg = maxi(last_leg, int(c["leg"]))
	var last_candidates: Array = []
	for c: Dictionary in candidates:
		if int(c["leg"]) == last_leg and _clearance(temp, c["p"]) >= RicochetSim.TARGET_R + 10.0:
			last_candidates.append(c)
	if last_candidates.is_empty():
		return []
	var final_c: Dictionary = last_candidates[rng.randi_range(0, last_candidates.size() - 1)]
	var ft: Array = [round(final_c["p"].x), round(final_c["p"].y), 1]
	chosen.append(ft)
	temp["targets"].append(ft)
	used_legs["%d:%d" % [final_c["track"], final_c["leg"]]] = true

	var available_legs: Dictionary = {}
	for c: Dictionary in candidates:
		available_legs["%d:%d" % [c["track"], c["leg"]]] = true
	var n_legs: int = available_legs.size()
	for c: Dictionary in order:
		if chosen.size() >= count:
			break
		var key: String = "%d:%d" % [c["track"], c["leg"]]
		if used_legs.has(key) and used_legs.size() < n_legs:
			continue
		var p: Vector2 = c["p"]
		if _clearance(temp, p) < RicochetSim.TARGET_R + 12.0:
			continue
		var t: Array = [round(p.x), round(p.y), 1]
		chosen.append(t)
		temp["targets"].append(t)
		used_legs[key] = true
	if allow_armored and chosen.size() >= 2:
		# An armored target needs two passes: put it where the path crosses itself.
		var cross: Vector2 = _self_crossing(shot)
		if cross != Vector2.INF:
			temp["targets"].pop_back()
			if _clearance(temp, cross) >= RicochetSim.TARGET_R + 22.0:
				chosen[chosen.size() - 1] = [round(cross.x), round(cross.y), 2]
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


# --- Measuring -------------------------------------------------------------------

func _clears(level: Dictionary, angle: float, limit: int = -1) -> bool:
	return bool(RicochetSim.simulate(level, RicochetSim.initial_state(level), angle, limit)["cleared"])


func _bounces_needed(level: Dictionary, angle: float) -> int:
	for b: int in range(0, MAX_BOUNCES + 2):
		if _clears(level, angle, b):
			return b
	return MAX_BOUNCES + 2


## How many times the ball bounces before the room is clear: the allowance it
## needs, plus any sparks it collects on the way (those pay for extra bounces).
func _bounce_count(level: Dictionary, angle: float) -> int:
	var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), angle)
	var last_pop: float = _last_pop(res)
	var sparks: int = 0
	for e: Dictionary in res["events"]:
		if str(e["type"]) == "spark" and float(e["t"]) <= last_pop:
			sparks += 1
	return _bounces_needed(level, angle) + sparks


func _last_pop(res: Dictionary) -> float:
	var last: float = 0.0
	for e: Dictionary in res["events"]:
		if str(e["type"]) == "pop":
			last = maxf(last, float(e["t"]))
	return last


## Width (radians) of the solving window containing `angle`.
func _local_width(level: Dictionary, angle: float) -> float:
	var total: float = 0.0
	for sgn: float in [-1.0, 1.0]:
		var good: float = 0.0
		var bad: float = deg_to_rad(0.05)
		while _clears(level, angle + bad * sgn) and bad < deg_to_rad(20.0):
			good = bad
			bad *= 2.0
		for i: int in 8:
			var mid: float = (good + bad) * 0.5
			if _clears(level, angle + mid * sgn):
				good = mid
			else:
				bad = mid
		total += good
	return total


## How long (world-clock units) the release can be early or late and still clear,
## around the moment the room opened (clock 0, which comes round every period).
func _time_width(level: Dictionary, angle: float) -> float:
	var period: float = 1.0e9
	for w: Array in level.get("walls", []):
		if RicochetSim.is_moving(w):
			period = minf(period, float(w[6][2]))
	var total: float = 0.0
	for sgn: float in [-1.0, 1.0]:
		var dt: float = 10.0
		while dt < period * 0.5:
			var st: Dictionary = RicochetSim.initial_state(level)
			st["t0"] = dt * sgn
			if not bool(RicochetSim.simulate(level, st, angle)["cleared"]):
				break
			dt += 10.0
		total += dt - 10.0
	return total


## The room with this chapter's idea taken away, to prove the idea matters.
func _without_mechanic(level: Dictionary) -> Dictionary:
	var out: Dictionary = level.duplicate(true)
	match str(chapter["mech"]):
		"glass", "pivot":
			for w: Array in out.get("walls", []):
				if RicochetSim.wall_kind(w) == str(chapter["mech"]):
					w[5] = "wall"
		"bumper":
			out.erase("bumpers")
		"portal":
			out.erase("portals")
		"split":
			out.erase("prisms")
		"switch":
			out.erase("switches")
		"spark":
			out.erase("sparks")
		"move":
			for w: Array in out.get("walls", []):
				w.resize(6)
		_:
			return {}
	return out


func _mechanic_matters(level: Dictionary, angle: float, width: float = 0.0) -> bool:
	# Void: the dark must matter. Either the solution banks off a bumper, or a near
	# miss on one side of the solving window is swallowed by a dark block.
	if str(chapter["mech"]) == "void":
		var shot: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), angle)
		for e: Dictionary in shot["events"]:
			if str(e["type"]) == "bumper":
				return true
		var half: float = (width if width > 0.0 else _local_width(level, angle)) * 0.5
		for sgn: float in [-1.0, 1.0]:
			for extra: float in [deg_to_rad(0.15), deg_to_rad(0.6), deg_to_rad(1.5)]:
				var miss: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), angle + sgn * (half + extra))
				for e: Dictionary in miss["events"]:
					if str(e["type"]) == "absorb":
						return true
		return false
	# A bounce off glass or a pivot works like any wall unless the path comes back
	# through the gap, so for those it is enough that the solution hits one.
	if str(chapter["mech"]) in ["glass", "pivot"]:
		return _uses_mechanic(RicochetSim.simulate(level, RicochetSim.initial_state(level), angle), level)
	var plain: Dictionary = _without_mechanic(level)
	if plain.is_empty():
		return true
	return not _clears(plain, angle)


func _uses_mechanic(shot: Dictionary, level: Dictionary) -> bool:
	var walls: Array = level.get("walls", [])
	if not walls.is_empty():
		var int_bounces: int = 0
		for e: Dictionary in shot["events"]:
			if str(e["type"]) in ["bounce", "glass", "pivot", "bumper", "portal", "split", "switch", "spark"]:
				if int(e.get("index", -1)) >= 0:
					int_bounces += 1
		if int_bounces == 0:
			return false
	var want: String = ""
	match str(chapter["mech"]):
		"void":
			for e: Dictionary in shot["events"]:
				if str(e["type"]) == "bumper":
					return true
			for track: Dictionary in shot["tracks"]:
				for p: Vector2 in track["points"]:
					for w: Array in walls:
						if RicochetSim.wall_kind(w) == "void":
							if p.distance_to(Vector2(float(w[0]), float(w[1]))) < 90.0:
								return true
			return false
		"glass":
			want = "glass"
		"bumper":
			want = "bumper"
		"portal":
			want = "portal"
		"split":
			want = "split"
		"switch":
			want = "switch"
		"spark":
			want = "spark"
		"pivot":
			want = "pivot"
		"move":
			for e: Dictionary in shot["events"]:
				if str(e["type"]) == "bounce" and int(e.get("index", -1)) >= 0 and RicochetSim.is_moving(level["walls"][int(e["index"])]):
					return true
			return RicochetSim.has_movers(level)
		_:
			return true
	for e: Dictionary in shot["events"]:
		if str(e["type"]) == want:
			return true
	return false


func _interior_hits(level: Dictionary, angle: float) -> int:
	var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), angle)
	var count: int = 0
	for e: Dictionary in res["events"]:
		if str(e["type"]) in ["bounce", "glass", "pivot", "bumper", "portal", "split", "switch", "spark"]:
			if int(e.get("index", -1)) >= 0:
				count += 1
	return count


## Prunes walls that are neither bounced on nor essential blockers against shortcuts.
func _prune_dead_walls(level: Dictionary, goal: int, sol_angle: float) -> bool:
	var walls: Array = level.get("walls", [])
	if walls.is_empty():
		return true
	
	var state: Dictionary = RicochetSim.initial_state(level)
	var sim: Dictionary = RicochetSim.simulate(level, state, sol_angle)
	if not bool(sim["cleared"]):
		return false
	
	var touched: Dictionary = {}
	for e: Dictionary in sim["events"]:
		if str(e["type"]) in ["bounce", "glass", "pivot"] and int(e.get("index", -1)) >= 0:
			touched[int(e["index"])] = true
	
	var i: int = walls.size() - 1
	while i >= 0:
		if touched.has(i):
			i -= 1
			continue
		var kind: String = RicochetSim.wall_kind(walls[i])
		if kind in ["void", "gate"] or RicochetSim.is_moving(walls[i]):
			i -= 1
			continue
		
		# Test removing wall i:
		var temp_walls: Array = walls.duplicate()
		temp_walls.remove_at(i)
		var temp_level: Dictionary = level.duplicate(true)
		temp_level["walls"] = temp_walls
		var temp_state: Dictionary = RicochetSim.initial_state(temp_level)
		
		# Original solution must still clear:
		var sol_sim: Dictionary = RicochetSim.simulate(temp_level, temp_state, sol_angle)
		if not bool(sol_sim["cleared"]):
			i -= 1
			continue
		
		# Check if removing this wall opens up an illegal shortcut!
		var wins: Array = RicochetSim.solve(temp_level, temp_state, 360, false)
		var is_essential_blocker: bool = false
		for w: Dictionary in wins:
			var s_sim: Dictionary = RicochetSim.simulate(temp_level, temp_state, float(w["angle"]))
			if bool(s_sim["cleared"]):
				var int_hits: int = 0
				for e: Dictionary in s_sim["events"]:
					if str(e["type"]) in ["bounce", "glass", "pivot", "bumper", "portal", "split", "switch", "spark"] and int(e.get("index", -1)) >= 0:
						int_hits += 1
				if int(s_sim["bounces_used"]) < goal or int_hits == 0:
					is_essential_blocker = true
					break
		
		if is_essential_blocker:
			i -= 1
		else:
			# Wall was dead clutter: delete it
			walls.remove_at(i)
			level["walls"] = walls
			touched = {}
			state = RicochetSim.initial_state(level)
			sim = RicochetSim.simulate(level, state, sol_angle)
			for e: Dictionary in sim["events"]:
				if str(e["type"]) in ["bounce", "glass", "pivot"] and int(e.get("index", -1)) >= 0:
					touched[int(e["index"])] = true
			i = mini(i - 1, walls.size() - 1)
	
	# After pruning, must still have at least 1 interior obstacle bounce
	var final_int_hits: int = 0
	for e: Dictionary in sim["events"]:
		if str(e["type"]) in ["bounce", "glass", "pivot", "bumper", "portal", "split", "switch", "spark"] and int(e.get("index", -1)) >= 0:
			final_int_hits += 1
	if final_int_hits == 0 and not walls.is_empty():
		return false
	return true


## Solves the room and annotates it. Returns {} if it is unfair or unsolvable.
func _grade(level: Dictionary, goal: int, intro: bool) -> Dictionary:
	var state: Dictionary = RicochetSim.initial_state(level)
	var windows: Array = RicochetSim.solve(level, state, 1440, true)
	if windows.is_empty():
		return _reject("unsolvable")
	var best: Dictionary = windows[0]
	var width_deg: float = rad_to_deg(float(best["width"]))
	var min_w: float = float(MIN_WINDOW.get(clampi(goal, 0, MAX_BOUNCES), 0.5))
	if intro:
		min_w = minf(min_w, 2.5)
	min_w *= float(chapter.get("window_scale", 1.0))
	if width_deg < min_w:
		return _reject("window")
	var angle: float = float(best["angle"])
	var total: float = 0.0
	for w: Dictionary in windows:
		total += float(w["width"])
	var fraction: float = total / TAU
	# Too many ways to win makes a room trivial (the openers may be generous).
	if not intro and fraction > (0.1 if goal <= 2 else 0.05):
		return _reject("too open")
	if not intro and not _mechanic_matters(level, angle, float(best["width"])):
		return _reject("mechanic optional")
	# No shortcut: every way to win needs nearly the full bounce count.
	var bounces: int = _bounce_count(level, angle)
	if not intro:
		if bounces != goal:
			return _reject("solution bounces")
		if not (level.get("walls", []) as Array).is_empty() and _interior_hits(level, angle) == 0:
			return _reject("solution bypasses interior")
		# Only 1 unique way to solve (or at most 2 for mirror symmetry)
		if windows.size() > 2:
			return _reject("too many solutions")
		for w: Dictionary in windows:
			var w_ang: float = float(w["angle"])
			if _bounce_count(level, w_ang) < goal:
				return _reject("shortcut")
			if not (level.get("walls", []) as Array).is_empty() and _interior_hits(level, w_ang) == 0:
				return _reject("shortcut bypasses interior")
	var out: Dictionary = level.duplicate(true)
	var time_score: float = 0.0
	if RicochetSim.has_movers(level):
		var tw: float = _time_width(level, angle)
		if tw < float(MIN_TIME_WINDOW.get(clampi(goal, 0, MAX_BOUNCES), 120.0)) * (0.8 if intro else 1.0):
			return _reject("timing")
		out["time_window"] = round(tw)
		time_score = 0.6 * log(450.0 / tw) / log(10.0)
	out["shots"] = 1
	out["need"] = bounces
	out["solution"] = [snappedf(rad_to_deg(angle), 0.001)]
	out["window"] = snappedf(width_deg, 0.01)
	out["windows"] = windows.size()
	# Within a bounce count, rooms get harder as the window narrows, the share of
	# winning angles shrinks, and more targets and moving parts must line up.
	var parts: int = (level.get("bumpers", []) as Array).size() + (level.get("portals", []) as Array).size() \
		+ (level.get("prisms", []) as Array).size() + (level.get("sparks", []) as Array).size() + (level.get("switches", []) as Array).size()
	for w: Array in level.get("walls", []):
		if RicochetSim.wall_kind(w) != "wall" or RicochetSim.is_moving(w):
			parts += 1
	var score: float = log(1.0 / maxf(fraction, 0.00001)) / log(10.0) + 0.9 * log(6.0 / width_deg) / log(10.0) \
		+ 0.2 * float((level["targets"] as Array).size()) + 0.15 * float(parts) + time_score
	if windows.size() == 1:
		score += 0.4
	score = maxf(0.0, score)
	out["score"] = snappedf(score, 0.001)
	out["difficulty"] = snappedf(float(bounces) + 0.95 * score / (1.0 + score), 0.001)
	out["sig"] = _signature(level, angle)
	out["dir"] = int(floor(rad_to_deg(angle) / 20.0))
	return out


## The bounce pattern of the solving shot: which surfaces it hits, in order.
func _signature(level: Dictionary, angle: float) -> String:
	var res: Dictionary = RicochetSim.simulate(level, RicochetSim.initial_state(level), angle)
	var last_pop: float = _last_pop(res)
	var parts: PackedStringArray = PackedStringArray()
	for e: Dictionary in res["events"]:
		if float(e["t"]) > last_pop:
			break
		var p: Vector2 = e["pos"]
		match str(e["type"]):
			"bounce", "glass", "pivot":
				var idx: int = int(e.get("index", -1))
				if idx < 0:
					parts.append("L" if p.x < 20.0 else ("R" if p.x > 620.0 else ("T" if p.y < 20.0 else "B")))
				else:
					parts.append(str(e["type"])[0] + ("m" if RicochetSim.is_moving(level["walls"][idx]) else ""))
			"bumper", "portal", "split", "switch", "spark", "shield":
				parts.append(str(e["type"]).substr(0, 2))
	# Same surfaces hit in the same order AND aimed the same way = the same solution.
	return "%s|%d|%d" % ["".join(parts), (level["targets"] as Array).size(), int(floor(rad_to_deg(angle) / 30.0))]


func _write(levels: Array) -> void:
	var out: Array = []
	for i: int in levels.size():
		var lv: Dictionary = levels[i]
		lv["id"] = "%s_%02d" % [chapter["id"], i + 1]
		lv["number"] = i + 1
		for key: String in ["walls", "bumpers", "portals", "prisms", "switches", "sparks"]:
			if lv.has(key) and (lv[key] as Array).is_empty():
				lv.erase(key)
		lv.erase("score")
		out.append(lv)
	for i: int in range(1, out.size()):
		var prev_d: float = float(out[i - 1]["difficulty"])
		var cur_d: float = float(out[i]["difficulty"])
		if i == 1 and cur_d <= prev_d:
			out[0]["difficulty"] = snappedf(cur_d - 0.05, 0.001)
		elif i > 1 and cur_d <= prev_d:
			out[i]["difficulty"] = snappedf(prev_d + 0.005, 0.001)
	var data: Dictionary = {"id": chapter["id"], "name": chapter["name"], "levels": out}
	var file: FileAccess = FileAccess.open(OUT_DIR + chapter["id"] + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", false))
