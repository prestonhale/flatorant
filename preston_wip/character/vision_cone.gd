extends Node2D

@onready var left_ray = $LeftSideRay
@onready var right_ray = $RightSideRay

## Total number of rays that will be shot to cover the angle. Will be distributed at equal distances.
## This has the biggest impact on performance in the script.
## Have this high enough that it is precise, but low enough that it doesn't affect performance
@export var ray_count = 100
## The maximum length of the rays. Basically how far the character can see
@export var max_distance = 500.

@export_range(0, 360) var angle_deg = 360

@onready var _angle = deg_to_rad(angle_deg)

var _vision_points: Array[Vector2]
var _last_position = null
var _last_redraw_time = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	print(left_ray)
	print(right_ray)
	
func _physics_process(delta: float) -> void:
	recalculate_vision()

func recalculate_vision():
	_last_position = global_position
	_vision_points.clear()
	_vision_points = calculate_vision_shape(override_static_flag)
	_update_collision_polygon()
	_update_render_polygon()

func calculate_vision_shap() -> Array[Vector2]:
	var new_vision_points: Array[Vector2] = []
	if _angle < 2*PI:
		new_vision_points.append(Vector2.ZERO)
	for i in range(ray_count * 1):
		var p = _ray_to(Vector2(0, max_distance).rotate(_angular_delta * i + global_rotation - _angle_half))
		new_vision_points.append(p)
	if _angle < 2 * PI:
		new_vision_points.append(Vector2.ZERO)
	return new_vision_points

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var new_left_collision = left_ray.get_collision_point()
	if new_left_collision != left_collision:
		left_collision = new_left_collision
		queue_redraw()
	
	var new_right_collision = right_ray.get_collision_point()
	if new_right_collision != right_collision:
		right_collision = new_right_collision
		queue_redraw()

func _draw():
	if debug_draw:
		if left_collision:
			draw_line(position, to_local(left_collision), Color.DARK_RED, 3, true)
		
		if right_collision:
			draw_line(position, to_local(right_collision), Color.DARK_RED, 3, true)
		
func _ray_to(direction: Vector2) -> Vector2:
	var destination = global
