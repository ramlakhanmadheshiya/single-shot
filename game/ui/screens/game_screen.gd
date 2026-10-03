extends Screen
## One room: a slim header, the board, shots left, and hint / undo.

const TIPS: Dictionary = {
	"ch1_01": "Drag to aim  ·  release to shoot",
	"ch1_02": "Dots over the launcher = bounces allowed",
	"ch1_03": "Clear the room in one shot for ★★★",
	"ch2_01": "Glass bounces you once, then breaks",
	"ch3_01": "Dark blocks swallow light  ·  rings bounce it",
	"ch4_01": "Portals carry your orb across the room",
	"ch5_01": "A prism splits one orb into two",
	"ch6_01": "Hit the switch to dissolve the gates",
	"ch7_01": "Fly through a spark for one extra bounce",
	"ch8_01": "Pivot walls turn 90° every time you hit them",
}

var chapter_id: String = "ch1"
var index: int = 0
var level: Dictionary = {}

var board: Board
var _shots: _ShotDots
var _hint_btn: Button
var _hint_badge: Label
var _undo_btn: Button
var _toast: Label
var _sheet: Control
var _done: bool = false
var _sheet_focus: Control


func music_track() -> String:
	return chapter_id


func in_game() -> bool:
	return true


func _ready() -> void:
	level = Levels.level(chapter_id, index)
	SaveSystem.set_last_played(chapter_id, index)
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	col.add_child(make_header("%s  ·  %d" % [pal["name"], index + 1], func() -> void: app.open_levels(chapter_id)))

	_shots = _ShotDots.new()
	_shots.pal = pal
	_shots.custom_minimum_size = Vector2(0, 40)
	col.add_child(_shots)

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
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 18
	_toast.offset_bottom = 70
	_toast.modulate.a = 0.0
	stage.add_child(_toast)

	var bar: HBoxContainer = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 40)
	bar.custom_minimum_size = Vector2(0, 112)
	col.add_child(bar)
	_undo_btn = UIKit.icon_button("undo-2", pal, 80.0)
	_undo_btn.name = "Undo"
	_undo_btn.pressed.connect(_undo)
	bar.add_child(_undo_btn)
	var restart: Button = UIKit.icon_button("rotate-ccw", pal, 80.0)
	restart.name = "Restart"
	restart.pressed.connect(_restart)
	bar.add_child(restart)
	_hint_btn = UIKit.icon_button("lightbulb", pal, 80.0)
	_hint_btn.name = "Hint"
	_hint_btn.pressed.connect(_hint)
	bar.add_child(_hint_btn)
	_hint_badge = UIKit.label("", 18, pal["top"], 700)
	_hint_badge.custom_minimum_size = Vector2(30, 30)
	var badge_bg: StyleBoxFlat = StyleBoxFlat.new()
	badge_bg.bg_color = pal["accent"]
	badge_bg.set_corner_radius_all(15)
	_hint_badge.add_theme_stylebox_override("normal", badge_bg)
	_hint_badge.position = Vector2(54, -2)
	_hint_badge.size = Vector2(30, 30)
	_hint_btn.add_child(_hint_badge)

	_refresh()
	var tip: String = str(TIPS.get(str(level.get("id", "")), ""))
	if tip.is_empty() and not SaveSystem.flag("tip_armored"):
		for t: Array in level.get("targets", []):
			if int(t[2]) > 1:
				tip = "Ringed targets need two passes"
				SaveSystem.set_flag("tip_armored")
				break
	if not tip.is_empty():
		_show_toast(tip, 0.0)


func focus_default() -> void:
	if _sheet != null and is_instance_valid(_sheet) and _sheet_focus != null:
		_sheet_focus.grab_focus()
	else:
		board.grab_focus()


func _refresh() -> void:
	_shots.total = int(level.get("shots", 3))
	_shots.left = board.shots_left()
	_shots.queue_redraw()
	_undo_btn.disabled = board.history.is_empty() or board.playing or _done
	if SaveSystem.is_supporter():
		_hint_badge.text = "∞"
	else:
		_hint_badge.text = str(SaveSystem.hints_left()) if SaveSystem.hints_left() > 0 else "+"


func _on_shot_fired() -> void:
	_hide_toast()
	_refresh()


func _on_shot_finished(cleared: bool, shots_used: int) -> void:
	_refresh()
	if cleared:
		_done = true
		var stars: int = clampi(4 - shots_used, 1, 3)
		var first_clear: bool = not SaveSystem.is_cleared(str(level["id"]))
		SaveSystem.record_level(str(level["id"]), stars, shots_used)
		Events.level_completed.emit(str(level["id"]), stars)
		AudioManager.play("win", 1.0)
		await get_tree().create_timer(0.55).timeout
		if is_inside_tree():
			_show_result(true, stars, shots_used, first_clear)
	elif board.shots_left() <= 0:
		_done = true
		await get_tree().create_timer(0.35).timeout
		if is_inside_tree():
			AudioManager.play("fail", 1.0)
			_show_result(false, 0, shots_used, false)


func _restart() -> void:
	_close_sheet()
	_done = false
	board.reset()
	_refresh()


func _undo() -> void:
	if _done:
		return
	if board.undo():
		_refresh()


func _hint() -> void:
	if _done or board.playing:
		return
	if not SaveSystem.is_supporter() and SaveSystem.hints_left() <= 0:
		_offer_hints()
		return
	if board.show_hint():
		SaveSystem.spend_hint()
		_refresh()
	else:
		_show_toast("No single shot clears this now — try a restart", 3.0)


func _offer_hints() -> void:
	var sheet: VBoxContainer = _open_sheet()
	sheet.add_child(UIKit.label("Out of hints", 40, pal["ink"], 600))
	var note: Label = UIKit.label("3 free hints refill every day at midnight.\nSupporters get every hint free.", 24, pal["muted"], 400)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(note)
	var watch: Button = UIKit.pill("Watch a short ad  ·  +1 hint", pal, "primary", Vector2(440, 88), 28)
	watch.name = "WatchAd"
	watch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	watch.disabled = not AdManager.rewarded_ready()
	watch.pressed.connect(func() -> void:
		AdManager.show_rewarded(func(ok: bool) -> void:
			if ok:
				SaveSystem.add_hints(1)
				AudioManager.play("unlock", 1.0)
			_close_sheet()
			_refresh()
		)
	)
	sheet.add_child(watch)
	var close: Button = UIKit.pill("Not now", pal, "ghost", Vector2(260, 72), 24)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_sheet)
	sheet.add_child(close)
	_sheet_focus = watch


func _show_result(won: bool, stars: int, shots_used: int, _first: bool) -> void:
	var sheet: VBoxContainer = _open_sheet()
	if won:
		var title: String = ["Cleared", "Cleared", "Nice", "Perfect"][stars]
		sheet.add_child(UIKit.label(title, 52, pal["ink"], 500))
		var row: _Stars = _Stars.new()
		row.pal = pal
		row.custom_minimum_size = Vector2(0, 96)
		sheet.add_child(row)
		row.play(stars)
		var sub: String = "One shot. Clean." if shots_used == 1 else "Cleared in %d shots  ·  one shot earns ★★★" % shots_used
		sheet.add_child(UIKit.label(sub, 22, pal["muted"], 400))
		var buttons: HBoxContainer = HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons.add_theme_constant_override("separation", 22)
		sheet.add_child(buttons)
		var again: Button = UIKit.icon_button("rotate-ccw", pal, 88.0)
		again.name = "Replay"
		again.pressed.connect(_restart)
		buttons.add_child(again)
		var nxt: Dictionary = Levels.next_after(chapter_id, index)
		var next_btn: Button = UIKit.pill("Next" if not nxt.is_empty() else "Chapters", pal, "primary", Vector2(260, 88), 30)
		next_btn.name = "Next"
		next_btn.pressed.connect(func() -> void:
			if nxt.is_empty():
				AdManager.between_levels(func() -> void: app.open_chapters())
			else:
				AdManager.between_levels(func() -> void: app.open_game(str(nxt["chapter"]), int(nxt["index"])))
		)
		buttons.add_child(next_btn)
		var grid: Button = UIKit.icon_button("layout-grid", pal, 88.0)
		grid.name = "Levels"
		grid.pressed.connect(func() -> void: AdManager.between_levels(func() -> void: app.open_levels(chapter_id)))
		buttons.add_child(grid)
		_sheet_focus = next_btn
	else:
		sheet.add_child(UIKit.label("Out of shots", 48, pal["ink"], 500))
		sheet.add_child(UIKit.label("Every room can be cleared in one shot.", 24, pal["muted"], 400))
		var buttons2: HBoxContainer = HBoxContainer.new()
		buttons2.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons2.add_theme_constant_override("separation", 22)
		sheet.add_child(buttons2)
		var retry: Button = UIKit.pill("Retry", pal, "primary", Vector2(260, 88), 30)
		retry.name = "Retry"
		retry.pressed.connect(_restart)
		buttons2.add_child(retry)
		var hint: Button = UIKit.icon_button("lightbulb", pal, 88.0)
		hint.name = "RetryHint"
		hint.pressed.connect(func() -> void:
			_restart()
			_hint()
		)
		buttons2.add_child(hint)
		_sheet_focus = retry


## Opens a bottom sheet and returns its content column.
func _open_sheet() -> VBoxContainer:
	_close_sheet()
	var root: Control = Control.new()
	root.name = "Sheet"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(pal["bottom"], 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = (pal["top"] as Color).lerp(Color.WHITE, 0.0 if pal.get("dark", false) else 0.35)
	if pal.get("dark", false):
		sb.bg_color = (pal["top"] as Color).lightened(0.06)
	sb.set_corner_radius_all(48)
	sb.corner_detail = 12
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 44
	sb.content_margin_bottom = 52
	sb.shadow_color = Color(0, 0, 0, 0.12)
	sb.shadow_size = 24
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	panel.add_child(col)
	_sheet = root
	shade.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(shade, "modulate:a", 1.0, 0.25)
	panel.modulate.a = 0.0
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	# Slide up once the container has measured itself.
	(func() -> void:
		var h: float = panel.get_combined_minimum_size().y
		panel.offset_top = -h + 140.0
		panel.offset_bottom = 140.0
		var slide: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slide.tween_property(panel, "offset_top", -h + 24.0, 0.42)
		slide.tween_property(panel, "offset_bottom", 24.0, 0.42)
	).call_deferred()
	return col


func _close_sheet() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null


func _show_toast(text: String, seconds: float) -> void:
	_toast.text = text
	var tw: Tween = create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.35)
	if seconds > 0.0:
		tw.tween_interval(seconds)
		tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _hide_toast() -> void:
	if _toast.modulate.a > 0.0:
		create_tween().tween_property(_toast, "modulate:a", 0.0, 0.25)


func handle_back() -> bool:
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
			if not _done:
				board.fire_current()
		KEY_Z:
			_undo()
		KEY_R:
			_restart()
		KEY_H:
			_hint()
		_:
			return
	get_viewport().set_input_as_handled()


## Remaining shots as a row of small orbs.
class _ShotDots:
	extends Control
	var pal: Dictionary
	var total: int = 3
	var left: int = 3

	func _draw() -> void:
		var gap: float = 30.0
		var x0: float = size.x * 0.5 - gap * float(total - 1) * 0.5
		for i: int in total:
			var p: Vector2 = Vector2(x0 + gap * float(i), size.y * 0.5)
			if i < left:
				draw_circle(p, 8.0, pal["ink"], true, -1.0, true)
			else:
				draw_arc(p, 7.0, 0.0, TAU, 24, Color(pal["ink"], 0.3), 2.0, true)


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
			var s: float = (64.0 if i == 1 else 52.0) * _shown[i]
			if s <= 1.0:
				continue
			var c: Vector2 = Vector2(size.x * 0.5 + (float(i) - 1.0) * 92.0, size.y * 0.5 - (10.0 if i == 1 else 0.0))
			var r: Rect2 = Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
			if i < _earned:
				draw_texture_rect(tex, r, false, pal["accent"])
			else:
				draw_texture_rect(outline, r, false, Color(pal["ink"], 0.25))
