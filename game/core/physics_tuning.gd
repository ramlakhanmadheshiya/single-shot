extends Resource
class_name PhysicsTuning

@export var gravity: float = 980.0
@export var default_gravity: float = 980.0
@export var shot_speed: float = 820.0
@export_range(0.0, 1.0) var bounce: float = 0.78
@export_range(0.0, 2.0) var shot_gravity_scale: float = 0.0
@export var shot_lifetime: float = 6.0
@export var max_drag_power: float = 460.0
@export var shot_radius: float = 11.0
@export var ghoul_radius: float = 23.0
@export var crate_edge: float = 44.0
@export var shot_linear_damp: float = 0.12
@export var shot_angular_damp: float = 1.0
@export var shot_stop_speed: float = 42.0
@export var crate_stop_speed: float = 18.0
@export var settle_time: float = 0.45
@export var last_shot_wait: float = 5.0
@export var floor_height: float = 0.91
@export var floor_width: float = 0.96
@export var floor_thickness: float = 24.0
@export var crate_mass: float = 1.0
@export var shot_offscreen_margin: float = 70.0
@export var minimum_drag_power: float = 80.0
@export var minimum_drag_pixels: float = 10.0
@export var shot_spawn_offset: float = 34.0
@export var pointer_pick_radius: float = 75.0
@export var shot_max_contacts: int = 8
@export var shot_friction: float = 0.05
@export var shot_min_motion_time: float = 0.65
@export var ghoul_hit_padding: float = 3.0
