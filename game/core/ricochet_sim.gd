class_name RicochetSim
extends RefCounted
## Deterministic, event-driven ricochet simulation.
##
## The same code drives gameplay playback, the aim preview, hints, the level
## generator and the tests, so what the player sees is exactly what is solvable.
## Orbs travel at a constant speed, so "time" is measured in travelled distance.

const ARENA: Vector2 = Vector2(640, 960)
const ORB_R: float = 10.0
const TARGET_R: float = 22.0
const PORTAL_R: float = 20.0
const PRISM_R: float = 18.0
const BUMPER_R: float = 30.0
const SWITCH_R: float = 18.0
const SPARK_R: float = 16.0
const SPLIT_ANGLE: float = 0.5585  # 32 degrees either side
const MAX_EVENTS: int = 360
const MAX_TRAVEL: float = 14000.0
const INF: float = 1.0e20

const KIND_WALL: String = "wall"
const KIND_GLASS: String = "glass"
const KIND_VOID: String = "void"
## Solid until any switch is hit, then gone for the rest of the attempt.
const KIND_GATE: String = "gate"
## Reflects, then turns 90 degrees about its centre.
const KIND_PIVOT: String = "pivot"
## Moving platforms never go faster than this fraction of the orb's speed, so a
## bounce always carries the orb clear of the wall that hit it.
const MAX_PLATFORM_SPEED: float = 0.4


## Returns a fresh mutable state for a level (target health and glass panes).
static func initial_state(level: Dictionary) -> Dictionary:
	var hp: Array[int] = []
	for t: Array in level.get("targets", []):
		hp.append(int(t[2]) if t.size() > 2 else 1)
	var intact: Array[bool] = []
	var rot: Array[float] = []
	for w: Array in level.get("walls", []):
		intact.append(true)
		rot.append(0.0)
	return {"hp": hp, "intact": intact, "rot": rot, "open": false, "t0": 0.0}


static func copy_state(state: Dictionary) -> Dictionary:
	return {
		"hp": (state["hp"] as Array).duplicate(), "intact": (state["intact"] as Array).duplicate(),
		"rot": (state.get("rot", []) as Array).duplicate(), "open": bool(state.get("open", false)),
		"t0": float(state.get("t0", 0.0)),
	}


static func is_cleared(state: Dictionary) -> bool:
	for v: int in state["hp"]:
		if v > 0:
			return false
	return true


static func targets_left(state: Dictionary) -> int:
	var n: int = 0
	for v: int in state["hp"]:
		if v > 0:
			n += 1
	return n


static func launcher(level: Dictionary) -> Vector2:
	var l: Array = level.get("launcher", [320, 880])
	return Vector2(float(l[0]), float(l[1]))


## Corners of a rotated wall rectangle, clockwise. `t` is the shot clock (travelled
## distance) and slides moving platforms along their rail.
static func wall_corners(w: Array, extra_deg: float = 0.0, t: float = 0.0) -> PackedVector2Array:
	var c: Vector2 = Vector2(float(w[0]), float(w[1])) + wall_offset(w, t)
	var half: Vector2 = Vector2(float(w[2]), float(w[3])) * 0.5
	var rot: float = deg_to_rad((float(w[4]) if w.size() > 4 else 0.0) + extra_deg)
	var pts: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		pts.append(c + corner.rotated(rot))
	return pts


static func wall_kind(w: Array) -> String:
	return str(w[5]) if w.size() > 5 else KIND_WALL


## A moving platform carries a rail as its 7th field: [dx, dy, period]. It never
## stops: it slides to start + (dx, dy) and back, one round trip every `period`
## units of the world clock (the orb covers one unit per unit of clock). The
## clock reads 0 when the room opens; `state["t0"]` is the clock when the shot is
## fired, so a shot depends on its angle and its timing, and nothing else.
static func is_moving(w: Array) -> bool:
	return w.size() > 6 and w[6] is Array and (w[6] as Array).size() >= 3


static func has_movers(level: Dictionary) -> bool:
	for w: Array in level.get("walls", []):
		if is_moving(w):
			return true
	return false


static func wall_offset(w: Array, t: float) -> Vector2:
	if not is_moving(w):
		return Vector2.ZERO
	var m: Array = w[6]
	var u: float = fposmod(t / float(m[2]), 1.0)
	var f: float = u * 2.0 if u < 0.5 else 2.0 - u * 2.0
	return Vector2(float(m[0]), float(m[1])) * f


## Platform velocity in arena units per unit of orb travel (the orb's speed is 1).
static func wall_velocity(w: Array, t: float) -> Vector2:
	if not is_moving(w):
		return Vector2.ZERO
	var m: Array = w[6]
	var period: float = float(m[2])
	var u: float = fposmod(t / period, 1.0)
	return Vector2(float(m[0]), float(m[1])) * (2.0 / period) * (1.0 if u < 0.5 else -1.0)


## The next moment after `t` when any platform turns around (INF if none move).
static func next_turn(level: Dictionary, t: float) -> float:
	var best: float = INF
	for w: Array in level.get("walls", []):
		if not is_moving(w):
			continue
		var half: float = float(w[6][2]) * 0.5
		var k: float = floor(t / half) + 1.0
		# (floor works for negative clocks too)
		var at: float = k * half
		if at - t < 0.0001:
			at += half
		best = minf(best, at)
	return best


## Builds the segment list used for collision at shot time `t`. Arena border
## segments carry index -1; each entry is [a, b, wall index, kind, velocity].
static func _segments(level: Dictionary, state: Dictionary, t: float = 0.0) -> Array:
	var segs: Array = []
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2(ARENA.x, 0)
	var c: Vector2 = ARENA
	var d: Vector2 = Vector2(0, ARENA.y)
	for pair: Array in [[a, b], [b, c], [c, d], [d, a]]:
		segs.append([pair[0], pair[1], -1, KIND_WALL, Vector2.ZERO])
	var walls: Array = level.get("walls", [])
	var intact: Array = state["intact"]
	var rot: Array = state.get("rot", [])
	var open: bool = bool(state.get("open", false))
	var clock: float = t + float(state.get("t0", 0.0))
	for i: int in walls.size():
		if not bool(intact[i]):
			continue
		var w: Array = walls[i]
		var kind: String = wall_kind(w)
		if kind == KIND_GATE and open:
			continue
		var pts: PackedVector2Array = wall_corners(w, float(rot[i]) if i < rot.size() else 0.0, clock)
		var v: Vector2 = wall_velocity(w, clock)
		for k: int in 4:
			segs.append([pts[k], pts[(k + 1) % 4], i, kind, v])
	return segs


## Ray against a segment inflated by radius r (a capsule). Returns [t, normal] or [].
static func _ray_capsule(p: Vector2, dir: Vector2, a: Vector2, b: Vector2, r: float) -> Array:
	var best_t: float = INF
	var best_n: Vector2 = Vector2.ZERO
	var e: Vector2 = b - a
	var len2: float = e.length_squared()
	if len2 > 0.0001:
		var n: Vector2 = Vector2(-e.y, e.x) / sqrt(len2)
		for s: float in [1.0, -1.0]:
			var m: Vector2 = n * s
			var dm: float = dir.dot(m)
			if dm >= -0.000001:
				continue
			var q: Vector2 = a + m * r
			var side: float = (p - q).dot(m)
			if side < -0.05:
				continue
			var t: float = maxf(0.0, -side / dm)
			if t >= best_t:
				continue
			var x: Vector2 = p + dir * t
			var u: float = (x - a).dot(e) / len2
			if u >= 0.0 and u <= 1.0:
				best_t = t
				best_n = m
	for c: Vector2 in [a, b]:
		var hit: Array = _ray_circle(p, dir, c, r, true)
		if not hit.is_empty() and float(hit[0]) < best_t:
			best_t = hit[0]
			best_n = hit[1]
	if best_t >= INF:
		return []
	return [best_t, best_n]


## Ray against a circle. Solid circles also catch an orb that starts just inside and
## moves inward; non-solid ones (pass-through triggers) only fire when entering.
static func _ray_circle(p: Vector2, dir: Vector2, c: Vector2, r: float, solid: bool) -> Array:
	var f: Vector2 = p - c
	var bq: float = f.dot(dir)
	var cc: float = f.length_squared() - r * r
	if cc < 0.0:
		if solid and bq < 0.0 and cc > -r * 0.5:
			var n_in: Vector2 = f.normalized() if f.length_squared() > 0.0001 else -dir
			return [0.0, n_in]
		return []
	if bq > 0.0:
		return []
	var disc: float = bq * bq - cc
	if disc < 0.0:
		return []
	var t: float = -bq - sqrt(disc)
	if t < 0.0:
		t = 0.0
	var hit_p: Vector2 = p + dir * t
	var n_out: Vector2 = hit_p - c
	return [t, n_out.normalized() if n_out.length_squared() > 0.0001 else -dir]


## Finds the earliest contact for one orb against the current world.
static func _next_hit(level: Dictionary, state: Dictionary, segs: Array, orb: Dictionary) -> Dictionary:
	var p: Vector2 = orb["pos"]
	var dir: Vector2 = orb["dir"]
	var best: Dictionary = {"d": INF}
	for s: Array in segs:
		var v: Vector2 = s[4]
		var hit: Array
		if v == Vector2.ZERO:
			hit = _ray_capsule(p, dir, s[0], s[1], ORB_R)
		else:
			# Solve in the platform's frame: the orb moves at (dir - v) there.
			var rel: Vector2 = dir - v
			var speed: float = rel.length()
			hit = _ray_capsule(p, rel / speed, s[0], s[1], ORB_R)
			if not hit.is_empty():
				hit[0] = float(hit[0]) / speed
		if not hit.is_empty() and float(hit[0]) < float(best["d"]):
			best = {"d": hit[0], "n": hit[1], "type": "wall", "index": s[2], "kind": s[3], "v": v}
	var targets: Array = level.get("targets", [])
	var hp: Array = state["hp"]
	for i: int in targets.size():
		if int(hp[i]) <= 0:
			continue
		var t: Array = targets[i]
		var hit_t: Array = _ray_circle(p, dir, Vector2(float(t[0]), float(t[1])), TARGET_R + ORB_R, false)
		if not hit_t.is_empty() and float(hit_t[0]) < float(best["d"]):
			best = {"d": hit_t[0], "n": hit_t[1], "type": "target", "index": i}
	var bumpers: Array = level.get("bumpers", [])
	for i: int in bumpers.size():
		var bm: Array = bumpers[i]
		var r: float = float(bm[2]) if bm.size() > 2 else BUMPER_R
		var hit_b: Array = _ray_circle(p, dir, Vector2(float(bm[0]), float(bm[1])), r + ORB_R, true)
		if not hit_b.is_empty() and float(hit_b[0]) < float(best["d"]):
			best = {"d": hit_b[0], "n": hit_b[1], "type": "bumper", "index": i}
	var portals: Array = level.get("portals", [])
	for i: int in portals.size():
		var pt: Array = portals[i]
		for side: int in 2:
			var centre: Vector2 = Vector2(float(pt[side * 2]), float(pt[side * 2 + 1]))
			var hit_p: Array = _ray_circle(p, dir, centre, PORTAL_R, false)
			if not hit_p.is_empty() and float(hit_p[0]) < float(best["d"]):
				best = {"d": hit_p[0], "type": "portal", "index": i, "side": side}
	var prisms: Array = level.get("prisms", [])
	var used: Array = orb["used_prisms"]
	for i: int in prisms.size():
		if used.has(i):
			continue
		var pr: Array = prisms[i]
		var hit_r: Array = _ray_circle(p, dir, Vector2(float(pr[0]), float(pr[1])), PRISM_R, false)
		if not hit_r.is_empty() and float(hit_r[0]) < float(best["d"]):
			best = {"d": hit_r[0], "type": "prism", "index": i}
	if not bool(state.get("open", false)):
		var switches: Array = level.get("switches", [])
		for i: int in switches.size():
			var sw: Array = switches[i]
			var hit_s: Array = _ray_circle(p, dir, Vector2(float(sw[0]), float(sw[1])), SWITCH_R, false)
			if not hit_s.is_empty() and float(hit_s[0]) < float(best["d"]):
				best = {"d": hit_s[0], "type": "switch", "index": i}
	var sparks: Array = level.get("sparks", [])
	var used_sparks: Array = orb.get("used_sparks", [])
	for i: int in sparks.size():
		if used_sparks.has(i):
			continue
		var sk: Array = sparks[i]
		var hit_k: Array = _ray_circle(p, dir, Vector2(float(sk[0]), float(sk[1])), SPARK_R, false)
		if not hit_k.is_empty() and float(hit_k[0]) < float(best["d"]):
			best = {"d": hit_k[0], "type": "spark", "index": i}
	return best


static func _new_orb(id: int, pos: Vector2, dir: Vector2, bounces: int, t: float, used: Array, parent: int) -> Dictionary:
	return {
		"id": id, "pos": pos, "dir": dir.normalized(), "bounces": bounces, "alive": true,
		"used_prisms": used.duplicate(), "used_sparks": [], "travel": 0.0,
		"track": {"id": id, "parent": parent, "points": [pos], "times": [t], "end": "", "bounces": [bounces]},
	}


static func _push_point(orb: Dictionary, t: float) -> void:
	var track: Dictionary = orb["track"]
	(track["points"] as Array).append(orb["pos"])
	(track["times"] as Array).append(t)
	(track["bounces"] as Array).append(int(orb["bounces"]))


## Simulates one shot fired at `angle` (radians, 0 = right, -PI/2 = up).
## Returns {tracks, events, state, cleared, duration, bounces_used}.
static func simulate(level: Dictionary, state_in: Dictionary, angle: float, bounce_limit: int = -1) -> Dictionary:
	var state: Dictionary = copy_state(state_in)
	var limit: int = bounce_limit if bounce_limit >= 0 else int(level.get("bounces", 3))
	var start: Vector2 = launcher(level)
	var orbs: Array = [_new_orb(0, start, Vector2.from_angle(angle), limit, 0.0, [], -1)]
	var next_id: int = 1
	var events: Array = []
	var tracks: Array = []
	var segs: Array = _segments(level, state)
	var movers: bool = has_movers(level)
	var t: float = 0.0
	var max_bounces_used: int = 0
	var guard: int = 0
	while guard < MAX_EVENTS:
		guard += 1
		if movers:
			segs = _segments(level, state, t)
		var best_d: float = INF
		var best_orb: Dictionary = {}
		var best_hit: Dictionary = {}
		var alive: int = 0
		for orb: Dictionary in orbs:
			if not orb["alive"]:
				continue
			alive += 1
			var hit: Dictionary = _next_hit(level, state, segs, orb)
			var remaining: float = MAX_TRAVEL - float(orb["travel"])
			if float(hit["d"]) > remaining:
				hit = {"d": remaining, "type": "expire"}
			if float(hit["d"]) < best_d:
				best_d = hit["d"]
				best_orb = orb
				best_hit = hit
		if alive == 0:
			break
		if movers:
			# A platform turning around changes its velocity: re-plan from there.
			var clock: float = t + float(state.get("t0", 0.0))
			var turn: float = next_turn(level, clock) - clock
			if turn < best_d:
				for o: Dictionary in orbs:
					if o["alive"]:
						o["pos"] = (o["pos"] as Vector2) + (o["dir"] as Vector2) * turn
						o["travel"] = float(o["travel"]) + turn
				t += turn
				continue
		for orb: Dictionary in orbs:
			if orb["alive"]:
				orb["pos"] = (orb["pos"] as Vector2) + (orb["dir"] as Vector2) * best_d
				orb["travel"] = float(orb["travel"]) + best_d
		t += best_d
		var orb: Dictionary = best_orb
		var pos: Vector2 = orb["pos"]
		match str(best_hit["type"]):
			"wall":
				var kind: String = best_hit["kind"]
				var idx: int = best_hit["index"]
				_push_point(orb, t)
				if kind == KIND_VOID:
					events.append({"t": t, "type": "absorb", "pos": pos, "orb": orb["id"], "index": idx})
					_end_orb(orb, tracks, "absorb")
				elif int(orb["bounces"]) <= 0:
					events.append({"t": t, "type": "fizzle", "pos": pos, "orb": orb["id"], "index": idx})
					_end_orb(orb, tracks, "fizzle")
				else:
					var n: Vector2 = best_hit["n"]
					orb["dir"] = _reflect(orb["dir"], n, best_hit.get("v", Vector2.ZERO))
					orb["pos"] = pos + n * 0.01
					orb["bounces"] = int(orb["bounces"]) - 1
					max_bounces_used = maxi(max_bounces_used, limit - int(orb["bounces"]))
					orb["track"]["bounces"][-1] = int(orb["bounces"])
					if kind == KIND_GLASS:
						state["intact"][idx] = false
						segs = _segments(level, state, t)
						events.append({"t": t, "type": "glass", "pos": pos, "orb": orb["id"], "index": idx, "n": n})
					elif kind == KIND_PIVOT:
						state["rot"][idx] = fmod(float(state["rot"][idx]) + 90.0, 360.0)
						segs = _segments(level, state, t)
						events.append({"t": t, "type": "pivot", "pos": pos, "orb": orb["id"], "index": idx, "n": n, "rot": state["rot"][idx]})
					else:
						events.append({"t": t, "type": "bounce", "pos": pos, "orb": orb["id"], "index": idx, "n": n})
			"bumper":
				_push_point(orb, t)
				if int(orb["bounces"]) <= 0:
					events.append({"t": t, "type": "fizzle", "pos": pos, "orb": orb["id"], "index": -1})
					_end_orb(orb, tracks, "fizzle")
				else:
					var nb: Vector2 = best_hit["n"]
					orb["dir"] = (orb["dir"] as Vector2).bounce(nb).normalized()
					orb["pos"] = pos + nb * 0.01
					orb["bounces"] = int(orb["bounces"]) - 1
					max_bounces_used = maxi(max_bounces_used, limit - int(orb["bounces"]))
					orb["track"]["bounces"][-1] = int(orb["bounces"])
					events.append({"t": t, "type": "bumper", "pos": pos, "orb": orb["id"], "index": best_hit["index"], "n": nb})
			"target":
				var ti: int = best_hit["index"]
				var hp: Array = state["hp"]
				if int(hp[ti]) >= 2:
					# Armored: the first pass only cracks the shield; the orb flies on.
					hp[ti] = int(hp[ti]) - 1
					events.append({"t": t, "type": "shield", "pos": pos, "orb": orb["id"], "index": ti})
					# Step just inside so the same pass is not counted twice.
					orb["pos"] = pos + (orb["dir"] as Vector2) * 0.5
				else:
					hp[ti] = 0
					events.append({"t": t, "type": "pop", "pos": pos, "orb": orb["id"], "index": ti, "left": targets_left(state)})
			"portal":
				var pi: int = best_hit["index"]
				var side: int = best_hit["side"]
				var pt: Array = level["portals"][pi]
				var entry: Vector2 = Vector2(float(pt[side * 2]), float(pt[side * 2 + 1]))
				var other: int = 1 - side
				var exit_c: Vector2 = Vector2(float(pt[other * 2]), float(pt[other * 2 + 1]))
				_push_point(orb, t)
				_end_orb(orb, tracks, "portal")
				# Exit just outside the far side of the twin so it does not re-trigger.
				var out_pos: Vector2 = exit_c + (orb["dir"] as Vector2) * (PORTAL_R + 0.5)
				var twin: Dictionary = _new_orb(next_id, out_pos, orb["dir"], int(orb["bounces"]), t, orb["used_prisms"], int(orb["id"]))
				next_id += 1
				twin["travel"] = orb["travel"]
				twin["used_sparks"] = (orb["used_sparks"] as Array).duplicate()
				orbs.append(twin)
				events.append({"t": t, "type": "portal", "pos": entry, "pos2": exit_c, "orb": orb["id"], "orb2": twin["id"], "index": pi})
			"prism":
				var ri: int = best_hit["index"]
				var pr: Array = level["prisms"][ri]
				var centre: Vector2 = Vector2(float(pr[0]), float(pr[1]))
				orb["pos"] = centre
				_push_point(orb, t)
				_end_orb(orb, tracks, "split")
				var used: Array = (orb["used_prisms"] as Array).duplicate()
				used.append(ri)
				var kids: Array = []
				for sgn: float in [-1.0, 1.0]:
					var kid: Dictionary = _new_orb(next_id, centre, (orb["dir"] as Vector2).rotated(SPLIT_ANGLE * sgn), int(orb["bounces"]), t, used, int(orb["id"]))
					kid["travel"] = orb["travel"]
					kid["used_sparks"] = (orb["used_sparks"] as Array).duplicate()
					next_id += 1
					orbs.append(kid)
					kids.append(kid["id"])
				events.append({"t": t, "type": "split", "pos": centre, "orb": orb["id"], "index": ri, "kids": kids})
			"switch":
				state["open"] = true
				segs = _segments(level, state, t)
				events.append({"t": t, "type": "switch", "pos": pos, "orb": orb["id"], "index": best_hit["index"]})
			"spark":
				(orb["used_sparks"] as Array).append(best_hit["index"])
				_push_point(orb, t)
				orb["bounces"] = int(orb["bounces"]) + 1
				orb["track"]["bounces"][-1] = int(orb["bounces"])
				events.append({"t": t, "type": "spark", "pos": pos, "orb": orb["id"], "index": best_hit["index"]})
			"expire":
				_push_point(orb, t)
				events.append({"t": t, "type": "fizzle", "pos": pos, "orb": orb["id"], "index": -1})
				_end_orb(orb, tracks, "fizzle")
	for orb: Dictionary in orbs:
		if orb["alive"]:
			_push_point(orb, t)
			_end_orb(orb, tracks, "fizzle")
	return {
		"tracks": tracks, "events": events, "state": state,
		"cleared": is_cleared(state), "duration": t, "bounces_used": max_bounces_used,
	}


## Mirror bounce. Off a moving platform, make sure the orb leaves faster than the
## platform follows it, so it can't be caught twice by the same face.
static func _reflect(dir: Vector2, n: Vector2, v: Vector2) -> Vector2:
	var out: Vector2 = dir.bounce(n).normalized()
	if v != Vector2.ZERO:
		var need: float = maxf(0.0, v.dot(n)) + 0.08
		if out.dot(n) < need:
			out = (out + n * (need - out.dot(n))).normalized()
	return out


static func _end_orb(orb: Dictionary, tracks: Array, reason: String) -> void:
	orb["alive"] = false
	orb["track"]["end"] = reason
	tracks.append(orb["track"])


## Cheap preview: the path from the launcher up to the first `segments` contacts,
## then a short reflected stub. Moving platforms are tracked along the way, so the
## line shows where they will be when the orb gets there.
## Returns {points: PackedVector2Array, stub_end: Vector2, kind: String, pops: Array}.
static func preview(level: Dictionary, state: Dictionary, angle: float, stub_length: float = 120.0, segments: int = 1) -> Dictionary:
	var movers: bool = has_movers(level)
	var temp_state: Dictionary = copy_state(state)
	var t: float = 0.0
	var segs: Array = _segments(level, temp_state)
	var orb: Dictionary = {"pos": launcher(level), "dir": Vector2.from_angle(angle), "used_prisms": [], "used_sparks": []}
	var points: PackedVector2Array = PackedVector2Array([orb["pos"]])
	var kind: String = ""
	var pops: Array[int] = []
	var contacts: int = 0
	var guard: int = 0
	var hit: Dictionary = {}
	while contacts < segments and guard < 80:
		guard += 1
		if movers:
			segs = _segments(level, temp_state, t)
		hit = _next_hit(level, temp_state, segs, orb)
		var clock: float = t + float(temp_state.get("t0", 0.0))
		if movers and float(hit["d"]) > next_turn(level, clock) - clock:
			var turn: float = next_turn(level, clock) - clock
			orb["pos"] = (orb["pos"] as Vector2) + (orb["dir"] as Vector2) * turn
			t += turn
			continue
		if str(hit.get("type", "")) in ["target", "switch", "spark"]:
			# Pass-through triggers: remember popped targets and keep going.
			match str(hit["type"]):
				"target":
					if int(temp_state["hp"][hit["index"]]) < 2:
						pops.append(hit["index"])
					temp_state["hp"][hit["index"]] = 0
				"switch":
					temp_state["open"] = true
				"spark":
					(orb["used_sparks"] as Array).append(hit["index"])
			orb["pos"] = (orb["pos"] as Vector2) + (orb["dir"] as Vector2) * float(hit["d"])
			t += float(hit["d"])
			continue
		if float(hit["d"]) >= INF:
			break
		var p: Vector2 = (orb["pos"] as Vector2) + (orb["dir"] as Vector2) * float(hit["d"])
		t += float(hit["d"])
		points.append(p)
		contacts += 1
		kind = str(hit["type"]) if str(hit["type"]) != "wall" else str(hit["kind"])
		if not hit.has("n") or kind == KIND_VOID:
			break
		var n: Vector2 = hit["n"]
		orb["dir"] = _reflect(orb["dir"], n, hit.get("v", Vector2.ZERO))
		orb["pos"] = p + n * 0.01
	var stub_end: Vector2 = points[-1]
	if kind != KIND_VOID and kind != "portal" and kind != "prism" and points.size() >= 2:
		if movers:
			segs = _segments(level, temp_state, t)
		var stub_hit: Dictionary = _next_hit(level, temp_state, segs, orb)
		var stub_len: float = minf(stub_length, float(stub_hit["d"]))
		stub_end = points[-1] + (orb["dir"] as Vector2) * stub_len
	return {"points": points, "stub_end": stub_end, "kind": kind, "pops": pops}


## Scans every launch angle and returns windows that clear all remaining targets in
## one shot, widest first: [{angle (rad), width (rad), bounces}].
static func solve(level: Dictionary, state: Dictionary, samples: int = 1440, refine: bool = true) -> Array:
	var step: float = TAU / float(samples)
	var ok: Array[bool] = []
	ok.resize(samples)
	for i: int in samples:
		ok[i] = bool(simulate(level, state, -PI + step * float(i))["cleared"])
	var windows: Array = []
	var i0: int = 0
	while i0 < samples:
		if not ok[i0]:
			i0 += 1
			continue
		var j: int = i0
		while j + 1 < samples and ok[j + 1]:
			j += 1
		var lo: float = -PI + step * float(i0)
		var hi: float = -PI + step * float(j)
		if refine:
			lo = _edge(level, state, lo - step, lo)
			hi = _edge(level, state, hi + step, hi)
		var mid: float = (lo + hi) * 0.5
		var res: Dictionary = simulate(level, state, mid)
		if bool(res["cleared"]):
			windows.append({"angle": mid, "width": hi - lo, "bounces": res["bounces_used"]})
		i0 = j + 1
	windows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["width"]) > float(b["width"]))
	return windows


## Bisects between a failing and a clearing angle to find the window edge.
static func _edge(level: Dictionary, state: Dictionary, bad: float, good: float) -> float:
	for k: int in 10:
		var m: float = (bad + good) * 0.5
		if bool(simulate(level, state, m)["cleared"]):
			good = m
		else:
			bad = m
	return good
