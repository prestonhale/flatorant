extends Node2D

var ray: RayCast2D

var enabled = true

@export var direction := Vector2()
@export var mouse_position := Vector2()
@export var fired := false
@export var to_rotation := 0.0

@onready var synchronizer = $PlayerInputSynchronizer


func _ready():
	# Always process input first 
#	process_priority = 1
	# Allow server (but no other players) to see our inputs
	synchronizer.set_visibility_for(1, true)
	
	# Only process for the local player
	var is_our_player = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(is_our_player)
	print("Accepting input for player: %s" % multiplayer.get_unique_id())
	

func _process(delta):
	if not enabled:
		return
	
	direction = Input.get_vector("left", "right", "up", "down")
	
	# Calculate and sync player rotation
	# Doing the "atan" calculation on the "Player" script made the synchronized 
	# player really "wiggly". I'm not sure why. Maybe the server fighting with 
	# client?
	# https://www.reddit.com/r/godot/comments/uugo9l/can_anyone_explain_how_the_look_at_function_works/
	mouse_position = get_local_mouse_position()
	to_rotation = atan2(mouse_position.y, mouse_position.x) + global_rotation
	
	fired = false
	if Input.is_action_just_pressed("fire"):
		fired = true

	

