extends Control
## The Google Play feature graphic (1024 x 500): the logo's bank shot on the brand
## indigo, the name and a plain line about the game. Rendered by
## `godot --path . res://tests/capture.tscn -- <dir> --store`.

const TOP: Color = Color("#3A2F7A")
const BOTTOM: Color = Color("#15122F")
const CORAL: Color = Color("#FF6B5B")
const WHITE: Color = Color("#F4F1FF")


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([TOP, BOTTOM, BOTTOM, TOP]))
	# A long, calm bank shot across the left half: launcher, wall, target.
	var launch: Vector2 = Vector2(96, 420)
	var hit: Vector2 = Vector2(250, 64)
	var goal: Vector2 = Vector2(404, 420)
	draw_line(Vector2(170, 46), Vector2(330, 46), WHITE, 24.0, true)
	draw_circle(Vector2(170, 46), 12.0, WHITE, true, -1.0, true)
	draw_circle(Vector2(330, 46), 12.0, WHITE, true, -1.0, true)
	for i: int in 13:
		draw_circle(launch.lerp(hit, (float(i) + 0.6) / 13.5), 6.0, Color(1, 1, 1, 0.45), true, -1.0, true)
	for i: int in 9:
		var f: float = float(i) / 9.0
		draw_line(hit.lerp(goal, f * 0.78), hit.lerp(goal, f * 0.78 + 0.05), Color(1, 1, 1, 0.15 + 0.75 * f), 16.0, true)
	draw_circle(goal, 110.0, Color(CORAL, 0.18), true, -1.0, true)
	draw_circle(goal, 54.0, CORAL, true, -1.0, true)
	draw_arc(goal, 24.0, 0.0, TAU, 48, Color("#FFF4EE"), 10.0, true)
	var orb: Vector2 = hit.lerp(goal, 0.82)
	draw_circle(orb, 40.0, Color(1, 1, 1, 0.14), true, -1.0, true)
	draw_circle(orb, 20.0, Color.WHITE, true, -1.0, true)
	draw_arc(launch, 30.0, 0.0, TAU, 48, WHITE, 9.0, true)
	# Name and line.
	var title: Font = UIKit.font(300)
	draw_string(title, Vector2(486, 236), "Single Shot", HORIZONTAL_ALIGNMENT_LEFT, -1, 74, WHITE)
	var body: Font = UIKit.font(500)
	draw_string(body, Vector2(490, 296), "A quiet ricochet puzzle.", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.75))
	draw_string(body, Vector2(490, 342), "One shot. Every target.", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#FFC9A8"))
