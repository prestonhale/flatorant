extends Node2D

var ray: RayCast2D

var enabled = true

@export var direction := Vector2()
@export var mouse_position := Vector2()
@export var fired := false
@export var to_rotation := 0.0

var frame_time: float = 0
#var desired_frame_time: float = 16.66 # 1000ms / 60 ticks
var desired_frame_time: float = 100 # Slow server for testing
var frame_count: int = 0

var simulation: Simulation


func _ready():
	# Always process input first 
#	process_priority = 1
	
	# Only process for the local player
	print(get_multiplayer_authority())
	print(multiplayer.get_unique_id())
	var is_our_player = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(is_our_player)
	if is_our_player:
		print("Accepting input for player: %s" % multiplayer.get_unique_id())
	

func _process(delta: float):
	if not enabled:
		return
		
	var new_direction = Input.get_vector("left", "right", "up", "down")
	if new_direction != direction:
		direction = new_direction
		
	# https://www.reddit.com/r/godot/comments/uugo9l/can_anyone_explain_how_the_look_at_function_works/
	mouse_position = get_local_mouse_position()
	var new_to_rotation = atan2(mouse_position.y, mouse_position.x) + global_rotation
	if new_to_rotation != to_rotation:
		to_rotation = new_to_rotation
	
	frame_time += (delta * 1000)
	if frame_time > desired_frame_time:
		
		simulation.change_direction.rpc_id(1, frame_count, direction)
		simulation.change_rotation.rpc_id(1, frame_count, to_rotation)
		
		frame_count += 1
		frame_time = frame_time - desired_frame_time
	
	fired = false
	if Input.is_action_just_pressed("fire"):
		fired = true
		simulation.fire_gun.rpc(frame_count)

	

