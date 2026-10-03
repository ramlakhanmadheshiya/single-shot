class_name VolumeSlider
extends Control
## Touch-friendly slider with its own visible track, fill and handle.
signal value_changed(value: float)
var value: float = 0.5:
	set(next_value):
		value = clampf(next_value, 0.0, 1.0)
		queue_redraw()
var track_color: Color = Color.WHITE
var fill_color: Color = Color.WHITE
var handle_color: Color = Color.WHITE
var outline_color: Color = Color.BLACK
var dragging: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(280.0, 56.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_palette(track: Color, fill: Color, handle: Color, outline: Color) -> void:
	track_color = track
	fill_color = fill
	handle_color = handle
	outline_color = outline
	queue_redraw()

func _draw() -> void:
	var left: float = 16.0
	var right: float = maxf(left + 1.0, size.x - 18.0)
	var center_y: float = size.y * 0.5
	var handle_x: float = lerpf(left, right, value)
	draw_line(Vector2(left, center_y), Vector2(right, center_y), track_color, 14.0, true)
	draw_line(Vector2(left, center_y), Vector2(handle_x, center_y), fill_color, 14.0, true)
	draw_circle(Vector2(handle_x, center_y), 17.0, outline_color, true, -1.0, true)
	draw_circle(Vector2(handle_x, center_y), 12.0, handle_color, true, -1.0, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		dragging = (event as InputEventMouseButton).pressed
		if dragging:
			_set_from_x((event as InputEventMouseButton).position.x)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		_set_from_x((event as InputEventMouseMotion).position.x)
		accept_event()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		dragging = touch.pressed
		if dragging:
			_set_from_x(touch.position.x)
			accept_event()
	elif event is InputEventScreenDrag and dragging:
		_set_from_x((event as InputEventScreenDrag).position.x)
		accept_event()

func _set_from_x(x: float) -> void:
	var left: float = 16.0
	var right: float = maxf(left + 1.0, size.x - 18.0)
	var next_value: float = clampf((x - left) / (right - left), 0.0, 1.0)
	if not is_equal_approx(next_value, value):
		value = next_value
		value_changed.emit(value)
