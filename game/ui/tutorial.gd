class_name Tutorial
extends Control
## Hands-on first-play tutorial for Dawn level 1. It never blocks input: the
## player really aims and shoots while an animated hand and short captions guide
## them through drag -> line up -> release.

signal finished

enum Step { SHOW, AIMING, ON_TARGET, FLYING, RETRY, DONE }

var board: Board
var pal: Dictionary
var step: Step = Step.SHOW
var _t: float = 0.0
var _caption: Label
var _bubble: PanelContainer
var _shown_text: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = pal["ink"]
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = UIKit.label("", 26, pal["top"], 600)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(420, 0)
	_bubble.add_child(_caption)
	add_child(_bubble)
	board.aim_started.connect(func() -> void:
		if step == Step.SHOW or step == Step.RETRY:
			_go(Step.AIMING)
	)
	board.shot_fired.connect(func() -> void: _go(Step.FLYING))
	board.shot_finished.connect(func(cleared: bool, _shots: int) -> void:
		if cleared:
			_go(Step.DONE)
			SaveSystem.set_flag("tutorial_done")
			var tw: Tween = create_tween()
			tw.tween_interval(0.4)
			tw.tween_property(self, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func() -> void:
				finished.emit()
				queue_free()
			)
		else:
			_go(Step.RETRY)
	)
	_go(Step.SHOW)


func _go(next: Step) -> void:
	step = next
	_t = 0.0
	match step:
		Step.SHOW:
			_say("Touch and drag to aim")
		Step.AIMING:
			_say("Move until the line touches the red target")
		Step.ON_TARGET:
			_say("Now let go to shoot!")
		Step.FLYING:
			_say("")
		Step.RETRY:
			_say("So close! Try again — drag to aim")
		Step.DONE:
			_say("Perfect — a clean shot!")


func _say(text: String) -> void:
	if text == _shown_text:
		return
	_shown_text = text
	_bubble.visible = not text.is_empty()
	_caption.text = text
	_bubble.pivot_offset = _bubble.size * 0.5
	_bubble.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(_bubble, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if step == Step.AIMING or step == Step.ON_TARGET:
		var on: bool = board.aiming and board.aim_hits_target()
		if on and step == Step.AIMING:
			_go(Step.ON_TARGET)
			Haptics.tap(10)
		elif not on and step == Step.ON_TARGET:
			_go(Step.AIMING)
		# Finger lifted without shooting (too close to the launcher): show the demo again.
		if not board.aiming and not board.playing:
			_go(Step.RETRY if board.shots_used > 0 else Step.SHOW)
	# Keep the caption above the arena.
	var top: Vector2 = board.global_position - global_position + board.to_screen(Vector2(RicochetSim.ARENA.x * 0.5, 0))
	_bubble.position = Vector2(top.x - _bubble.size.x * 0.5, top.y + 24)
	queue_redraw()


func _draw() -> void:
	if board == null or board.level.is_empty():
		return
	var origin: Vector2 = board.global_position - global_position
	var launcher: Vector2 = origin + board.to_screen(RicochetSim.launcher(board.level))
	var t0: Array = board.level["targets"][0]
	var target: Vector2 = origin + board.to_screen(Vector2(float(t0[0]), float(t0[1])))
	if step == Step.SHOW or step == Step.RETRY:
		# A looping demo: the hand presses below the target, drags up to it, lets go.
		var cycle: float = fmod(_t, 2.6) / 2.6
		var press: float = clampf(cycle / 0.15, 0.0, 1.0)
		var move: float = clampf((cycle - 0.15) / 0.55, 0.0, 1.0)
		move = 1.0 - pow(1.0 - move, 3.0)
		var release: float = clampf((cycle - 0.78) / 0.12, 0.0, 1.0)
		var start: Vector2 = launcher.lerp(target, 0.35) + Vector2(70, 0)
		var hand: Vector2 = start.lerp(target + Vector2(0, 40), move)
		var alpha: float = minf(press, 1.0 - clampf((cycle - 0.9) / 0.1, 0.0, 1.0))
		# Ghost aim line from the launcher toward the hand.
		var dir: Vector2 = (hand - launcher).normalized()
		var n: int = int(launcher.distance_to(target) / 18.0)
		for i: int in n:
			var p: Vector2 = launcher + dir * (30.0 + 18.0 * float(i))
			if p.distance_to(launcher) > launcher.distance_to(hand) + 40.0:
				break
			draw_circle(p, 3.2, Color(pal["accent"], 0.75 * alpha * move), true, -1.0, true)
		# Touch ripple on press and on release.
		draw_arc(start, 18.0 + 22.0 * press, 0.0, TAU, 32, Color(pal["accent"], 0.6 * (1.0 - press)), 3.0, true)
		if release > 0.0:
			draw_arc(hand, 16.0 + 30.0 * release, 0.0, TAU, 32, Color(pal["accent"], 0.7 * (1.0 - release)), 3.0, true)
		var s: float = 76.0 * (1.0 - 0.12 * press + 0.12 * release)
		var r: Rect2 = Rect2(hand - Vector2(s * 0.3, s * 0.05), Vector2(s, s))
		draw_texture_rect(UIKit.icon("pointer-filled"), r, false, Color(1, 1, 1, alpha))
		draw_texture_rect(UIKit.icon("pointer"), r, false, Color(pal["ink"], alpha))
	if step == Step.ON_TARGET or step == Step.SHOW or step == Step.AIMING or step == Step.RETRY:
		var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
		var rad: float = board.view_scale * (RicochetSim.TARGET_R + 10.0 + 8.0 * pulse)
		var col: Color = pal["accent"] if step == Step.ON_TARGET else Color(pal["accent"], 0.5)
		draw_arc(target, rad, 0.0, TAU, 48, Color(col, col.a * (0.5 + 0.5 * pulse)), 4.0, true)
