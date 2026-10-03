class_name LightBulbIcon
extends Control
## Original bulb icon made from simple Godot shapes.
var tint: Color = Color.WHITE
var outline: Color = Color.BLACK
func set_tint(color: Color, outline_color: Color) -> void:
	tint = color
	outline = outline_color
	queue_redraw()
func _draw() -> void:
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.38)
	draw_circle(center, size.x * 0.24, tint, true, -1.0, true)
	draw_rect(Rect2(center.x - size.x * 0.12, center.y + size.y * 0.15, size.x * 0.24, size.y * 0.19), tint, true)
	draw_line(Vector2(center.x - size.x * 0.12, center.y + size.y * 0.38), Vector2(center.x + size.x * 0.12, center.y + size.y * 0.38), outline, 3.0, true)
	draw_line(Vector2(center.x - size.x * 0.09, center.y + size.y * 0.46), Vector2(center.x + size.x * 0.09, center.y + size.y * 0.46), outline, 3.0, true)
