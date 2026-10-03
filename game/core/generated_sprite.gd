extends Node2D
## Simple shapes keep every generated character clear in both themes.
var kind: String = "hazel"
var ink: Color = Color("#241d31")
var fill: Color = Color("#b6d86b")
var accent: Color = Color("#e38c55")
var shape_size: Vector2 = Vector2(64, 18)
var pose: String = "idle"

func _draw() -> void:
	match kind:
		"hazel":
			draw_circle(Vector2(0, 0), 23, fill)
			draw_arc(Vector2(0, 0), 23, 0, TAU, 32, ink, 4, true)
			draw_circle(Vector2(-7, -3), 3.5 if pose != "fire" else 4.5, ink)
			draw_circle(Vector2(7, -3), 3.5 if pose != "fire" else 4.5, ink)
			if pose == "win":
				draw_circle(Vector2(0, -31), 7, accent)
				draw_circle(Vector2(-15, -26), 4, accent)
				draw_circle(Vector2(15, -26), 4, accent)
			elif pose == "lose":
				draw_arc(Vector2(0, 15), 8, PI + 0.2, TAU - 0.2, 12, ink, 3, true)
			else:
				draw_arc(Vector2(0, 7), 8, 0.2, 2.9, 12, ink, 3, true)
			if pose == "aim":
				draw_line(Vector2(-12, -10), Vector2(-4, -8), ink, 2, true)
				draw_line(Vector2(4, -8), Vector2(12, -10), ink, 2, true)
			draw_circle(Vector2(-17, -15), 8, accent)
		"ghoul":
			draw_circle(Vector2(0, 0), 24, fill)
			draw_arc(Vector2(0, 0), 24, 0, TAU, 32, ink, 4, true)
			draw_circle(Vector2(-8, -3), 4 if pose != "hit" else 2, ink)
			draw_circle(Vector2(8, -3), 4 if pose != "hit" else 2, ink)
			draw_colored_polygon(PackedVector2Array([Vector2(-5, 8), Vector2(5, 8), Vector2(0, 19)]), accent)
			if pose == "hit":
				draw_line(Vector2(-15, -15), Vector2(-9, -10), ink, 2, true)
				draw_line(Vector2(9, -10), Vector2(15, -15), ink, 2, true)
		"crate":
			draw_rect(Rect2(-22, -22, 44, 44), fill, true)
			draw_rect(Rect2(-22, -22, 44, 44), ink, false, 4)
			draw_line(Vector2(-18, -18), Vector2(18, 18), ink, 4, true)
			draw_line(Vector2(18, -18), Vector2(-18, 18), ink, 4, true)
		"wall":
			draw_rect(Rect2(-shape_size * 0.5, shape_size), fill, true)
			draw_rect(Rect2(-shape_size * 0.5, shape_size), ink, false, 3)
			draw_line(Vector2(-shape_size.x * 0.35, -shape_size.y * 0.5), Vector2(shape_size.x * 0.35, shape_size.y * 0.5), accent, 3, true)
