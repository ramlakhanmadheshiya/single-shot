extends Screen
## One room, one shot. A miss resets the room at once (the missed path stays as a
## faint guide) and counts a try; clearing it shows the result card.
## Stars: ★★★ first try, ★★ within three tries (or first try with a hint), ★ after.

const TIPS: Dictionary = {
	"ch1_02": "The dots over the launcher are the bounces you get",
	"ch1_03": "One shot per room  ·  clear it first try for ★★★",
}
## Shown the first time a room holds something the chapter hasn't used yet.
const NEW_THINGS: Dictionary = {
	"armored": "Ringed targets need two passes",
	"glass": "Glass bounces you once, then breaks",
	"void": "Dark blocks swallow the orb",
	"bumper": "Round bumpers bounce the orb",
	"multi_mover": "Two platforms: watch both rails",
	"two_gates": "One switch opens every gate",
}
const TITLES: Array = ["", "Cleared", "Nicely done", "One clean shot"]

var chapter_id: String = "ch1"
var index: int = 0
var level: Dictionary = {}

var board: Board
var _info: Label
var _hint_btn: Button
var _hint_badge: Label
var _toast: Label
var _toast_tween: Tween
var _sheet: Control
var _done: bool = false
var _sheet_focus: Control
var _tries: int = 0
var _hinted: bool = false
var _win_angle: float = 0.0
var _win_tracks: Array = []
var _stars: int = 0
var _intro: Control


func music_track() -> String:
	return chapter_id


func in_game() -> bool:
	return true


func _ready() -> void:
	level = Levels.level(chapter_id, index)
	SaveSystem.set_last_played(chapter_id, index)
	var lid: String = str(level.get("id", ""))
	_tries = 0 if SaveSystem.is_cleared(lid) else SaveSystem.misses(lid)
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	col.add_child(make_header("%s  ·  %d" % [pal["name"], index + 1], func() -> void: app.open_levels(chapter_id)))

	_info = UIKit.label("", 22, pal["muted"], 600)
	_info.name = "TryInfo"
	_info.custom_minimum_size = Vector2(0, 40)
	col.add_child(_info)

	var stage: Control = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(stage)
	board = Board.new()
	board.name = "Board"
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(board)
	board.setup(level, pal)
	board.shot_fired.connect(_on_shot_fired)
	board.shot_finished.connect(_on_shot_finished)
	board.aim_started.connect(func() -> void: _hide_toast())

	_toast = UIKit.label("", 24, pal["ink"], 500)
	_toast.name = "Toast"
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.offset_top = 14
	_toast.offset_bottom = 70
	_toast.modulate.a = 0.0
	stage.add_child(_toast)

	var bar: HBoxContainer = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 40)
	bar.custom_minimum_size = Vector2(0, 112)
	col.add_child(bar)
	var grid: Button = UIKit.icon_button("layout-grid", pal, 80.0)
	grid.name = "LevelsButton"
	grid.pressed.connect(func() -> void: app.open_levels(chapter_id))
	bar.add_child(grid)
	_hint_btn = UIKit.icon_button("lightbulb", pal, 92.0)
	_hint_btn.name = "Hint"
	_hint_btn.pressed.connect(_hint)
	bar.add_child(_hint_btn)
	_hint_badge = UIKit.label("", 18, pal["top"], 700)
	var badge_bg: StyleBoxFlat = StyleBoxFlat.new()
	badge_bg.bg_color = pal["accent"]
	badge_bg.set_corner_radius_all(15)
	_hint_badge.add_theme_stylebox_override("normal", badge_bg)
	_hint_badge.position = Vector2(62, -2)
	_hint_badge.size = Vector2(30, 30)
	_hint_btn.add_child(_hint_badge)
	var restart: Button = UIKit.icon_button("rotate-ccw", pal, 80.0)
	restart.name = "Restart"
	restart.pressed.connect(_restart)
	bar.add_child(restart)

	_refresh()
	if lid == "ch1_01" and not SaveSystem.flag("tutorial_done"):
		var tut: Tutorial = Tutorial.new()
		tut.name = "Tutorial"
		tut.board = board
		tut.pal = pal
		stage.add_child(tut)
		return
	if bool(level.get("intro", false)) and not SaveSystem.flag("intro_" + chapter_id):
		_show_intro(stage)
		return
	var tip: String = str(TIPS.get(lid, ""))
	if tip.is_empty():
		tip = _new_thing_tip()
	if not tip.is_empty():
		_show_toast(tip, 4.0)


## Chapter opener: a card that explains the new idea with a live demo, then the
## room itself with the new element spotlit and the solving path shown once.
func _show_intro(stage: Control) -> void:
	var intro: ChapterIntro = ChapterIntro.new()
	intro.name = "ChapterIntro"
	intro.chapter_id = chapter_id
	intro.pal = pal
	intro.board = board
	intro.done.connect(func() -> void:
		SaveSystem.set_flag("intro_" + chapter_id)
		board.show_hint()
	)
	stage.add_child(intro)
	_intro = intro


## A tip the first time this chapter shows something new (a ringed target, an
## older chapter's idea, two platforms at once...).
func _new_thing_tip() -> String:
	var seen: Dictionary = {}
	for i: int in index:
		for f: String in _features(Levels.level(chapter_id, i)):
			seen[f] = true
	for f: String in _features(level):
		if not seen.has(f) and NEW_THINGS.has(f) and not SaveSystem.flag("tip_" + f):
			SaveSystem.set_flag("tip_" + f)
			return str(NEW_THINGS[f])
	return ""


static func _features(lv: Dictionary) -> Array:
	var out: Array = []
	for t: Array in lv.get("targets", []):
		if t.size() > 2 and int(t[2]) > 1:
			out.append("armored")
	var movers: int = 0
	var gates: int = 0
	for w: Array in lv.get("walls", []):
		var kind: String = RicochetSim.wall_kind(w)
		if kind in ["glass", "void"]:
			out.append(kind)
		if kind == "gate":
			gates += 1
		if RicochetSim.is_moving(w):
			movers += 1
	if not (lv.get("bumpers", []) as Array).is_empty():
		out.append("bumper")
	if movers > 1:
		out.append("multi_mover")
	if gates > 1:
		out.append("two_gates")
	return out


func focus_default() -> void:
	if _sheet != null and is_instance_valid(_sheet) and _sheet_focus != null:
		_sheet_focus.grab_focus()
	else:
		board.grab_focus()


func _refresh() -> void:
	var best: int = SaveSystem.stars_for(str(level.get("id", "")))
	var text: String = "Try %d" % (_tries + 1)
	if best > 0:
		text += "   ·   best " + "★".repeat(best)
	elif _tries == 0:
		text = "One shot"
	_info.text = text
	if SaveSystem.is_supporter():
		_hint_badge.text = "∞"
	else:
		_hint_badge.text = str(SaveSystem.hints_left()) if SaveSystem.hints_left() > 0 else "+"


func _on_shot_fired() -> void:
	_hide_toast()


func _on_shot_finished(cleared: bool, _shots_used: int) -> void:
	var lid: String = str(level["id"])
	if cleared:
		_done = true
		_win_angle = board.last_angle
		_win_tracks = board.last_tracks
		var attempt: int = _tries + 1
		_stars = 3 if attempt == 1 and not _hinted else (2 if attempt <= 3 else 1)
		SaveSystem.record_level(lid, _stars, attempt)
		Events.level_completed.emit(lid, _stars)
		AudioManager.play("win", 1.0)
		await get_tree().create_timer(0.55).timeout
		if is_inside_tree():
			_show_result(attempt)
		return
	# Missed: count the try, say why, and reset the room for the next one.
	_tries += 1
	if not SaveSystem.is_cleared(lid):
		SaveSystem.add_miss(lid)
	AudioManager.play("fail", 1.0)
	Haptics.tap(20)
	var why: String = board.miss_reason()
	if _tries == 3 and not _hinted:
		why += "\nStuck? The bulb shows the way"
		_pulse(_hint_btn)
	_show_toast(why, 3.0)
	await get_tree().create_timer(0.25).timeout
	if is_inside_tree() and not _done:
		board.retry()
		_refresh()


func _pulse(c: Control) -> void:
	var tw: Tween = c.create_tween().set_loops(3)
	tw.tween_property(c, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)


func _restart() -> void:
	_close_sheet()
	_done = false
	board.reset()
	_refresh()


func _hint() -> void:
	if _done or board.playing:
		return
	if SaveSystem.is_supporter() or SaveSystem.hints_left() > 0:
		if _show_hint_now():
			SaveSystem.spend_hint()
			_refresh()
		return
	# Out of free hints: ask first. If no ad can be shown, the hint is free.
	if AdManager.rewarded_ready():
		_ask_for_ad()
	else:
		if _show_hint_now():
			_show_toast("Here's a free hint", 2.5)


func _show_hint_now() -> bool:
	board.retry()
	if board.show_hint():
		_hinted = true
		return true
	return false


func _ask_for_ad() -> void:
	var sheet: VBoxContainer = _open_sheet()
	sheet.add_child(UIKit.label("Out of hints", 44, pal["ink"], 600))
	var note: Label = UIKit.label("Watch a short video to get 1 hint?\nFree hints refill to 3 at midnight.", 24, pal["muted"], 400)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(note)
	var watch: Button = UIKit.pill("Watch a video", pal, "primary", Vector2(0, 88), 30)
	watch.name = "WatchAd"
	watch.pressed.connect(func() -> void:
		_close_sheet()
		AdManager.show_rewarded(func(ok: bool) -> void:
			if ok:
				AudioManager.play("unlock", 1.0)
				_show_hint_now()
			_refresh()
		)
	)
	sheet.add_child(watch)
	var shop: Button = UIKit.pill("Every hint free · Supporter pack", pal, "soft", Vector2(0, 76), 22)
	shop.name = "HintShop"
	shop.pressed.connect(func() -> void:
		_close_sheet()
		app.open_product("supporter_pack")
	)
	sheet.add_child(shop)
	var close: Button = UIKit.pill("Not now", pal, "ghost", Vector2(0, 76), 24)
	close.name = "NotNow"
	close.pressed.connect(_close_sheet)
	sheet.add_child(close)
	_sheet_focus = watch


## How the clear went, in a few words.
func _verdict(attempt: int) -> String:
	if attempt == 1 and not _hinted:
		return "First try. Perfect."
	if attempt == 1:
		return "First try, with a hint."
	if attempt <= 3:
		return "Cleared on try %d." % attempt
	return "Try %d. Persistence pays." % attempt


func _show_result(attempt: int) -> void:
	var sheet: VBoxContainer = _open_sheet()
	sheet.add_theme_constant_override("separation", 14)
	sheet.add_child(UIKit.label("%s  ·  LEVEL %d" % [str(pal["name"]).to_upper(), index + 1], 20, pal["accent"], 700))
	var title: Label = UIKit.label(TITLES[_stars], 54, pal["ink"], 500)
	title.name = "ResultTitle"
	sheet.add_child(title)
	var row: _Stars = _Stars.new()
	row.pal = pal
	row.custom_minimum_size = Vector2(0, 96)
	sheet.add_child(row)
	row.play(_stars)
	sheet.add_child(UIKit.label(_verdict(attempt), 28, pal["ink"], 500))
	sheet.add_child(UIKit.label(_stats_line(), 22, pal["muted"], 500))
	var nxt: Dictionary = Levels.next_after(chapter_id, index)
	var next_btn: Button = UIKit.pill("Next level" if not nxt.is_empty() else "Chapters", pal, "primary", Vector2(0, 92), 32)
	next_btn.name = "Next"
	next_btn.pressed.connect(func() -> void:
		if nxt.is_empty():
			app.open_chapters()
		else:
			app.open_game(str(nxt["chapter"]), int(nxt["index"]))
	)
	sheet.add_child(next_btn)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	sheet.add_child(actions)
	actions.add_child(_action("play", "WATCH", "Watch", func() -> void:
		_close_sheet()
		board.replay(_win_angle)
		_show_toast("Your shot", 1.5)
		await get_tree().create_timer(0.4).timeout
		while is_inside_tree() and board.playing:
			await get_tree().process_frame
		if is_inside_tree():
			await get_tree().create_timer(0.5).timeout
			if is_inside_tree():
				_show_result(attempt)
	))
	actions.add_child(_action("share-2", "SHARE", "Share", func() -> void: app.open_share(_share_info(attempt))))
	actions.add_child(_action("rotate-ccw", "AGAIN", "Replay", func() -> void:
		_tries = 0
		_hinted = false
		_restart()
	))
	actions.add_child(_action("layout-grid", "LEVELS", "Levels", func() -> void: app.open_levels(chapter_id)))
	_sheet_focus = next_btn


func _stats_line() -> String:
	var b: int = int(level.get("need", level.get("bounces", 0)))
	var n: int = (level.get("targets", []) as Array).size()
	return "%d %s  ·  %d %s" % [b, "bounce" if b == 1 else "bounces", n, "target" if n == 1 else "targets"]


## Everything the share card needs.
func _share_info(attempt: int) -> Dictionary:
	return {
		"level": level, "pal": pal, "chapter": str(pal["name"]), "number": index + 1,
		"stars": _stars, "title": TITLES[_stars], "verdict": _verdict(attempt),
		"stats": _stats_line(), "tracks": _win_tracks, "angle": _win_angle,
	}


## A round icon button with a small caption under it.
func _action(icon_name: String, caption: String, node_name: String, cb: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var b: Button = UIKit.icon_button(icon_name, pal, 80.0)
	b.name = node_name
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.label(caption, 16, pal["muted"], 600))
	return box


## Opens a centred card and returns its content column.
func _open_sheet() -> VBoxContainer:
	_close_sheet()
	var root: Control = Control.new()
	root.name = "Sheet"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(pal["bottom"], 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.card_style(pal))
	panel.custom_minimum_size = Vector2(600, 0)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	panel.add_child(col)
	_sheet = root
	shade.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(shade, "modulate:a", 1.0, 0.25)
	panel.modulate.a = 0.0
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	# Pop in from slightly smaller once the card has measured itself.
	(func() -> void:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.85, 0.85)
		var pop: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(panel, "scale", Vector2.ONE, 0.42)
	).call_deferred()
	return col


func _close_sheet() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null


func _show_toast(text: String, seconds: float) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	if seconds > 0.0:
		_toast_tween.tween_interval(seconds)
		_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _hide_toast() -> void:
	if _toast.modulate.a > 0.0:
		if _toast_tween != null:
			_toast_tween.kill()
		_toast_tween = create_tween()
		_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.25)


func handle_back() -> bool:
	if _intro != null and is_instance_valid(_intro):
		_intro.call("dismiss")
		return true
	if _sheet != null and is_instance_valid(_sheet) and not _done:
		_close_sheet()
		return true
	app.open_levels(chapter_id)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var key: InputEventKey = event
	var fine: float = 0.1 if key.shift_pressed else 0.6
	match key.keycode:
		KEY_LEFT, KEY_A:
			board.nudge_aim(-fine)
		KEY_RIGHT, KEY_D:
			board.nudge_aim(fine)
		KEY_SPACE:
			if board.playing:
				board.fast_forward()
			elif not _done:
				board.fire_current()
		KEY_R:
			_restart()
		KEY_H:
			_hint()
		_:
			return
	get_viewport().set_input_as_handled()


## Three stars that pop in one after another with rising notes.
class _Stars:
	extends Control
	var pal: Dictionary
	var _shown: Array[float] = [0.0, 0.0, 0.0]
	var _earned: int = 0

	func play(stars: int) -> void:
		_earned = stars
		for i: int in 3:
			var tw: Tween = create_tween()
			tw.tween_interval(0.25 + 0.22 * float(i))
			tw.tween_callback(func() -> void:
				if i < _earned:
					AudioManager.play("star", [1.0, 1.25, 1.5][i])
					Haptics.tap(12)
			)
			tw.tween_method(func(v: float) -> void:
				_shown[i] = v
				queue_redraw(), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var tex: Texture2D = UIKit.icon("star-filled")
		var outline: Texture2D = UIKit.icon("star")
		for i: int in 3:
			var s: float = (78.0 if i == 1 else 64.0) * _shown[i]
			if s <= 1.0:
				continue
			var c: Vector2 = Vector2(size.x * 0.5 + (float(i) - 1.0) * 104.0, size.y * 0.5 - (8.0 if i == 1 else 0.0))
			var r: Rect2 = Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
			if i < _earned:
				draw_texture_rect(tex, r, false, Color("#FFC53D"))
			else:
				draw_texture_rect(outline, r, false, Color(pal["ink"], 0.25))
