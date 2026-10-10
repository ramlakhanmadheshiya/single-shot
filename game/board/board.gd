class_name Board
extends Control
## The play field: draws the room, handles aiming, plays shots back from the
## deterministic simulation, and layers on feedback (rings, particles, shake,
## slow motion on the final target, pitched pops).

signal shot_fired
signal shot_finished(cleared: bool, shots_used: int)
signal target_popped(left: int)
signal aim_started

const SPEED: float = 1500.0

var pal: Dictionary = Palette.get_palette("ch1")
var level: Dictionary = {}
var state: Dictionary = {}
var history: Array = []
var shots_used: int = 0
var demo: bool = false
var quiet: bool = false
var input_enabled: bool = true
## Orb look from the shop's Orb pack (see OrbStyles).
var orb_style: String = "classic"
## Replaying a finished shot for the player to watch: no input, no recording.
var replaying: bool = false

# View transform (arena units -> control pixels).
var view_scale: float = 1.0
var view_offset: Vector2 = Vector2.ZERO
var _shake: Vector2 = Vector2.ZERO
var _trauma: float = 0.0
var _clock: float = 0.0

# Aiming.
var aim_angle: float = -PI / 2.0
var aiming: bool = false
var has_aim: bool = false
var _last_tick_angle: float = 0.0
var _preview: Dictionary = {}


# Playback.
var playing: bool = false
var _result: Dictionary = {}
var last_result: Dictionary = {}
var _play_t: float = 0.0
var _event_i: int = 0
var _settle: float = -1.0
var _slowmo: float = 0.0
var _rate: float = 1.0
var _hp: Array = []
var _intact: Array = []
var _rot_shown: Array = []
var _rot_goal: Array = []
var _open: bool = false
var _gate_alpha: float = 1.0
var _sparks_taken: Dictionary = {}
var _combo: int = 0
var _trails: Dictionary = {}

# Effects.
var _particles: Array = []
var _rings: Array = []
var _flash: Dictionary = {}
var _pops: Dictionary = {}
var _bumps: Dictionary = {}
var _screen_flash: float = 0.0
var _kick: float = 0.0
var _hint_tracks: Array = []
var _hint_t: float = 0.0
## The path of the last missed shot, kept faintly visible so the next try can adjust.
var _ghost_tracks: Array = []
var _ghost_end: Array = []
## The tracks of the last shot played (for the share card).
var last_tracks: Array = []
var last_angle: float = 0.0
var _fast: float = 1.0
## World clock (arena units of orb travel) that places moving platforms. It never
## stops: platforms keep sliding while you aim, fly, miss or wait.
var _world_t: float = 0.0
var _shot_t0: float = 0.0
var _movers: bool = false
var last_t0: float = 0.0
var _intro: float = 1.0
var _demo_wait: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	# A new orb picked in Settings shows up at once, even mid-level.
	Events.setting_changed.connect(func(key: String, _v: Variant) -> void:
		if key == "orb_style" and not demo:
			orb_style = SaveSystem.orb_style()
	)
	Events.purchases_changed.connect(func() -> void:
		if not demo:
			orb_style = SaveSystem.orb_style()
	)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = false
	resized.connect(_layout)
	_rng.randomize()
	_layout()


func setup(level_data: Dictionary, palette: Dictionary) -> void:
	level = level_data
	pal = palette
	orb_style = SaveSystem.orb_style() if not demo else "classic"
	_movers = RicochetSim.has_movers(level)
	_world_t = 0.0
	reset()


func reset() -> void:
	state = RicochetSim.initial_state(level)
	history.clear()
	shots_used = 0
	_stop_playback()
	_hint_t = 0.0
	_intro = 0.0
	aiming = false
	has_aim = false
	_particles.clear()
	_rings.clear()
	_pops.clear()
	_fast = 1.0
	replaying = false
	_sync_display()
	queue_redraw()


## Resets the room for the next try, keeping the missed path as a faint guide.
func retry() -> void:
	var keep: Array = _ghost_tracks
	var keep_end: Array = _ghost_end
	reset()
	_intro = 1.0
	_ghost_tracks = keep
	_ghost_end = keep_end


## Plays a shot again from a fresh room so the player can watch it.
func replay(angle: float, t0: float = 0.0) -> void:
	reset()
	_intro = 1.0
	_ghost_tracks = []
	replaying = true
	_world_t = t0
	fire(angle)


## Speeds up the shot in flight (tap while it plays).
func fast_forward() -> void:
	if playing:
		_fast = 3.0


## Why the last shot failed, in a few words.
func miss_reason() -> String:
	if last_result.is_empty():
		return ""
	var left: int = RicochetSim.targets_left(last_result["state"])
	var swallowed: bool = false
	for e: Dictionary in last_result["events"]:
		if str(e["type"]) == "absorb":
			swallowed = true
	var what: String = "1 target left" if left == 1 else "%d targets left" % left
	if swallowed:
		return "Swallowed by the dark  ·  " + what
	return "Out of bounces  ·  " + what


func undo() -> bool:
	if playing or history.is_empty():
		return false
	state = history.pop_back()
	shots_used = maxi(0, shots_used - 1)
	_sync_display()
	_sound("undo")
	_add_ring(RicochetSim.launcher(level), 10.0, 60.0, 0.35, pal["accent"], 4.0)
	return true


func shots_left() -> int:
	return int(level.get("shots", 1)) - shots_used


func targets_left() -> int:
	return RicochetSim.targets_left(state)


func _sync_display() -> void:
	_hp = (state["hp"] as Array).duplicate()
	_intact = (state["intact"] as Array).duplicate()
	_rot_goal = (state.get("rot", []) as Array).duplicate()
	_rot_shown = _rot_goal.duplicate()
	_open = bool(state.get("open", false))
	_gate_alpha = 0.0 if _open else 1.0
	_sparks_taken.clear()


func _stop_playback() -> void:
	playing = false
	_result = {}
	_settle = -1.0
	_slowmo = 0.0
	_rate = 1.0
	_trails.clear()


func _layout() -> void:
	var avail: Vector2 = size
	view_scale = minf(avail.x / RicochetSim.ARENA.x, avail.y / RicochetSim.ARENA.y)
	view_offset = (avail - RicochetSim.ARENA * view_scale) * 0.5


func to_world(p: Vector2) -> Vector2:
	return (p - view_offset) / view_scale


func to_screen(p: Vector2) -> Vector2:
	return view_offset + p * view_scale


# --- Input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if playing and event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not demo:
		fast_forward()
		accept_event()
		return
	if demo or playing or not input_enabled or level.is_empty() or shots_left() <= 0:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			aiming = true
			_aim_at(mb.position)
			aim_started.emit()
		elif aiming:
			aiming = false
			_aim_at(mb.position)
			if has_aim:
				fire(aim_angle)
			has_aim = false
		accept_event()
	elif event is InputEventMouseMotion and aiming:
		_aim_at((event as InputEventMouseMotion).position)
		accept_event()


func _aim_at(screen_pos: Vector2) -> void:
	var d: Vector2 = to_world(screen_pos) - RicochetSim.launcher(level)
	has_aim = d.length() > 46.0
	if has_aim:
		aim_angle = d.angle()
		if absf(angle_difference(aim_angle, _last_tick_angle)) > deg_to_rad(2.5):
			_last_tick_angle = aim_angle
			_sound("aim_tick", 1.0, -6.0)
	_preview = {}
	queue_redraw()


## Keyboard / gamepad aiming.
func nudge_aim(degrees: float) -> void:
	if playing or demo:
		return
	has_aim = true
	aim_angle = wrapf(aim_angle + deg_to_rad(degrees), -PI, PI)
	_preview = {}
	_sound("aim_tick", 1.0, -6.0)
	queue_redraw()


## True when the current aim line passes through at least one target.
func aim_hits_target() -> bool:
	if not has_aim or playing:
		return false
	if _preview.is_empty():
		_preview = RicochetSim.preview(level, _timed_state(), aim_angle, 150.0, 2 if bool(SaveSystem.get_setting("long_guide", true)) else 1)
	return not (_preview.get("pops", []) as Array).is_empty()


## The room's state at this moment of the world clock.
func _timed_state() -> Dictionary:
	if not _movers:
		return state
	var st: Dictionary = RicochetSim.copy_state(state)
	st["t0"] = _world_t
	return st


func fire_current() -> void:
	if has_aim and not playing:
		fire(aim_angle)
		has_aim = false


# --- Shooting & playback ------------------------------------------------------

func fire(angle: float) -> void:
	if playing or shots_left() <= 0:
		return
	history.append(RicochetSim.copy_state(state))
	shots_used += 1
	_shot_t0 = _world_t
	last_t0 = _world_t
	var fired: Dictionary = RicochetSim.copy_state(state)
	fired["t0"] = _world_t
	_result = RicochetSim.simulate(level, fired, angle)
	last_result = _result
	last_angle = angle
	last_tracks = _result["tracks"]
	_ghost_tracks = []
	_hint_t = 0.0
	_fast = 1.0
	playing = true
	_play_t = 0.0
	_event_i = 0
	_settle = -1.0
	_combo = 0
	_trails.clear()
	_hint_t = 0.0
	_preview = {}
	_kick = 1.0
	_add_trauma(0.08)
	_sound("launch")
	_haptic(8)
	var origin: Vector2 = RicochetSim.launcher(level)
	_add_ring(origin, 14.0, 46.0, 0.3, pal["orb"], 3.0)
	shot_fired.emit()


func _process(delta: float) -> void:
	_clock += delta
	# Moving platforms never stop; the world clock runs at the orb's speed.
	if playing and not _result.is_empty():
		_world_t = _shot_t0 + _play_t
	else:
		_world_t += SPEED * delta
	if _movers and (aiming or has_aim) and not playing:
		_preview = {}
	_intro = minf(1.0, _intro + delta * 2.2)
	if playing:
		_advance(delta)
	elif demo:
		_demo_tick(delta)
	_update_fx(delta)
	queue_redraw()


func _advance(delta: float) -> void:
	if _slowmo > 0.0:
		_slowmo -= delta
		_rate = lerpf(_rate, 0.2, minf(1.0, delta * 18.0))
	else:
		_rate = lerpf(_rate, 1.0, minf(1.0, delta * 5.0))
	if _settle < 0.0:
		_play_t += SPEED * delta * _rate * _fast
		var events: Array = _result["events"]
		while _event_i < events.size() and float(events[_event_i]["t"]) <= _play_t:
			_apply_event(events[_event_i])
			_event_i += 1
		for track: Dictionary in _result["tracks"]:
			var p: Variant = _track_pos(track, _play_t)
			var id: int = track["id"]
			if p != null:
				var tr: Array = _trails.get(id, [])
				tr.append(p)
				if tr.size() > OrbStyles.trail_length(orb_style):
					tr.pop_front()
				_trails[id] = tr
			elif _trails.has(id):
				var tr2: Array = _trails[id]
				if not tr2.is_empty():
					tr2.pop_front()
		if _play_t >= float(_result["duration"]):
			_settle = 0.0
	else:
		_settle += delta
		for id: Variant in _trails.keys():
			var tr3: Array = _trails[id]
			if not tr3.is_empty():
				tr3.pop_front()
		if _settle >= 0.38:
			_finish_shot()


func _finish_shot() -> void:
	state = _result["state"]
	_sync_display()
	var cleared: bool = bool(_result["cleared"])
	if not cleared:
		_remember_miss(_result)
	var was_replay: bool = replaying
	_stop_playback()
	replaying = false
	if not was_replay:
		shot_finished.emit(cleared, shots_used)


func _remember_miss(res: Dictionary) -> void:
	_ghost_tracks = []
	_ghost_end = []
	for track: Dictionary in res["tracks"]:
		_ghost_tracks.append(track["points"])
		if str(track["end"]) in ["fizzle", "absorb"]:
			_ghost_end.append((track["points"] as Array)[-1])


## Position of an orb on its track at time t, or null if it is not in flight.
func _track_pos(track: Dictionary, t: float) -> Variant:
	var times: Array = track["times"]
	var pts: Array = track["points"]
	if t < float(times[0]) or t > float(times[-1]):
		return null
	for k: int in range(times.size() - 1):
		var t0: float = times[k]
		var t1: float = times[k + 1]
		if t <= t1:
			var span: float = t1 - t0
			return (pts[k] as Vector2).lerp(pts[k + 1], 0.0 if span <= 0.0001 else (t - t0) / span)
	return pts[-1]


func _apply_event(e: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	var idx: int = int(e.get("index", -1))
	match str(e["type"]):
		"bounce":
			if idx >= 0:
				_flash["w%d" % idx] = 1.0
			_add_ring(pos, 4.0, 26.0, 0.32, Color(pal["ink"], 0.55), 3.0)
			_burst(pos, 4, Color(pal["ink"], 0.6), 90.0, 2.5, e.get("n", Vector2.ZERO))
			_sound("bounce")
			_add_trauma(0.05)
			_haptic(4)
		"glass":
			_intact[idx] = false
			_shatter(idx)
			_sound("bounce_glass")
			_sound("glass_break", -1.0, -2.0)
			_add_trauma(0.16)
			_haptic(14)
		"bumper":
			_bumps[idx] = 1.0
			_add_ring(pos, 6.0, 40.0, 0.35, pal["accent"], 4.0)
			_sound("bumper")
			_add_trauma(0.08)
			_haptic(6)
		"pop":
			_hp[idx] = 0
			_pops[idx] = 0.0
			var tp: Vector2 = _target_pos(idx)
			_add_ring(tp, RicochetSim.TARGET_R, RicochetSim.TARGET_R * 3.8, 0.55, pal["target"], 6.0)
			_burst(tp, 18, pal["target"], 260.0, 5.0)
			AudioManager.play_note("pop", _combo) if not quiet else null
			_combo += 1
			_add_trauma(0.22)
			_haptic(16)
			target_popped.emit(int(e.get("left", 0)))
			if int(e.get("left", 0)) == 0:
				_slowmo = 0.45
				_screen_flash = 1.0
				_add_trauma(0.35)
				_haptic(30)
		"shield":
			_hp[idx] = int(_hp[idx]) - 1
			var sp: Vector2 = _target_pos(idx)
			_add_ring(sp, RicochetSim.TARGET_R + 8.0, RicochetSim.TARGET_R + 40.0, 0.45, pal["target"], 4.0)
			_burst(sp, 8, pal["ink"], 180.0, 3.0)
			_sound("shield")
			_add_trauma(0.12)
			_haptic(10)
		"portal":
			var p2: Vector2 = e["pos2"]
			_add_ring(pos, 30.0, 4.0, 0.3, pal["special"], 4.0)
			_add_ring(p2, 4.0, 44.0, 0.4, pal["special"], 4.0)
			_sound("portal")
			_haptic(8)
		"split":
			_add_ring(pos, 10.0, 60.0, 0.45, pal["special"], 5.0)
			_burst(pos, 10, pal["special"], 200.0, 3.5)
			_sound("split")
			_add_trauma(0.12)
			_haptic(12)
		"pivot":
			_rot_goal[idx] = float(_rot_goal[idx]) + 90.0
			_flash["w%d" % idx] = 1.0
			_add_ring(pos, 4.0, 30.0, 0.32, pal["special"], 3.0)
			_sound("bounce")
			_sound("undo", 1.4, -6.0)
			_add_trauma(0.08)
			_haptic(8)
		"switch":
			_open = true
			var sp2: Vector2 = _feature_pos("switches", idx)
			_add_ring(sp2, 10.0, 70.0, 0.5, pal["special"], 5.0)
			_burst(sp2, 10, pal["special"], 200.0, 3.5)
			_sound("unlock", 1.0, -3.0)
			_add_trauma(0.12)
			_haptic(12)
		"spark":
			_sparks_taken[idx] = true
			var kp: Vector2 = _feature_pos("sparks", idx)
			_add_ring(kp, 6.0, 46.0, 0.4, pal["special"], 4.0)
			_burst(kp, 8, pal["special"], 160.0, 3.0)
			_sound("star", 1.5, -4.0)
			_haptic(8)
		"absorb":
			_add_ring(pos, 44.0, 2.0, 0.4, pal["accent"], 4.0)
			_sound("absorb")
			_add_trauma(0.1)
			_haptic(10)
		"fizzle":
			_burst(pos, 7, Color(pal["orb"], 0.7), 70.0, 2.5)
			_sound("fizzle", -1.0, -4.0)


func _feature_pos(key: String, i: int) -> Vector2:
	var q: Array = level[key][i]
	return Vector2(float(q[0]), float(q[1]))


func _target_pos(i: int) -> Vector2:
	var t: Array = level["targets"][i]
	return Vector2(float(t[0]), float(t[1]))


# --- Hints --------------------------------------------------------------------

## Shows the solving path for the current room state. Returns false if the room
## can no longer be cleared in one shot (the player should restart).
func show_hint() -> bool:
	if playing:
		return false
	var angle: float
	if history.is_empty():
		angle = deg_to_rad(float(level.get("solution", [-90.0])[0]))
	else:
		var wins: Array = RicochetSim.solve(level, state, 720, false)
		if wins.is_empty():
			return false
		angle = wins[0]["angle"]
	var tracks: Array = _path_for(angle)
	if tracks.is_empty():
		return false
	_hint_tracks = tracks
	_hint_t = 5.0
	aim_angle = angle
	has_aim = true
	_preview = {}
	_sound("hint")
	return true


## A solid path drawn over the room (the share card shows the winning shot).
var _path_tracks: Array = []


func show_path(angle: float, t0: float = 0.0) -> void:
	_intro = 1.0
	_world_t = t0
	_path_tracks = _path_for(angle, t0)


## The clearing path for `angle` from the current state, cut at the last target.
func _path_for(angle: float, t0: float = 0.0) -> Array:
	var st: Dictionary = RicochetSim.copy_state(state)
	st["t0"] = t0
	var res: Dictionary = RicochetSim.simulate(level, st, angle)
	if not bool(res["cleared"]):
		return []
	var last_pop: float = 0.0
	for e: Dictionary in res["events"]:
		if str(e["type"]) == "pop":
			last_pop = maxf(last_pop, float(e["t"]))
	var out: Array = []
	for track: Dictionary in res["tracks"]:
		var pts: Array = []
		var times: Array = track["times"]
		for k: int in (track["points"] as Array).size():
			if float(times[k]) <= last_pop + 1.0:
				pts.append(track["points"][k])
			elif k > 0 and float(times[k - 1]) < last_pop:
				var p: Variant = _track_pos(track, last_pop + 30.0)
				if p != null:
					pts.append(p)
		if pts.size() >= 2:
			out.append(pts)
	return out


# --- Demo / attract mode -----------------------------------------------------

func _demo_tick(delta: float) -> void:
	_demo_wait -= delta
	if _demo_wait > 0.0:
		var target: float = deg_to_rad(float(level.get("solution", [-90.0])[0]))
		has_aim = RicochetSim.is_cleared(state) == false
		aim_angle = lerp_angle(aim_angle, target, minf(1.0, delta * 2.5))
		_preview = {}
		return
	if RicochetSim.is_cleared(state) or shots_left() <= 0:
		reset()
		_demo_wait = 1.6
		return
	fire(deg_to_rad(float(level.get("solution", [-90.0])[0])))
	_demo_wait = 2.2


# --- Effects -------------------------------------------------------------------

func _sound(id: String, pitch: float = -1.0, db: float = 0.0) -> void:
	if not quiet:
		AudioManager.play(id, pitch, db)


func _haptic(ms: int) -> void:
	if not quiet:
		Haptics.tap(ms)


func _add_trauma(amount: float) -> void:
	if quiet or not bool(SaveSystem.get_setting("shake", true)):
		return
	_trauma = minf(1.0, _trauma + amount)


func _add_ring(p: Vector2, r0: float, r1: float, life: float, color: Color, width: float) -> void:
	_rings.append({"p": p, "r0": r0, "r1": r1, "life": life, "max": life, "c": color, "w": width})


func _burst(p: Vector2, count: int, color: Color, speed: float, radius: float, normal: Vector2 = Vector2.ZERO) -> void:
	for i: int in count:
		var dir: Vector2 = Vector2.from_angle(_rng.randf() * TAU)
		if normal != Vector2.ZERO:
			dir = (normal + dir * 0.9).normalized()
		var life: float = _rng.randf_range(0.35, 0.7)
		_particles.append({"p": p, "v": dir * speed * _rng.randf_range(0.4, 1.0), "life": life, "max": life, "c": color, "r": radius * _rng.randf_range(0.6, 1.2), "shard": false})


func _shatter(wall_index: int) -> void:
	var pts: PackedVector2Array = RicochetSim.wall_corners(level["walls"][wall_index])
	for i: int in 22:
		var a: Vector2 = pts[0].lerp(pts[1], _rng.randf())
		var b: Vector2 = pts[3].lerp(pts[2], _rng.randf())
		var p: Vector2 = a.lerp(b, _rng.randf())
		var life: float = _rng.randf_range(0.5, 0.9)
		_particles.append({"p": p, "v": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60, 220) + Vector2(0, 40), "life": life, "max": life, "c": pal["special"], "r": _rng.randf_range(5, 11), "shard": true, "rot": _rng.randf() * TAU})


func _update_fx(delta: float) -> void:
	for p: Dictionary in _particles:
		p["life"] = float(p["life"]) - delta
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * delta
		p["v"] = (p["v"] as Vector2) * pow(0.04, delta) + Vector2(0, 160 if p["shard"] else 0) * delta
		if p["shard"]:
			p["rot"] = float(p["rot"]) + delta * 6.0
	_particles = _particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)
	for r: Dictionary in _rings:
		r["life"] = float(r["life"]) - delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return float(r["life"]) > 0.0)
	for key: Variant in _flash.keys():
		_flash[key] = float(_flash[key]) - delta * 4.0
		if float(_flash[key]) <= 0.0:
			_flash.erase(key)
	for key: Variant in _bumps.keys():
		_bumps[key] = float(_bumps[key]) - delta * 4.0
		if float(_bumps[key]) <= 0.0:
			_bumps.erase(key)
	for key: Variant in _pops.keys():
		_pops[key] = float(_pops[key]) + delta * 4.0
		if float(_pops[key]) >= 1.0:
			_pops.erase(key)
	_screen_flash = maxf(0.0, _screen_flash - delta * 3.0)
	for i: int in _rot_shown.size():
		_rot_shown[i] = lerpf(float(_rot_shown[i]), float(_rot_goal[i]), minf(1.0, delta * 12.0))
	if _open:
		_gate_alpha = maxf(0.0, _gate_alpha - delta * 3.0)
	_kick = maxf(0.0, _kick - delta * 5.0)

	# A hint stays until the player releases a shot.
	_trauma = maxf(0.0, _trauma - delta * 1.4)
	var s: float = _trauma * _trauma
	_shake = Vector2(14.0 * s * (0.6 * sin(_clock * 47.0) + 0.4 * sin(_clock * 89.0 + 1.3)), 10.0 * s * (0.6 * sin(_clock * 53.0 + 0.7) + 0.4 * sin(_clock * 97.0)))


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	if level.is_empty():
		return
	var ease_in: float = 1.0 - pow(1.0 - _intro, 3.0)
	draw_set_transform(view_offset + _shake, 0.0, Vector2.ONE * view_scale)
	_draw_arena()
	if _hint_t > 0.0:
		_draw_hint()
	if not _ghost_tracks.is_empty() and not playing:
		_draw_ghost()
	for pts: Array in _path_tracks:
		for i: int in pts.size() - 1:
			_dotted(pts[i], pts[i + 1], Color(pal["accent"], 0.9), 20.0, 4.5)
	_draw_rails()
	if not playing and (aiming or has_aim) and shots_left() > 0:
		_draw_aim()
	_draw_walls(ease_in)
	_draw_features()
	_draw_targets(ease_in)
	_draw_orbs()
	_draw_launcher()
	_draw_fx()
	if _screen_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, RicochetSim.ARENA), Color(1, 1, 1, 0.18 * _screen_flash))
	draw_set_transform(Vector2.ZERO)


func _draw_arena() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, RicochetSim.ARENA)
	_draw_round_rect(rect, 28.0, pal["faint"])
	var dot: Color = Color(pal["ink"], 0.07)
	var y: float = 40.0
	while y < RicochetSim.ARENA.y:
		var x: float = 40.0
		while x < RicochetSim.ARENA.x:
			draw_circle(Vector2(x, y), 1.6, dot, true, -1.0, true)
			x += 40.0
		y += 40.0


func _draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 10
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


func _draw_aim() -> void:
	if _preview.is_empty():
		_preview = RicochetSim.preview(level, _timed_state(), aim_angle, 150.0, 2 if bool(SaveSystem.get_setting("long_guide", true)) else 1)
	var pts: PackedVector2Array = _preview["points"]
	var col: Color = Color(pal["ink"], 0.75)
	var phase: float = fmod(_clock * 60.0, 22.0)
	for i: int in pts.size() - 1:
		_dotted(pts[i], pts[i + 1], col if i == 0 else Color(col, 0.5), 22.0, 3.4, phase if i == 0 else 0.0)
	if pts.size() >= 2:
		var hit: Vector2 = pts[-1]
		draw_arc(hit, RicochetSim.ORB_R, 0.0, TAU, 28, Color(pal["ink"], 0.8), 2.5, true)
		var stub: Vector2 = _preview["stub_end"]
		if stub.distance_to(hit) > 2.0:
			var n: int = 6
			for k: int in n:
				var f: float = float(k + 1) / float(n + 1)
				draw_circle(hit.lerp(stub, f), 3.0 * (1.0 - f * 0.6), Color(pal["ink"], 0.5 * (1.0 - f)), true, -1.0, true)
	for ti: int in _preview.get("pops", []):
		draw_arc(_target_pos(ti), RicochetSim.TARGET_R + 8.0, 0.0, TAU, 40, Color(pal["target"], 0.7), 2.5, true)


func _dotted(a: Vector2, b: Vector2, color: Color, spacing: float, radius: float, phase: float = 0.0) -> void:
	var length: float = a.distance_to(b)
	if length < 1.0:
		return
	var dir: Vector2 = (b - a) / length
	var s: float = 26.0 + phase
	while s < length:
		draw_circle(a + dir * s, radius, color, true, -1.0, true)
		s += spacing


func _draw_hint() -> void:
	var alpha: float = minf(1.0, _hint_t) * (0.65 + 0.2 * sin(_clock * 6.0))
	for pts: Array in _hint_tracks:
		for i: int in pts.size() - 1:
			_dotted(pts[i], pts[i + 1], Color(pal["accent"], alpha), 18.0, 4.0, fmod(_clock * 40.0, 18.0))
	# Moving platforms: where they must be when you release (the hint's timing).
	var walls: Array = level.get("walls", [])
	for i: int in walls.size():
		var w: Array = walls[i]
		if not RicochetSim.is_moving(w) or (i < _intact.size() and not bool(_intact[i])):
			continue
		var pts2: PackedVector2Array = RicochetSim.wall_corners(w, 0.0, 0.0)
		var close: bool = RicochetSim.wall_offset(w, _world_t).length() < 18.0
		var col: Color = Color(pal["accent"], 0.95 if close else 0.6)
		for k: int in 4:
			_dashed(pts2[k], pts2[(k + 1) % 4], col, 3.0 if close else 2.0)


## True when every moving platform is close to where the hint wants it.
func hint_timing_now() -> bool:
	for w: Array in level.get("walls", []):
		if RicochetSim.is_moving(w) and RicochetSim.wall_offset(w, _world_t).length() > 18.0:
			return false
	return true


func _draw_walls(appear: float) -> void:
	var walls: Array = level.get("walls", [])
	for i: int in walls.size():
		if not bool(_intact[i]) if i < _intact.size() else false:
			continue
		var w: Array = walls[i]
		var kind: String = RicochetSim.wall_kind(w)
		var flash: float = float(_flash.get("w%d" % i, 0.0))
		if kind == RicochetSim.KIND_GATE and _gate_alpha <= 0.0:
			continue
		var pts: PackedVector2Array = RicochetSim.wall_corners(w, float(_rot_shown[i]) if i < _rot_shown.size() else 0.0, _world_t)
		var centre: Vector2 = Vector2(float(w[0]), float(w[1])) + RicochetSim.wall_offset(w, _world_t)
		if appear < 1.0:
			for k: int in 4:
				pts[k] = centre + (pts[k] - centre) * appear
		var thin: bool = minf(float(w[2]), float(w[3])) <= 24.0
		match kind:
			RicochetSim.KIND_GLASS:
				var fill: Color = Color(pal["special"], 0.28 + 0.4 * flash)
				draw_colored_polygon(pts, fill)
				var outline: PackedVector2Array = pts.duplicate()
				outline.append(pts[0])
				draw_polyline(outline, Color(pal["special"], 0.95), 2.5, true)
				var glint_a: Vector2 = pts[0].lerp(pts[1], 0.15).lerp(pts[3].lerp(pts[2], 0.15), 0.5)
				var glint_b: Vector2 = pts[0].lerp(pts[1], 0.32).lerp(pts[3].lerp(pts[2], 0.32), 0.5)
				draw_line(glint_a, glint_b, Color(1, 1, 1, 0.8), 3.0, true)
			RicochetSim.KIND_GATE:
				var ga: float = _gate_alpha
				draw_colored_polygon(pts, Color(pal["special"], 0.3 * ga))
				for k: int in 4:
					_dashed(pts[k], pts[(k + 1) % 4], Color(pal["special"], 0.95 * ga), 3.0)
			RicochetSim.KIND_VOID:
				draw_colored_polygon(pts, Color("#0B0A14"))
				var o: PackedVector2Array = pts.duplicate()
				o.append(pts[0])
				draw_polyline(o, Color(pal["accent"], 0.45 + 0.2 * sin(_clock * 3.0 + float(i))), 2.0, true)
			_:
				var col: Color = (pal["wall"] as Color).lerp(pal["accent"], flash * 0.8)
				if thin:
					var a: Vector2 = pts[0].lerp(pts[3], 0.5)
					var b: Vector2 = pts[1].lerp(pts[2], 0.5)
					var t: float = float(w[3]) * appear
					if float(w[3]) > float(w[2]):
						a = pts[0].lerp(pts[1], 0.5)
						b = pts[3].lerp(pts[2], 0.5)
						t = float(w[2]) * appear
					var dir: Vector2 = (b - a).normalized()
					a += dir * t * 0.5
					b -= dir * t * 0.5
					draw_line(a, b, col, t, true)
					draw_circle(a, t * 0.5, col, true, -1.0, true)
					draw_circle(b, t * 0.5, col, true, -1.0, true)
					if kind == RicochetSim.KIND_PIVOT:
						draw_circle(centre, t * 0.95, pal["special"], true, -1.0, true)
						draw_circle(centre, t * 0.35, pal["top"], true, -1.0, true)
						var spin: float = deg_to_rad(float(_rot_shown[i]))
						draw_arc(centre, t * 1.9, spin + 0.4, spin + 1.9, 12, Color(pal["special"], 0.7), 2.5, true)
				else:
					draw_colored_polygon(pts, col)
					var o2: PackedVector2Array = pts.duplicate()
					o2.append(pts[0])
					draw_polyline(o2, col, 3.0, true)


## Moving platforms: a dotted rail with end stops.
func _draw_rails() -> void:
	var walls: Array = level.get("walls", [])
	for i: int in walls.size():
		var w: Array = walls[i]
		if not RicochetSim.is_moving(w) or (i < _intact.size() and not bool(_intact[i])):
			continue
		var c0: Vector2 = Vector2(float(w[0]), float(w[1]))
		var c1: Vector2 = c0 + Vector2(float(w[6][0]), float(w[6][1]))
		var col: Color = Color(pal["special"], 0.55)
		_dotted(c0 - (c1 - c0).normalized() * 26.0, c1, col, 16.0, 2.6)
		for c: Vector2 in [c0, c1]:
			draw_circle(c, 6.0, Color(pal["special"], 0.25), true, -1.0, true)
			draw_arc(c, 6.0, 0.0, TAU, 20, col, 2.0, true)



## The last missed shot, faint, ending in a small cross where the orb gave out.
func _draw_ghost() -> void:
	var col: Color = Color(pal["ink"], 0.22)
	for pts: Array in _ghost_tracks:
		for i: int in pts.size() - 1:
			_dotted(pts[i], pts[i + 1], col, 14.0, 2.2)
	for p: Vector2 in _ghost_end:
		var r: float = 9.0
		draw_line(p + Vector2(-r, -r), p + Vector2(r, r), Color(pal["target"], 0.6), 3.0, true)
		draw_line(p + Vector2(-r, r), p + Vector2(r, -r), Color(pal["target"], 0.6), 3.0, true)


func _dashed(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var length: float = a.distance_to(b)
	if length < 1.0:
		return
	var dir: Vector2 = (b - a) / length
	var s: float = 0.0
	while s < length:
		draw_line(a + dir * s, a + dir * minf(s + 10.0, length), col, width, true)
		s += 18.0


func _draw_features() -> void:
	for i: int in (level.get("switches", []) as Array).size():
		var c: Vector2 = _feature_pos("switches", i)
		var col: Color = pal["special"]
		var rr: float = RicochetSim.SWITCH_R
		var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)])
		if _open:
			var o: PackedVector2Array = pts.duplicate()
			o.append(pts[0])
			draw_polyline(o, Color(col, 0.35), 2.0, true)
		else:
			draw_colored_polygon(pts, col)
			var pulse: float = 0.5 + 0.5 * sin(_clock * 3.0)
			draw_arc(c, rr + 6.0 + 4.0 * pulse, 0.0, TAU, 32, Color(col, 0.5 - 0.3 * pulse), 2.5, true)
			draw_circle(c, 4.0, pal["top"], true, -1.0, true)
	for i: int in (level.get("sparks", []) as Array).size():
		if _sparks_taken.has(i):
			continue
		var c2: Vector2 = _feature_pos("sparks", i)
		var tw: float = 1.0 + 0.12 * sin(_clock * 5.0 + float(i))
		var star: PackedVector2Array = PackedVector2Array()
		for k: int in 8:
			var rad: float = (RicochetSim.SPARK_R * tw) if k % 2 == 0 else RicochetSim.SPARK_R * 0.38
			star.append(c2 + Vector2.from_angle(-PI / 2.0 + TAU * float(k) / 8.0 + _clock * 0.6) * rad)
		draw_circle(c2, RicochetSim.SPARK_R * 1.5, Color(pal["special"], 0.15), true, -1.0, true)
		draw_colored_polygon(star, pal["special"])
	for i: int in (level.get("bumpers", []) as Array).size():
		var b: Array = level["bumpers"][i]
		var c: Vector2 = Vector2(float(b[0]), float(b[1]))
		var r: float = float(b[2]) if b.size() > 2 else RicochetSim.BUMPER_R
		var pulse: float = float(_bumps.get(i, 0.0))
		r *= 1.0 + 0.12 * pulse
		draw_circle(c, r, Color(pal["accent"], 0.16 + 0.3 * pulse), true, -1.0, true)
		draw_arc(c, r, 0.0, TAU, 48, pal["accent"], 4.0, true)
		draw_circle(c, 5.0, pal["accent"], true, -1.0, true)
	for i: int in (level.get("portals", []) as Array).size():
		var pt: Array = level["portals"][i]
		for side: int in 2:
			var c: Vector2 = Vector2(float(pt[side * 2]), float(pt[side * 2 + 1]))
			var col: Color = pal["special"]
			draw_circle(c, RicochetSim.PORTAL_R + 4.0, Color(col, 0.18), true, -1.0, true)
			draw_arc(c, RicochetSim.PORTAL_R + 4.0, 0.0, TAU, 40, col, 3.0, true)
			var spin: float = _clock * (1.6 if side == 0 else -1.6)
			for k: int in 3:
				var a0: float = spin + TAU * float(k) / 3.0
				draw_arc(c, RicochetSim.PORTAL_R + 13.0, a0, a0 + 1.1, 12, Color(col, 0.7), 3.0, true)
			draw_circle(c, 5.0, col, true, -1.0, true)
	for i: int in (level.get("prisms", []) as Array).size():
		var pr: Array = level["prisms"][i]
		var c: Vector2 = Vector2(float(pr[0]), float(pr[1]))
		var rot: float = _clock * 0.8
		var r: float = RicochetSim.PRISM_R + 6.0
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in 3:
			pts.append(c + Vector2.from_angle(rot + TAU * float(k) / 3.0) * r)
		draw_colored_polygon(pts, Color(pal["special"], 0.3))
		var o: PackedVector2Array = pts.duplicate()
		o.append(pts[0])
		draw_polyline(o, pal["special"], 3.0, true)
		draw_circle(c, 4.0, pal["special2"], true, -1.0, true)


func _draw_targets(appear: float) -> void:
	var targets: Array = level.get("targets", [])
	for i: int in targets.size():
		var c: Vector2 = _target_pos(i)
		var hp: int = int(_hp[i]) if i < _hp.size() else 0
		if hp <= 0:
			if _pops.has(i):
				var k: float = float(_pops[i])
				draw_circle(c, RicochetSim.TARGET_R * (1.0 + 0.6 * k), Color(pal["target"], 1.0 - k), true, -1.0, true)
			continue
		var breathe: float = 1.0 + 0.035 * sin(_clock * 2.4 + float(i) * 1.7)
		var r: float = RicochetSim.TARGET_R * breathe * appear
		draw_circle(c, r, pal["target"], true, -1.0, true)
		draw_arc(c, r * 0.46, 0.0, TAU, 32, Color(pal["top"], 0.9), 3.0, true)
		if hp >= 2:
			draw_arc(c, r + 8.0, 0.0, TAU, 48, pal["target"], 4.0, true)
			draw_arc(c, r + 8.0, 0.0, TAU, 48, Color(pal["ink"], 0.25), 1.5, true)


func _draw_orbs() -> void:
	for id: Variant in _trails:
		OrbStyles.draw_trail(self, orb_style, _trails[id], pal, _clock)
	if not playing or _result.is_empty():
		return
	for track: Dictionary in _result["tracks"]:
		var p: Variant = _track_pos(track, _play_t)
		if p == null:
			continue
		OrbStyles.draw_orb(self, orb_style, p, RicochetSim.ORB_R, pal, _clock, true)


func _draw_launcher() -> void:
	var c: Vector2 = RicochetSim.launcher(level)
	var ink: Color = pal["ink"]
	var k: float = 1.0 + 0.18 * _kick
	draw_arc(c, 24.0 * k, 0.0, TAU, 40, Color(ink, 0.9), 3.0, true)
	if not playing and shots_left() > 0:
		var bob: float = 1.0 + 0.05 * sin(_clock * 3.0)
		OrbStyles.draw_orb(self, orb_style, c, RicochetSim.ORB_R * bob, pal, _clock, false)
	# Bounce allowance as pips arched over the launcher.
	var n: int = int(level.get("bounces", 0))
	var spread: float = deg_to_rad(16.0)
	var base: float = aim_angle if (aiming or has_aim) and not playing else -PI / 2.0
	for i: int in n:
		var a: float = base + (float(i) - float(n - 1) * 0.5) * spread
		draw_circle(c + Vector2.from_angle(a) * 38.0, 3.6, Color(ink, 0.85), true, -1.0, true)


func _draw_fx() -> void:
	for r: Dictionary in _rings:
		var k: float = 1.0 - float(r["life"]) / float(r["max"])
		var e: float = 1.0 - pow(1.0 - k, 3.0)
		var rad: float = lerpf(float(r["r0"]), float(r["r1"]), e)
		var col: Color = r["c"]
		draw_arc(r["p"], maxf(0.5, rad), 0.0, TAU, 48, Color(col, col.a * (1.0 - k)), maxf(0.5, float(r["w"]) * (1.0 - k * 0.7)), true)
	for p: Dictionary in _particles:
		var k2: float = float(p["life"]) / float(p["max"])
		var col2: Color = p["c"]
		if p["shard"]:
			var dir: Vector2 = Vector2.from_angle(float(p["rot"])) * float(p["r"]) * 0.5
			draw_line((p["p"] as Vector2) - dir, (p["p"] as Vector2) + dir, Color(col2, k2), 3.0, true)
		else:
			draw_circle(p["p"], float(p["r"]) * (0.4 + 0.6 * k2), Color(col2, col2.a * k2), true, -1.0, true)
