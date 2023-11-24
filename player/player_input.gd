extends Node2D

var ray: RayCast2D

var enabled = false

@export var direction := Vector2()
@export var mouse_position := Vector2()
@export var fired := false
@export var to_rotation := 0.0

#var frame_time: float = 0
#var desired_frame_time: float = 16.66 # 1000ms / 60 ticks
#var desired_frame_time: float = 100 # Slow server for testing
var current_frame: int = 0

var simulation: Simulation


func _ready():
	# Always process input first 
	process_priority = 0
	
	# Only process for the local player
	var is_our_player = get_multiplayer_authority() == multiplayer.get_unique_id()
	if not is_our_player:
		return
	
	print("Accepting input for player: %s" % multiplayer.get_unique_id())
	enabled = true
	

func _physics_process(delta: float):
#	print("INFO: Player %s sending input for frame %d" % [get_parent().player, current_frame])
	send_player_input(delta)
	current_frame += 1

func send_player_input(delta: float):
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
		
	fired = false
	if Input.is_action_pressed("fire"):
		fired = true
	
	var player_input = {
		"player_id": get_parent().player,
		"current_frame": current_frame,
		"direction": direction,
		"rotation": to_rotation,
		"fired": fired
	}
		
	# Update our local simulation
#	print("INFO: Sending input for player %s at local frame %s" % [get_parent().player, current_frame])
	simulation.local_player_input(player_input)

	# Tell the server about our inputs
	if not multiplayer.is_server():
		simulation.accept_player_input.rpc_id(1, player_input)

