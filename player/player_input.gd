extends Node2D

var ray: RayCast2D

var enabled = true

@export var direction := Vector2()
@export var mouse_position := Vector2()
@export var fired := false
@export var to_rotation := 0.0

@onready var synchronizer = $PlayerInputSynchronizer

var frame_time: float = 0
var desired_frame_time: float = 7.8 # 1000ms / 128 ticks
#var desired_frame_time: float = 100 # Slow server for testing
var frame_count: int = 0

var last_sent_rotation
var last_sent_direction

var simulation: Simulation


func _ready():
	# Always process input first 
#	process_priority = 1
	# Allow server (but no other players) to see our inputs
	synchronizer.set_visibility_for(1, true)
	
	# Only process for the local player
	var is_our_player = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(is_our_player)
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
		if last_sent_direction != direction:
			simulation.change_direction.rpc(frame_count, direction)
			last_sent_direction = direction
		if last_sent_rotation != to_rotation:
			print(to_rotation)
			simulation.change_rotation.rpc(frame_count, to_rotation)
			last_sent_rotation = to_rotation
		frame_count += 1
		frame_time = frame_time - desired_frame_time
	
	fired = false
	if Input.is_action_just_pressed("fire"):
		fired = true
		simulation.fire_gun.rpc(frame_count)

	

