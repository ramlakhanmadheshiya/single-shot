class_name AimHint
extends Control
## Faint, simple suggested path shown by the in-level bulb button.
var tint: Color = Color.WHITE
func set_tint(color: Color) -> void:
	tint = color
	queue_redraw()
func _draw() -> void:
	var origin: Vector2 = Vector2(size.x * 0.28, size.y * 0.57)
	var bend: Vector2 = Vector2(size.x * 0.54, size.y * 0.34)
	var end: Vector2 = Vector2(size.x * 0.71, size.y * 0.55)
	draw_line(origin, bend, Color(tint, 0.42), 5.0, true)
	draw_line(bend, end, Color(tint, 0.32), 5.0, true)
