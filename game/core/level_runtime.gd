extends Control
class_name LevelRuntime
## Small, data-driven slingshot game board.
signal shots_changed(value: int)
signal state_changed(value: String)
signal target_removed
signal action_made(value: String)

const SpriteScript = preload("res://game/core/generated_sprite.gd")
const TUNING: PhysicsTuning = preload("res://game/core/physics_tuning.tres")
var tuning: PhysicsTuning = TUNING.duplicate(true)
var level: Dictionary = {}
var palette: Dictionary = {}
var world: Node2D
var hazel: Node2D
var hazel_sprite: Node2D
var projectiles: Array[RigidBody2D] = []
var crates: Array[RigidBody2D] = []
var ghouls: Array[Area2D] = []
var ghoul_sprites: Array[Node2D] = []
var aim_cast: ShapeCast2D
var shots_used: int = 0
var shot_limit: int = 3
var par_three: int = 1
var par_two: int = 2
var state: String = "intro"
var aim_vector: Vector2 = Vector2.ZERO
var drag_origin: Vector2 = Vector2.ZERO
var pointer_active: bool = false
var shot_age: float = 0.0
var settle_age: float = 0.0
var hint_visible: bool = false
var _world_size: Vector2 = Vector2.ZERO
var _snapshot: Dictionary = {}
var _last_bounce_msec: int = 0
var _gamepad_fired: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	world = Node2D.new()
	world.name = "PhysicsWorld"
	add_child(world)
	resized.connect(_on_resized)
	set_physics_process(true)
	set_process(true)

func _process(_delta: float) -> void:
	var pads: Array[int] = Input.get_connected_joypads()
	if state == "aiming" and not pads.is_empty():
		var pad: int = pads[0]
		var stick: Vector2 = Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if stick.length() > 0.25:
			aim_vector = stick.normalized()
			queue_redraw()
		var fire_down: bool = Input.is_joy_button_pressed(pad, JOY_BUTTON_A)
		if fire_down and not _gamepad_fired:
			fire(aim_vector)
		_gamepad_fired = fire_down
	if hazel_sprite != null and state == "aiming" and not pointer_active:
		hazel_sprite.position.y = sin(float(Time.get_ticks_msec()) / 360.0) * 3.0
	for index in mini(ghoul_sprites.size(), ghouls.size()):
		var sprite: Node2D = ghoul_sprites[index]
		if is_instance_valid(sprite):
			sprite.position.y = sin(float(Time.get_ticks_msec()) / 420.0 + float(index)) * 2.5

func configure(level_data: Dictionary, colors: Dictionary, tuning_override: PhysicsTuning = TUNING) -> void:
	level = level_data.duplicate(true)
	palette = colors.duplicate(true)
	tuning = tuning_override.duplicate(true)
	shots_used = 0
	shot_limit = int(level.get("shots", 3))
	par_three = int(level.get("par_3", 1))
	par_two = int(level.get("par_2", 2))
	if is_node_ready():
		_build_level()

func _on_resized() -> void:
	if level.is_empty() or size.x < 10 or size.y < 10:
		return
	if _world_size != size:
		_world_size = size
		_build_level()

func _build_level() -> void:
	if world == null:
		return
	for child: Node in world.get_children():
		world.remove_child(child)
		child.free()
	projectiles.clear()
	crates.clear()
	ghouls.clear()
	ghoul_sprites.clear()
	aim_cast = ShapeCast2D.new()
	aim_cast.name = "AimCast"
	aim_cast.collide_with_bodies = true
	aim_cast.collide_with_areas = true
	var guide_shape: CircleShape2D = CircleShape2D.new()
	guide_shape.radius = tuning.shot_radius
	aim_cast.shape = guide_shape
	world.add_child(aim_cast)
	world.position = Vector2.ZERO
	_world_size = size
	var floor_y: float = size.y * tuning.floor_height
	_add_wall(Vector2(size.x * 0.5, floor_y), Vector2(size.x * tuning.floor_width, tuning.floor_thickness))
	hazel = Node2D.new()
	hazel.name = "Hazel"
	hazel.position = Vector2(size.x * 0.16, size.y * 0.66)
	world.add_child(hazel)
	hazel_sprite = _add_sprite(hazel, "hazel", Color(palette.get("success", "#b6d86b")), Color(palette.get("text", "#241d31")), Color(palette.get("accent", "#e38c55")))
	var target_positions: Array = level.get("targets", [[0.72, 0.63]])
	for index in target_positions.size():
		var point: Array = target_positions[index]
		var target: Area2D = Area2D.new()
		target.name = "Ghoul_%02d" % index
		target.monitoring = true
		target.monitorable = true
		target.position = Vector2(float(point[0]) * size.x, float(point[1]) * size.y)
		target.add_to_group("ghoul")
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = tuning.ghoul_radius
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.shape = shape
		target.add_child(collision)
		world.add_child(target)
		ghoul_sprites.append(_add_sprite(target, "ghoul", Color(palette.get("danger", "#dd746f")), Color(palette.get("text", "#241d31")), Color(palette.get("accent", "#e38c55"))))
		target.body_entered.connect(_on_ghoul_body_entered.bind(target))
		ghouls.append(target)
	var wall_data: Array = level.get("walls", [])
	for item: Variant in wall_data:
		if item is Array and item.size() == 4:
			var wall_size: Vector2 = Vector2(float(item[2]) * size.x, float(item[3]) * size.y)
			_add_wall(Vector2(float(item[0]) * size.x, float(item[1]) * size.y), wall_size)
	var crate_data: Array = level.get("crates", [])
	for point_value: Variant in crate_data:
		if point_value is Array and point_value.size() == 2:
			_add_crate(Vector2(float(point_value[0]) * size.x, float(point_value[1]) * size.y))
	state = "aiming"
	aim_vector = Vector2.RIGHT
	state_changed.emit(state)
	queue_redraw()

func _add_sprite(parent: Node2D, type: String, fill: Color, ink: Color, accent: Color, sprite_size: Vector2 = Vector2.ZERO) -> Node2D:
	var sprite: Node2D = Node2D.new()
	sprite.set_script(SpriteScript)
	sprite.kind = type
	sprite.fill = fill
	sprite.ink = ink
	sprite.accent = accent
	if sprite_size != Vector2.ZERO:
		sprite.shape_size = sprite_size
	parent.add_child(sprite)
	return sprite

func _add_wall(at: Vector2, dimensions: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Wall"
	body.position = at
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = dimensions
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	_add_sprite(body, "wall", Color(palette.get("surface_alt", "#7a7390")), Color(palette.get("text", "#241d31")), Color(palette.get("accent", "#e38c55")), dimensions)

func _add_crate(at: Vector2) -> void:
	var body: RigidBody2D = RigidBody2D.new()
	body.name = "Crate"
	body.position = at
	body.mass = tuning.crate_mass
	body.gravity_scale = tuning.gravity / tuning.default_gravity
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2.ONE * tuning.crate_edge
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	_add_sprite(body, "crate", Color(palette.get("surface_alt", "#9c744f")), Color(palette.get("text", "#241d31")), Color(palette.get("accent", "#e38c55")))
	crates.append(body)

func _draw() -> void:
	if hazel == null:
		return
	var ink: Color = Color(palette.get("outline", "#241d31"))
	draw_line(hazel.position + Vector2(12, 0), hazel.position + aim_vector * 0.22, Color(palette.get("accent", "#e38c55"), 0.75), 5, true)
	if state == "aiming" and pointer_active:
		_draw_aim_path(aim_vector, 42, Color(palette.get("primary", "#b6d86b"), 0.88))
	if hint_visible and state == "aiming":
		var solution: Vector2 = Vector2(float(level.get("solution", [1, 0, 0.75])[0]), float(level.get("solution", [1, 0, 0.75])[1]))
		_draw_aim_path(solution, 52, Color(palette.get("accent", "#e38c55"), 0.52))
	if state == "aiming" and bool(SaveSystem.get_setting("show_aim_guide", true)) and not pointer_active:
		_draw_aim_path(_solution_vector(), 24, Color(palette.get("text_muted", "#777777"), 0.35))
	if not ink.is_equal_approx(Color.TRANSPARENT):
		draw_circle(hazel.position + Vector2(0, 29), 4, ink)

func _solution_vector() -> Vector2:
	var target_value: Array = level.get("solution_target", [])
	if target_value.size() == 2 and hazel != null:
		var target: Vector2 = Vector2(float(target_value[0]) * size.x, float(target_value[1]) * size.y)
		if str(level.get("solution_mode", "direct")) == "bounce_top":
			var wall: Array = level.get("walls", [])
			if not wall.is_empty():
				var wall_top: float = (float(wall[0][1]) - float(wall[0][3]) * 0.5) * size.y
				return Vector2((target.x - hazel.position.x) * 0.5, wall_top - hazel.position.y).normalized()
		return (target - hazel.position).normalized()
	var solution: Array = level.get("solution", [1.0, 0.0, 0.72])
	return Vector2(float(solution[0]), float(solution[1])).normalized()

func show_hint() -> void:
	hint_visible = true
	queue_redraw()
	get_tree().create_timer(2.8).timeout.connect(func():
		hint_visible = false
		queue_redraw()
	)

func _draw_aim_path(direction: Vector2, dots: int, tint: Color) -> void:
	if direction.length_squared() < 0.001:
		return
	var start: Vector2 = hazel.position + direction.normalized() * tuning.shot_spawn_offset
	var direction_n: Vector2 = direction.normalized()
	var distance: float = size.x * 1.5
	aim_cast.collision_mask = 1
	if not projectiles.is_empty() and is_instance_valid(projectiles[0]):
		aim_cast.collision_mask = projectiles[0].collision_mask
	aim_cast.position = start
	aim_cast.target_position = direction_n * distance
	aim_cast.force_shapecast_update()
	var hit: bool = aim_cast.is_colliding()
	var first_end: Vector2 = start + direction_n * distance
	if hit:
		first_end = start + direction_n * distance * aim_cast.get_closest_collision_safe_fraction()
	_draw_dots(start, first_end, dots, tint)
	if hit:
		var normal: Vector2 = aim_cast.get_collision_normal(0)
		var bounce_dir: Vector2 = direction_n.bounce(normal)
		_draw_dots(first_end, first_end + bounce_dir * minf(distance * 0.55, size.x * 0.4), dots / 2, Color(tint, tint.a * 0.72))

func _draw_dots(from: Vector2, to: Vector2, count: int, tint: Color) -> void:
	for index in maxi(2, count):
		draw_circle(from.lerp(to, float(index) / float(maxi(2, count))), 3.1 if index % 2 == 0 else 2.0, tint)

func _gui_input(event: InputEvent) -> void:
	if state != "aiming" or hazel == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and hazel.position.distance_to(mouse.position) < tuning.pointer_pick_radius:
			pointer_active = true
			drag_origin = mouse.position
			accept_event()
		elif not mouse.pressed and pointer_active:
			_release_aim(mouse.position)
			accept_event()
	elif event is InputEventMouseMotion and pointer_active:
		_update_drag(event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and hazel.position.distance_to(touch.position) < tuning.pointer_pick_radius:
			pointer_active = true
			drag_origin = touch.position
			accept_event()
		elif not touch.pressed and pointer_active:
			_release_aim(touch.position)
			accept_event()
	elif event is InputEventScreenDrag and pointer_active:
		_update_drag(event.position)
		accept_event()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if state != "aiming" or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: InputEventKey = event as InputEventKey
	if key.keycode == KEY_LEFT:
		aim_vector = aim_vector.rotated(-0.08)
	elif key.keycode == KEY_RIGHT:
		aim_vector = aim_vector.rotated(0.08)
	elif key.keycode == KEY_UP:
		aim_vector.y = maxf(-0.95, aim_vector.y - 0.08)
	elif key.keycode == KEY_DOWN:
		aim_vector.y = minf(0.85, aim_vector.y + 0.08)
	elif key.keycode == KEY_SPACE:
		fire(aim_vector)
	queue_redraw()

func _update_drag(pointer: Vector2) -> void:
	var pull: Vector2 = hazel.position - pointer
	if pull.length() > tuning.max_drag_power:
		pull = pull.normalized() * tuning.max_drag_power
	aim_vector = pull.normalized() if pull.length() > 10.0 else Vector2.ZERO
	if hazel_sprite != null: hazel_sprite.pose = "aim" if aim_vector != Vector2.ZERO else "idle"
	if hazel_sprite != null: hazel_sprite.queue_redraw()
	queue_redraw()

func _release_aim(pointer: Vector2) -> void:
	_update_drag(pointer)
	var power: float = hazel.position.distance_to(pointer)
	pointer_active = false
	if power <= tuning.minimum_drag_pixels:
		aim_vector = Vector2.ZERO
		queue_redraw()
		return
	fire(aim_vector, power)

func tutorial_drag_is_real(start: Vector2, end: Vector2) -> bool:
	if hazel == null or start.distance_to(end) < 24:
		return false
	var hazel_screen: Vector2 = gameplay_screen_origin()
	return start.distance_to(hazel_screen) <= 82 and (start - end).x > 8

func gameplay_screen_origin() -> Vector2:
	return get_global_transform_with_canvas() * hazel.position

func fire(direction: Vector2, power: float = -1.0) -> void:
	if state != "aiming" or direction.length_squared() < 0.002 or shots_used >= shot_limit:
		return
	_save_snapshot()
	state = "shot_flying"
	if hazel_sprite != null:
		hazel_sprite.pose = "fire"
		hazel_sprite.queue_redraw()
	state_changed.emit(state)
	action_made.emit("shot")
	shots_used += 1
	shots_changed.emit(shots_used)
	var body: RigidBody2D = RigidBody2D.new()
	body.name = "Shot"
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	body.collision_layer = 1
	body.collision_mask = 1
	body.contact_monitor = true
	body.max_contacts_reported = tuning.shot_max_contacts
	body.gravity_scale = tuning.shot_gravity_scale * tuning.gravity / tuning.default_gravity
	body.linear_damp = tuning.shot_linear_damp
	body.angular_damp = tuning.shot_angular_damp
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.bounce = tuning.bounce
	material.friction = 0.0
	body.physics_material_override = material
	var shot_shape: CircleShape2D = CircleShape2D.new()
	shot_shape.radius = tuning.shot_radius
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shot_shape
	body.add_child(collision)
	world.add_child(body)
	body.position = hazel.position + direction.normalized() * tuning.shot_spawn_offset
	_add_sprite(body, "hazel", Color(palette.get("accent", "#e38c55")), Color(palette.get("text", "#241d31")), Color(palette.get("moon", "#f4c95d")))
	var strength: float = tuning.max_drag_power * 0.66 if power < 0 else clampf(power, tuning.minimum_drag_power, tuning.max_drag_power)
	body.apply_central_impulse(direction.normalized() * tuning.shot_speed * strength / tuning.max_drag_power)
	body.body_entered.connect(_on_shot_body_entered.bind(body))
	projectiles.append(body)
	shot_age = 0.0
	settle_age = 0.0
	AudioManager.play_game("shot")
	queue_redraw()

func _on_shot_body_entered(other: Node, shot: RigidBody2D) -> void:
	if not is_instance_valid(shot):
		return
	if other.is_in_group("ghoul"):
		AudioManager.play_game("ghoul_hit")
		if other in ghouls:
			_kill_ghoul(other)
	elif other is RigidBody2D:
		AudioManager.play_game("crate_hit")
	else:
		var now: int = Time.get_ticks_msec()
		if now - _last_bounce_msec > 100:
			_last_bounce_msec = now
			AudioManager.play_game("bounce")

func _create_hit_pop(at: Vector2, death: bool) -> void:
	if death:
		AudioManager.play_game("ghoul_death")

func _on_ghoul_body_entered(body: Node2D, target: Area2D) -> void:
	if body is RigidBody2D:
		AudioManager.play_game("ghoul_hit")
		_kill_ghoul(target)

func _kill_ghoul(target: Area2D) -> void:
	if not is_instance_valid(target) or not ghouls.has(target):
		return
	ghouls.erase(target)
	_create_hit_pop(target.global_position, true)
	var ghoul_sprite: Node2D = target.get_child(1) as Node2D if target.get_child_count() > 1 else null
	if ghoul_sprite != null:
		ghoul_sprite.pose = "hit"
		ghoul_sprite.queue_redraw()
	var collision: CollisionShape2D = target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null: collision.disabled = true
	var death_tween: Tween = create_tween()
	death_tween.tween_property(target, "scale", Vector2.ZERO, 0.24)
	death_tween.parallel().tween_property(target, "modulate:a", 0.0, 0.24)
	death_tween.tween_callback(target.queue_free)
	target_removed.emit()

func _physics_process(delta: float) -> void:
	if state != "shot_flying" and state != "settling":
		return
	shot_age += delta
	if shot_age >= tuning.shot_lifetime:
		for projectile in projectiles:
			if is_instance_valid(projectile): projectile.queue_free()
		projectiles.clear()
		_finish_shot()
		return
	var moving: bool = false
	for projectile in projectiles.duplicate():
		if not is_instance_valid(projectile):
			projectiles.erase(projectile)
			continue
		for ghoul in ghouls.duplicate():
			if is_instance_valid(ghoul) and projectile.position.distance_to(ghoul.position) <= tuning.ghoul_radius + tuning.shot_radius + tuning.ghoul_hit_padding:
				_kill_ghoul(ghoul)
		var slow_enough: bool = projectile.linear_velocity.length() < tuning.shot_stop_speed
		var slow_time: float = float(projectile.get_meta("slow_time", 0.0))
		slow_time = slow_time + delta if slow_enough else 0.0
		projectile.set_meta("slow_time", slow_time)
		if shot_age >= tuning.shot_lifetime or slow_time >= 1.0:
			projectile.queue_free()
			projectiles.erase(projectile)
		else:
			moving = true
	for crate in crates:
		if is_instance_valid(crate) and crate.linear_velocity.length() > tuning.crate_stop_speed:
			moving = true
	if not moving:
		state = "settling"
		settle_age += delta
		state_changed.emit(state)
		if settle_age >= tuning.settle_time or shot_age >= tuning.shot_lifetime and shots_used >= shot_limit:
			_finish_shot()
	elif shot_age >= tuning.shot_lifetime:
		_finish_shot()

func _finish_shot() -> void:
	if state == "win" or state == "try_again":
		return
	state = "settling"
	if not ghouls.is_empty() and shots_used < shot_limit:
		state = "aiming"
		state_changed.emit(state)
		return
	if ghouls.is_empty():
		state = "win"
		AudioManager.play_game("win")
	else:
		state = "try_again"
		AudioManager.play_game("try_again")
	state_changed.emit(state)

func _save_snapshot() -> void:
	var positions: Array[Vector2] = []
	for target in ghouls:
		if is_instance_valid(target): positions.append(target.position)
	var crate_positions: Array[Dictionary] = []
	for crate in crates:
		if is_instance_valid(crate): crate_positions.append({"position": crate.position, "rotation": crate.rotation, "velocity": crate.linear_velocity, "angular_velocity": crate.angular_velocity})
	_snapshot = {"targets": positions, "crates": crate_positions, "shots_used": shots_used}

func undo() -> bool:
	if _snapshot.is_empty():
		return false
	var targets: Array = _snapshot.get("targets", [])
	var crate_points: Array = _snapshot.get("crates", [])
	var prior_shots: int = int(_snapshot.get("shots_used", 0))
	_build_level()
	for index in mini(targets.size(), ghouls.size()):
		ghouls[index].position = targets[index]
	for index in mini(crate_points.size(), crates.size()):
		var saved_crate: Dictionary = crate_points[index]
		crates[index].position = saved_crate["position"]
		crates[index].rotation = float(saved_crate["rotation"])
		crates[index].linear_velocity = saved_crate["velocity"]
		crates[index].angular_velocity = float(saved_crate["angular_velocity"])
	shots_used = prior_shots
	shots_changed.emit(shots_used)
	_snapshot.clear()
	action_made.emit("undo")
	return true

func restart() -> void:
	shots_used = 0
	_snapshot.clear()
	_build_level()
	if hazel_sprite != null:
		hazel_sprite.pose = "idle"
	shots_changed.emit(shots_used)
	action_made.emit("restart")

func get_aim_origin() -> Vector2:
	return hazel.position if hazel != null else size * Vector2(0.16, 0.66)

func get_stars() -> int:
	if shots_used <= par_three: return 3
	if shots_used <= par_two: return 2
	return 1

func get_solution_line() -> PackedVector2Array:
	var result := PackedVector2Array()
	if hazel == null: return result
	var dir: Vector2 = _solution_vector()
	var start: Vector2 = hazel.position + dir * tuning.shot_spawn_offset
	var distance: float = size.x * 1.5
	aim_cast.collision_mask = 1
	if not projectiles.is_empty() and is_instance_valid(projectiles[0]):
		aim_cast.collision_mask = projectiles[0].collision_mask
	aim_cast.position = start
	aim_cast.target_position = dir * distance
	aim_cast.force_shapecast_update()
	var hit: bool = aim_cast.is_colliding()
	var end: Vector2 = start + dir * distance
	if hit: end = start + dir * distance * aim_cast.get_closest_collision_safe_fraction()
	result.append(start); result.append(end)
	if hit: result.append(end + dir.bounce(aim_cast.get_collision_normal(0)) * distance * 0.44)
	return result
