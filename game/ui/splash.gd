class_name Splash
extends Control
## The opening moment: the logo's shot plays out (the orb leaves the launcher,
## banks off the wall and pops the target), the title appears, then it fades into
## the game. Matches the boot splash colour so the hand-off is seamless.
## Tap to skip.

signal finished

const BG_TOP: Color = Color("#3A2F7A")
const BG_BOTTOM: Color = Color("#15122F")
const CORAL: Color = Color("#FF6B5B")
const LENGTH: float = 2.6

var _t: float = 0.0
## Driven frame by frame (the share video) instead of by the clock: no sound, no
## tap to skip, no fade-out.
var manual: bool = false
var _done: bool = false
var _popped: bool = false
var _bounced: bool = false


## Shows the moment `t` seconds in (manual mode).
func show_at(t: float) -> void:
	_t = t
	_bounced = t > 0.95
	_popped = t > 1.45
	queue_redraw()


func _ready() -> void:
	if manual:
		set_process(false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_finish()
	)


func _process(delta: float) -> void:
	_t += delta
	if not _bounced and _t > 0.95:
		_bounced = true
		AudioManager.play("bounce", 1.0, -6.0)
	if not _popped and _t > 1.45:
		_popped = true
		AudioManager.play_note("pop", 2)
		Haptics.tap(14)
	if _t >= LENGTH:
		_finish()
	queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)


## Logo space (1024 x 1024) to screen, centred a little above the middle.
func _p(v: Vector2) -> Vector2:
	var s: float = minf(size.x, size.y) / 1024.0 * 0.62
	return size * Vector2(0.5, 0.42) + (v - Vector2(512, 512)) * s


func _r(v: float) -> float:
	return v * minf(size.x, size.y) / 1024.0 * 0.62


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	var appear: float = clampf(_t / 0.35, 0.0, 1.0)
	var white: Color = Color("#F4F1FF", appear)
	# Wall and launcher.
	var wa: Vector2 = _p(Vector2(390, 236))
	var wb: Vector2 = _p(Vector2(620, 236))
	draw_line(wa, wb, white, _r(60), true)
	draw_circle(wa, _r(30), white, true, -1.0, true)
	draw_circle(wb, _r(30), white, true, -1.0, true)
	draw_arc(_p(Vector2(250, 780)), _r(60), 0.0, TAU, 48, white, _r(18), true)
	# The shot: up to the wall (0.4 -> 0.95 s), then down to the target (-> 1.45 s).
	var launch: Vector2 = Vector2(250, 780)
	var hit: Vector2 = Vector2(500, 280)
	var goal: Vector2 = Vector2(740, 760)
	var k1: float = clampf((_t - 0.4) / 0.55, 0.0, 1.0)
	var k2: float = clampf((_t - 0.95) / 0.5, 0.0, 1.0)
	for i: int in 9:
		var f: float = (float(i) + 0.5) / 9.0
		if f < k1:
			draw_circle(_p(launch.lerp(hit, f)), _r(13), Color(1, 1, 1, 0.45), true, -1.0, true)
	if k2 > 0.0:
		var tail: Vector2 = hit.lerp(goal, maxf(0.0, k2 - 0.35))
		var head: Vector2 = hit.lerp(goal, k2 * 0.86)
		var fade: float = 1.0 - clampf((_t - 1.45) / 0.25, 0.0, 1.0)
		if fade > 0.0:
			draw_line(_p(tail), _p(head), Color(1, 1, 1, 0.6 * fade), _r(36), true)
	if _bounced and _t < 1.3:
		var b: float = clampf((_t - 0.95) / 0.35, 0.0, 1.0)
		draw_arc(_p(hit), _r(20 + 60 * b), 0.0, TAU, 40, Color("#FFC9A8", 1.0 - b), _r(10), true)
	# Target, which pops into a ring when the orb arrives.
	if not _popped:
		draw_circle(_p(goal), _r(104), Color(CORAL, appear), true, -1.0, true)
		draw_arc(_p(goal), _r(46), 0.0, TAU, 40, Color("#FFF4EE", appear), _r(20), true)
	else:
		var p: float = clampf((_t - 1.45) / 0.5, 0.0, 1.0)
		draw_arc(_p(goal), _r(104 + 140 * p), 0.0, TAU, 56, Color(CORAL, 1.0 - p), _r(14), true)
		draw_circle(_p(goal), _r(104 * (1.0 - p)), Color(CORAL, 1.0 - p), true, -1.0, true)
	# The orb.
	var orb: Vector2 = launch
	if k1 > 0.0 and k2 <= 0.0:
		orb = launch.lerp(hit, k1)
	elif k2 > 0.0:
		orb = hit.lerp(goal, k2 * 0.86)
	if not _popped:
		draw_circle(_p(orb), _r(80), Color(1, 1, 1, 0.12 * appear), true, -1.0, true)
		draw_circle(_p(orb), _r(42), Color(1, 1, 1, appear), true, -1.0, true)
	# Title.
	var ta: float = clampf((_t - 1.55) / 0.45, 0.0, 1.0)
	if ta > 0.0:
		var f2: Font = UIKit.font(250)
		var fs: int = int(clampf(size.x * 0.11, 48.0, 96.0))
		var title: String = "one clean shot"
		var w: float = f2.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y: float = size.y * 0.42 + _r(560) + 20.0 * (1.0 - ta)
		draw_string(f2, Vector2(size.x * 0.5 - w * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#F4F1FF", ta))
		var f3: Font = UIKit.font(500)
		var tag: String = "a quiet ricochet puzzle"
		var tw2: float = f3.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(f3, Vector2(size.x * 0.5 - tw2 * 0.5, y + 46.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5 * ta))
