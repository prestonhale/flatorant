extends Node2D

class_name PlayerInput

var ray: RayCast2D

var enabled = false

@export var direction := Vector2()
@export var mouse_position := Vector2()
@export var fired := false
@export var to_rotation := 0.0

var simulation: Simulation

enum held_selection {
	LARGE_GUN,
	SMALL_GUN
}

func _ready():
	# Always process input first 
	process_priority = 0
	
	# Only process for the local player
	var is_our_player = get_multiplayer_authority() == multiplayer.get_unique_id()
	if not is_our_player:
		return
	

func _physics_process(delta: float):
#	print("INFO: Player %s sending input for frame %d" % [get_parent().player, current_frame])
	send_player_input(delta)

func server_acknowledge():
	print("Accepting input for player: %s" % multiplayer.get_unique_id())
	enabled = true

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
	
	var held = null
	if Input.is_action_pressed("select_large_gun"):
		held = held_selection.LARGE_GUN
	elif Input.is_action_pressed("select_small_gun"):
		held = held_selection.SMALL_GUN
	
	var player_input = {
		"player_id": get_parent().player,
		"current_frame": simulation.current_frame,
		"direction": direction,
		"rotation": to_rotation,
		"fired": fired,
		"time": Time.get_ticks_msec(),
		"change_held": held
	}
		
	# Update our local simulation
#	print("INFO: Sending input for player %s at local frame %s" % [get_parent().player, current_frame])
	simulation.accept_player_input(player_input)

	# Tell the server about our inputs
	if not multiplayer.is_server():
		simulation.accept_player_input.rpc_id(1, player_input)

