class_name LockIcon
extends Control
## Small lock drawn with Godot shapes.
var ink: Color = Color.WHITE
var body: Color = Color.WHITE
func set_colors(outline: Color, fill: Color) -> void:
	ink = outline
	body = fill
	queue_redraw()
func _draw() -> void:
	var center_x: float = size.x * 0.5
	draw_arc(Vector2(center_x, size.y * 0.42), size.x * 0.23, PI, TAU, 20, ink, 5.0, true)
	draw_rect(Rect2(center_x - size.x * 0.27, size.y * 0.4, size.x * 0.54, size.y * 0.46), ink, true)
	draw_rect(Rect2(center_x - size.x * 0.21, size.y * 0.45, size.x * 0.42, size.y * 0.36), body, true)
	draw_circle(Vector2(center_x, size.y * 0.59), size.x * 0.045, ink, true)
	draw_rect(Rect2(center_x - size.x * 0.02, size.y * 0.59, size.x * 0.04, size.y * 0.12), ink, true)
