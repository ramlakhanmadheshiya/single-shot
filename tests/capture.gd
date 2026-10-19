extends Node
## Drives the real app through every screen and saves screenshots.
## Run (needs a window): godot --path . res://tests/capture.tscn -- <out_dir>

var out_dir: String = "user://captures"
var _store_vp: SubViewport
var app: Control
var _backup: Dictionary


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	AudioManager.mute_for_tests = not OS.get_cmdline_user_args().has("--new")
	_backup = SaveSystem.data.duplicate(true)
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	if OS.get_cmdline_user_args().has("--store-raw"):
		_guard_save()
	if OS.get_cmdline_user_args().has("--store") or OS.get_cmdline_user_args().has("--store-raw"):
		# Store screenshots: a full 1080 x 1920 phone screen, whatever the monitor.
		_store_vp = SubViewport.new()
		_store_vp.size = Vector2i(1080, 1920)
		_store_vp.size_2d_override = Vector2i(720, 1280)
		_store_vp.size_2d_override_stretch = true
		_store_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_store_vp)
		_store_vp.add_child(app)
	else:
		add_child(app)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = (_store_vp if _store_vp != null else get_viewport()).get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("captured ", name)


func _board() -> Board:
	return app.current.get("board") as Board


func _run() -> void:
	if OS.get_cmdline_user_args().has("--new"):
		await _new_screens()
		return
	if OS.get_cmdline_user_args().has("--marketing"):
		await _marketing()
		return
	if OS.get_cmdline_user_args().has("--store"):
		await _store()
		return
	if OS.get_cmdline_user_args().has("--store-raw"):
		await _store_raw()
		return
	if OS.get_cmdline_user_args().has("--about"):
		await _wait(1.5)
		app.open_about()
		await _wait(0.8)
		await _shot("about")
		get_tree().quit()
		return
	SaveSystem.data["owned"] = {}
	SaveSystem.data["flags"] = {}
	await _wait(2.4)
	await _shot("01_home")
	app.open_chapters()
	await _wait(1.6)
	await _shot("02_chapters")
	(app.find_child("Scroll", true, false) as TouchScroll).scroll_to(1200.0)
	await _wait(0.8)
	await _shot("02b_chapters_more")
	app.open_levels("ch1")
	await _wait(0.9)
	await _shot("03_levels")
	app.open_game("ch1", 0)
	await _wait(1.6)
	await _shot("04_tutorial")
	app.open_game("ch2", 0)
	await _wait(1.2)
	await _shot("05_chapter_intro")
	app.current.find_child("GotIt", true, false).emit_signal("pressed")
	await _wait(0.8)
	await _shot("05b_intro_spotlight")
	var b: Board
	for spec: Array in [["ch1", 12, "06_dawn_13"], ["ch3", 9, "08_void_10"], ["ch4", 8, "09_shift_09"], ["ch9", 5, "10e_drift_06"], ["ch9", 30, "10f_drift_31"], ["ch8", 12, "10d_turn_13"], ["ch5", 10, "10_prism_11"]]:
		app.open_game(spec[0], spec[1])
		await _wait(1.1)
		b = _board()
		await _shot(spec[2] + "_room")
		b.fire(deg_to_rad(float(b.level["solution"][0])))
		await _wait(0.5)
		await _shot(spec[2] + "_flight")
	await _wait(5.0)
	await _shot("11_result")
	app.current.find_child("Share", true, false).emit_signal("pressed")
	await _wait(1.5)
	await _shot("11b_share")
	app.close_settings()
	app.open_game("ch1", 20)
	await _wait(1.0)
	b = _board()
	b.fire(deg_to_rad(float(b.level["solution"][0]) + 4.0))
	while b.playing:
		await _wait(0.1)
	await _wait(0.4)
	await _shot("12_missed")
	app.open_settings(true)
	await _wait(0.6)
	await _shot("13_settings")
	app.open_how_to_play()
	await _wait(0.6)
	await _shot("13b_how_to_play")
	app.open_about()
	await _wait(0.6)
	await _shot("13c_about")
	app.open_credits()
	await _wait(0.6)
	await _shot("13e_credits")
	app.close_settings()
	app.open_shop()
	await _wait(1.2)
	await _shot("14_shop")
	app.open_product("complete_pack")
	await _wait(0.8)
	await _shot("14b_complete")
	app.open_product("orb_pack")
	await _wait(0.8)
	await _shot("14c_orbs")
	app.open_picker("themes")
	await _wait(0.8)
	await _shot("14d_themes_picker")
	app.open_tips()
	await _wait(0.6)
	await _shot("14e_tips")
	app.close_settings()
	SaveSystem.data["owned"] = {"theme_pack": true}
	SaveSystem.set_setting("theme", "midnight")
	app.open_chapters()
	await _wait(1.4)
	await _shot("16_theme_midnight")
	SaveSystem.set_setting("theme", "chapters")
	SaveSystem.data = _backup
	SaveSystem.save()
	SaveSystem._apply_cosmetics()
	get_tree().quit()


## The screens added in the second round of changes.
func _new_screens() -> void:
	await _wait(1.25)
	await _shot("n01_splash_shot")
	await _wait(0.75)
	await _shot("n02_splash_title")
	AudioManager.mute_for_tests = true
	await _wait(1.2)
	for i: int in 13:
		SaveSystem.data["levels"]["ch1_%02d" % (i + 1)] = {"stars": [3, 2, 3, 1][i % 4], "best": 1}
	SaveSystem.data["keys"] = 3
	SaveSystem.data["unlocked"]["ch1_20"] = true
	app.open_levels("ch1")
	await _wait(1.4)
	await _shot("n03_levels")
	(app.find_child("Scroll", true, false) as TouchScroll).scroll_to(900.0)
	await _wait(0.6)
	await _shot("n04_levels_bottom")
	app.open_locked("ch1", 25)
	await _wait(0.6)
	await _shot("n05_locked")
	app.open_keys()
	await _wait(0.6)
	app.find_child("Quick_5", true, false).emit_signal("pressed")
	await _wait(0.4)
	await _shot("n06_keys")
	app.open_tips()
	await _wait(0.6)
	await _shot("n07_tips")
	app.open_setting_info("long_guide")
	await _wait(0.8)
	await _shot("n08_info_guide")
	app.open_setting_info("shake")
	await _wait(1.0)
	await _shot("n09_info_shake")
	app.close_settings()
	app.open_game("ch1", 14)
	await _wait(1.0)
	var b: Board = _board()
	b.fire(deg_to_rad(float(b.level["solution"][0]) + 5.0))
	while b.playing:
		await _wait(0.1)
	await _wait(0.5)
	b.fire(deg_to_rad(float(b.level["solution"][0]) + 5.0))
	while b.playing:
		await _wait(0.1)
	await _wait(0.6)
	await _shot("n10_hud_try3")
	app.current.call("_hint")
	await _wait(0.4)
	await _shot("n11_hint")
	app.open_game("ch9", 7)
	await _wait(1.0)
	app.current.call("_hint")
	await _wait(0.7)
	await _shot("n12_drift_hint")
	app.open_shop()
	await _wait(1.0)
	await _shot("n13_shop")
	SaveSystem.data = _backup
	SaveSystem.save()
	get_tree().quit()


## Clean, ad-free shots for the website and store listing.
func _marketing() -> void:
	SaveSystem.data["owned"] = {"supporter_pack": true}
	SaveSystem.data["flags"] = {"tutorial_done": true, "intro_ch2": true, "intro_ch5": true, "intro_ch9": true}
	AdManager.refresh_banner()
	for i: int in 9:
		SaveSystem.data["levels"]["ch1_%02d" % (i + 1)] = {"stars": [3, 3, 2][i % 3], "best": 1}
	await _wait(1.5)
	app.open_home()
	await _wait(1.6)
	await _shot("m1_home")
	app.open_chapters()
	await _wait(1.6)
	await _shot("m2_chapters")
	for spec: Array in [["ch2", 14, "m3_glass"], ["ch5", 12, "m4_prism"], ["ch1", 24, "m5_dawn"]]:
		app.open_game(spec[0], spec[1])
		await _wait(1.2)
		var b: Board = _board()
		b.has_aim = true
		b.aim_angle = deg_to_rad(float(b.level["solution"][0]))
		await _wait(0.3)
		await _shot(spec[2] + "_aim")
		b.fire(b.aim_angle)
		await _wait(0.75)
		await _shot(spec[2] + "_flight")
	while _board().playing:
		await _wait(0.1)
	await _wait(2.2)
	await _shot("m6_result")
	app.open_levels("ch1")
	await _wait(1.4)
	await _shot("m7_levels")
	SaveSystem.data = _backup
	SaveSystem.save()
	get_tree().quit()


## Google Play phone screenshots (1080 x 1920, real screens, no frames, no
## prices, no ads) and the 1024 x 500 feature graphic.
func _store() -> void:
	SaveSystem.data["owned"] = {"supporter_pack": true}
	SaveSystem.data["flags"] = {"tutorial_done": true, "intro_ch2": true, "intro_ch5": true, "intro_ch9": true, "intro_ch6": true}
	SaveSystem.data["hints"] = 3
	AdManager.refresh_banner()
	for i: int in 12:
		SaveSystem.data["levels"]["ch1_%02d" % (i + 1)] = {"stars": [3, 3, 2, 3][i % 4], "best": 1}
	for i: int in 6:
		SaveSystem.data["levels"]["ch9_%02d" % (i + 1)] = {"stars": 3, "best": 1}
	await _wait(1.5)
	app.open_home()
	await _wait(1.8)
	await _shot("01_home")
	for spec: Array in [["ch1", 22, "02_dawn"], ["ch2", 14, "03_glass"], ["ch9", 11, "04_drift"], ["ch5", 12, "05_prism"]]:
		app.open_game(spec[0], spec[1])
		await _wait(1.2)
		var b: Board = _board()
		b.has_aim = true
		b.aim_angle = deg_to_rad(float(b.level["solution"][0]))
		b.set("_world_t", 0.0)
		b.replay(b.aim_angle, 0.0)
		await _wait(0.8)
		await _shot(spec[2])
	# A real clear (not a replay), so the result card appears.
	app.open_game("ch1", 7)
	await _wait(1.2)
	var won: Board = _board()
	won.fire(deg_to_rad(float(won.level["solution"][0])))
	while won.playing:
		await _wait(0.1)
	await _wait(2.6)
	await _shot("06_result")
	app.open_chapters()
	await _wait(1.8)
	await _shot("07_chapters")
	app.open_levels("ch1")
	await _wait(1.6)
	await _shot("08_levels")
	SaveSystem.data = _backup
	SaveSystem.save()
	get_tree().quit()


# --- Store raws (tools/store_art.py composes them) ----------------------------
# Run: godot --fixed-fps 60 --disable-vsync --always-on-top --path . res://tests/capture.tscn -- build/store/raw --store-raw [only=a,b]
# Each raw in tools/store_raws.json is staged through the game's own code paths at
# the pixel size it is composed at, with a JSON sidecar giving the board's geometry
# (arena, launcher, aim line, hint path, solution path, targets) in frame fractions.

const STORE_SIZES: Dictionary = {
	"phone": Vector2i(1080, 1920), "tablet": Vector2i(1200, 1920), "hero": Vector2i(2160, 3840),
}
## Holds the player's real save while a capture runs; a run that dies leaves it
## here, and the next run puts it back before doing anything else.
const SAVE_GUARD: String = "user://capture_save_guard.json"


func _guard_save() -> void:
	if FileAccess.file_exists(SAVE_GUARD):
		_restore_save()
		SaveSystem.load_save()
	var existed: bool = FileAccess.file_exists(SaveSystem.SAVE_PATH)
	var text: String = FileAccess.get_file_as_string(SaveSystem.SAVE_PATH) if existed else ""
	var f: FileAccess = FileAccess.open(SAVE_GUARD, FileAccess.WRITE)
	f.store_string(JSON.stringify({"existed": existed, "text": text}))
	f.close()
	_backup = SaveSystem.data.duplicate(true)
	# Shots start from a fresh install's save, whatever theme or orb the player picked.
	SaveSystem.data = SaveSystem._defaults()
	SaveSystem._apply_cosmetics()


func _restore_save() -> void:
	var guard: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_GUARD))
	if guard is Dictionary:
		if bool(guard["existed"]):
			var f: FileAccess = FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
			f.store_string(str(guard["text"]))
			f.close()
		elif FileAccess.file_exists(SaveSystem.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_GUARD))


func _store_raw() -> void:
	if out_dir.is_relative_path():
		out_dir = ProjectSettings.globalize_path("res://").path_join(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Keep Godot from importing the PNGs if the editor is opened.
	FileAccess.open(out_dir.get_base_dir().path_join(".gdignore"), FileAccess.WRITE).close()
	var only: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	SaveSystem.data["owned"] = {"supporter_pack": true}
	for cid: String in Palette.ids():
		SaveSystem.data["flags"]["intro_" + cid] = true
	SaveSystem.data["flags"]["tutorial_done"] = true
	for i: int in 12:
		SaveSystem.data["levels"]["ch1_%02d" % (i + 1)] = {"stars": [3, 3, 2, 3][i % 4], "best": 1}
	SaveSystem._apply_cosmetics()
	AdManager.refresh_banner()
	var spec: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/store_raws.json"))
	await _wait(1.5)
	for raw: Dictionary in spec:
		if not only.is_empty() and not only.has(str(raw["name"])):
			continue
		await _stage_raw(raw)
	SaveSystem.data = _backup
	_restore_save()
	get_tree().quit()


func _store_size(kind: String) -> void:
	var px: Vector2i = STORE_SIZES[kind]
	if _store_vp.size == px:
		return
	_store_vp.size = px
	_store_vp.size_2d_override = Vector2i(720, roundi(720.0 * px.y / px.x))
	app.call("_apply_safe_area")
	await _wait(0.2)


func _stage_raw(raw: Dictionary) -> void:
	seed(1)
	await _store_size(str(raw.get("size", "phone")))
	var name: String = str(raw["name"])
	var act: String = str(raw["do"])
	if act == "title":
		app.open_home()
		await _wait(1.8)
		# The chip under Play carries the star tally, which would date the shot.
		var chip: Control = app.find_child("Continue", true, false) as Control
		if chip != null:
			chip.modulate.a = 0.0
		await _raw_shot(name, null)
		return
	var lv: PackedStringArray = str(raw["level"]).split(":")
	app.open_game(lv[0], int(lv[1]) - 1)
	await _wait(1.3)
	var screen: Node = app.current
	var b: Board = _board()
	# Staged as a supporter so no ad shows; the hint badge would then read "∞", so it goes.
	var badge: Control = screen.get("_hint_badge") as Control
	if badge != null:
		badge.visible = false
	var angle: float = deg_to_rad(float(b.level["solution"][0]) + float(raw.get("deg", 0.0)))
	match act:
		"aim":
			# What a finger held on the room draws: the aim line and the targets it reaches.
			b.set("_world_t", float(raw.get("t", 0.0)))
			b.has_aim = true
			b.aim_angle = angle
			b.set("_preview", {})
			await _wait(0.25)
		"hint":
			screen.call("_hint")
			await _wait(float(raw.get("wait", 0.7)))
		"flight":
			if bool(raw.get("path", false)):
				b.show_path(angle, 0.0)
			b.set("_world_t", 0.0)
			b.replay(angle, 0.0)
			var goal: float = _flight_goal(b, raw)
			while b.playing and float(b.get("_play_t")) < goal:
				await get_tree().process_frame
			await _wait(float(raw.get("hold", 0.0)))
		"won":
			# A real clear, so the result card rises.
			b.fire(angle)
			while b.playing:
				await _wait(0.1)
			await _wait(2.6)
	await _raw_shot(name, b)
	if act == "won":
		var info: Dictionary = screen.call("_share_info", 1)
		var done: Array = []
		ShareCard.render(self, info, func(img: Image) -> void: done.append(img))
		while done.is_empty():
			await get_tree().process_frame
		var card: Image = done[0]
		card.convert(Image.FORMAT_RGB8)
		card.save_png(out_dir.path_join(name + "_card.png"))
		print("captured ", name, "_card")


## How far (in arena units of travel) a staged flight runs before the still: just
## after the Nth pop, or after the prism split.
func _flight_goal(b: Board, raw: Dictionary) -> float:
	var events: Array = (b.get("_result") as Dictionary)["events"]
	var after: float = float(raw.get("after", 40.0))
	var want: int = int(raw.get("pop", 0))
	var kind: String = "split" if raw.has("split") else "pop"
	var seen: int = 0
	for e: Dictionary in events:
		if str(e["type"]) == kind:
			seen += 1
			if kind == "split" or seen >= want:
				return float(e["t"]) + after
	return float((b.get("_result") as Dictionary)["duration"]) * float(raw.get("frac", 0.9))


func _raw_shot(name: String, b: Board) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = _store_vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join(name + ".png"))
	var px: Vector2 = Vector2(_store_vp.size)
	var meta: Dictionary = {"size": [px.x, px.y]}
	if b != null:
		var k: float = px.x / float(_store_vp.size_2d_override.x)
		var xf: Transform2D = b.get_global_transform_with_canvas()
		var to_frame: Callable = func(p: Vector2) -> Array:
			var q: Vector2 = xf * b.to_screen(p) * k
			return [snappedf(q.x / px.x, 0.0001), snappedf(q.y / px.y, 0.0001)]
		var lines: Callable = func(tracks: Array) -> Array:
			var out: Array = []
			for pts: Variant in tracks:
				var line: Array = []
				for p: Vector2 in pts:
					line.append(to_frame.call(p))
				out.append(line)
			return out
		var a: Array = to_frame.call(Vector2.ZERO)
		var z: Array = to_frame.call(RicochetSim.ARENA)
		meta["board"] = [a[0], a[1], z[0], z[1]]
		meta["launcher"] = to_frame.call(RicochetSim.launcher(b.level))
		var targets: Array = []
		for t: Array in b.level.get("targets", []):
			targets.append(to_frame.call(Vector2(t[0], t[1])))
		meta["targets"] = targets
		var prev: Dictionary = b.get("_preview")
		if b.has_aim and not prev.is_empty():
			meta["aim"] = lines.call([prev["points"]])[0]
		meta["hint"] = lines.call(b.get("_hint_tracks"))
		var st: Dictionary = RicochetSim.initial_state(b.level)
		st["t0"] = 0.0
		var res: Dictionary = RicochetSim.simulate(b.level, st, deg_to_rad(float(b.level["solution"][0])))
		var sol: Array = []
		for tr: Dictionary in res["tracks"]:
			sol.append(tr["points"])
		meta["solution"] = lines.call(sol)
		var pal: Dictionary = b.pal
		meta["colours"] = {}
		for key: String in ["top", "bottom", "ink", "accent", "target", "wall"]:
			meta["colours"][key] = "#" + (pal[key] as Color).to_html(false)
		meta["chapter"] = str(pal["name"])
	var f: FileAccess = FileAccess.open(out_dir.path_join(name + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("captured ", name)
