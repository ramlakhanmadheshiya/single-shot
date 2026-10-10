class_name ChapterArt
extends Control
## A looping mini-scene that shows what a chapter is about: the orb plays out the
## chapter's one idea (glass breaking, a portal hop, a prism split...). Used as the
## chapter card background and as the diagram in each chapter's tutorial card.
## Scenes are drawn in a virtual 300 x 150 box, scaled into `area` (or the whole
## control if `area` is empty).

const VIRTUAL: Vector2 = Vector2(300, 150)
const PERIOD: float = 3.6
## Share of the loop spent travelling; the rest holds the finished scene.
const TRAVEL: float = 0.68

var chapter_id: String = "ch1"
var pal: Dictionary = Palette.get_palette("ch1")
## Where to draw, in local pixels. Empty = the full control.
var area: Rect2 = Rect2()
var playing: bool = true
var line_scale: float = 1.0
var _t: float = 0.0
var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * PERIOD


func _process(delta: float) -> void:
	if playing and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _p(v: Vector2) -> Vector2:
	return _origin + v * _scale


func _r(v: float) -> float:
	return v * _scale


## Path progress 0..1 for this moment of the loop.
func _progress() -> float:
	var u: float = fmod(_t, PERIOD) / PERIOD
	var k: float = clampf(u / TRAVEL, 0.0, 1.0)
	return k


## Fades the whole scene in at the start of each loop and out at the end.
func _alpha() -> float:
	var u: float = fmod(_t, PERIOD) / PERIOD
	return clampf(u / 0.06, 0.0, 1.0) * clampf((1.0 - u) / 0.08, 0.0, 1.0)


## Position along a polyline at progress f (by length), and the index of the last
## corner passed.
static func along(pts: Array, f: float) -> Array:
	var total: float = 0.0
	for i: int in pts.size() - 1:
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	var want: float = total * clampf(f, 0.0, 1.0)
	for i: int in pts.size() - 1:
		var seg: float = (pts[i] as Vector2).distance_to(pts[i + 1])
		if want <= seg or i == pts.size() - 2:
			return [(pts[i] as Vector2).lerp(pts[i + 1], clampf(want / maxf(seg, 0.001), 0.0, 1.0)), i]
		want -= seg
	return [pts[-1], pts.size() - 2]


## Length fraction at which the path reaches corner `i`.
static func corner_at(pts: Array, i: int) -> float:
	var total: float = 0.0
	var upto: float = 0.0
	for k: int in pts.size() - 1:
		var seg: float = (pts[k] as Vector2).distance_to(pts[k + 1])
		total += seg
		if k < i:
			upto += seg
	return upto / maxf(total, 0.001)


func _draw() -> void:
	var r: Rect2 = area if area.size != Vector2.ZERO else Rect2(Vector2.ZERO, size)
	_scale = minf(r.size.x / VIRTUAL.x, r.size.y / VIRTUAL.y)
	_origin = r.position + (r.size - VIRTUAL * _scale) * 0.5
	var f: float = _progress()
	var a: float = _alpha()
	match chapter_id:
		"ch2":
			_glass(f, a)
		"ch3":
			_void(f, a)
		"ch4":
			_shift(f, a)
		"ch5":
			_prism(f, a)
		"ch6":
			_gate(f, a)
		"ch7":
			_spark(f, a)
		"ch8":
			_turn(f, a)
		"ch9":
			_drift(f, a)
		_:
			_dawn(f, a)


# --- Drawing helpers --------------------------------------------------------------

func _ink(alpha: float) -> Color:
	return Color(pal["ink"], alpha)


func _wall(a: Vector2, b: Vector2, col: Color, width: float = 6.0) -> void:
	draw_line(_p(a), _p(b), col, _r(width), true)
	draw_circle(_p(a), _r(width) * 0.5, col, true, -1.0, true)
	draw_circle(_p(b), _r(width) * 0.5, col, true, -1.0, true)


func _launcher(at: Vector2, alpha: float) -> void:
	draw_arc(_p(at), _r(9.0), 0.0, TAU, 32, _ink(0.85 * alpha), _r(2.0) * line_scale, true)


func _orb(at: Vector2, alpha: float) -> void:
	draw_circle(_p(at), _r(8.0), Color(pal["orb"], 0.12 * alpha), true, -1.0, true)
	draw_circle(_p(at), _r(4.5), Color(pal["orb"], alpha), true, -1.0, true)


## A target that pops (ring + fade) once the orb has passed it.
func _target(at: Vector2, popped_at: float, f: float, alpha: float) -> void:
	if f < popped_at:
		draw_circle(_p(at), _r(9.0), Color(pal["target"], alpha), true, -1.0, true)
		draw_arc(_p(at), _r(4.0), 0.0, TAU, 24, Color(pal["top"], 0.9 * alpha), _r(1.6), true)
	else:
		var k: float = clampf((f - popped_at) / 0.18, 0.0, 1.0)
		draw_arc(_p(at), _r(9.0 + 14.0 * k), 0.0, TAU, 32, Color(pal["target"], (1.0 - k) * alpha), _r(2.0), true)


## Dotted trail of the path travelled so far (and a faint guide of the rest).
func _trail(pts: Array, f: float, alpha: float) -> void:
	var here: Array = along(pts, f)
	var done: Array = pts.slice(0, int(here[1]) + 1)
	done.append(here[0])
	for i: int in pts.size() - 1:
		_dots(pts[i], pts[i + 1], _ink(0.12 * alpha))
	for i: int in done.size() - 1:
		_dots(done[i], done[i + 1], _ink(0.35 * alpha))


func _dots(a: Vector2, b: Vector2, col: Color) -> void:
	var length: float = a.distance_to(b)
	var n: int = int(length / 7.0)
	for k: int in n:
		draw_circle(_p(a.lerp(b, (float(k) + 0.5) / float(maxi(n, 1)))), _r(1.1), col, true, -1.0, true)


func _ring_at(at: Vector2, start: float, f: float, col: Color, alpha: float, grow: float = 16.0) -> void:
	if f < start:
		return
	var k: float = clampf((f - start) / 0.15, 0.0, 1.0)
	if k >= 1.0:
		return
	draw_arc(_p(at), _r(4.0 + grow * k), 0.0, TAU, 32, Color(col, (1.0 - k) * alpha), _r(1.8), true)


# --- Scenes -----------------------------------------------------------------------

func _dawn(f: float, a: float) -> void:
	var pts: Array = [Vector2(30, 140), Vector2(120, 16), Vector2(210, 140)]
	_wall(Vector2(78, 10), Vector2(162, 10), _ink(0.9 * a))
	_wall(Vector2(262, 50), Vector2(262, 112), _ink(0.9 * a))
	_trail(pts, f, a)
	_ring_at(pts[1], corner_at(pts, 1), f, pal["ink"], a)
	_target(Vector2(75, 78), corner_at(pts, 1) * 0.5, f, a)
	_target(Vector2(165, 78), 0.75, f, a)
	_launcher(pts[0], a)
	if f < 1.0:
		_orb(along(pts, f)[0], a)


func _glass(f: float, a: float) -> void:
	var pts: Array = [Vector2(130, 135), Vector2(150, 76), Vector2(170, 140), Vector2(204, 40)]
	var hit: float = corner_at(pts, 1)
	_wall(Vector2(40, 146), Vector2(260, 146), _ink(0.9 * a), 5.0)
	if f < hit:
		var g0: Vector2 = _p(Vector2(100, 66))
		var g1: Vector2 = _p(Vector2(214, 72))
		draw_rect(Rect2(g0, g1 - g0), Color(pal["special"], 0.35 * a))
		draw_rect(Rect2(g0, g1 - g0), Color(pal["special"], 0.95 * a), false, _r(1.4))
		draw_line(_p(Vector2(112, 68)), _p(Vector2(124, 68)), Color(1, 1, 1, 0.8 * a), _r(1.4), true)
	else:
		# Shards fly off and fall.
		var k: float = clampf((f - hit) / 0.35, 0.0, 1.0)
		for i: int in 9:
			var x: float = 104.0 + 12.0 * float(i)
			var dir: Vector2 = Vector2(sin(float(i) * 2.1) * 18.0, -10.0 + 60.0 * k)
			var p: Vector2 = Vector2(x, 69) + dir * k
			draw_line(_p(p), _p(p + Vector2(4, 2).rotated(float(i) + k * 6.0)), Color(pal["special"], (1.0 - k) * a), _r(1.6), true)
	_trail(pts, f, a)
	_ring_at(pts[2], corner_at(pts, 2), f, pal["ink"], a)
	_target(Vector2(204, 40), 0.98, f, a)
	_launcher(pts[0], a)
	if f < 1.0:
		_orb(along(pts, f)[0], a)


func _void(f: float, a: float) -> void:
	var pts: Array = [Vector2(40, 140), Vector2(138, 74), Vector2(250, 40)]
	# A stray shot heads into the dark block and is swallowed.
	var v0: Vector2 = _p(Vector2(196, 104))
	var v1: Vector2 = _p(Vector2(272, 128))
	draw_rect(Rect2(v0, v1 - v0), Color("#0B0A14", a))
	draw_rect(Rect2(v0, v1 - v0), Color(pal["accent"], (0.4 + 0.2 * sin(_t * 3.0)) * a), false, _r(1.2))
	_dots(Vector2(40, 140), Vector2(194, 116), _ink(0.14 * a))
	var sw: float = clampf(f / 0.5, 0.0, 1.0)
	if sw < 1.0:
		_orb(Vector2(40, 140).lerp(Vector2(194, 116), sw), a * 0.5)
	else:
		_ring_at(Vector2(196, 116), 0.5, f, pal["accent"], a)
	var bump: Vector2 = Vector2(152, 60)
	var pulse: float = 0.0
	var at: float = corner_at(pts, 1)
	if f >= at:
		pulse = maxf(0.0, 1.0 - (f - at) / 0.12)
	draw_circle(_p(bump), _r(16.0 * (1.0 + 0.15 * pulse)), Color(pal["accent"], (0.16 + 0.3 * pulse) * a), true, -1.0, true)
	draw_arc(_p(bump), _r(16.0 * (1.0 + 0.15 * pulse)), 0.0, TAU, 40, Color(pal["accent"], a), _r(2.2), true)
	_trail(pts, f, a)
	_target(Vector2(250, 40), 0.98, f, a)
	_launcher(pts[0], a)
	if f < 1.0:
		_orb(along(pts, f)[0], a)


func _portal(at: Vector2, a: float, spin: float) -> void:
	var col: Color = pal["special"]
	draw_circle(_p(at), _r(11.0), Color(col, 0.18 * a), true, -1.0, true)
	draw_arc(_p(at), _r(11.0), 0.0, TAU, 32, Color(col, a), _r(1.8), true)
	for k: int in 3:
		var a0: float = spin + TAU * float(k) / 3.0
		draw_arc(_p(at), _r(16.0), a0, a0 + 1.1, 10, Color(col, 0.7 * a), _r(1.6), true)


func _shift(f: float, a: float) -> void:
	var leg1: Array = [Vector2(40, 140), Vector2(90, 50)]
	var leg2: Array = [Vector2(230, 110), Vector2(270, 38)]
	_portal(leg1[1], a, _t * 1.6)
	_portal(leg2[0], a, -_t * 1.6)
	var split: float = 0.6
	_dots(leg1[0], leg1[1], _ink(0.3 * a))
	_dots(leg2[0], leg2[1], _ink((0.3 if f > split else 0.12) * a))
	_ring_at(leg2[0], split, f, pal["special"], a, 20.0)
	_target(Vector2(268, 42), 0.98, f, a)
	_launcher(leg1[0], a)
	if f < split:
		_orb(leg1[0].lerp(leg1[1], f / split), a)
	elif f < 1.0:
		_orb(leg2[0].lerp(leg2[1], (f - split) / (1.0 - split)), a)


func _prism(f: float, a: float) -> void:
	var start: Vector2 = Vector2(150, 140)
	var prism: Vector2 = Vector2(150, 80)
	var ends: Array = [Vector2(110, 16), Vector2(190, 16)]
	var rot: float = _t * 0.8
	var tri: PackedVector2Array = PackedVector2Array()
	for k: int in 3:
		tri.append(_p(prism + Vector2.from_angle(rot + TAU * float(k) / 3.0) * 14.0))
	draw_colored_polygon(tri, Color(pal["special"], 0.3 * a))
	var o: PackedVector2Array = tri.duplicate()
	o.append(tri[0])
	draw_polyline(o, Color(pal["special"], a), _r(1.8), true)
	var split: float = 0.45
	_dots(start, prism, _ink(0.3 * a))
	for e: Vector2 in ends:
		_dots(prism, e, _ink((0.3 if f > split else 0.12) * a))
		_target(e + Vector2(0, 4), 0.98, f, a)
	_ring_at(prism, split, f, pal["special"], a, 20.0)
	_launcher(start, a)
	if f < split:
		_orb(start.lerp(prism, f / split), a)
	elif f < 1.0:
		for e: Vector2 in ends:
			_orb(prism.lerp(e, (f - split) / (1.0 - split)), a)


func _gate(f: float, a: float) -> void:
	var pts: Array = [Vector2(40, 140), Vector2(100, 90), Vector2(178, 25)]
	var opened: float = corner_at(pts, 1)
	var sw: Vector2 = pts[1]
	var dia: PackedVector2Array = PackedVector2Array([_p(sw + Vector2(0, -9)), _p(sw + Vector2(9, 0)), _p(sw + Vector2(0, 9)), _p(sw + Vector2(-9, 0))])
	if f < opened:
		draw_colored_polygon(dia, Color(pal["special"], a))
	else:
		var o: PackedVector2Array = dia.duplicate()
		o.append(dia[0])
		draw_polyline(o, Color(pal["special"], 0.4 * a), _r(1.4), true)
	var gate_a: float = 1.0 if f < opened else maxf(0.0, 1.0 - (f - opened) / 0.15)
	if gate_a > 0.0:
		var x: float = 130.0
		while x < 230.0:
			draw_line(_p(Vector2(x, 50)), _p(Vector2(minf(x + 8.0, 230.0), 50)), Color(pal["special"], gate_a * a), _r(3.0), true)
			x += 14.0
	_trail(pts, f, a)
	_ring_at(sw, opened, f, pal["special"], a, 22.0)
	_target(Vector2(178, 25), 0.98, f, a)
	_launcher(pts[0], a)
	if f < 1.0:
		_orb(along(pts, f)[0], a)


func _spark(f: float, a: float) -> void:
	var pts: Array = [Vector2(40, 140), Vector2(100, 120), Vector2(244, 72), Vector2(150, 41)]
	var got: float = corner_at(pts, 1)
	var bounce: float = corner_at(pts, 2)
	_wall(Vector2(256, 40), Vector2(256, 140), _ink(0.9 * a))
	if f < got:
		var star: PackedVector2Array = PackedVector2Array()
		for k: int in 8:
			var rad: float = 9.0 if k % 2 == 0 else 3.5
			star.append(_p(pts[1] + Vector2.from_angle(-PI / 2.0 + TAU * float(k) / 8.0 + _t * 0.6) * rad))
		draw_circle(_p(pts[1]), _r(13.0), Color(pal["special"], 0.15 * a), true, -1.0, true)
		draw_colored_polygon(star, Color(pal["special"], a))
	_ring_at(pts[1], got, f, pal["special"], a, 18.0)
	# Bounce pips over the launcher: none to start, one from the spark, spent on the wall.
	var pips: int = 0 if f < got else (1 if f < bounce else 0)
	if pips > 0:
		draw_circle(_p(pts[0] + Vector2(0, -16)), _r(2.6), _ink(0.9 * a), true, -1.0, true)
	else:
		draw_arc(_p(pts[0] + Vector2(0, -16)), _r(2.4), 0.0, TAU, 12, _ink(0.35 * a), _r(1.0), true)
	_trail(pts, f, a)
	_ring_at(pts[2], bounce, f, pal["ink"], a)
	_target(Vector2(150, 41), 0.98, f, a)
	_launcher(pts[0], a)
	if f < 1.0:
		_orb(along(pts, f)[0], a)


func _turn(f: float, a: float) -> void:
	var pts: Array = [Vector2(120, 140), Vector2(200, 76), Vector2(258, 122)]
	var hit: float = corner_at(pts, 1)
	var c: Vector2 = Vector2(200, 70)
	var ang: float = 0.0
	if f >= hit:
		ang = PI * 0.5 * (1.0 - pow(1.0 - clampf((f - hit) / 0.2, 0.0, 1.0), 3.0))
	var d: Vector2 = Vector2(32, 0).rotated(ang)
	_wall(c - d, c + d, _ink(0.9 * a))
	draw_circle(_p(c), _r(5.5), Color(pal["special"], a), true, -1.0, true)
	draw_circle(_p(c), _r(2.0), Color(pal["top"], a), true, -1.0, true)
	draw_arc(_p(c), _r(12.0), ang + 0.4, ang + 1.9, 12, Color(pal["special"], 0.7 * a), _r(1.6), true)
	_trail(pts, f, a)
	_ring_at(pts[1], hit, f, pal["special"], a)
	_target(Vector2(258, 122), 0.98, f, a)
	_launcher(pts[0], a)
	if f < 1.0:
		_orb(along(pts, f)[0], a)


func _drift(f: float, a: float) -> void:
	var start: Vector2 = Vector2(150, 140)
	var end: Vector2 = Vector2(150, 20)
	var rest: Vector2 = Vector2(150, 70)
	# The platform never stops; the orb is released so it passes at the far end.
	var u: float = fmod(_t, PERIOD) / PERIOD
	var slide: float = 110.0 * (0.5 - 0.5 * cos(TAU * (u + 0.103)))
	var rail_end: Vector2 = rest + Vector2(110, 0)
	_dots(rest + Vector2(-16, 0), rail_end, Color(pal["special"], 0.6 * a))
	for p: Vector2 in [rest, rail_end]:
		draw_arc(_p(p), _r(3.0), 0.0, TAU, 16, Color(pal["special"], 0.6 * a), _r(1.2), true)
	var c: Vector2 = rest + Vector2(slide, 0)
	_wall(c - Vector2(32, 0), c + Vector2(32, 0), _ink(0.9 * a))
	_trail([start, end], f, a)
	_target(end + Vector2(0, 2), 0.98, f, a)
	_launcher(start, a)
	if f < 1.0:
		_orb(start.lerp(end, f), a)
